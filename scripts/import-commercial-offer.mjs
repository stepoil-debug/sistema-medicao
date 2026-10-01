import fs from 'node:fs/promises';
import pg from 'pg';

const { Client } = pg;
const inputPath = process.argv[2];
if (!inputPath) {
  throw new Error('Uso: node scripts/import-commercial-offer.mjs <commercial-offer.json>');
}

const input = JSON.parse(await fs.readFile(inputPath, 'utf8'));
const categories = new Set([
  'normal_hours', 'overtime_hours', 'night_hours', 'standby_hours',
  'travel_hours', 'beyond_rotation_hours', 'daily', 'mobilization',
  'demobilization', 'logistics', 'habitat', 'rentals', 'consumables',
]);

function required(value, label) {
  const text = String(value ?? '').trim();
  if (!text) throw new Error(`${label} é obrigatório.`);
  return text;
}

function number(value, label) {
  const parsed = typeof value === 'number'
    ? value
    : Number(String(value ?? '').replace(/R\$\s?/gi, '').replace(/\./g, '').replace(',', '.').trim());
  if (!Number.isFinite(parsed) || parsed < 0) throw new Error(`${label} deve ser um número não negativo.`);
  return parsed;
}

const bsp = required(input.bsp, 'bsp');
const proposalCode = required(input.proposal_code, 'proposal_code');
const fileName = required(input.file_name, 'file_name');
const rows = Array.isArray(input.rows) ? input.rows : [];
if (!rows.length) throw new Error('rows deve conter pelo menos uma linha extraída da Commercial offer.');

for (const [index, row] of rows.entries()) {
  if (!categories.has(row.category)) throw new Error(`rows[${index}].category inválida.`);
  required(row.description, `rows[${index}].description`);
  required(row.unit, `rows[${index}].unit`);
  number(row.rate, `rows[${index}].rate`);
}

const connectionString = process.env.SUPABASE_DB_URL_DASHBOARD;
if (!connectionString) throw new Error('SUPABASE_DB_URL_DASHBOARD não está disponível.');

const client = new Client({
  connectionString,
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 8000,
  statement_timeout: 30000,
});

await client.connect();
try {
  await client.query('begin');
  const existing = await client.query(`
    select id
    from medicao.rate_sources
    where bsp = $1 and proposal_code = $2 and file_name = $3
      and coalesce(file_hash, '') = coalesce($4, '')
    limit 1
  `, [bsp, proposalCode, fileName, input.file_hash ?? null]);
  if (existing.rows.length) {
    await client.query('rollback');
    console.log(JSON.stringify({ ok: true, skipped: true, reason: 'rate_source_already_imported', id: existing.rows[0].id }));
    process.exit(0);
  }

  const source = await client.query(`
    insert into medicao.rate_sources
      (bsp, proposal_code, file_name, source_section, source_locator, file_hash,
       valid_from, valid_to, metadata, imported_by)
    values ($1, $2, $3, coalesce($4, 'Commercial offer'), $5, $6, $7, $8, $9, current_user)
    returning id
  `, [
    bsp,
    proposalCode,
    fileName,
    input.source_section ?? 'Commercial offer',
    input.source_locator ?? null,
    input.file_hash ?? null,
    input.valid_from ?? null,
    input.valid_to ?? null,
    input.metadata ?? {},
  ]);
  const sourceId = source.rows[0].id;

  for (const [index, row] of rows.entries()) {
    await client.query(`
      insert into medicao.rate_rules
        (category, project_key, bsp, unit, rate, currency, valid_from, valid_to,
         active, notes, rate_source_id, employee_function, employee_function_normalized,
         rate_description, source_reference, source_row_number)
      values ($1, $2, $3, $4, $5, $6, coalesce($7, '1900-01-01'), $8,
              true, $9, $10, nullif($11, ''), medicao.normalize_function(nullif($11, '')),
              $12, coalesce($13, 'Commercial offer / row ' || ($14 + 1)::text), $14)
    `, [
      row.category,
      row.project_key ?? null,
      bsp,
      row.unit,
      number(row.rate, `rows[${index}].rate`),
      row.currency ?? input.currency ?? 'BRL',
      row.valid_from ?? input.valid_from ?? null,
      row.valid_to ?? input.valid_to ?? null,
      row.notes ?? null,
      sourceId,
      String(row.employee_function ?? '').trim(),
      row.description,
      row.source_reference ?? null,
      index,
    ]);
  }

  // Rebuild existing draft measurements for this BSP so a rate import is
  // immediately reflected in the live dashboard. The generator creates the
  // next version and keeps the previous draft available for audit.
  const drafts = await client.query(`
    select bsp, period_start, period_end, project_key, currency
    from medicao.measurements
    where medicao.normalize_bsp(bsp) = medicao.normalize_bsp($1)
      and status = 'draft'
    group by bsp, period_start, period_end, project_key, currency
    order by period_start, period_end, bsp
  `, [bsp]);
  const regeneratedMeasurements = [];
  for (const draft of drafts.rows) {
    const regenerated = await client.query(`
      select medicao.generate_draft($1, $2::date, $3::date, $4, $5::char(3)) as id
    `, [draft.bsp, draft.period_start, draft.period_end, draft.project_key, draft.currency]);
    regeneratedMeasurements.push(regenerated.rows[0].id);
  }

  await client.query('commit');
  console.log(JSON.stringify({
    ok: true,
    rate_source_id: sourceId,
    imported_rules: rows.length,
    regenerated_measurements: regeneratedMeasurements,
  }));
} catch (error) {
  await client.query('rollback').catch(() => undefined);
  throw error;
} finally {
  await client.end().catch(() => undefined);
}
