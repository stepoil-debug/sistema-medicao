(() => {
  const SUPABASE_URL = 'https://qxmxtbjxkhecqilpnhgq.supabase.co';
  const PUBLISHABLE_KEY = 'sb_publishable_TiGdrzZ6H7TCjQ8wPaAkzA_cQxVxdvr';
  const PERIOD_START = '2026-08-26';
  const PERIOD_END = '2026-09-25';
  const PERIOD_M0 = 7;

  const headers = {
    apikey: PUBLISHABLE_KEY,
    Authorization: 'Bearer ' + PUBLISHABLE_KEY
  };

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

  const dataPromise = Promise.all([
    get('medicao_live_execution', 'select=*&work_date=gte.' + PERIOD_START + '&work_date=lte.' + PERIOD_END + '&order=bsp_raw.asc,work_date.asc,employee_name.asc'),
    get('medicao_live_reconciliation', 'select=*&work_date=gte.' + PERIOD_START + '&work_date=lte.' + PERIOD_END + '&order=bsp_raw.asc,work_date.asc,employee_name.asc'),
    get('medicao_live_bms', 'select=*&order=bsp.asc,sent_pm_date.asc')
  ]).then(([execution, reconciliation, bms]) => {
    window.STEP_LIVE_DATA = buildData(execution, reconciliation, bms);
    window.STEP_LIVE_ERROR = null;
  }).catch(error => {
    console.error('[STEP live data]', error);
    window.STEP_LIVE_DATA = { areaBsps: [], medicaoBsps: [], reconciliation: [], periodStart: PERIOD_START, periodEnd: PERIOD_END };
    window.STEP_LIVE_ERROR = error.message || String(error);
  });

  const domPromise = new Promise(resolve => {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', resolve, { once: true });
    else resolve();
  });

  Promise.allSettled([dataPromise, domPromise]).then(() => {
    const script = document.createElement('script');
    script.src = './support.js';
    script.async = false;
    document.head.appendChild(script);
  });
})();