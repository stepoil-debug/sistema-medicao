import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const html = await readFile(new URL('../index.html', import.meta.url), 'utf8');
const app = await readFile(new URL('../app.js', import.meta.url), 'utf8');

test('frontend oficial contém somente os módulos do novo modelo', () => {
  for (const label of ['Área de medição', 'Medição e embarque', 'Ferramental / Habitat', 'Rates']) {
    assert.match(html, new RegExp(label.replace('/', '\\/')));
  }
});

test('runtime e rotas do protótipo antigo foram removidos', () => {
  assert.doesNotMatch(html, /support\.js|Painel BSP\.dc\.html|dc-runtime/i);
  assert.doesNotMatch(app, /support\.js|Painel BSP\.dc\.html|dc-runtime/i);
});

test('frontend consulta apenas projeções do domínio medicao', () => {
  for (const resource of ['medicao_dashboard_summary', 'medicao_dashboard_people', 'medicao_measurement_sections', 'medicao_dashboard_lines', 'medicao_rate_catalog']) {
    assert.match(app, new RegExp(resource));
  }
});
