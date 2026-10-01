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
  const sync = await client.query('select medicao.sync_sources($1::date, $2::date, null::text) as run_id', [start, end]);
  const runId = sync.rows[0].run_id;
  console.log(`Sincronização concluída: ${runId}`);

  const { rows: bspRows } = await client.query(`
    select distinct bsp
    from medicao.source_rdo_timesheet_entries
    where work_date between $1::date and $2::date
      and bsp is not null
    order by bsp
  `, [start, end]);

  for (const { bsp } of bspRows) {
    const draft = await client.query(
      'select medicao.generate_draft($1::text, $2::date, $3::date, null::text, $4::char(3)) as measurement_id',
      [bsp, start, end, 'BRL'],
    );
    const measurementId = draft.rows[0].measurement_id;
    const { rows } = await client.query(`
      select id, bsp, total_amount, line_count, error_count, warning_count
      from medicao_api.measurement_summary
      where id = $1::uuid
    `, [measurementId]);
    console.table(rows);
  }

  const { rows: syncRows } = await client.query(`
    select id, status, rdo_records_count, rdo_timesheet_entries_count,
      timesheet_entries_count, started_at, finished_at
    from medicao.sync_runs where id = $1::uuid
  `, [runId]);
  console.table(syncRows);
} finally {
  await client.end().catch(() => undefined);
}
