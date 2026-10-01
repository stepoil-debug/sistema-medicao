import fs from 'node:fs/promises';
import pg from 'pg';

const { Client } = pg;
const migrationFile = process.argv[2] ?? '20261001093000_create_medicao_schema.sql';
const migrationPath = new URL(`../supabase/migrations/${migrationFile}`, import.meta.url);
const sql = await fs.readFile(migrationPath, 'utf8');
const connectionString = process.env.SUPABASE_DB_URL_DASHBOARD;
if (!connectionString) throw new Error('SUPABASE_DB_URL_DASHBOARD não está disponível');

const client = new Client({
  connectionString,
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 8000,
  statement_timeout: 30000,
});

try {
  await client.connect();
  await client.query('begin');
  await client.query(sql);
  await client.query('commit');
  const { rows } = await client.query(`
    select n.nspname as schema_name, count(*)::int as object_count
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('medicao', 'medicao_api')
      and c.relkind in ('r', 'v', 'm')
    group by n.nspname
    order by n.nspname;
  `);
  console.table(rows);
  console.log('Migration aplicada com sucesso.');
} catch (error) {
  await client.query('rollback').catch(() => undefined);
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
} finally {
  await client.end().catch(() => undefined);
}
