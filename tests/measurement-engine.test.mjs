import test from 'node:test';
import assert from 'node:assert/strict';
import {
  calculateAtCostMarkup,
  calculateConsumable,
  calculateDailyLine,
  calculateHoursFromDaily,
  calculateRental,
  sumMeasurementSections,
} from '../src/domain/calculator.js';
import { measurementPeriodForReference } from '../src/domain/period.js';

const confirmed = { confirmed: true, evidence: 'test' };

test('período alvo 26/25 atravessa a virada do mês', () => {
  assert.deepEqual(measurementPeriodForReference('2026-09-30'), { start: '2026-09-26', end: '2026-10-25' });
  assert.deepEqual(measurementPeriodForReference('2026-10-05'), { start: '2026-09-26', end: '2026-10-25' });
});

test('diária usa fator informado pela regra comercial', () => {
  assert.equal(calculateDailyLine({ days: 2, dailyRate: 1000, factor: 2, rule: confirmed }), 4000);
  assert.equal(calculateDailyLine({ days: 1, dailyRate: 1000, factor: 0.5, rule: confirmed }), 500);
});

test('hora derivada de diária nunca assume multiplicador ou divisor', () => {
  assert.equal(calculateHoursFromDaily({ hours: 3, dailyRate: 1200, multiplier: 2, divisorHours: 12, rule: confirmed }), 600);
});

test('rental preserva comportamento do modelo quando quantidade é ignorada', () => {
  assert.deepEqual(calculateRental({ start: '2026-09-01', end: '2026-09-03', dailyRate: 10, quantity: 5, quantityMode: 'ignore', rule: confirmed }), { days: 3, amount: 30 });
  assert.deepEqual(calculateRental({ start: '2026-09-01', end: '2026-09-03', dailyRate: 10, quantity: 5, quantityMode: 'multiply', rule: confirmed }), { days: 3, amount: 150 });
});

test('consumível usa quantidade x valor unitário', () => {
  assert.equal(calculateConsumable({ quantity: 4, unitRate: 12.5, rule: confirmed }), 50);
});

test('at cost + markup é parametrizado', () => {
  assert.equal(calculateAtCostMarkup({ cost: 1000, markupPercent: 15, rule: confirmed }), 1150);
});

test('motor bloqueia cálculo financeiro sem regra confirmada', () => {
  assert.throws(() => calculateDailyLine({ days: 1, dailyRate: 1000, factor: 1, rule: { confirmed: false } }), /não confirmada/i);
});

test('total do BM soma as seções calculadas', () => {
  assert.equal(sumMeasurementSections({ daily: [{ amount: 1000 }], overtime: [{ amount: 250 }], rentals: [{ amount: 300.25 }] }), 1550.25);
});
