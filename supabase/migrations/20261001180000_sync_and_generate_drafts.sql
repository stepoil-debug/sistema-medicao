-- Rotina única para o backend executar a implantação/sincronização da medição.
-- RDO e Timesheet são somente leitura; os resultados são gravados em medicao.

create or replace function medicao.sync_and_generate_drafts(
  p_period_start date,
  p_period_end date,
  p_bsp text default null,
  p_currency char(3) default 'BRL'
)
returns jsonb
language plpgsql
set search_path = pg_catalog, medicao
as $$
declare
  v_run_id uuid;
  v_structure jsonb;
  v_bsp text;
  v_measurement_id uuid;
  v_items jsonb := '[]'::jsonb;
begin
  if p_period_end < p_period_start then
    raise exception 'Período inválido: data final anterior à inicial';
  end if;

  v_run_id := medicao.sync_sources(p_period_start, p_period_end, p_bsp);
  v_structure := medicao.sync_timesheet_structure(p_period_start, p_period_end, p_bsp);

  for v_bsp in
    select distinct bsp
    from (
      select t.bsp
      from medicao.source_rdo_timesheet_entries t
      where t.work_date between p_period_start and p_period_end
        and t.bsp is not null
      union
      select t.bsp
      from medicao.source_timesheet_entries t
      where t.work_date between p_period_start and p_period_end
        and t.bsp is not null
    ) sources
    where p_bsp is null or medicao.normalize_bsp(bsp) = medicao.normalize_bsp(p_bsp)
    order by bsp
  loop
    v_measurement_id := medicao.generate_draft(v_bsp, p_period_start, p_period_end, null, p_currency);
    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'bsp', v_bsp,
      'measurement_id', v_measurement_id
    ));
  end loop;

  return jsonb_build_object(
    'sync_run_id', v_run_id,
    'timesheet_structure', v_structure,
    'measurements', v_items
  );
end;
$$;

revoke all on function medicao.sync_and_generate_drafts(date, date, text, char) from public, anon, authenticated;
grant execute on function medicao.sync_and_generate_drafts(date, date, text, char) to service_role;

