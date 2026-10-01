-- Tarifas da medição devem ser rastreáveis à proposta BPP da BSP.
-- A tabela é interna: a página pública só recebe os valores já calculados.

create or replace function medicao.normalize_bsp(p_value text)
returns text
language sql
immutable
as $$
  select regexp_replace(lower(trim(coalesce(p_value, ''))), '[^a-z0-9]', '', 'g');
$$;

create or replace function medicao.normalize_function(p_value text)
returns text
language sql
immutable
as $$
  select regexp_replace(
    translate(
      lower(trim(coalesce(p_value, ''))),
      'áàãâäéèêëíìîïóòõôöúùûüçñ',
      'aaaaaeeeeiiiiooooouuuucn'
    ),
    '[^a-z0-9]',
    '',
    'g'
  );
$$;

create table if not exists medicao.rate_sources (
  id uuid primary key default gen_random_uuid(),
  bsp text not null,
  proposal_code text not null,
  file_name text not null,
  source_section text not null default 'Commercial offer',
  source_locator text,
  file_hash text,
  valid_from date,
  valid_to date,
  active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  imported_by text,
  imported_at timestamptz not null default now(),
  check (valid_to is null or valid_from is null or valid_to >= valid_from)
);

create index if not exists rate_sources_lookup_idx
  on medicao.rate_sources (bsp, active, valid_from, valid_to);

alter table medicao.rate_rules
  add column if not exists rate_source_id uuid references medicao.rate_sources(id),
  add column if not exists employee_function text,
  add column if not exists employee_function_normalized text,
  add column if not exists rate_description text,
  add column if not exists source_reference text,
  add column if not exists source_row_number integer;

update medicao.rate_rules
set employee_function_normalized = medicao.normalize_function(employee_function)
where employee_function is not null
  and nullif(employee_function_normalized, '') is null;

create index if not exists rate_rules_function_lookup_idx
  on medicao.rate_rules (category, bsp, employee_function_normalized, valid_from, valid_to, active);

