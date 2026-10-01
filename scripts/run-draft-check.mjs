import pg from 'pg';

const { Client } = pg;
const client = new Client({
  connectionString: process.env.SUPABASE_DB_URL_DASHBOARD,
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 8000,
  statement_timeout: 30000,
});

const start = process.argv[2] ?? '2026-09-16';
const end = process.argv[3] ?? '2026-09-26';

try {
  await client.connect();
  const deployment = await client.query(
    'select medicao.sync_and_generate_drafts($1::date, $2::date, null::text, $3::char(3)) as result',
    [start, end, 'BRL'],
  );
  const result = deployment.rows[0].result;
  console.log('Implantação/sincronização concluída:', JSON.stringify(result, null, 2));

  for (const measurement of result.measurements ?? []) {
    const { rows } = await client.query(`
      select id, bsp, total_amount, line_count, error_count, warning_count
      from medicao_api.measurement_summary
      where id = $1::uuid
    `, [measurement.measurement_id]);
    console.table(rows);
  }

  const { rows: syncRows } = await client.query(`
    select id, status, rdo_records_count, rdo_timesheet_entries_count,
      timesheet_entries_count, started_at, finished_at
    from medicao.sync_runs where id = $1::uuid
  `, [result.sync_run_id]);
  console.table(syncRows);
} finally {
  await client.end().catch(() => undefined);
}
