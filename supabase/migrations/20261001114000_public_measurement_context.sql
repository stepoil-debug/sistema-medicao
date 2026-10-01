-- Contexto operacional sanitizado para a interface pública.
-- Exibe cliente/projeto/local, sem colaborador, payload ou credencial.

drop view if exists public.medicao_dashboard_summary;

create view public.medicao_dashboard_summary as
with line_counts as (
  select measurement_id, count(*)::integer as line_count
  from medicao.measurement_lines
  group by measurement_id
), validation_counts as (
  select
    measurement_id,
    count(*) filter (where severity = 'error')::integer as error_count,
    count(*) filter (where severity = 'warning')::integer as warning_count
  from medicao.measurement_validations
  group by measurement_id
), people_counts as (
  select
    m.id as measurement_id,
    coalesce(
      nullif((select count(distinct t.employee_name)::integer
        from medicao.source_timesheet_entries t
        where t.bsp = m.bsp and t.work_date between m.period_start and m.period_end and t.source_approved), 0),
      (select count(distinct t.employee_name)::integer
        from medicao.source_rdo_timesheet_entries t
        where t.bsp = m.bsp and t.work_date between m.period_start and m.period_end and t.rdo_status = 'completed'),
      0
    ) as people_count,
    case when exists (
      select 1 from medicao.source_timesheet_entries t
      where t.bsp = m.bsp and t.work_date between m.period_start and m.period_end and t.source_approved
    ) then 'Timesheet' else 'RDO' end as source_mode
  from medicao.measurements m
), source_context as (
  select
    m.id as measurement_id,
    coalesce(
      (select t.client_name from medicao.source_timesheet_entries t
        where t.bsp = m.bsp and t.work_date between m.period_start and m.period_end
        order by t.work_date desc, t.imported_at desc limit 1),
      (select r.client_name from medicao.source_rdo_records r
        where r.bsp = m.bsp and r.work_date between m.period_start and m.period_end
        order by r.work_date desc, r.imported_at desc limit 1)
    ) as client_name,
    coalesce(
      (select r.project_name from medicao.source_rdo_records r
        where r.bsp = m.bsp and r.work_date between m.period_start and m.period_end
        order by r.work_date desc, r.imported_at desc limit 1),
      m.project_key
    ) as project_name,
    coalesce(
      (select t.location from medicao.source_timesheet_entries t
        where t.bsp = m.bsp and t.work_date between m.period_start and m.period_end
        order by t.work_date desc, t.imported_at desc limit 1),
      (select r.location from medicao.source_rdo_records r
        where r.bsp = m.bsp and r.work_date between m.period_start and m.period_end
        order by r.work_date desc, r.imported_at desc limit 1)
    ) as location
  from medicao.measurements m
)
select
  m.id,
  m.bsp,
  m.project_key,
  sc.client_name,
  sc.project_name,
  sc.location,
  m.period_start,
  m.period_end,
  m.version,
  m.status,
  m.currency,
  m.total_amount,
  coalesce(lc.line_count, 0) as line_count,
  coalesce(vc.error_count, 0) as error_count,
  coalesce(vc.warning_count, 0) as warning_count,
  coalesce(pc.people_count, 0) as people_count,
  coalesce(pc.source_mode, 'Sem fonte') as source_mode,
  m.generated_at,
  m.approved_at
from medicao.measurements m
left join line_counts lc on lc.measurement_id = m.id
left join validation_counts vc on vc.measurement_id = m.id
left join people_counts pc on pc.measurement_id = m.id
left join source_context sc on sc.measurement_id = m.id;

revoke all on public.medicao_dashboard_summary from anon, authenticated;
grant select on public.medicao_dashboard_summary to anon, authenticated;
