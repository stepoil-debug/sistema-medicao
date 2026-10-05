function asDate(value) {
  if (value instanceof Date) return new Date(Date.UTC(value.getUTCFullYear(), value.getUTCMonth(), value.getUTCDate()));
  const parsed = new Date(`${value}T00:00:00Z`);
  if (Number.isNaN(parsed.getTime())) throw new TypeError(`Data inválida: ${value}`);
  return parsed;
}

function iso(date) {
  return date.toISOString().slice(0, 10);
}

export function measurementPeriodForReference(reference, startDay = 26, endDay = 25) {
  const ref = asDate(reference);
  const y = ref.getUTCFullYear();
  const m = ref.getUTCMonth();
  const d = ref.getUTCDate();

  let startYear = y;
  let startMonth = m;
  if (d <= endDay) {
    startMonth -= 1;
    if (startMonth < 0) {
      startMonth = 11;
      startYear -= 1;
    }
  }

  let endYear = startYear;
  let endMonth = startMonth + 1;
  if (endMonth > 11) {
    endMonth = 0;
    endYear += 1;
  }

  return {
    start: iso(new Date(Date.UTC(startYear, startMonth, startDay))),
    end: iso(new Date(Date.UTC(endYear, endMonth, endDay))),
  };
}

export function inclusiveDays(start, end) {
  const a = asDate(start);
  const b = asDate(end);
  if (b < a) throw new RangeError('Data final anterior à data inicial.');
  return Math.floor((b - a) / 86400000) + 1;
}
