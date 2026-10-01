import pg from 'pg';

const { Client } = pg;
const client = new Client({
  connectionString: process.env.SUPABASE_DB_URL_DASHBOARD,
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 8000,
  statement_timeout: 30000,
});

try {
  await client.connect();
  await client.query('begin');
  await client.query(`
    insert into medicao.rate_rules (category, unit, rate, currency, valid_from, notes)
    values
      ('normal_hours', 'hour', 100, 'USD', '2026-01-01', 'teste transacional'),
      ('overtime_hours', 'hour', 150, 'USD', '2026-01-01', 'teste transacional'),
      ('night_hours', 'hour', 180, 'USD', '2026-01-01', 'teste transacional'),
      ('standby_hours', 'hour', 80, 'USD', '2026-01-01', 'teste transacional'),
      ('travel_hours', 'hour', 80, 'USD', '2026-01-01', 'teste transacional'),
      ('beyond_rotation_hours', 'hour', 150, 'USD', '2026-01-01', 'teste transacional')
  `);

  const { rows } = await client.query(`
    select medicao.generate_draft('25-1032', '2026-09-16', '2026-09-26', null, 'USD') as measurement_id
  `);
  const measurementId = rows[0].measurement_id;
  const result = await client.query(`
    with validation_counts as (
      select measurement_id, count(*) filter (where severity = 'error')::int as error_count
      from medicao.measurement_validations
      group by measurement_id
    )
    select m.total_amount, count(l.id)::int as line_count, coalesce(v.error_count, 0) as error_count
    from medicao.measurements m
    left join medicao.measurement_lines l on l.measurement_id = m.id
    left join validation_counts v on v.measurement_id = m.id
    where m.id = $1::uuid
    group by m.id, m.total_amount, v.error_count
  `, [measurementId]);

  const row = result.rows[0];
  if (!row || Number(row.total_amount) <= 0 || row.error_count !== 0) {
    throw new Error(`Validação do motor falhou: ${JSON.stringify(row)}`);
  }

  console.table([row]);
  console.log('Motor calculou valor positivo e não gerou erro de tarifa.');
  await client.query('rollback');
  console.log('Tarifas e BM de teste foram desfeitos pela transação.');
} catch (error) {
  await client.query('rollback').catch(() => undefined);
  throw error;
} finally {
  await client.end().catch(() => undefined);
}
