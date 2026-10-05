const cfg = window.MEDICAO_CONFIG || {};
const state = { summaries: [], latest: [], people: [], rates: [], selected: null };
const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];

const labels = {
  draft: 'Rascunho', review_pm: 'Revisão PM', sent_client: 'Enviado ao cliente', approved: 'Aprovado', invoiced: 'Faturado', cancelled: 'Cancelado',
  daily: 'Diárias / Over stay', normal_hours: 'Horas normais', overtime_hours: 'Horas extras', night_hours: 'Adicional noturno',
  standby_hours: 'Standby', travel_hours: 'Travel', beyond_rotation_hours: 'Beyond rotation', mobilization: 'Mobilização',
  demobilization: 'Desmobilização', logistics: 'Logística', transport: 'Transporte', hotel: 'Hotel',
  habitat: 'Habitat / Ferramental', rentals: 'Rentals', consumables: 'Consumíveis', mob_materials: 'Mob/Desmob materiais'
};

function node(tag, className, text) {
  const n = document.createElement(tag);
  if (className) n.className = className;
  if (text !== undefined && text !== null) n.textContent = text;
  return n;
}
function money(value, currency = 'BRL') {
  const n = Number(value || 0);
  return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: currency || 'BRL' }).format(Number.isFinite(n) ? n : 0);
}
function number(value, digits = 2) {
  return new Intl.NumberFormat('pt-BR', { maximumFractionDigits: digits }).format(Number(value || 0));
}
function dateBR(value) {
  if (!value) return '—';
  const [y, m, d] = String(value).slice(0, 10).split('-');
  return y && m && d ? `${d}/${m}/${y}` : value;
}
function escKey(value) { return String(value || '').trim().toLowerCase(); }
function targetPeriod(reference = new Date()) {
  const y = reference.getFullYear(), m = reference.getMonth(), d = reference.getDate();
  const start = d <= 25 ? new Date(y, m - 1, 26) : new Date(y, m, 26);
  const end = new Date(start.getFullYear(), start.getMonth() + 1, 25);
  return `${dateBR(start.toISOString())} – ${dateBR(end.toISOString())}`;
}
function setConnection(kind, text) {
  const el = $('#connection-status');
  el.className = `connection ${kind ? `is-${kind}` : ''}`;
  el.lastChild.textContent = text;
}
async function rest(resource, query = '') {
  if (!cfg.supabaseUrl || !cfg.publishableKey) throw new Error('Configuração do Supabase ausente.');
  const url = `${cfg.supabaseUrl.replace(/\/$/, '')}/rest/v1/${resource}${query ? `?${query}` : ''}`;
  const res = await fetch(url, {
    headers: { apikey: cfg.publishableKey, Authorization: `Bearer ${cfg.publishableKey}` }
  });
  if (!res.ok) throw new Error(`${resource}: HTTP ${res.status}`);
  return res.json();
}
function latestByBsp(rows) {
  const sorted = [...rows].sort((a, b) => new Date(b.generated_at || 0) - new Date(a.generated_at || 0));
  const seen = new Set(), out = [];
  for (const row of sorted) {
    const key = escKey(row.bsp);
    if (!seen.has(key)) { seen.add(key); out.push(row); }
  }
  return out.sort((a, b) => String(a.bsp).localeCompare(String(b.bsp), 'pt-BR', { numeric: true }));
}
function statusBadge(status) {
  return node('span', `badge ${status || 'draft'}`, labels[status] || status || 'Rascunho');
}
function td(text, className = '') { return node('td', className, text); }

