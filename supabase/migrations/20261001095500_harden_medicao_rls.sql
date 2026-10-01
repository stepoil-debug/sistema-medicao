-- As tabelas internas ficam protegidas por RLS e não são expostas ao browser.

alter table medicao.sync_runs enable row level security;
alter table medicao.source_rdo_records enable row level security;
alter table medicao.source_rdo_timesheet_entries enable row level security;
alter table medicao.source_timesheet_entries enable row level security;
alter table medicao.rate_rules enable row level security;
alter table medicao.measurements enable row level security;
alter table medicao.measurement_lines enable row level security;
alter table medicao.measurement_validations enable row level security;
alter table medicao.audit_events enable row level security;

revoke all on all tables in schema medicao from anon, authenticated;
revoke all on all sequences in schema medicao from anon, authenticated;
revoke all on all functions in schema medicao from anon, authenticated;
