-- Corrige a agregação da view para não multiplicar linhas por validações.

create or replace view medicao_api.measurement_summary
with (security_invoker = true)
as
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
  m.generated_at,
  m.approved_at
from medicao.measurements m
left join line_counts lc on lc.measurement_id = m.id
left join validation_counts vc on vc.measurement_id = m.id;
