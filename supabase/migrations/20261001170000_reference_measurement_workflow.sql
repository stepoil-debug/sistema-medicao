-- Estrutura complementar inspirada no fluxo operacional mapeado no My Step Time.
-- Tudo permanece isolado em medicao; as fontes offshore_rdo/offshore_ts são somente leitura.

create table if not exists medicao.source_timesheet_periods (
  id uuid primary key default gen_random_uuid(),
  source_system text not null default 'offshore_ts',
  source_table text not null default 'offshore_ts.weekly_timesheets',
  source_record_id text not null,
  campaign_id uuid,
  campaign_member_id uuid,
  project_key text,
  client_name text,
  unit_name text,
  bsp text,
  employee_key text,
  employee_name text not null,
  employee_function text,
  period_start date not null,
  period_end date,
  source_status text not null,
  version integer not null default 1,
  approval_status text,
  source_approved boolean not null default false,
  locked_at timestamptz,
  source_updated_at timestamptz,
  source_payload jsonb not null default '{}'::jsonb,
  imported_at timestamptz not null default now(),
  unique (source_system, source_table, source_record_id)
);

create index if not exists source_timesheet_periods_lookup_idx
  on medicao.source_timesheet_periods (bsp, period_start, period_end, source_approved);

create table if not exists medicao.source_timesheet_days (
  id uuid primary key default gen_random_uuid(),
  source_system text not null default 'offshore_ts',
  source_table text not null default 'offshore_ts.timesheet_days',
  source_record_id text not null,
  source_period_id uuid references medicao.source_timesheet_periods(id) on delete cascade,
  source_weekly_timesheet_id uuid,
  work_date date not null,
  day_status text,
  expected_minutes integer not null default 0,
  break_minutes integer not null default 0,
  normal_minutes integer not null default 0,
  overtime_minutes integer not null default 0,
  night_minutes integer not null default 0,
  total_minutes integer not null default 0,
  overtime_authorized boolean not null default false,
  requires_review boolean not null default false,
  validation_errors jsonb not null default '[]'::jsonb,
  source_payload jsonb not null default '{}'::jsonb,
  imported_at timestamptz not null default now(),
  unique (source_system, source_table, source_record_id)
);

create index if not exists source_timesheet_days_lookup_idx
  on medicao.source_timesheet_days (work_date, source_period_id, requires_review);

create table if not exists medicao.measurement_logistics_lines (
  id uuid primary key default gen_random_uuid(),
  measurement_id uuid not null references medicao.measurements(id) on delete cascade,
  bsp text not null,
  category text not null check (category in ('transport', 'hotel', 'other')),
  source_system text not null,
  source_table text not null,
  source_record_id text not null,
  service_date date,
  employee_name text,
  description text,
  quantity numeric(14,4) not null default 1,
  unit text not null default 'item',
  unit_rate numeric(14,4) not null default 0,
  amount numeric(14,2) generated always as (round(quantity * unit_rate, 2)) stored,
  currency char(3) not null default 'BRL',
  applied boolean not null default false,
  source_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (measurement_id, category, source_system, source_table, source_record_id)
);

create index if not exists measurement_logistics_lookup_idx
  on medicao.measurement_logistics_lines (measurement_id, bsp, category, applied);

