const apiBaseUrl = window.MEDICAO_API_BASE_URL || '';

const elements = {
  status: document.querySelector('#connection-status'),
  bmCount: document.querySelector('#bm-count'),
  lineCount: document.querySelector('#line-count'),
  totalAmount: document.querySelector('#total-amount'),
  currency: document.querySelector('#currency'),
  validationCount: document.querySelector('#validation-count'),
  list: document.querySelector('#measurement-list'),
};

function formatAmount(value, currency = 'USD') {
  if (value === null || value === undefined || Number.isNaN(Number(value))) return '—';
  return new Intl.NumberFormat('pt-BR', { style: 'currency', currency }).format(Number(value));
}

function setStatus(label, live = false) {
  elements.status.textContent = label;
  elements.status.classList.toggle('status-live', live);
  elements.status.classList.toggle('status-pending', !live);
}

function renderRows(rows) {
  if (!rows.length) {
    elements.list.textContent = 'A API respondeu, mas não há medições para exibir.';
    return;
  }
  elements.list.innerHTML = rows.map((row) => `
    <div class="measurement-row">
      <div><strong>${row.bsp || 'Sem BSP'}</strong><small>${row.period_start || ''} → ${row.period_end || ''}</small></div>
      <strong>${formatAmount(row.total_amount, row.currency || 'USD')}</strong>
    </div>`).join('');
}

async function loadMeasurements() {
  if (!apiBaseUrl) {
    setStatus('Backend pendente');
    return;
  }
  try {
    const response = await fetch(`${apiBaseUrl.replace(/\/$/, '')}/measurement-summary`);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const payload = await response.json();
    const rows = Array.isArray(payload) ? payload : payload.data || [];
    const total = rows.reduce((sum, row) => sum + Number(row.total_amount || 0), 0);
    elements.bmCount.textContent = rows.length;
    elements.lineCount.textContent = rows.reduce((sum, row) => sum + Number(row.line_count || 0), 0);
    elements.totalAmount.textContent = formatAmount(total, rows[0]?.currency || 'USD');
    elements.currency.textContent = rows[0]?.currency || 'sem moeda';
    elements.validationCount.textContent = rows.reduce((sum, row) => sum + Number(row.error_count || 0) + Number(row.warning_count || 0), 0);
    renderRows(rows);
    setStatus('Backend conectado', true);
  } catch (error) {
    setStatus('Erro na API');
    elements.list.textContent = `Não foi possível carregar a API: ${error.message}`;
  }
}

document.querySelector('#refresh').addEventListener('click', loadMeasurements);
loadMeasurements();