function renderKpis() {
  const rows = state.latest;
  $('#kpi-bm').textContent = rows.length;
  $('#kpi-errors').textContent = rows.filter(r => Number(r.error_count) > 0).length;
  $('#kpi-people').textContent = rows.reduce((s, r) => s + Number(r.people_count || 0), 0);
  $('#kpi-total').textContent = money(rows.reduce((s, r) => s + Number(r.total_amount || 0), 0), rows[0]?.currency || 'BRL');
  $('#calculation-notice').hidden = !rows.some(r => Number(r.error_count) > 0 || Number(r.warning_count) > 0);
}
function renderMeasurements() {
  const body = $('#measurement-body'); body.replaceChildren();
  const term = escKey($('#search-bsp').value), status = $('#status-filter').value;
  const rows = state.latest.filter(r =>
    (!status || r.status === status) &&
    (!term || [r.bsp, r.client_name, r.location, r.project_name].some(v => escKey(v).includes(term)))
  );
  $('#measurement-empty').hidden = rows.length > 0;
  for (const row of rows) {
    const tr = node('tr'); tr.tabIndex = 0;
    const c1 = td('', 'primary-cell');
    c1.textContent = row.bsp || 'Sem BSP';
    c1.append(node('span', 'secondary-cell', `v${row.version || 1}`));
    tr.append(c1);
    const c2 = td('');
    c2.append(node('span', '', row.client_name || 'Cliente não informado'), node('span', 'secondary-cell', row.location || row.project_name || '—'));
    tr.append(c2);
    tr.append(td(`${dateBR(row.period_start)} → ${dateBR(row.period_end)}`));
    tr.append(td(row.source_mode || '—'));
    tr.append(td(String(row.people_count ?? 0)));
    const issues = Number(row.error_count || 0) + Number(row.warning_count || 0);
    const c6 = td('');
    c6.append(node('span', issues ? 'badge error' : 'badge ok', issues ? `${issues} pendência${issues === 1 ? '' : 's'}` : 'Sem pendência'));
    tr.append(c6);
    tr.append(td(money(row.total_amount, row.currency), 'amount-cell'));
    const c8 = td(''); c8.append(statusBadge(row.status)); tr.append(c8);
    tr.append(td('›', 'amount-cell'));
    const open = () => openMeasurement(row);
    tr.addEventListener('click', open);
    tr.addEventListener('keydown', e => { if (e.key === 'Enter') open(); });
    body.append(tr);
  }
}
function renderPeople() {
  const body = $('#people-body'); body.replaceChildren();
  const term = escKey($('#search-people').value);
  const latestIds = new Set(state.latest.map(r => r.id));
  const rows = state.people
    .filter(r => latestIds.has(r.measurement_id))
    .filter(r => !term || [r.employee_name, r.employee_function, r.bsp].some(v => escKey(v).includes(term)))
    .sort((a, b) => String(b.work_date).localeCompare(String(a.work_date)));
  $('#people-empty').hidden = rows.length > 0;
  for (const r of rows) {
    const tr = node('tr');
    tr.append(td(dateBR(r.work_date)), td(r.employee_name || '—', 'primary-cell'), td(r.employee_function || '—'), td(r.bsp || '—'),
      td(number(r.normal_hours)), td(number(r.overtime_hours)), td(number(r.total_hours), 'amount-cell'), td(r.source_mode || '—'));
    const c = td('');
    c.append(node('span', r.source_approved ? 'badge ok' : 'badge pending', r.source_approved ? 'Confirmado' : (r.source_status || 'Pendente')));
    tr.append(c); body.append(tr);
  }
}
function renderRates() {
  const body = $('#rates-body'); body.replaceChildren();
  const term = escKey($('#search-rates').value);
  const rows = state.rates.filter(r => !term || [r.client_name, r.bsp, r.employee_function, r.category].some(v => escKey(v).includes(term)));
  $('#rates-empty').hidden = rows.length > 0;
  for (const r of rows) {
    const tr = node('tr');
    tr.append(td(r.client_name || '—', 'primary-cell'), td(r.bsp || 'Todos'), td(r.employee_function || '—'),
      td(labels[r.category] || r.category || '—'), td(r.unit || '—'), td(money(r.rate, r.currency), 'amount-cell'),
      td(`${dateBR(r.valid_from)}${r.valid_to ? ` → ${dateBR(r.valid_to)}` : ' → vigente'}`), td(r.file_name || r.proposal_code || '—'));
    body.append(tr);
  }
}
async function loadCore() {
  setConnection('', 'Conectando');
  try {
    const [summaries, people] = await Promise.all([
      rest('medicao_dashboard_summary', 'select=*&order=generated_at.desc'),
      rest('medicao_dashboard_people', 'select=*&order=work_date.desc&limit=1000')
    ]);
    state.summaries = summaries;
    state.latest = latestByBsp(summaries);
    state.people = people;
    renderKpis(); renderMeasurements(); renderPeople();
    setConnection('live', 'Dados sincronizados');
  } catch (err) {
    console.error(err);
    setConnection('error', 'Falha de conexão');
    $('#measurement-empty').hidden = false;
    $('#measurement-empty').querySelector('p').textContent = err.message;
  }
}
async function loadRates() {
  try {
    state.rates = await rest('medicao_rate_catalog', 'select=*&order=client_name.asc,employee_function.asc');
    renderRates();
  } catch (err) {
    console.error(err); state.rates = []; renderRates();
  }
}
function switchView(name) {
  $$('.nav-item').forEach(x => x.classList.toggle('is-active', x.dataset.view === name));
  $$('[data-view-panel]').forEach(x => x.classList.toggle('is-active', x.dataset.viewPanel === name));
  history.replaceState(null, '', `#${name}`);
  if (name === 'rates' && !state.rates.length) loadRates();
}
function renderWorkflow(status) {
  const order = ['draft', 'review_pm', 'sent_client', 'approved', 'invoiced'];
  const current = Math.max(0, order.indexOf(status));
  const root = $('#workflow'); root.replaceChildren();
  order.forEach((s, i) => {
    const step = node('div', `workflow-step ${i < current ? 'done' : i === current ? 'current' : ''}`);
    step.append(node('span', 'workflow-dot', i < current ? '✓' : String(i + 1)), node('span', '', labels[s]));
    root.append(step);
  });
}
function summaryBox(label, value) {
  const b = node('div', 'summary-box');
  b.append(node('span', '', label), node('strong', '', value));
  return b;
}
async function openMeasurement(row) {
  state.selected = row;
  $('#drawer-title').textContent = `BSP ${row.bsp}`;
  $('#drawer-subtitle').textContent = `${row.client_name || 'Cliente não informado'} · ${row.location || row.project_name || '—'} · ${dateBR(row.period_start)} → ${dateBR(row.period_end)}`;
  renderWorkflow(row.status);
  const sum = $('#drawer-summary');
  sum.replaceChildren(summaryBox('Versão', `v${row.version || 1}`), summaryBox('Fonte', row.source_mode || '—'),
    summaryBox('Pessoas', String(row.people_count || 0)), summaryBox('Total', money(row.total_amount, row.currency)));
  openDrawer();
  try {
    const id = encodeURIComponent(row.id);
    const [sections, lines, people] = await Promise.all([
      rest('medicao_measurement_sections', `select=*&measurement_id=eq.${id}&order=category.asc`),
      rest('medicao_dashboard_lines', `select=*&measurement_id=eq.${id}&order=service_date.asc`),
      rest('medicao_dashboard_people', `select=*&measurement_id=eq.${id}&order=work_date.asc`)
    ]);
    renderSections(sections, row); renderDetailLines(lines); renderDetailPeople(people);
  } catch (err) {
    console.error(err);
    $('#detail-sections').replaceChildren(node('div', 'notice warning', `Não foi possível carregar o detalhe: ${err.message}`));
  }
}
function renderSections(rows, measurement) {
  const root = $('#detail-sections'); root.replaceChildren();
  if (!rows.length) { root.append(node('div', 'empty-state', 'Sem composição disponível.')); return; }
  const grid = node('div', 'section-list');
  for (const r of rows) {
    const card = node('div', 'section-card');
    card.append(node('span', '', labels[r.category] || r.category), node('strong', '', money(r.total_amount, measurement.currency)),
      node('small', '', `${r.line_count || 0} lançamento(s)`));
    grid.append(card);
  }
  root.append(grid);
}
function renderDetailLines(rows) {
  const body = $('#detail-lines-body'); body.replaceChildren();
  for (const r of rows) {
    const tr = node('tr');
    tr.append(td(dateBR(r.service_date)), td(labels[r.category] || r.category), td(r.employee_name || r.description || '—'),
      td(`${number(r.quantity)} ${r.unit || ''}`), td(r.unit_rate == null ? 'Rate pendente' : money(r.unit_rate, r.currency), 'amount-cell'),
      td(money(r.amount, r.currency), 'amount-cell'), td(r.source_system || '—'));
    body.append(tr);
  }
}
function renderDetailPeople(rows) {
  const body = $('#detail-people-body'); body.replaceChildren();
  for (const r of rows) {
    const tr = node('tr');
    tr.append(td(dateBR(r.work_date)), td(r.employee_name || '—', 'primary-cell'), td(r.employee_function || '—'),
      td(number(r.normal_hours)), td(number(r.overtime_hours)), td(number(r.total_hours), 'amount-cell'));
    const c = td('');
    c.append(node('span', r.source_approved ? 'badge ok' : 'badge pending', r.source_approved ? 'Confirmado' : (r.source_status || 'Pendente')));
    tr.append(c); body.append(tr);
  }
}
function openDrawer() {
  $('#drawer-backdrop').hidden = false;
  $('#measurement-drawer').classList.add('is-open');
  $('#measurement-drawer').setAttribute('aria-hidden', 'false');
}
function closeDrawer() {
  $('#measurement-drawer').classList.remove('is-open');
  $('#measurement-drawer').setAttribute('aria-hidden', 'true');
  setTimeout(() => { $('#drawer-backdrop').hidden = true; }, 220);
}

