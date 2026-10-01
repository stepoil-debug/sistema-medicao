import pg from 'pg';

const { Client } = pg;
const connectionString = process.env.SUPABASE_DB_URL_DASHBOARD;
if (!connectionString) throw new Error('SUPABASE_DB_URL_DASHBOARD não está disponível');

const client = new Client({
  connectionString,
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 8000,
  statement_timeout: 10000,
});

const columnsSql = `
  select table_schema, table_name, ordinal_position, column_name, data_type, is_nullable
  from information_schema.columns
  where table_schema in ('offshore_rdo', 'offshore_ts')
  order by table_schema, table_name, ordinal_position;
`;

const keysSql = `
  select tc.table_schema, tc.table_name, tc.constraint_type, kcu.column_name
  from information_schema.table_constraints tc
  join information_schema.key_column_usage kcu
    on kcu.constraint_schema = tc.constraint_schema
   and kcu.constraint_name = tc.constraint_name
   and kcu.table_name = tc.table_name
  where tc.table_schema in ('offshore_rdo', 'offshore_ts')
  order by tc.table_schema, tc.table_name, tc.constraint_type, kcu.ordinal_position;
`;

try {
  await client.connect();
  const [{ rows: columns }, { rows: keys }] = await Promise.all([
    client.query(columnsSql),
    client.query(keysSql),
  ]);

  console.log('=== COLUNAS DAS FONTES ===');
  let previousTable = '';
  for (const column of columns) {
    const table = `${column.table_schema}.${column.table_name}`;
    if (table !== previousTable) {
      console.log(`\n[${table}]`);
      previousTable = table;
    }
    console.log(`${column.ordinal_position}. ${column.column_name} (${column.data_type}, nullable=${column.is_nullable})`);
  }

  console.log('\n=== CHAVES E RESTRIÇÕES ===');
  for (const key of keys) console.log(`${key.table_schema}.${key.table_name}: ${key.constraint_type} -> ${key.column_name}`);
} finally {
  await client.end().catch(() => undefined);
}
