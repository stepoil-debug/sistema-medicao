import { assertCommercialRule } from './measurement-profile.js';
import { inclusiveDays } from './period.js';

function num(value, label) {
  const n = Number(value);
  if (!Number.isFinite(n)) throw new TypeError(`${label} inválido.`);
  return n;
}

function money(value) {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

export function calculateUnitLine({ quantity, unitRate, rule }) {
  assertCommercialRule(rule);
  return money(num(quantity, 'Quantidade') * num(unitRate, 'Rate'));
}

export function calculateDailyLine({ days = 1, dailyRate, factor = 1, rule }) {
  assertCommercialRule(rule);
  return money(num(days, 'Dias') * num(dailyRate, 'Diária') * num(factor, 'Fator'));
}

export function calculateHoursFromDaily({ hours, dailyRate, multiplier, divisorHours, rule }) {
  assertCommercialRule(rule);
  const divisor = num(divisorHours, 'Divisor de horas');
  if (divisor <= 0) throw new RangeError('Divisor de horas deve ser maior que zero.');
  return money(num(hours, 'Horas') * num(dailyRate, 'Diária') * num(multiplier, 'Multiplicador') / divisor);
}

export function calculateAtCostMarkup({ cost, markupPercent, rule }) {
  assertCommercialRule(rule);
  return money(num(cost, 'Custo') * (1 + num(markupPercent, 'Markup') / 100));
}

export function calculateRental({ start, end, dailyRate, quantity = 1, quantityMode = 'ignore', rule }) {
  assertCommercialRule(rule);
  const days = inclusiveDays(start, end);
  const rate = num(dailyRate, 'Rate diário');
  const qty = num(quantity, 'Quantidade');
  if (!['ignore', 'multiply'].includes(quantityMode)) throw new RangeError('quantityMode inválido.');
  const quantityFactor = quantityMode === 'multiply' ? qty : 1;
  return { days, amount: money(days * rate * quantityFactor) };
}

export function calculateConsumable({ quantity, unitRate, rule }) {
  return calculateUnitLine({ quantity, unitRate, rule });
}

export function sumMeasurementSections(sections) {
  return money(Object.values(sections).flat().reduce((total, line) => total + Number(line.amount || 0), 0));
}
