-- Cadastro persistente de tarifas por cliente, função e categoria.
-- A confirmação feita na tela cria uma nova versão rastreável das regras e
-- regenera o rascunho da medição que estava aguardando tarifa.

create table if not exists medicao.client_rate_cards (
  id uuid primary key default gen_random_uuid(),
  client_name text not null,
  client_key text not null,
  bsp text,
  project_key text,
  proposal_code text,
  file_name text,
  currency char(3) not null default 'BRL',
  valid_from date not null default date '1900-01-01',
  valid_to date,
  active boolean not null default true,
  confirmed_at timestamptz,
  confirmed_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (valid_to is null or valid_to >= valid_from)
);

create index if not exists client_rate_cards_lookup_idx
  on medicao.client_rate_cards (client_key, bsp, project_key, active, valid_from, valid_to);

create table if not exists medicao.client_rate_items (
  id uuid primary key default gen_random_uuid(),
  rate_card_id uuid not null references medicao.client_rate_cards(id) on delete cascade,
  category text not null check (category in (
    'normal_hours', 'overtime_hours', 'night_hours', 'standby_hours',
    'travel_hours', 'beyond_rotation_hours', 'daily', 'mobilization',
    'demobilization', 'logistics', 'habitat', 'rentals', 'consumables'
  )),
  employee_function text not null,
  employee_function_normalized text not null,
  unit text not null,
  rate numeric(14, 4) not null check (rate >= 0),
  active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists client_rate_items_unique_idx
  on medicao.client_rate_items (rate_card_id, category, employee_function_normalized);

alter table medicao.client_rate_cards enable row level security;
alter table medicao.client_rate_cards force row level security;
alter table medicao.client_rate_items enable row level security;
alter table medicao.client_rate_items force row level security;

drop policy if exists client_rate_cards_public_read on medicao.client_rate_cards;
create policy client_rate_cards_public_read
  on medicao.client_rate_cards for select
  to anon, authenticated
  using (active);

drop policy if exists client_rate_items_public_read on medicao.client_rate_items;
create policy client_rate_items_public_read
  on medicao.client_rate_items for select
  to anon, authenticated
  using (active and exists (
    select 1 from medicao.client_rate_cards c
    where c.id = rate_card_id and c.active
  ));

revoke all on medicao.client_rate_cards, medicao.client_rate_items from anon, authenticated;
grant select on medicao.client_rate_cards, medicao.client_rate_items to anon, authenticated;
grant all on medicao.client_rate_cards, medicao.client_rate_items to service_role;

drop view if exists public.medicao_rate_catalog;
create view public.medicao_rate_catalog with (security_invoker = true) as
select
  c.id as rate_card_id,
  c.client_name,
  c.client_key,
  c.bsp,
  c.project_key,
  c.proposal_code,
  c.file_name,
  c.currency,
  c.valid_from,
  c.valid_to,
  i.id as rate_item_id,
  i.category,
  i.employee_function,
  i.employee_function_normalized,
  i.unit,
  i.rate,
  i.notes,
  c.confirmed_at
from medicao.client_rate_cards c
join medicao.client_rate_items i on i.rate_card_id = c.id
where c.active and i.active;

revoke all on public.medicao_rate_catalog from anon, authenticated;
grant select on public.medicao_rate_catalog to anon, authenticated;

create or replace function public.medicao_confirm_rate_catalog(
  p_measurement_id uuid,
  p_client_name text,
  p_bsp text,
  p_project_key text,
  p_currency char(3),
  p_rows jsonb,
  p_proposal_code text default null,
  p_file_name text default 'Cadastro de rates por cliente'
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, medicao
as $$
declare
  v_measurement medicao.measurements%rowtype;
  v_card_id uuid;
  v_source_id uuid;
  v_new_measurement_id uuid;
  v_client_key text := medicao.normalize_function(p_client_name);
  v_row record;
  v_rows integer := 0;
begin
  if nullif(trim(p_client_name), '') is null then
    raise exception 'Cliente é obrigatório.';
  end if;
  if nullif(trim(p_bsp), '') is null then
    raise exception 'BSP é obrigatória.';
  end if;
  if jsonb_typeof(p_rows) <> 'array' then
    raise exception 'As tarifas devem ser enviadas como uma lista.';
  end if;

  select * into v_measurement
  from medicao.measurements
  where id = p_measurement_id;
  if not found then
    raise exception 'Medição não encontrada.';
  end if;
  if medicao.normalize_bsp(v_measurement.bsp) <> medicao.normalize_bsp(p_bsp) then
    raise exception 'A BSP da confirmação não corresponde à medição.';
  end if;

  select id into v_card_id
  from medicao.client_rate_cards
  where client_key = v_client_key
    and medicao.normalize_bsp(bsp) = medicao.normalize_bsp(p_bsp)
    and project_key is not distinct from p_project_key
  order by updated_at desc
  limit 1;

  if v_card_id is null then
    insert into medicao.client_rate_cards (
      client_name, client_key, bsp, project_key, proposal_code, file_name,
      currency, confirmed_at, confirmed_by
    ) values (
      trim(p_client_name), v_client_key, trim(p_bsp), p_project_key,
      nullif(trim(p_proposal_code), ''), nullif(trim(p_file_name), ''),
      coalesce(nullif(trim(p_currency), ''), 'BRL'), now(), current_user
    ) returning id into v_card_id;
  else
    update medicao.client_rate_cards
    set client_name = trim(p_client_name),
        proposal_code = coalesce(nullif(trim(p_proposal_code), ''), proposal_code),
        file_name = coalesce(nullif(trim(p_file_name), ''), file_name),
        currency = coalesce(nullif(trim(p_currency), ''), currency),
        active = true,
        confirmed_at = now(),
        confirmed_by = current_user,
        updated_at = now()
    where id = v_card_id;
  end if;

  for v_row in
    select * from jsonb_to_recordset(p_rows) as x(
      category text,
      employee_function text,
      unit text,
      rate numeric,
      notes text
    )
  loop
    if v_row.category not in (
      'normal_hours', 'overtime_hours', 'night_hours', 'standby_hours',
      'travel_hours', 'beyond_rotation_hours', 'daily', 'mobilization',
      'demobilization', 'logistics', 'habitat', 'rentals', 'consumables'
    ) then
      raise exception 'Categoria de tarifa inválida: %.', v_row.category;
    end if;
    if nullif(trim(v_row.employee_function), '') is null then
      raise exception 'Toda tarifa precisa de uma função.';
    end if;
    if v_row.rate is null or v_row.rate < 0 then
      raise exception 'Toda tarifa precisa de um valor não negativo.';
    end if;

    insert into medicao.client_rate_items (
      rate_card_id, category, employee_function, employee_function_normalized,
      unit, rate, notes, active, updated_at
    ) values (
      v_card_id, v_row.category, trim(v_row.employee_function),
      medicao.normalize_function(v_row.employee_function),
      coalesce(nullif(trim(v_row.unit), ''), case when v_row.category = 'daily' then 'day' else 'hour' end),
      v_row.rate, v_row.notes, true, now()
    )
    on conflict (rate_card_id, category, employee_function_normalized)
    do update set
      employee_function = excluded.employee_function,
      unit = excluded.unit,
      rate = excluded.rate,
      notes = excluded.notes,
      active = true,
      updated_at = now();
    v_rows := v_rows + 1;
  end loop;

  if v_rows = 0 then
    raise exception 'Informe pelo menos uma tarifa.';
  end if;

  update medicao.rate_sources
  set active = false
  where medicao.normalize_bsp(bsp) = medicao.normalize_bsp(p_bsp)
    and source_section = 'Cadastro por cliente'
    and active;

  insert into medicao.rate_sources (
    bsp, proposal_code, file_name, source_section, valid_from, metadata, imported_by
  ) values (
    trim(p_bsp), coalesce(nullif(trim(p_proposal_code), ''), 'CATALOG-' || upper(v_client_key)),
    coalesce(nullif(trim(p_file_name), ''), 'Cadastro de rates por cliente'),
    'Cadastro por cliente', date '1900-01-01',
    jsonb_build_object('rate_card_id', v_card_id, 'client_name', trim(p_client_name)), current_user
  ) returning id into v_source_id;

  update medicao.rate_rules r
  set active = false
  where r.rate_source_id in (
    select id from medicao.rate_sources
    where medicao.normalize_bsp(bsp) = medicao.normalize_bsp(p_bsp)
      and source_section = 'Cadastro por cliente'
      and id <> v_source_id
  );

  insert into medicao.rate_rules (
    category, project_key, bsp, unit, rate, currency, valid_from, valid_to,
    active, notes, rate_source_id, employee_function, employee_function_normalized,
    rate_description, source_reference
  )
  select
    i.category, v_measurement.project_key, v_measurement.bsp, i.unit, i.rate,
    c.currency, c.valid_from, c.valid_to, true, i.notes, v_source_id,
    i.employee_function, i.employee_function_normalized,
    i.employee_function || ' · ' || i.category,
    'client_rate_card:' || v_card_id::text
  from medicao.client_rate_items i
  join medicao.client_rate_cards c on c.id = i.rate_card_id
  where i.rate_card_id = v_card_id and i.active;

  select medicao.generate_draft(
    v_measurement.bsp, v_measurement.period_start, v_measurement.period_end,
    v_measurement.project_key, v_measurement.currency
  ) into v_new_measurement_id;

  return jsonb_build_object(
    'ok', true,
    'rate_card_id', v_card_id,
    'rate_source_id', v_source_id,
    'measurement_id', v_new_measurement_id,
    'confirmed_rows', v_rows
  );
end;
$$;

revoke all on function public.medicao_confirm_rate_catalog(uuid, text, text, text, char, jsonb, text, text)
  from public, anon, authenticated;
grant execute on function public.medicao_confirm_rate_catalog(uuid, text, text, text, char, jsonb, text, text)
  to anon, authenticated, service_role;
