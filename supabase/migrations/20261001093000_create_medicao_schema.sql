-- Sistema de Medição
-- Schema isolado das fontes offshore_rdo/offshore_ts.
-- Esta migration é aditiva: não altera tabelas existentes.

create extension if not exists pgcrypto;

create schema if not exists medicao;
create schema if not exists medicao_api;

revoke all on schema medicao from public, anon, authenticated;
revoke all on schema medicao_api from public, anon;

create table if not exists medicao.sync_runs (
  id uuid primary key default gen_random_uuid(),
  period_start date not null,
  period_end date not null,
  bsp text,
  status text not null default 'running' check (status in ('running', 'completed', 'failed')),
  rdo_records_count integer not null default 0,
  rdo_timesheet_entries_count integer not null default 0,
  timesheet_entries_count integer not null default 0,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  error_message text,
  created_at timestamptz not null default now(),
  check (period_end >= period_start)
);

create table if not exists medicao.source_rdo_records (
  id uuid primary key default gen_random_uuid(),
  source_system text not null default 'offshore_rdo',
  source_table text not null default 'offshore_rdo.rdos',
  source_record_id text not null,
  protocol text not null,
  work_date date not null,
  location text,
  bsp text,
  client_name text,
  project_name text,
  status text not null,
  source_updated_at timestamptz,
  source_payload jsonb not null default '{}'::jsonb,
  imported_at timestamptz not null default now(),
  unique (source_system, source_table, source_record_id)
);

create index if not exists source_rdo_records_period_idx
  on medicao.source_rdo_records (bsp, work_date, status);

create table if not exists medicao.source_rdo_timesheet_entries (
  id uuid primary key default gen_random_uuid(),
  source_system text not null default 'offshore_rdo',
  source_table text not null default 'offshore_rdo.individual_timesheets',
  source_record_id text not null,
  source_rdo_record_id text not null,
  protocol text not null,
  employee_key text,
  employee_name text not null,
  employee_function text,
  work_date date not null,
  location text,
  bsp text,
  task_description text,
  source_status text not null,
  rdo_status text not null,
  source_approved boolean not null default false,
  normal_hours numeric(12, 4) not null default 0,
  overtime_hours numeric(12, 4) not null default 0,
  total_hours numeric(12, 4) not null default 0,
  confirmed_at timestamptz,
  source_updated_at timestamptz,
  source_payload jsonb not null default '{}'::jsonb,
  imported_at timestamptz not null default now(),
  unique (source_system, source_table, source_record_id)
);

create index if not exists source_rdo_timesheet_period_idx
  on medicao.source_rdo_timesheet_entries (bsp, work_date, rdo_status, source_status);

create table if not exists medicao.source_timesheet_entries (
  id uuid primary key default gen_random_uuid(),
  source_system text not null default 'offshore_ts',
  source_table text not null default 'offshore_ts.task_entries',
  source_record_id text not null,
  source_weekly_timesheet_id uuid not null,
  source_timesheet_day_id uuid not null,
  campaign_id uuid not null,
  project_key text,
  bsp text,
  purchase_order text,
  client_name text,
  employee_key text,
  employee_name text not null,
  employee_function text,
  location text,
  work_date date not null,
  task_description text,
  task_number text,
  source_status text not null,
  approval_status text,
  source_approved boolean not null default false,
  normal_minutes integer not null default 0,
  overtime_minutes integer not null default 0,
  night_minutes integer not null default 0,
  standby_minutes integer not null default 0,
  travel_minutes integer not null default 0,
  beyond_rotation_minutes integer not null default 0,
  total_minutes integer not null default 0,
  source_updated_at timestamptz,
  source_payload jsonb not null default '{}'::jsonb,
  imported_at timestamptz not null default now(),
  unique (source_system, source_table, source_record_id)
);

create index if not exists source_timesheet_period_idx
  on medicao.source_timesheet_entries (bsp, project_key, work_date, source_approved);

