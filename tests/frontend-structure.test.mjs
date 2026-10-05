import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const root = await readFile(new URL('../index.html', import.meta.url), 'utf8');
const area = await readFile(new URL('../Area de Medicao.dc.html', import.meta.url), 'utf8');
const suporte = await readFile(new URL('../support.js', import.meta.url), 'utf8');

test('pagina inicial e Area de Medicao sao literalmente iguais', () => {
  assert.equal(root, area);
});

test('modelo original do ZIP usa o runtime dc original', () => {
  assert.match(area, /<x-dc>/);
  assert.match(area, /<script src="\.\/support\.js"><\/script>/);
  assert.match(suporte, /dc-runtime/);
});

test('dimensoes e navegacao originais foram preservadas', () => {
  assert.match(area, /width: 1680px; height: 1010px/);
  assert.match(area, /Carteira de BSPs/);
  assert.match(area, /Área de medição/);
  assert.match(area, /Ferramental Habitat\.dc\.html/);
});
