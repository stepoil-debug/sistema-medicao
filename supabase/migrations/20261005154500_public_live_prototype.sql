-- Exposição temporária do protótipo GitHub Pages.
-- Revogar os grants para anon quando o painel migrar para a intranet.

create table if not exists medicao.bm_control_sources (
  source_row_id bigint primary key,
  bsp text not null,
  client_name text,
  po_contract text,
  po_billing text,
  bm_number text,
  sales_value numeric(18,2),
  rental_value numeric(18,2),
  manpower_value numeric(18,2),
  mob_demob_value numeric(18,2),
  logistics_value numeric(18,2),
  service_type text,
  bm_value numeric(18,2),
  po_balance numeric(18,2),
  bm_status text,
  pm_name text,
  sent_pm_date date,
  revision_date date,
  sent_client_date date,
  approval_date date,
  sent_billing_date date,
  po_value numeric(18,2),
  po_ref text,
  bms_accumulated numeric(18,2),
  total_billed numeric(18,2),
  source_payload jsonb not null default '{}'::jsonb,
  synced_at timestamptz not null default now()
);

alter table medicao.bm_control_sources enable row level security;
revoke all on medicao.bm_control_sources from public, anon, authenticated;
grant all on medicao.bm_control_sources to service_role;

drop view if exists public.medicao_live_execution;
create view public.medicao_live_execution as
select
  l.source_family,
  l.source_type,
  l.source_record_id,
  l.parent_record_id,
  l.protocol,
  l.work_date,
  l.employee_name,
  l.employee_function,
  l.bsp_raw,
  l.canonical_bsp,
  l.bsp_resolution_status,
  l.location,
  l.source_client_name,
  s.task_description,
  l.normal_hours,
  l.overtime_hours,
  l.night_hours,
  l.standby_hours,
  l.travel_hours,
  l.beyond_rotation_hours,
  l.total_hours,
  l.source_status,
  l.parent_status,
  l.source_approved,
  l.context_clients,
  l.context_units,
  l.purchase_orders,
  l.pms,
  l.service_types,
  l.work_types,
  l.work_regime,
  l.context_status,
  l.link_status
from medicao.v_execution_project_link l
join medicao.v_execution_sources s
  on s.source_family=l.source_family
 and s.source_record_id=l.source_record_id;

drop view if exists public.medicao_live_reconciliation;
create view public.medicao_live_reconciliation as
select * from medicao.v_reconciliation_daily;

drop view if exists public.medicao_live_context;
create view public.medicao_live_context as
select * from medicao.v_project_context_summary;

drop view if exists public.medicao_live_bms;
create view public.medicao_live_bms as
select * from medicao.bm_control_sources;

revoke all on public.medicao_live_execution from public, anon, authenticated;
revoke all on public.medicao_live_reconciliation from public, anon, authenticated;
revoke all on public.medicao_live_context from public, anon, authenticated;
revoke all on public.medicao_live_bms from public, anon, authenticated;

grant select on public.medicao_live_execution to authenticated, service_role;
grant select on public.medicao_live_reconciliation to authenticated, service_role;
grant select on public.medicao_live_context to authenticated, service_role;
grant select on public.medicao_live_bms to authenticated, service_role;

revoke select on public.medicao_dashboard_people from anon;
revoke select on public.medicao_dashboard_lines from anon;
revoke select on public.medicao_dashboard_summary from anon;
revoke select on public.medicao_measurement_sections from anon;
revoke select on public.medicao_rate_catalog from anon;

comment on view public.medicao_live_execution is
'Dados reais acessíveis apenas com sessão authenticated durante o protótipo GitHub Pages.';
comment on view public.medicao_live_reconciliation is
'Reconciliação acessível apenas com sessão authenticated durante o protótipo.';
comment on view public.medicao_live_context is
'Contexto de projeto temporariamente exposto ao protótipo; revogar anon na migração para intranet.';
comment on view public.medicao_live_bms is
'Snapshot real do BM Control acessível apenas com sessão authenticated durante o protótipo.';
