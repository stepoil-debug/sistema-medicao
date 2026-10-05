-- Sistema de Medição STEP — estrutura V1.
-- Migration preparada para revisão/aplicação controlada.
-- Não altera fontes offshore_rdo/offshore_ts.

create table if not exists medicao.user_access (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('viewer', 'measurement', 'pm', 'finance', 'admin')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

alter table medicao.user_access enable row level security;
alter table medicao.user_access force row level security;
revoke all on medicao.user_access from public, anon, authenticated;
grant select on medicao.user_access to authenticated;
grant all on medicao.user_access to service_role;

drop policy if exists medicao_user_access_self_read on medicao.user_access;
create policy medicao_user_access_self_read
  on medicao.user_access
  for select
  to authenticated
  using (user_id = (select auth.uid()) and active);

create table if not exists medicao.measurement_events (
  id uuid primary key default gen_random_uuid(),
  measurement_id uuid not null references medicao.measurements(id) on delete cascade,
  event_date date not null,
  employee_key text,
  employee_name text,
  employee_function text,
  event_code text not null check (event_code in ('E','P','D','HO','EC','DO')),
  source_system text not null,
  source_table text not null,
  source_record_id text not null,
  source_approved boolean not null default false,
  source_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (measurement_id, event_code, source_system, source_table, source_record_id, event_date)
);

create index if not exists measurement_events_lookup_idx
  on medicao.measurement_events (measurement_id, event_date, event_code);

create table if not exists medicao.commercial_rule_terms (
  id uuid primary key default gen_random_uuid(),
  rate_card_id uuid references medicao.client_rate_cards(id) on delete cascade,
  rule_code text not null,
  category text not null,
  employee_function text,
  event_code text,
  calculation_method text not null check (calculation_method in (
    'unit_rate', 'daily_factor', 'daily_hourly_factor', 'at_cost_markup',
    'rental_daily', 'manual_evidenced'
  )),
  base_category text,
  multiplier numeric(14,6),
  divisor_hours numeric(14,6),
  markup_percent numeric(14,6),
  quantity_mode text check (quantity_mode is null or quantity_mode in ('ignore','multiply')),
  unit text,
  valid_from date not null default date '1900-01-01',
  valid_to date,
  status text not null default 'draft' check (status in ('draft','confirmed','superseded')),
  evidence jsonb not null default '{}'::jsonb,
  confirmed_at timestamptz,
  confirmed_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (valid_to is null or valid_to >= valid_from),
  check (status <> 'confirmed' or (confirmed_at is not null and confirmed_by is not null))
);

create index if not exists commercial_rule_terms_lookup_idx
  on medicao.commercial_rule_terms (rate_card_id, category, event_code, valid_from, valid_to, status);

create table if not exists medicao.measurement_evidence (
  id uuid primary key default gen_random_uuid(),
  measurement_id uuid not null references medicao.measurements(id) on delete cascade,
  measurement_line_id uuid references medicao.measurement_lines(id) on delete cascade,
  evidence_type text not null check (evidence_type in (
    'rdo','timesheet','histogram','contract','proposal','po','rate','logistics',
    'habitat','rental','consumable','invoice_backup','other'
  )),
  source_system text,
  source_table text,
  source_record_id text,
  file_name text,
  file_reference text,
  content_hash text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists measurement_evidence_lookup_idx
  on medicao.measurement_evidence (measurement_id, evidence_type, measurement_line_id);

create table if not exists medicao.measurement_workflow_events (
  id bigserial primary key,
  measurement_id uuid not null references medicao.measurements(id) on delete cascade,
  from_status text,
  to_status text not null,
  actor_user_id uuid references auth.users(id),
  actor_role text,
  comments text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists measurement_workflow_events_idx
  on medicao.measurement_workflow_events (measurement_id, created_at);

create table if not exists medicao.measurement_snapshots (
  id uuid primary key default gen_random_uuid(),
  measurement_id uuid not null unique references medicao.measurements(id),
  measurement_version integer not null,
  source_hash text not null,
  rate_hash text not null,
  calculation_hash text not null,
  payload jsonb not null,
  frozen_at timestamptz not null default now(),
  frozen_by uuid references auth.users(id)
);

create or replace function medicao.reject_snapshot_mutation()
returns trigger
language plpgsql
set search_path = pg_catalog, medicao
as $$
begin
  raise exception 'Snapshot de medição é imutável.';
end;
$$;

drop trigger if exists measurement_snapshots_immutable_ud on medicao.measurement_snapshots;
create trigger measurement_snapshots_immutable_ud
before update or delete on medicao.measurement_snapshots
for each row execute function medicao.reject_snapshot_mutation();

alter table medicao.source_timesheet_periods enable row level security;
alter table medicao.source_timesheet_periods force row level security;
alter table medicao.source_timesheet_days enable row level security;
alter table medicao.source_timesheet_days force row level security;
alter table medicao.measurement_logistics_lines enable row level security;
alter table medicao.measurement_logistics_lines force row level security;
alter table medicao.measurement_extra_lines enable row level security;
alter table medicao.measurement_extra_lines force row level security;
alter table medicao.measurement_approval_steps enable row level security;
alter table medicao.measurement_approval_steps force row level security;

alter table medicao.measurement_events enable row level security;
alter table medicao.measurement_events force row level security;
alter table medicao.commercial_rule_terms enable row level security;
alter table medicao.commercial_rule_terms force row level security;
alter table medicao.measurement_evidence enable row level security;
alter table medicao.measurement_evidence force row level security;
alter table medicao.measurement_workflow_events enable row level security;
alter table medicao.measurement_workflow_events force row level security;
alter table medicao.measurement_snapshots enable row level security;
alter table medicao.measurement_snapshots force row level security;

grant usage on schema medicao to authenticated;
revoke all on medicao.source_timesheet_periods, medicao.source_timesheet_days,
  medicao.measurement_logistics_lines, medicao.measurement_extra_lines,
  medicao.measurement_approval_steps, medicao.measurement_events,
  medicao.commercial_rule_terms, medicao.measurement_evidence,
  medicao.measurement_workflow_events, medicao.measurement_snapshots
from public, anon, authenticated;

grant select on medicao.source_timesheet_periods, medicao.source_timesheet_days,
  medicao.measurement_logistics_lines, medicao.measurement_extra_lines,
  medicao.measurement_approval_steps, medicao.measurement_events,
  medicao.commercial_rule_terms, medicao.measurement_evidence,
  medicao.measurement_workflow_events, medicao.measurement_snapshots
  to authenticated;

grant all on medicao.source_timesheet_periods, medicao.source_timesheet_days,
  medicao.measurement_logistics_lines, medicao.measurement_extra_lines,
  medicao.measurement_approval_steps, medicao.measurement_events,
  medicao.commercial_rule_terms, medicao.measurement_evidence,
  medicao.measurement_workflow_events, medicao.measurement_snapshots
  to service_role;

do $$
declare
  t text;
begin
  foreach t in array array[
    'source_timesheet_periods','source_timesheet_days','measurement_logistics_lines',
    'measurement_extra_lines','measurement_approval_steps','measurement_events',
    'commercial_rule_terms','measurement_evidence','measurement_workflow_events','measurement_snapshots'
  ]
  loop
    execute format('drop policy if exists %I on medicao.%I', 'medicao_authorized_read', t);
    execute format(
      'create policy %I on medicao.%I for select to authenticated using (exists (select 1 from medicao.user_access ua where ua.user_id = (select auth.uid()) and ua.active))',
      'medicao_authorized_read', t
    );
  end loop;
end $$;

revoke execute on function public.medicao_confirm_rate_catalog(uuid, text, text, text, char, jsonb, text, text)
  from public, anon, authenticated;
grant execute on function public.medicao_confirm_rate_catalog(uuid, text, text, text, char, jsonb, text, text)
  to service_role;

create or replace function public.medicao_current_access()
returns table(role text)
language sql
security invoker
set search_path = pg_catalog, medicao
as $$
  select ua.role
  from medicao.user_access ua
  where ua.user_id = (select auth.uid()) and ua.active;
$$;

revoke all on function public.medicao_current_access() from public, anon;
grant execute on function public.medicao_current_access() to authenticated, service_role;
