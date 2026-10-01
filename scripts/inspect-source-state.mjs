import pg from 'pg';

const { Client } = pg;
const connectionString = process.env.SUPABASE_DB_URL_DASHBOARD;
const client = new Client({ connectionString, ssl: { rejectUnauthorized: false }, connectionTimeoutMillis: 8000, statement_timeout: 10000 });

const queries = [
  ['RDO status', `select status, count(*)::int as total from offshore_rdo.rdos group by status order by status`],
  ['RDO date range', `select min(work_date) as min_date, max(work_date) as max_date, count(*)::int as total from offshore_rdo.rdos`],
  ['RDO BSP summary', `select bsp, count(*)::int as total, min(work_date) as min_date, max(work_date) as max_date from offshore_rdo.rdos group by bsp order by total desc limit 30`],
  ['Timesheet status', `select status::text as status, count(*)::int as total from offshore_ts.weekly_timesheets group by status order by status`],
  ['Timesheet date range', `select min(week_start) as min_date, max(coalesce(week_end, week_start)) as max_date, count(*)::int as total from offshore_ts.weekly_timesheets`],
  ['Campaign summary', `select id, code, project_key, project_name, bsp_context, purchase_order, client_name, status::text as status from offshore_ts.campaigns order by created_at desc limit 30`],
  ['Approval summary', `select status::text as status, level::text as level, count(*)::int as total from offshore_ts.approvals group by status, level order by level, status`],
  ['Task entry totals', `select count(*)::int as total, coalesce(sum(normal_minutes),0)::bigint as normal_minutes, coalesce(sum(overtime_minutes),0)::bigint as overtime_minutes, coalesce(sum(night_minutes),0)::bigint as night_minutes from offshore_ts.task_entries`],
];

try {
  await client.connect();
  for (const [label, sql] of queries) {
    const { rows } = await client.query(sql);
    console.log(`\n=== ${label} ===`);
    console.table(rows);
  }
} finally {
  await client.end().catch(() => undefined);
}