alter table medicao.measurement_lines
  add column if not exists employee_function text,
  add column if not exists rate_source_id uuid references medicao.rate_sources(id),
  add column if not exists rate_source_proposal text,
  add column if not exists rate_source_file text,
  add column if not exists rate_source_section text,
  add column if not exists rate_source_reference text;

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
      t.employee_function,
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
    where medicao.normalize_bsp(t.bsp) = medicao.normalize_bsp(p_bsp)
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
      t.employee_function,
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
    where medicao.normalize_bsp(t.bsp) = medicao.normalize_bsp(p_bsp)
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
      employee_function, task_description, source_approved, source_payload, 'daily'::text category,
      1::numeric quantity, 'day'::text unit
      from selected_base
      where source_system = 'offshore_rdo' and normal_hours > 0
    union all
    select source_system, source_table, source_record_id, work_date, employee_name,
      employee_function, task_description, source_approved, source_payload, 'normal_hours'::text category,
      normal_hours quantity, 'hour'::text unit
      from selected_base
      where source_system <> 'offshore_rdo' and normal_hours > 0
    union all
    select source_system, source_table, source_record_id, work_date, employee_name,
      employee_function, task_description, source_approved, source_payload, 'overtime_hours', overtime_hours, 'hour'
      from selected_base where overtime_hours > 0
    union all
    select source_system, source_table, source_record_id, work_date, employee_name,
      employee_function, task_description, source_approved, source_payload, 'night_hours', night_hours, 'hour'
      from selected_base where night_hours > 0
    union all
    select source_system, source_table, source_record_id, work_date, employee_name,
      employee_function, task_description, source_approved, source_payload, 'standby_hours', standby_hours, 'hour'
      from selected_base where standby_hours > 0
    union all
    select source_system, source_table, source_record_id, work_date, employee_name,
      employee_function, task_description, source_approved, source_payload, 'travel_hours', travel_hours, 'hour'
      from selected_base where travel_hours > 0
    union all
    select source_system, source_table, source_record_id, work_date, employee_name,
      employee_function, task_description, source_approved, source_payload, 'beyond_rotation_hours', beyond_rotation_hours, 'hour'
      from selected_base where beyond_rotation_hours > 0
  )
  insert into medicao.measurement_lines (
    measurement_id, category, source_system, source_table, source_record_id,
    service_date, employee_name, employee_function, description, quantity, unit,
    unit_rate, amount, currency, source_approved, source_payload,
    rate_source_id, rate_source_proposal, rate_source_file, rate_source_section,
    rate_source_reference
  )
  select
    v_measurement_id, n.category, n.source_system, n.source_table, n.source_record_id,
    n.work_date, n.employee_name, n.employee_function, n.task_description, n.quantity, n.unit,
    rr.rate,
    round(n.quantity * coalesce(rr.rate, 0), 2),
    coalesce(rr.currency, p_currency), n.source_approved, n.source_payload,
    rr.rate_source_id, rr.proposal_code, rr.file_name, rr.source_section, rr.source_reference
  from normalized n
  left join lateral (
    select
      r.rate, r.currency, r.rate_source_id, rs.proposal_code, rs.file_name,
      rs.source_section, r.source_reference
    from medicao.rate_rules r
    left join medicao.rate_sources rs on rs.id = r.rate_source_id
    where r.category = n.category
      and r.active
      and (r.bsp is null or medicao.normalize_bsp(r.bsp) = medicao.normalize_bsp(p_bsp))
      and (r.project_key is null or r.project_key = p_project_key)
      and (r.employee_function is null
        or medicao.normalize_function(r.employee_function) = medicao.normalize_function(n.employee_function))
      and n.work_date >= r.valid_from
      and (r.valid_to is null or n.work_date <= r.valid_to)
      and (r.rate_source_id is null or (rs.active and medicao.normalize_bsp(rs.bsp) = medicao.normalize_bsp(p_bsp)))
    order by
      (r.employee_function is not null) desc,
      (r.bsp is not null) desc,
      (r.project_key is not null) desc,
      (r.rate_source_id is not null) desc,
      r.valid_from desc
    limit 1
  ) rr on true;

  select count(*) into v_source_count
  from medicao.measurement_lines l
  where l.measurement_id = v_measurement_id;

  insert into medicao.measurement_validations (
    measurement_id, measurement_line_id, severity, code, message, metadata
  )
  select v_measurement_id, l.id, 'error', 'MISSING_RATE',
    format('Não existe tarifa Commercial offer para %s / %s na data %s.',
      l.category, coalesce(l.employee_function, 'função não informada'), l.service_date),
    jsonb_build_object(
      'category', l.category,
      'employee_function', l.employee_function,
      'bsp', p_bsp,
      'service_date', l.service_date,
      'expected_source', 'BPP / Commercial offer'
    )
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
    jsonb_build_object('source_count', v_source_count, 'period_start', p_period_start, 'period_end', p_period_end,
      'rate_source', 'BPP / Commercial offer', 'function_matching', true));

  return v_measurement_id;
end;
$$;

drop view if exists public.medicao_dashboard_lines;

create view public.medicao_dashboard_lines as
select
  l.id,
  l.measurement_id,
  l.category,
  l.source_system,
  l.service_date,
  l.employee_name,
  l.employee_function,
  l.description,
  l.quantity,
  l.unit,
  l.unit_rate,
  l.amount,
  l.currency,
  l.source_approved,
  l.rate_source_proposal,
  l.rate_source_file,
  l.rate_source_section,
  l.rate_source_reference
from medicao.measurement_lines l;

alter table medicao.rate_sources enable row level security;
alter table medicao.rate_sources force row level security;
revoke all on medicao.rate_sources from anon, authenticated;
grant select, insert, update, delete on medicao.rate_sources to service_role;

revoke all on public.medicao_dashboard_lines from anon, authenticated;
grant select on public.medicao_dashboard_lines to anon, authenticated;
