(() => {
  const SUPABASE_URL = 'https://qxmxtbjxkhecqilpnhgq.supabase.co';
  const AUTH_URL = SUPABASE_URL + '/functions/v1/ops-panel-auth';
  const DATA_URL = SUPABASE_URL + '/functions/v1/medicao-panel-api';
  const PERIOD_START = '2026-08-26';
  const PERIOD_END = '2026-09-25';
  const PERIOD_M0 = 7;
  const SESSION_KEY = 'step_medicao_intranet_session_v1';

  function readSession() {
    try {
      const session = JSON.parse(localStorage.getItem(SESSION_KEY) || 'null');
      if (!session || !session.token) return null;
      if (session.expiresAt && Date.parse(session.expiresAt) <= Date.now()) {
        localStorage.removeItem(SESSION_KEY);
        return null;
      }
      return session;
    } catch (_) {
      return null;
    }
  }

  function writeSession(session) {
    localStorage.setItem(SESSION_KEY, JSON.stringify({
      token: session.token,
      expiresAt: session.expiresAt || null,
      user: session.user || null
    }));
  }

  function clearSession() {
    localStorage.removeItem(SESSION_KEY);
  }

  async function postJson(url, body, token) {
    const response = await fetch(url, {
      method: 'POST',
      cache: 'no-store',
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: 'Bearer ' + token } : {})
      },
      body: JSON.stringify(body)
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok || data.ok === false) {
      const error = new Error(data.error || ('HTTP ' + response.status));
      error.status = response.status;
      throw error;
    }
    return data;
  }

  async function validateSession(session) {
    if (!session?.token) return null;
    try {
      const data = await postJson(AUTH_URL, { action: 'session' }, session.token);
      return { ...session, user: data.user || session.user };
    } catch (_) {
      clearSession();
      return null;
    }
  }

  async function login(identifier, password) {
    const data = await postJson(AUTH_URL, { action: 'login', identifier, password });
    const session = {
      token: data.token,
      expiresAt: data.expiresAt || null,
      user: data.user || null
    };
    writeSession(session);
    return session;
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
          <div style="font-size:11px;font-weight:700;letter-spacing:.14em;text-transform:uppercase;color:#1E86D8">STEP · SISTEMA DE MEDIÇÃO</div>
          <div style="font-size:26px;font-weight:700;color:#0B2340;margin:8px 0 6px">Acesso restrito</div>
          <div style="font-size:13px;line-height:1.5;color:#5B7185;margin-bottom:22px">Use o mesmo usuário e a mesma senha da Intranet STEP.</div>
          <label style="display:block;font-size:12px;font-weight:600;color:#425B73;margin-bottom:6px">Usuário ou e-mail</label>
          <input id="step-login-user" type="text" autocomplete="username" required placeholder="ex.: douglas@pcp" style="width:100%;height:42px;border:1px solid #DCE5EE;border-radius:10px;padding:0 12px;margin-bottom:14px;outline:none">
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
          const identifier = document.getElementById('step-login-user').value.trim();
          const password = document.getElementById('step-login-password').value;
          const session = await login(identifier, password);
          resolve(session);
        } catch (e) {
          error.textContent = e.status === 429
            ? 'Muitas tentativas. Aguarde alguns minutos e tente novamente.'
            : (e.message || 'Usuário ou senha inválidos.');
          button.disabled = false;
          button.textContent = 'Entrar';
        }
      });
    });
  }

  async function ensureSession() {
    const stored = readSession();
    const valid = await validateSession(stored);
    if (valid) return valid;
    return loginScreen();
  }

  async function loadDashboard(session) {
    return postJson(DATA_URL, {
      action: 'dashboard',
      periodStart: PERIOD_START,
      periodEnd: PERIOD_END
    }, session.token);
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

    if (!document.querySelector('x-dc')) document.body.innerHTML = originalBody;

    const payload = await loadDashboard(session);
    window.STEP_LIVE_DATA = buildData(
      payload.execution || [],
      payload.reconciliation || [],
      payload.bms || []
    );
    window.STEP_LIVE_SESSION = session.user || payload.user || null;
    window.STEP_LOGOUT = async () => {
      try { await postJson(AUTH_URL, { action: 'logout' }, session.token); } catch (_) {}
      clearSession();
      location.reload();
    };
    window.STEP_LIVE_ERROR = null;
    loadRuntime();
  }

  start().catch(error => {
    console.error('[STEP live data]', error);
    if (error && (error.status === 401 || error.status === 403)) clearSession();
    document.body.innerHTML = '<div style="padding:32px;font-family:Arial;color:#8A1C1C"><strong>Falha ao carregar o painel.</strong><br>' +
      String(error.message || error) + '<br><br><button onclick="localStorage.removeItem(\'' + SESSION_KEY + '\');location.reload()">Entrar novamente</button></div>';
    window.STEP_LIVE_ERROR = error.message || String(error);
  });
})();