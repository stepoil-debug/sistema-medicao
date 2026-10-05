(() => {
  const SUPABASE_URL = 'https://qxmxtbjxkhecqilpnhgq.supabase.co';
  const PUBLISHABLE_KEY = 'sb_publishable_TiGdrzZ6H7TCjQ8wPaAkzA_cQxVxdvr';
  const PERIOD_START = '2026-08-26';
  const PERIOD_END = '2026-09-25';
  const PERIOD_M0 = 7;
  const SESSION_KEY = 'step_medicao_session_v1';

  const publicHeaders = {
    apikey: PUBLISHABLE_KEY,
    'Content-Type': 'application/json'
  };

  function readSession() {
    try { return JSON.parse(localStorage.getItem(SESSION_KEY) || 'null'); }
    catch (_) { return null; }
  }
  function writeSession(session) {
    localStorage.setItem(SESSION_KEY, JSON.stringify({
      access_token: session.access_token,
      refresh_token: session.refresh_token,
      expires_at: session.expires_at || null,
      user: session.user ? { id: session.user.id, email: session.user.email } : null
    }));
  }
  function clearSession() {
    localStorage.removeItem(SESSION_KEY);
  }

  async function authRequest(path, options = {}) {
    const response = await fetch(SUPABASE_URL + '/auth/v1/' + path, {
      ...options,
      headers: { ...publicHeaders, ...(options.headers || {}) }
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(data.msg || data.message || data.error_description || ('HTTP ' + response.status));
    return data;
  }

  async function verifySession(session) {
    if (!session?.access_token) return null;
    try {
      const user = await authRequest('user', { headers: { Authorization: 'Bearer ' + session.access_token } });
      return { ...session, user };
    } catch (_) {
      return null;
    }
  }

  async function refreshSession(session) {
    if (!session?.refresh_token) return null;
    try {
      const fresh = await authRequest('token?grant_type=refresh_token', {
        method: 'POST',
        body: JSON.stringify({ refresh_token: session.refresh_token })
      });
      writeSession(fresh);
      return fresh;
    } catch (_) {
      clearSession();
      return null;
    }
  }

  function loginScreen() {
    return new Promise(resolve => {
      document.body.innerHTML = '';
      document.body.style.margin = '0';
      document.body.style.background = '#F4F8FB';
      document.body.style.fontFamily = "'IBM Plex Sans', Arial, sans-serif";

      const root = document.createElement('div');
      root.style.cssText = 'min-height:100vh;display:flex;align-items:center;justify-content:center;padding:24px;background:#F4F8FB;';
      root.innerHTML = `
        <form id="step-login-form" style="width:100%;max-width:390px;background:#fff;border:1px solid #E1E9F4;border-radius:20px;padding:28px;box-shadow:0 18px 50px rgba(11,35,64,.10)">
          <div style="font-size:11px;font-weight:700;letter-spacing:.14em;text-transform:uppercase;color:#1E86D8">STEP · Sistema de Medição</div>
          <div style="font-size:26px;font-weight:700;color:#0B2340;margin:8px 0 6px">Acesso restrito</div>
          <div style="font-size:13px;line-height:1.5;color:#5B7185;margin-bottom:22px">Entre com o usuário autorizado do Supabase para acessar RDO, Timesheet e dados reais de medição.</div>
          <label style="display:block;font-size:12px;font-weight:600;color:#425B73;margin-bottom:6px">E-mail</label>
          <input id="step-login-email" type="email" autocomplete="username" required style="width:100%;height:42px;border:1px solid #DCE5EE;border-radius:10px;padding:0 12px;margin-bottom:14px;outline:none">
          <label style="display:block;font-size:12px;font-weight:600;color:#425B73;margin-bottom:6px">Senha</label>
          <input id="step-login-password" type="password" autocomplete="current-password" required style="width:100%;height:42px;border:1px solid #DCE5EE;border-radius:10px;padding:0 12px;margin-bottom:16px;outline:none">
          <button id="step-login-submit" type="submit" style="width:100%;height:42px;border:0;border-radius:11px;background:linear-gradient(100deg,#0E4AA8,#1E86D8);color:#fff;font-weight:600;cursor:pointer">Entrar</button>
          <div id="step-login-error" style="min-height:18px;margin-top:12px;font-size:12px;color:#C43232"></div>
        </form>`;
      document.body.appendChild(root);

      const form = document.getElementById('step-login-form');
      const error = document.getElementById('step-login-error');
      const button = document.getElementById('step-login-submit');
      form.addEventListener('submit', async event => {
        event.preventDefault();
        error.textContent = '';
        button.disabled = true;
        button.textContent = 'Entrando…';
        try {
          const email = document.getElementById('step-login-email').value.trim();
          const password = document.getElementById('step-login-password').value;
          const session = await authRequest('token?grant_type=password', {
            method: 'POST',
            body: JSON.stringify({ email, password })
          });
          writeSession(session);
          resolve(session);
        } catch (e) {
          error.textContent = 'Não foi possível entrar: ' + (e.message || String(e));
          button.disabled = false;
          button.textContent = 'Entrar';
        }
      });
    });
  }

  async function ensureSession() {
    let session = readSession();
    let verified = await verifySession(session);
    if (verified) return verified;
    session = await refreshSession(session);
    verified = await verifySession(session);
    if (verified) return verified;
    return loginScreen();
  }

  async function get(table, query, accessToken) {
    const response = await fetch(SUPABASE_URL + '/rest/v1/' + table + '?' + query, {
      headers: {
        apikey: PUBLISHABLE_KEY,
        Authorization: 'Bearer ' + accessToken
      }
    });
    if (response.status === 401) {
      clearSession();
      throw new Error('Sessão expirada. Recarregue a página para entrar novamente.');
    }
    if (!response.ok) throw new Error(table + ': HTTP ' + response.status);
    return response.json();
  }

  const n = value => {
    const x = Number(value);
    return Number.isFinite(x) ? x : 0;
  };
  const uniq = values => [...new Set(values.filter(v => v !== null && v !== undefined && String(v).trim() !== ''))];
  const arr = value => Array.isArray(value) ? value : [];
  const key = value => String(value || '').trim().toUpperCase();
  const isoDay = value => Date.parse(value + 'T00:00:00Z');
  const dayIndex = date => Math.round((isoDay(date) - isoDay(PERIOD_START)) / 86400000);

  async function get(table, query) {
    const response = await fetch(SUPABASE_URL + '/rest/v1/' + table + '?' + query, { headers });
    if (!response.ok) throw new Error(table + ': HTTP ' + response.status);
    return response.json();
  }

  function linkRank(status) {
    return ({ UNRESOLVED_BSP: 4, CLIENT_MISMATCH: 3, CONTEXT_CONFLICT: 2, LINKED: 1 })[status] || 0;
  }
  function worstLink(rows) {
    return rows.map(r => r.link_status).sort((a, b) => linkRank(b) - linkRank(a))[0] || 'UNRESOLVED_BSP';
  }
  function linkLabel(status) {
    return ({
      LINKED: 'Vínculo confirmado',
      CONTEXT_CONFLICT: 'Contexto conflitante',
      CLIENT_MISMATCH: 'Cliente divergente',
      UNRESOLVED_BSP: 'BSP não resolvida'
    })[status] || status || 'Não verificado';
  }
  function regimeLabel(value) {
    return ({
      ONSHORE: 'Onshore',
      OFFSHORE: 'Offshore',
      CONFLITANTE: 'Onshore/Offshore conflitante',
      NOT_VERIFIED: 'Regime a confirmar'
    })[value] || 'Regime a confirmar';
  }
  function mapBmStatus(raw) {
    const s = String(raw || '').toLowerCase();
    if (s.includes('cancel')) return 'Rascunho';
    if (s.includes('faturamento')) return 'Aprovado';
    if (s.includes('engenheiro') || s.includes('cliente')) return 'Enviado ao cliente';
    if (s.includes('aprov')) return 'Aprovado';
    if (s.includes('pm')) return 'Revisão PM';
    return 'Rascunho';
  }
  function eventDate(bm) {
    return bm.sent_pm_date || bm.sent_client_date || bm.approval_date || bm.sent_billing_date || '1900-01-01';
  }
  function selectCurrentBm(rows) {
    if (!rows.length) return null;
    const cutoff = isoDay(PERIOD_END) + 10 * 86400000;
    const eligible = rows.filter(r => isoDay(eventDate(r)) <= cutoff);
    const list = eligible.length ? eligible : rows;
    return list.slice().sort((a, b) => {
      const d = isoDay(eventDate(b)) - isoDay(eventDate(a));
      if (d) return d;
      return n(String(b.bm_number || '').replace(',', '.')) - n(String(a.bm_number || '').replace(',', '.'));
    })[0];
  }
  function currentPoEmit(bm) {
    if (!bm) return 0;
    if (bm.po_balance !== null && bm.po_balance !== undefined && bm.po_value !== null && bm.po_value !== undefined) {
      return Math.max(0, n(bm.po_value) - n(bm.bm_value) - n(bm.po_balance));
    }
    if (bm.bms_accumulated !== null && bm.bms_accumulated !== undefined) {
      return Math.max(0, n(bm.bms_accumulated) - n(bm.bm_value));
    }
    return n(bm.total_billed);
  }

  function buildProject(rows, bms) {
    const bspRaw = rows[0].bsp_raw;
    const canonical = rows.find(r => r.canonical_bsp)?.canonical_bsp || null;
    const exactBmBsp = canonical || (/^\d{2}-\d+/.test(bspRaw) ? bspRaw : null);
    const bmRows = exactBmBsp ? bms.filter(b => b.bsp === exactBmBsp) : [];
    const currentBm = selectCurrentBm(bmRows);

    const client = uniq(rows.map(r => r.source_client_name))[0] || uniq(rows.flatMap(r => arr(r.context_clients)))[0] || '—';
    const location = uniq(rows.map(r => r.location))[0] || uniq(rows.flatMap(r => arr(r.context_units)))[0] || '—';
    const regime = rows.map(r => r.work_regime).find(v => v && v !== 'NOT_VERIFIED') || rows[0].work_regime || 'NOT_VERIFIED';
    const linkStatus = worstLink(rows);
    const services = uniq(rows.flatMap(r => arr(r.service_types)));
    const pms = uniq(rows.flatMap(r => arr(r.pms)));
    const purchaseOrders = uniq(rows.flatMap(r => arr(r.purchase_orders)));

    const personMap = new Map();
    for (const row of rows) {
      const pk = key(row.employee_name) + '|' + key(row.employee_function);
      if (!personMap.has(pk)) personMap.set(pk, []);
      personMap.get(pk).push(row);
    }

    const people = [...personMap.values()].map(group => {
      const first = group[0];
      const dates = uniq(group.map(r => r.work_date))
        .map(d => ({ d, i: dayIndex(d) }))
        .filter(x => x.i >= 0 && x.i < 31)
        .sort((a, b) => a.i - b.i);
      const spec = dates.map(x => ['R', x.i]);
      const otDays = uniq(group.filter(r => n(r.overtime_hours) > 0).map(r => dayIndex(r.work_date)))
        .filter(i => i >= 0 && i < 31)
        .sort((a, b) => a - b);
      return {
        name: first.employee_name,
        role: first.employee_function || 'Função não informada',
        spec,
        otDays,
        normalHours: group.reduce((s, r) => s + n(r.normal_hours), 0),
        overtimeHours: group.reduce((s, r) => s + n(r.overtime_hours), 0),
        totalHours: group.reduce((s, r) => s + n(r.total_hours), 0)
      };
    });

    const realRows = rows.map(r => ({
      name: r.employee_name,
      role: r.employee_function || 'Função não informada',
      workDate: r.work_date,
      normalHours: n(r.normal_hours),
      overtimeHours: n(r.overtime_hours),
      totalHours: n(r.total_hours),
      approved: !!r.source_approved,
      sourceStatus: r.source_status,
      parentStatus: r.parent_status,
      task: r.task_description || '',
      protocol: r.protocol || ''
    }));

    const bmNumber = currentBm?.bm_number || '—';
    const bmStatus = currentBm ? mapBmStatus(currentBm.bm_status) : 'Rascunho';
    const po = currentBm?.po_ref || currentBm?.po_billing || purchaseOrders[0] || 'não informada';
    const poVal = n(currentBm?.po_value);
    const bmValue = n(currentBm?.bm_value);
    const emit = currentPoEmit(currentBm);
    const pm = currentBm?.pm_name || pms[0] || '—';
    const sections = {
      __total: bmValue,
      __rawStatus: currentBm?.bm_status || 'Sem BM no BM Control',
      diarias: n(currentBm?.manpower_value),
      horas: 0,
      logistica: n(currentBm?.logistics_value),
      mob: n(currentBm?.mob_demob_value),
      habitat: 0,
      rentals: n(currentBm?.rental_value),
      consumiveis: 0
    };

    const name = (services.length ? services.join(' + ') : 'Execução operacional') + ' · ' + linkLabel(linkStatus);
    const unitWithRegime = location + ' · ' + regimeLabel(regime);
    const allApproved = rows.length > 0 && rows.every(r => !!r.source_approved);
    const dateBr = value => value ? value.slice(8,10) + '/' + value.slice(5,7) + '/' + value.slice(0,4) : '—';
    const bmMeta = {
      sentPm: currentBm?.sent_pm_date || null,
      sentPmLabel: dateBr(currentBm?.sent_pm_date),
      sentClient: currentBm?.sent_client_date || null,
      sentClientLabel: dateBr(currentBm?.sent_client_date),
      approval: currentBm?.approval_date || null,
      approvalLabel: dateBr(currentBm?.approval_date),
      sentBilling: currentBm?.sent_billing_date || null,
      sentBillingLabel: dateBr(currentBm?.sent_billing_date)
    };

    return {
      n: bspRaw,
      canonical,
      nome: name,
      cli: client,
      un: unitWithRegime,
      pm,
      po,
      poVal,
      bm: bmNumber,
      bmValue,
      emit,
      st: bmStatus,
      currentBmRawStatus: currentBm?.bm_status || 'Sem BM no BM Control',
      regime,
      regimeLabel: regimeLabel(regime),
      linkStatus,
      linkLabel: linkLabel(linkStatus),
      sourceApproved: allApproved,
      bmMeta,
      pessoas: people.map(p => [p.name, p.role, null, p.spec]),
      equipe: people.map(p => [p.name, p.role, null]),
      horas: people.filter(p => p.overtimeHours > 0).map(p => [p.name, p.role, 'HE', p.otDays, p.overtimeHours, null]),
      normalHours: rows.reduce((s, r) => s + n(r.normal_hours), 0),
      overtimeHours: rows.reduce((s, r) => s + n(r.overtime_hours), 0),
      totalHours: rows.reduce((s, r) => s + n(r.total_hours), 0),
      realRows,
      bms: [[bmNumber, PERIOD_M0, bmStatus, sections]],
      ferr: [],
      reemb: [],
      logistica: [],
      rentals: [],
      consumiveis: [],
      periodo: '26/08 a 25/09/2026',
      real: true
    };
  }

  function buildData(execution, reconciliation, bms) {
    const byBsp = new Map();
    for (const row of execution) {
      if (!byBsp.has(row.bsp_raw)) byBsp.set(row.bsp_raw, []);
      byBsp.get(row.bsp_raw).push(row);
    }
    const projects = [...byBsp.values()].map(rows => buildProject(rows, bms))
      .sort((a, b) => String(a.n).localeCompare(String(b.n), 'pt-BR', { numeric: true }));
    return {
      periodStart: PERIOD_START,
      periodEnd: PERIOD_END,
      fetchedAt: new Date().toISOString(),
      areaBsps: projects,
      medicaoBsps: projects,
      reconciliation
    };
  }


  function loadRuntime() {
    const script = document.createElement('script');
    script.src = './support.js';
    script.async = false;
    document.head.appendChild(script);
  }

  async function start() {
    if (document.readyState === 'loading') {
      await new Promise(resolve => document.addEventListener('DOMContentLoaded', resolve, { once: true }));
    }

    const originalBody = document.body.innerHTML;
    const session = await ensureSession();

    // O login substitui temporariamente o body; restauramos o layout original antes do runtime.
    if (!document.querySelector('x-dc')) document.body.innerHTML = originalBody;

    const [execution, reconciliation, bms] = await Promise.all([
      get('medicao_live_execution', 'select=*&work_date=gte.' + PERIOD_START + '&work_date=lte.' + PERIOD_END + '&order=bsp_raw.asc,work_date.asc,employee_name.asc', session.access_token),
      get('medicao_live_reconciliation', 'select=*&work_date=gte.' + PERIOD_START + '&work_date=lte.' + PERIOD_END + '&order=bsp_raw.asc,work_date.asc,employee_name.asc', session.access_token),
      get('medicao_live_bms', 'select=*&order=bsp.asc,sent_pm_date.asc', session.access_token)
    ]);

    window.STEP_LIVE_DATA = buildData(execution, reconciliation, bms);
    window.STEP_LIVE_SESSION = { email: session.user?.email || null };
    window.STEP_LOGOUT = () => { clearSession(); location.reload(); };
    window.STEP_LIVE_ERROR = null;
    loadRuntime();
  }

  start().catch(error => {
    console.error('[STEP live data]', error);
    document.body.innerHTML = '<div style="padding:32px;font-family:Arial;color:#8A1C1C"><strong>Falha ao carregar o painel.</strong><br>' +
      String(error.message || error) + '</div>';
    window.STEP_LIVE_ERROR = error.message || String(error);
  });
})();