$('#target-period').textContent = `Período alvo ${targetPeriod()}`;
$$('.nav-item').forEach(b => b.addEventListener('click', () => switchView(b.dataset.view)));
$('#refresh-all').addEventListener('click', () => { loadCore(); if ($('[data-view-panel="rates"]').classList.contains('is-active')) loadRates(); });
$('#search-bsp').addEventListener('input', renderMeasurements);
$('#status-filter').addEventListener('change', renderMeasurements);
$('#search-people').addEventListener('input', renderPeople);
$('#search-rates').addEventListener('input', renderRates);
$('#open-histogram').addEventListener('click', () => switchView('embarque'));
$('#new-bm').addEventListener('click', () => $('#new-bm-dialog').showModal());
$('#close-drawer').addEventListener('click', closeDrawer);
$('#drawer-backdrop').addEventListener('click', closeDrawer);
document.addEventListener('keydown', e => { if (e.key === 'Escape') closeDrawer(); });
$$('.drawer-tab').forEach(b => b.addEventListener('click', () => {
  $$('.drawer-tab').forEach(x => x.classList.toggle('is-active', x === b));
  $$('[data-detail-panel]').forEach(x => x.classList.toggle('is-active', x.dataset.detailPanel === b.dataset.detailTab));
}));
const initial = ['medicao', 'embarque', 'ferramental', 'rates'].includes(location.hash.slice(1)) ? location.hash.slice(1) : 'medicao';
switchView(initial);
loadCore();
