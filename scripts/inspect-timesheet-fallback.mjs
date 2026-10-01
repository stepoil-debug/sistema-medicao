import pg from 'pg';

const { Client } = pg;
const client = new Client({ connectionString: process.env.SUPABASE_DB_URL_DASHBOARD, ssl: { rejectUnauthorized: false }, connectionTimeoutMillis: 8000, statement_timeout: 10000 });

try {
  await client.connect();
  const { rows } = await client.query(`
    select table_name, column_name, data_type, ordinal_position
    from information_schema.columns
    where table_schema = 'public'
      and table_name in ('offshore_ts_entries', 'offshore_ts_timesheets', 'offshore_ts_status_history', 'offshore_rdo_rdos', 'offshore_rdo_individual_timesheets')
    order by table_name, ordinal_position;
  `);
  let previous = '';
  for (const row of rows) {
    if (row.table_name !== previous) {
      console.log(`\n[public.${row.table_name}]`);
      previous = row.table_name;
    }
    console.log(`${row.ordinal_position}. ${row.column_name} (${row.data_type})`);
  }
  for (const table of ['offshore_ts_entries', 'offshore_ts_timesheets', 'offshore_ts_status_history', 'offshore_rdo_rdos', 'offshore_rdo_individual_timesheets']) {
    const result = await client.query(`select count(*)::int as total from public.${table}`);
    console.log(`public.${table}: ${result.rows[0].total}`);
  }
} finally {
  await client.end().catch(() => undefined);
}
