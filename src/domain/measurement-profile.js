export const RULE_STATUS = Object.freeze({
  CONFIRMED: 'CONFIRMADO',
  INFERRED: 'INFERIDO',
  CONFLICTING: 'CONFLITANTE',
  NOT_VERIFIED: 'NOT_VERIFIED',
  CONFIRM_WITH_CLIENT: 'CONFIRM_WITH_CLIENT',
  TARGET_REFERENCE: 'TARGET_REFERENCE',
});

export const MEASUREMENT_STATUS = Object.freeze([
  'draft',
  'review_pm',
  'sent_client',
  'approved',
  'invoiced',
  'cancelled',
]);

export const TARGET_PERIOD = Object.freeze({
  startDay: 26,
  endDay: 25,
  status: RULE_STATUS.TARGET_REFERENCE,
  source: 'Modelo de medição fornecido pela STEP',
});

export const EVENT_CODES = Object.freeze({
  E: { label: 'Embarcado', commercialMeaning: 'daily', status: RULE_STATUS.TARGET_REFERENCE },
  P: { label: 'MOB / embarque', commercialMeaning: 'daily', status: RULE_STATUS.TARGET_REFERENCE },
  D: { label: 'Desembarque', commercialMeaning: 'demobilization', status: RULE_STATUS.TARGET_REFERENCE },
  HO: { label: 'Hotel pré-embarque', commercialMeaning: 'hotel', status: RULE_STATUS.TARGET_REFERENCE },
  EC: { label: 'Embarque cancelado', commercialMeaning: 'cancelled_boarding', status: RULE_STATUS.TARGET_REFERENCE },
  DO: { label: 'Dobra', commercialMeaning: 'double_daily', status: RULE_STATUS.TARGET_REFERENCE },
});

export const SECTION_CODES = Object.freeze([
  'daily',
  'overtime_hours',
  'night_hours',
  'logistics',
  'mobilization',
  'demobilization',
  'habitat',
  'rentals',
  'consumables',
  'mob_materials',
]);

export function assertCommercialRule(rule) {
  if (!rule || rule.confirmed !== true) {
    const err = new Error('Regra comercial não confirmada para cálculo financeiro.');
    err.code = 'COMMERCIAL_RULE_NOT_CONFIRMED';
    throw err;
  }
  return rule;
}