create table if not exists medicao.rate_rules (
  id uuid primary key default gen_random_uuid(),
  category text not null check (category in (
    'normal_hours', 'overtime_hours', 'night_hours', 'standby_hours',
    'travel_hours', 'beyond_rotation_hours', 'daily', 'mobilization',
    'demobilization', 'logistics', 'habitat', 'rentals', 'consumables'
  )),
  project_key text,
  bsp text,
  unit text not null,
  rate numeric(14, 4) not null check (rate >= 0),
  currency char(3) not null default 'BRL',
  valid_from date not null,
  valid_to date,
  active boolean not null default true,
  notes text,
  created_by text,
  created_at timestamptz not null default now(),
  check (valid_to is null or valid_to >= valid_from)
);

create index if not exists rate_rules_lookup_idx
  on medicao.rate_rules (category, bsp, project_key, valid_from, valid_to, active);

create table if not exists medicao.measurements (
  id uuid primary key default gen_random_uuid(),
  bsp text not null,
  project_key text,
  period_start date not null,
  period_end date not null,
  version integer not null default 1,
  status text not null default 'draft' check (status in (
    'draft', 'review_pm', 'sent_client', 'approved', 'invoiced', 'cancelled'
  )),
  currency char(3) not null default 'BRL',
  source_sync_run_id uuid references medicao.sync_runs(id),
  total_amount numeric(14, 2) not null default 0,
  calculation_hash text,
  generated_at timestamptz not null default now(),
  generated_by text,
  approved_at timestamptz,
  approved_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (period_end >= period_start)
);

create index if not exists measurements_lookup_idx
  on medicao.measurements (bsp, project_key, period_start, period_end, version);

create table if not exists medicao.measurement_lines (
  id uuid primary key default gen_random_uuid(),
  measurement_id uuid not null references medicao.measurements(id) on delete cascade,
  category text not null,
  source_system text not null,
  source_table text not null,
  source_record_id text not null,
  service_date date not null,
  employee_name text,
  description text,
  quantity numeric(14, 4) not null default 0,
  unit text not null,
  unit_rate numeric(14, 4),
  amount numeric(14, 2) not null default 0,
  currency char(3) not null,
  source_approved boolean not null default false,
  source_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (measurement_id, category, source_system, source_table, source_record_id)
);

create index if not exists measurement_lines_measurement_idx
  on medicao.measurement_lines (measurement_id, category, service_date);

