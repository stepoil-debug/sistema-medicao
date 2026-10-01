-- Projeções sanitizadas para a interface pública do GitHub Pages.
-- Nenhuma coluna de colaborador, payload de origem ou credencial é exposta.

create or replace view public.medicao_dashboard_summary as
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
)
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
left join people_counts pc on pc.measurement_id = m.id;

create or replace view public.medicao_dashboard_lines as
select
  l.id,
  l.measurement_id,
  l.category,
  l.source_system,
  l.service_date,
  l.quantity,
  l.unit,
  l.unit_rate,
  l.amount,
  l.currency,
  l.source_approved
from medicao.measurement_lines l;

revoke all on public.medicao_dashboard_summary, public.medicao_dashboard_lines from anon, authenticated;
grant select on public.medicao_dashboard_summary, public.medicao_dashboard_lines to anon, authenticated;
