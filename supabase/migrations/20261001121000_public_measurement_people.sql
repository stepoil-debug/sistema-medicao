-- Detalhamento operacional para o boletim: pessoas e horas do período.
-- Esta projeção não expõe payloads de origem nem dados de autenticação.

drop view if exists public.medicao_dashboard_lines;

create view public.medicao_dashboard_lines as
select
  l.id,
  l.measurement_id,
  l.category,
  l.source_system,
  l.service_date,
  l.employee_name,
  coalesce(
    (select t.employee_function
       from medicao.source_rdo_timesheet_entries t
      where l.source_system = 'offshore_rdo'
        and t.source_record_id = l.source_record_id
      limit 1),
    (select t.employee_function
       from medicao.source_timesheet_entries t
      where l.source_system = 'offshore_ts'
        and t.source_record_id = l.source_record_id
      limit 1)
  ) as employee_function,
  l.description,
  l.quantity,
  l.unit,
  l.unit_rate,
  l.amount,
  l.currency,
  l.source_approved
from medicao.measurement_lines l;

create or replace view public.medicao_dashboard_people as
with rdo_people as (
  select
    m.id as measurement_id,
    m.bsp,
    t.employee_name,
    t.employee_function,
    t.work_date,
    t.normal_hours,
    t.overtime_hours,
    t.total_hours,
    t.source_status,
    t.source_approved,
    'RDO'::text as source_mode
  from medicao.measurements m
  join medicao.source_rdo_timesheet_entries t
    on t.bsp = m.bsp
   and t.work_date between m.period_start and m.period_end
   and t.rdo_status = 'completed'
), ts_people as (
  select
    m.id as measurement_id,
    m.bsp,
    t.employee_name,
    t.employee_function,
    t.work_date,
    t.normal_minutes::numeric / 60 as normal_hours,
    t.overtime_minutes::numeric / 60 as overtime_hours,
    t.total_minutes::numeric / 60 as total_hours,
    t.source_status,
    t.source_approved,
    'Timesheet'::text as source_mode
  from medicao.measurements m
  join medicao.source_timesheet_entries t
    on t.bsp = m.bsp
   and t.work_date between m.period_start and m.period_end
)
select * from rdo_people
union all
select * from ts_people;

revoke all on public.medicao_dashboard_lines, public.medicao_dashboard_people from anon, authenticated;
grant select on public.medicao_dashboard_lines, public.medicao_dashboard_people to anon, authenticated;