create table if not exists medicao.measurement_validations (
  id uuid primary key default gen_random_uuid(),
  measurement_id uuid not null references medicao.measurements(id) on delete cascade,
  measurement_line_id uuid references medicao.measurement_lines(id) on delete cascade,
  severity text not null check (severity in ('info', 'warning', 'error')),
  code text not null,
  message text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists measurement_validations_lookup_idx
  on medicao.measurement_validations (measurement_id, severity, code);

create table if not exists medicao.audit_events (
  id bigserial primary key,
  measurement_id uuid references medicao.measurements(id),
  action text not null,
  actor_user_id text,
  actor_name text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function medicao.sync_sources(
  p_period_start date,
  p_period_end date,
  p_bsp text default null
)
returns uuid
language plpgsql
set search_path = pg_catalog, medicao, offshore_rdo, offshore_ts
as $$
declare
  v_run_id uuid := gen_random_uuid();
  v_count integer := 0;
  v_rdo_count integer := 0;
  v_rdo_ts_count integer := 0;
  v_ts_count integer := 0;
begin
  if p_period_end < p_period_start then
    raise exception 'Período inválido: data final anterior à inicial';
  end if;

  insert into medicao.sync_runs (id, period_start, period_end, bsp)
  values (v_run_id, p_period_start, p_period_end, p_bsp);

  insert into medicao.source_rdo_records (
    source_record_id, protocol, work_date, location, bsp, client_name,
    project_name, status, source_updated_at, source_payload, imported_at
  )
  select
    r.id::text, r.protocol, r.work_date, r.location, r.bsp, r.client_name,
    r.project_name, r.status, r.updated_at, to_jsonb(r), now()
  from offshore_rdo.rdos r
  where r.work_date between p_period_start and p_period_end
    and (p_bsp is null or r.bsp = p_bsp)
  on conflict (source_system, source_table, source_record_id) do update set
    protocol = excluded.protocol,
    work_date = excluded.work_date,
    location = excluded.location,
    bsp = excluded.bsp,
    client_name = excluded.client_name,
    project_name = excluded.project_name,
    status = excluded.status,
    source_updated_at = excluded.source_updated_at,
    source_payload = excluded.source_payload,
    imported_at = now();
  get diagnostics v_rdo_count = row_count;

  insert into medicao.source_rdo_timesheet_entries (
    source_record_id, source_rdo_record_id, protocol, employee_key, employee_name,
    employee_function, work_date, location, bsp, task_description, source_status,
    rdo_status, source_approved, normal_hours, overtime_hours, total_hours,
    confirmed_at, source_updated_at, source_payload, imported_at
  )
  select
    i.id::text, i.rdo_id::text, i.protocol, i.employee_user_id, i.employee_name,
    i.employee_job_title, i.work_date, i.location, i.bsp, i.task_description,
    i.status, r.status,
    lower(i.status) in ('confirmed', 'approved', 'signed')
      and lower(r.status) = 'completed',
    i.normal_hours, i.overtime_hours, i.total_hours,
    i.confirmed_at, i.updated_at, to_jsonb(i), now()
  from offshore_rdo.individual_timesheets i
  join offshore_rdo.rdos r on r.id = i.rdo_id
  where i.work_date between p_period_start and p_period_end
    and r.status = 'completed'
    and (p_bsp is null or i.bsp = p_bsp or r.bsp = p_bsp)
  on conflict (source_system, source_table, source_record_id) do update set
    source_rdo_record_id = excluded.source_rdo_record_id,
    protocol = excluded.protocol,
    employee_key = excluded.employee_key,
    employee_name = excluded.employee_name,
    employee_function = excluded.employee_function,
    work_date = excluded.work_date,
    location = excluded.location,
    bsp = excluded.bsp,
    task_description = excluded.task_description,
    source_status = excluded.source_status,
    rdo_status = excluded.rdo_status,
    source_approved = excluded.source_approved,
    normal_hours = excluded.normal_hours,
    overtime_hours = excluded.overtime_hours,
    total_hours = excluded.total_hours,
    confirmed_at = excluded.confirmed_at,
    source_updated_at = excluded.source_updated_at,
    source_payload = excluded.source_payload,
    imported_at = now();
  get diagnostics v_rdo_ts_count = row_count;

  insert into medicao.source_timesheet_entries (
    source_record_id, source_weekly_timesheet_id, source_timesheet_day_id,
    campaign_id, project_key, bsp, purchase_order, client_name, employee_key,
    employee_name, employee_function, location, work_date, task_description,
    task_number, source_status, approval_status, source_approved, normal_minutes,
    overtime_minutes, night_minutes, standby_minutes, travel_minutes,
    beyond_rotation_minutes, total_minutes, source_updated_at, source_payload,
    imported_at
  )
  select
    te.id::text, w.id, d.id, c.id, c.project_key,
    coalesce(w.bsp_snapshot, c.bsp_context), c.purchase_order, c.client_name,
    cm.employee_registration, w.employee_name_snapshot, w.function_snapshot,
    coalesce(w.location_snapshot, c.location), d.work_date, te.task_description,
    te.task_number, w.status::text,
    (select max(a.status::text) from offshore_ts.approvals a
      where a.weekly_timesheet_id = w.id),
    (
      w.status::text in ('supervisor_approved', 'management_approved', 'client_approved', 'locked')
      or exists (
        select 1 from offshore_ts.approvals a
        where a.weekly_timesheet_id = w.id
          and a.status::text = 'approved'
          and a.level::text in ('measurement', 'manager', 'client')
      )
    ),
    te.normal_minutes, te.overtime_minutes, te.night_minutes, te.standby_minutes,
    te.travel_minutes, te.beyond_rotation_minutes, te.total_minutes,
    te.updated_at, to_jsonb(te), now()
  from offshore_ts.task_entries te
  join offshore_ts.timesheet_days d on d.id = te.timesheet_day_id
  join offshore_ts.weekly_timesheets w on w.id = d.weekly_timesheet_id
  join offshore_ts.campaigns c on c.id = w.campaign_id
  left join offshore_ts.campaign_members cm on cm.id = w.campaign_member_id
  where d.work_date between p_period_start and p_period_end
    and w.status::text not in ('draft', 'returned', 'cancelled')
    and (p_bsp is null or coalesce(w.bsp_snapshot, c.bsp_context) = p_bsp)
  on conflict (source_system, source_table, source_record_id) do update set
    source_weekly_timesheet_id = excluded.source_weekly_timesheet_id,
    source_timesheet_day_id = excluded.source_timesheet_day_id,
    campaign_id = excluded.campaign_id,
    project_key = excluded.project_key,
    bsp = excluded.bsp,
    purchase_order = excluded.purchase_order,
    client_name = excluded.client_name,
    employee_key = excluded.employee_key,
    employee_name = excluded.employee_name,
    employee_function = excluded.employee_function,
    location = excluded.location,
    work_date = excluded.work_date,
    task_description = excluded.task_description,
    task_number = excluded.task_number,
    source_status = excluded.source_status,
    approval_status = excluded.approval_status,
    source_approved = excluded.source_approved,
    normal_minutes = excluded.normal_minutes,
    overtime_minutes = excluded.overtime_minutes,
    night_minutes = excluded.night_minutes,
    standby_minutes = excluded.standby_minutes,
    travel_minutes = excluded.travel_minutes,
    beyond_rotation_minutes = excluded.beyond_rotation_minutes,
    total_minutes = excluded.total_minutes,
    source_updated_at = excluded.source_updated_at,
    source_payload = excluded.source_payload,
    imported_at = now();
  get diagnostics v_ts_count = row_count;

  update medicao.sync_runs
  set status = 'completed',
      rdo_records_count = v_rdo_count,
      rdo_timesheet_entries_count = v_rdo_ts_count,
      timesheet_entries_count = v_ts_count,
      finished_at = now()
  where id = v_run_id;

  return v_run_id;
exception when others then
  update medicao.sync_runs
  set status = 'failed', finished_at = now(), error_message = sqlerrm
  where id = v_run_id;
  raise;
end;
$$;

create or replace function medicao.generate_draft(
  p_bsp text,
  p_period_start date,
  p_period_end date,
  p_project_key text default null,
  p_currency char(3) default 'BRL'
)
returns uuid
language plpgsql
set search_path = pg_catalog, medicao
as $$
declare
  v_measurement_id uuid := gen_random_uuid();
  v_source_sync_id uuid;
  v_source_count integer := 0;
begin
  if p_period_end < p_period_start then
    raise exception 'Período inválido: data final anterior à inicial';
  end if;

  select s.id into v_source_sync_id
  from medicao.sync_runs s
  where s.period_start = p_period_start
    and s.period_end = p_period_end
    and (s.bsp is not distinct from p_bsp)
    and s.status = 'completed'
  order by s.finished_at desc nulls last
  limit 1;

  insert into medicao.measurements (
    id, bsp, project_key, period_start, period_end, version, currency,
    source_sync_run_id, generated_by
  )
  values (
    v_measurement_id, p_bsp, p_project_key, p_period_start, p_period_end,
    coalesce((select max(m.version) + 1 from medicao.measurements m
      where m.bsp = p_bsp and m.period_start = p_period_start and m.period_end = p_period_end), 1),
    p_currency, v_source_sync_id, current_user
  );

  with ts_base as (
    select
      'offshore_ts'::text as source_system,
      'offshore_ts.task_entries'::text as source_table,
      t.source_record_id,
      t.project_key,
      t.work_date,
      t.employee_name,
      t.task_description,
      t.source_approved,
      t.source_payload,
      t.normal_minutes::numeric / 60 as normal_hours,
      t.overtime_minutes::numeric / 60 as overtime_hours,
      t.night_minutes::numeric / 60 as night_hours,
      t.standby_minutes::numeric / 60 as standby_hours,
      t.travel_minutes::numeric / 60 as travel_hours,
      t.beyond_rotation_minutes::numeric / 60 as beyond_rotation_hours
    from medicao.source_timesheet_entries t
    where t.bsp = p_bsp
      and t.work_date between p_period_start and p_period_end
      and (p_project_key is null or t.project_key = p_project_key)
      and t.source_approved
  ),
  rdo_base as (
    select
      'offshore_rdo'::text as source_system,
      'offshore_rdo.individual_timesheets'::text as source_table,
      t.source_record_id,
      null::text as project_key,
      t.work_date,
      t.employee_name,
      t.task_description,
      t.source_approved,
      t.source_payload,
      t.normal_hours,
      t.overtime_hours,
      0::numeric as night_hours,
      0::numeric as standby_hours,
      0::numeric as travel_hours,
      0::numeric as beyond_rotation_hours
    from medicao.source_rdo_timesheet_entries t
    where t.bsp = p_bsp
      and t.work_date between p_period_start and p_period_end
      and t.rdo_status = 'completed'
  ),
  selected_base as (
    select * from ts_base
    union all
    select * from rdo_base
    where not exists (select 1 from ts_base)
  ),
  normalized as (
    select source_system, source_table, source_record_id, work_date, employee_name,
      task_description, source_approved, source_payload, 'normal_hours'::text category,
      normal_hours quantity, 'hour'::text unit from selected_base where normal_hours > 0
    union all
    select source_system, source_table, source_record_id, work_date, employee_name,
      task_description, source_approved, source_payload, 'overtime_hours', overtime_hours, 'hour'
      from selected_base where overtime_hours > 0
    union all
    select source_system, source_table, source_record_id, work_date, employee_name,
      task_description, source_approved, source_payload, 'night_hours', night_hours, 'hour'
      from selected_base where night_hours > 0
    union all
    select source_system, source_table, source_record_id, work_date, employee_name,
      task_description, source_approved, source_payload, 'standby_hours', standby_hours, 'hour'
      from selected_base where standby_hours > 0
    union all
    select source_system, source_table, source_record_id, work_date, employee_name,
      task_description, source_approved, source_payload, 'travel_hours', travel_hours, 'hour'
      from selected_base where travel_hours > 0
    union all
    select source_system, source_table, source_record_id, work_date, employee_name,
      task_description, source_approved, source_payload, 'beyond_rotation_hours', beyond_rotation_hours, 'hour'
      from selected_base where beyond_rotation_hours > 0
  )
  insert into medicao.measurement_lines (
    measurement_id, category, source_system, source_table, source_record_id,
    service_date, employee_name, description, quantity, unit, unit_rate, amount,
    currency, source_approved, source_payload
  )
  select
    v_measurement_id, n.category, n.source_system, n.source_table, n.source_record_id,
    n.work_date, n.employee_name, n.task_description, n.quantity, n.unit,
    rr.rate,
    round(n.quantity * coalesce(rr.rate, 0), 2),
    coalesce(rr.currency, p_currency), n.source_approved, n.source_payload
  from normalized n
  left join lateral (
    select r.rate, r.currency
    from medicao.rate_rules r
    where r.category = n.category
      and r.active
      and (r.bsp is null or r.bsp = p_bsp)
      and (r.project_key is null or r.project_key = p_project_key)
      and n.work_date >= r.valid_from
      and (r.valid_to is null or n.work_date <= r.valid_to)
    order by (r.bsp is not null) desc, (r.project_key is not null) desc, r.valid_from desc
    limit 1
  ) rr on true;

  select count(*) into v_source_count
  from medicao.measurement_lines l
  where l.measurement_id = v_measurement_id;

  insert into medicao.measurement_validations (
    measurement_id, measurement_line_id, severity, code, message, metadata
  )
  select v_measurement_id, l.id, 'error', 'MISSING_RATE',
    format('Não existe tarifa ativa para a categoria %s na data %s.', l.category, l.service_date),
    jsonb_build_object('category', l.category, 'service_date', l.service_date)
  from medicao.measurement_lines l
  where l.measurement_id = v_measurement_id and l.unit_rate is null;

  insert into medicao.measurement_validations (
    measurement_id, measurement_line_id, severity, code, message, metadata
  )
  select v_measurement_id, l.id, 'warning', 'SOURCE_NOT_CONFIRMED',
    'Linha originada de apontamento ainda não confirmado/assinado na fonte.',
    jsonb_build_object('source_system', l.source_system, 'source_record_id', l.source_record_id)
  from medicao.measurement_lines l
  where l.measurement_id = v_measurement_id and not l.source_approved;

  if v_source_count = 0 then
    insert into medicao.measurement_validations (
      measurement_id, severity, code, message
    ) values (
      v_measurement_id, 'error', 'NO_SOURCE_DATA',
      'Nenhum apontamento aprovado ou RDO concluído foi encontrado para o período/BSP informado.'
    );
  end if;

  update medicao.measurements m
  set total_amount = coalesce((select sum(l.amount) from medicao.measurement_lines l where l.measurement_id = v_measurement_id), 0),
      calculation_hash = md5(coalesce((select string_agg(l.id::text || ':' || l.amount::text, '|' order by l.id) from medicao.measurement_lines l where l.measurement_id = v_measurement_id), '')),
      updated_at = now()
  where m.id = v_measurement_id;

  insert into medicao.audit_events (measurement_id, action, actor_name, metadata)
  values (v_measurement_id, 'draft_generated', current_user,
    jsonb_build_object('source_count', v_source_count, 'period_start', p_period_start, 'period_end', p_period_end));

  return v_measurement_id;
end;
$$;

create or replace view medicao_api.measurement_summary
with (security_invoker = true)
as
select
  m.id,
  m.bsp,
  m.project_key,
  m.period_start,
  m.period_end,
  m.version,
  m.status,
  m.currency,
  m.total_amount,
  count(l.id)::integer as line_count,
  count(v.id) filter (where v.severity = 'error')::integer as error_count,
  count(v.id) filter (where v.severity = 'warning')::integer as warning_count,
  m.generated_at,
  m.approved_at
from medicao.measurements m
left join medicao.measurement_lines l on l.measurement_id = m.id
left join medicao.measurement_validations v on v.measurement_id = m.id
group by m.id;

create or replace view medicao_api.measurement_lines
with (security_invoker = true)
as
select
  l.id, l.measurement_id, l.category, l.source_system, l.source_table,
  l.source_record_id, l.service_date, l.employee_name, l.description,
  l.quantity, l.unit, l.unit_rate, l.amount, l.currency, l.source_approved
from medicao.measurement_lines l;

-- Acesso intencionalmente restrito: a aplicação deverá consultar por backend
-- com uma credencial de serviço, nunca expondo conexão privilegiada no browser.
grant usage on schema medicao, medicao_api to service_role;
grant select, insert, update, delete on all tables in schema medicao to service_role;
grant execute on function medicao.sync_sources(date, date, text) to service_role;
grant execute on function medicao.generate_draft(text, date, date, text, char) to service_role;
grant select on medicao_api.measurement_summary, medicao_api.measurement_lines to service_role;
