import { createClient } from "npm:@supabase/supabase-js@2";
import { createHash } from "node:crypto";

const DEFAULT_START = "2026-08-26";
const DEFAULT_END = "2026-09-25";

function allowedOrigin(request: Request) {
  const origin = request.headers.get("origin") || "";
  if (origin === "https://stepoil-debug.github.io") return origin;
  if (origin === "https://intranet.step-og.com") return origin;
  if (/^https:\/\/[^/]+\.vercel\.app$/i.test(origin)) return origin;
  if (/^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(origin)) return origin;
  return "https://stepoil-debug.github.io";
}
function cors(request: Request) {
  return {
    "Access-Control-Allow-Origin": allowedOrigin(request),
    "Access-Control-Allow-Headers": "authorization,content-type",
    "Access-Control-Allow-Methods": "POST,OPTIONS",
    "Cache-Control": "no-store, max-age=0",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "Vary": "Origin",
  };
}
function json(request: Request, body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors(request), "Content-Type": "application/json; charset=utf-8" },
  });
}
function hash(value: string) {
  return createHash("sha256").update(value).digest("hex");
}
function bearer(request: Request) {
  const value = request.headers.get("authorization") || "";
  return value.startsWith("Bearer ") ? value.slice(7).trim() : "";
}
function validDate(value: unknown, fallback: string) {
  const text = typeof value === "string" ? value.trim() : "";
  return /^\d{4}-\d{2}-\d{2}$/.test(text) ? text : fallback;
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors(request) });
  if (request.method !== "POST") return json(request, { ok: false, error: "Use POST." }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return json(request, { ok: false, error: "Backend não configurado." }, 503);

  const token = bearer(request);
  if (!token) return json(request, { ok: false, error: "Sessão ausente." }, 401);

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: sessionUser, error: sessionError } = await admin.rpc("ops_panel_session_validate", {
    p_token_hash: hash(token),
  });
  if (sessionError || !sessionUser) return json(request, { ok: false, error: "Sessão inválida ou expirada." }, 401);

  let body: Record<string, unknown> = {};
  try { body = await request.json(); } catch { body = {}; }
  if (String(body.action || "dashboard") !== "dashboard") {
    return json(request, { ok: false, error: "Ação inválida." }, 400);
  }

  const periodStart = validDate(body.periodStart, DEFAULT_START);
  const periodEnd = validDate(body.periodEnd, DEFAULT_END);

  const [executionRes, reconciliationRes, bmsRes, contextRes] = await Promise.all([
    admin.from("medicao_live_execution").select("*")
      .gte("work_date", periodStart).lte("work_date", periodEnd)
      .order("bsp_raw").order("work_date").order("employee_name"),
    admin.from("medicao_live_reconciliation").select("*")
      .gte("work_date", periodStart).lte("work_date", periodEnd)
      .order("bsp_raw").order("work_date").order("employee_name"),
    admin.from("medicao_live_bms").select("*").order("bsp").order("sent_pm_date"),
    admin.from("medicao_live_context").select("*").order("canonical_bsp"),
  ]);

  const error = executionRes.error || reconciliationRes.error || bmsRes.error || contextRes.error;
  if (error) {
    console.error("[medicao-panel-api]", error);
    return json(request, { ok: false, error: "Não foi possível carregar os dados de medição." }, 500);
  }

  return json(request, {
    ok: true,
    periodStart,
    periodEnd,
    user: sessionUser,
    execution: executionRes.data || [],
    reconciliation: reconciliationRes.data || [],
    bms: bmsRes.data || [],
    context: contextRes.data || [],
  });
});