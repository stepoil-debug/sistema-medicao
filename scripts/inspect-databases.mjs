import pg from 'pg';

const { Client } = pg;
const connectionNames = ['SUPABASE_DB_URL_DASHBOARD', 'SUPABASE_DB_URL_ESTOQUE'];

const tableQuery = `
  select
    n.nspname as schema_name,
    c.relname as object_name,
    case c.relkind when 'r' then 'table' when 'v' then 'view' when 'm' then 'materialized view' else c.relkind::text end as object_type
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where c.relkind in ('r', 'v', 'm')
    and n.nspname not in ('pg_catalog', 'information_schema', 'pg_toast')
  order by n.nspname, c.relname;
`;

const columnQuery = `
  select table_schema, table_name, column_name, data_type
  from information_schema.columns
  where table_schema not in ('pg_catalog', 'information_schema')
    and (
      lower(table_name) ~ '(rdo|timesheet|time_sheet|apont|hora|medic|diar|embar|employee|colab)'
      or lower(column_name) ~ '(rdo|timesheet|time_sheet|apont|hora|medic|diar|embar|employee|colab|projeto|project|bsp|po)'
    )
  order by table_schema, table_name, ordinal_position;
`;

for (const name of connectionNames) {
  const connectionString = process.env[name];
  if (!connectionString) {
    console.log(`${name}: ausente`);
    continue;
  }

  const client = new Client({
    connectionString,
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 8000,
    statement_timeout: 10000,
  });

  try {
    await client.connect();
    const [{ rows: objects }, { rows: columns }] = await Promise.all([
      client.query(tableQuery),
      client.query(columnQuery),
    ]);

    console.log(`\n=== ${name} ===`);
    console.log(`Objetos encontrados: ${objects.length}`);
    for (const object of objects) console.log(`${object.schema_name}.${object.object_name} [${object.object_type}]`);
    console.log('Colunas potencialmente relacionadas:');
    for (const column of columns) console.log(`${column.table_schema}.${column.table_name}.${column.column_name} [${column.data_type}]`);
  } catch (error) {
    console.log(`\n=== ${name} ===`);
    console.log(`Falha somente leitura: ${error instanceof Error ? error.message : String(error)}`);
  } finally {
    await client.end().catch(() => undefined);
  }
}