create table if not exists medicao.measurement_extra_lines (
  id uuid primary key default gen_random_uuid(),
  measurement_id uuid not null references medicao.measurements(id) on delete cascade,
  category text not null check (category in ('habitat', 'rentals', 'consumables', 'mob_materials')),
  bsp text not null,
  tag text,
  description text not null,
  client_name text,
  service_start date,
  service_end date,
  quantity numeric(14,4) not null default 1,
  unit text not null default 'item',
  unit_rate numeric(14,4) not null default 0,
  amount numeric(14,2) generated always as (round(quantity * unit_rate, 2)) stored,
  currency char(3) not null default 'BRL',
  notes text,
  applied boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists measurement_extra_lines_lookup_idx
  on medicao.measurement_extra_lines (measurement_id, category, bsp, applied);

create table if not exists medicao.measurement_approval_steps (
  id uuid primary key default gen_random_uuid(),
  measurement_id uuid not null references medicao.measurements(id) on delete cascade,
  step_code text not null check (step_code in ('draft', 'review_pm', 'sent_client', 'approved', 'invoiced')),
  step_order integer not null,
  status text not null default 'pending' check (status in ('pending', 'current', 'completed', 'rejected')),
  actor_user_id text,
  actor_name text,
  comments text,
  acted_at timestamptz,
  created_at timestamptz not null default now(),
  unique (measurement_id, step_code)
);

create index if not exists measurement_approval_steps_lookup_idx
  on medicao.measurement_approval_steps (measurement_id, step_order);

create or replace view public.medicao_measurement_sections
with (security_invoker = true)
as
select
  m.id as measurement_id,
  m.bsp,
  m.period_start,
  m.period_end,
  coalesce(l.category, 'sem_lancamento') as category,
  coalesce(sum(l.amount), 0)::numeric(14,2) as total_amount,
  count(l.id)::integer as line_count
from medicao.measurements m
left join medicao.measurement_lines l on l.measurement_id = m.id
group by m.id, m.bsp, m.period_start, m.period_end, l.category
union all
select
  m.id, m.bsp, m.period_start, m.period_end, l.category,
  coalesce(sum(l.amount), 0)::numeric(14,2), count(l.id)::integer
from medicao.measurements m
join medicao.measurement_logistics_lines l on l.measurement_id = m.id
where l.applied
group by m.id, m.bsp, m.period_start, m.period_end, l.category
union all
select
  m.id, m.bsp, m.period_start, m.period_end, l.category,
  coalesce(sum(l.amount), 0)::numeric(14,2), count(l.id)::integer
from medicao.measurements m
join medicao.measurement_extra_lines l on l.measurement_id = m.id
where l.applied
group by m.id, m.bsp, m.period_start, m.period_end, l.category;

revoke all on medicao.source_timesheet_periods, medicao.source_timesheet_days,
  medicao.measurement_logistics_lines, medicao.measurement_extra_lines,
  medicao.measurement_approval_steps from anon, authenticated;
grant select, insert, update, delete on all tables in schema medicao to service_role;
revoke all on public.medicao_measurement_sections from anon, authenticated;
grant select on public.medicao_measurement_sections to anon, authenticated;

create or replace function medicao.sync_timesheet_structure(
  p_period_start date,
  p_period_end date,
  p_bsp text default null
)
returns jsonb
language plpgsql
set search_path = pg_catalog, medicao, offshore_ts
as $$
declare
  v_periods integer := 0;
  v_days integer := 0;
begin
  if p_period_end < p_period_start then
    raise exception 'Período inválido: data final anterior à inicial';
  end if;

  insert into medicao.source_timesheet_periods (
    source_record_id, campaign_id, campaign_member_id, project_key, client_name,
    unit_name, bsp, employee_key, employee_name, employee_function, period_start,
    period_end, source_status, version, approval_status, source_approved,
    locked_at, source_updated_at, source_payload, imported_at
  )
  select
    w.id::text,
    w.campaign_id,
    w.campaign_member_id,
    c.project_key,
    c.client_name,
    c.unit_name,
    coalesce(w.bsp_snapshot, c.bsp_context),
    cm.employee_registration,
    w.employee_name_snapshot,
    w.function_snapshot,
    w.week_start,
    coalesce(w.week_end, w.week_start + 6),
    w.status::text,
    w.version,
    (select max(a.status::text) from offshore_ts.approvals a where a.weekly_timesheet_id = w.id),
    (
      w.status::text in ('supervisor_approved', 'management_approved', 'client_approved', 'locked')
      or exists (
        select 1 from offshore_ts.approvals a
        where a.weekly_timesheet_id = w.id
          and a.status::text = 'approved'
          and a.level::text in ('measurement', 'manager', 'client')
      )
    ),
    w.locked_at,
    w.updated_at,
    to_jsonb(w),
    now()
  from offshore_ts.weekly_timesheets w
  join offshore_ts.campaigns c on c.id = w.campaign_id
  left join offshore_ts.campaign_members cm on cm.id = w.campaign_member_id
  where coalesce(w.week_end, w.week_start + 6) >= p_period_start
    and w.week_start <= p_period_end
    and (p_bsp is null or medicao.normalize_bsp(coalesce(w.bsp_snapshot, c.bsp_context)) = medicao.normalize_bsp(p_bsp))
  on conflict (source_system, source_table, source_record_id) do update set
    campaign_id = excluded.campaign_id,
    campaign_member_id = excluded.campaign_member_id,
    project_key = excluded.project_key,
    client_name = excluded.client_name,
    unit_name = excluded.unit_name,
    bsp = excluded.bsp,
    employee_key = excluded.employee_key,
    employee_name = excluded.employee_name,
    employee_function = excluded.employee_function,
    period_start = excluded.period_start,
    period_end = excluded.period_end,
    source_status = excluded.source_status,
    version = excluded.version,
    approval_status = excluded.approval_status,
    source_approved = excluded.source_approved,
    locked_at = excluded.locked_at,
    source_updated_at = excluded.source_updated_at,
    source_payload = excluded.source_payload,
    imported_at = now();
  get diagnostics v_periods = row_count;

  insert into medicao.source_timesheet_days (
    source_record_id, source_period_id, source_weekly_timesheet_id, work_date,
    day_status, expected_minutes, break_minutes, normal_minutes, overtime_minutes,
    night_minutes, total_minutes, overtime_authorized, requires_review,
    validation_errors, source_payload, imported_at
  )
  select
    d.id::text,
    p.id,
    d.weekly_timesheet_id,
    d.work_date,
    d.status::text,
    d.expected_minutes,
    d.break_minutes,
    coalesce(sum(te.normal_minutes), 0)::integer,
    coalesce(sum(te.overtime_minutes), 0)::integer,
    coalesce(sum(te.night_minutes), 0)::integer,
    coalesce(sum(te.total_minutes), 0)::integer,
    d.overtime_authorized,
    d.requires_review,
    d.validation_errors,
    to_jsonb(d),
    now()
  from offshore_ts.timesheet_days d
  join medicao.source_timesheet_periods p
    on p.source_record_id = d.weekly_timesheet_id::text
  left join offshore_ts.task_entries te on te.timesheet_day_id = d.id
  where d.work_date between p_period_start and p_period_end
  group by d.id, p.id, d.weekly_timesheet_id, d.work_date, d.status,
    d.expected_minutes, d.break_minutes, d.overtime_authorized, d.requires_review,
    d.validation_errors
  on conflict (source_system, source_table, source_record_id) do update set
    source_period_id = excluded.source_period_id,
    source_weekly_timesheet_id = excluded.source_weekly_timesheet_id,
    work_date = excluded.work_date,
    day_status = excluded.day_status,
    expected_minutes = excluded.expected_minutes,
    break_minutes = excluded.break_minutes,
    normal_minutes = excluded.normal_minutes,
    overtime_minutes = excluded.overtime_minutes,
    night_minutes = excluded.night_minutes,
    total_minutes = excluded.total_minutes,
    overtime_authorized = excluded.overtime_authorized,
    requires_review = excluded.requires_review,
    validation_errors = excluded.validation_errors,
    source_payload = excluded.source_payload,
    imported_at = now();
  get diagnostics v_days = row_count;

  return jsonb_build_object('periods', v_periods, 'days', v_days);
end;
$$;

grant execute on function medicao.sync_timesheet_structure(date, date, text) to service_role;
