-- STEP Sistema de Medição — integração RDO / Timesheet / Onshore-Offshore
-- Fonte operacional: offshore_rdo + offshore_ts
-- Contexto: Smartsheet Service Control + RFQ
-- Regra: conflitos nunca são resolvidos silenciosamente.

create table if not exists medicao.project_context_sources (
  id uuid primary key default gen_random_uuid(),
  source_system text not null,
  source_asset_id bigint not null,
  source_row_id bigint not null,
  source_name text not null,
  canonical_bsp text not null,
  bsp_source text,
  client_name text,
  unit_name text,
  po_number text,
  po_date date,
  pm_name text,
  service_type text,
  work_type text,
  quote_status text,
  total_po_value numeric(18,2),
  project_closed boolean,
  explicit_regime text not null default 'NOT_VERIFIED'
    check (explicit_regime in ('ONSHORE','OFFSHORE','NOT_VERIFIED')),
  evidence_status text not null default 'CONFIRMADO'
    check (evidence_status in ('CONFIRMADO','INFERIDO','CONFLITANTE','NOT_VERIFIED','CONFIRM_WITH_CLIENT')),
  source_payload jsonb not null default '{}'::jsonb,
  synced_at timestamptz not null default now(),
  unique (source_system, source_asset_id, source_row_id)
);

create index if not exists project_context_sources_bsp_idx
  on medicao.project_context_sources (canonical_bsp);

create table if not exists medicao.bsp_aliases (
  alias_bsp text not null,
  canonical_bsp text not null,
  match_status text not null
    check (match_status in ('CONFIRMADO','INFERIDO','CONFLITANTE','NOT_VERIFIED','CONFIRM_WITH_CLIENT')),
  auto_match boolean not null default false,
  source_reference text,
  notes text,
  created_at timestamptz not null default now(),
  primary key (alias_bsp, canonical_bsp)
);

create table if not exists medicao.bsp_composite_components (
  source_bsp text not null,
  component_bsp text not null,
  match_status text not null
    check (match_status in ('CONFIRMADO','INFERIDO','CONFLITANTE','NOT_VERIFIED','CONFIRM_WITH_CLIENT')),
  auto_allocate boolean not null default false,
  source_reference text,
  notes text,
  created_at timestamptz not null default now(),
  primary key (source_bsp, component_bsp)
);

alter table medicao.project_context_sources enable row level security;
alter table medicao.bsp_aliases enable row level security;
alter table medicao.bsp_composite_components enable row level security;

revoke all on medicao.project_context_sources from public, anon, authenticated;
revoke all on medicao.bsp_aliases from public, anon, authenticated;
revoke all on medicao.bsp_composite_components from public, anon, authenticated;
grant all on medicao.project_context_sources to service_role;
grant all on medicao.bsp_aliases to service_role;
grant all on medicao.bsp_composite_components to service_role;

create or replace function medicao.bsp_match_key(p_value text)
returns text language sql immutable
set search_path = pg_catalog, medicao
as $$
  select upper(
    regexp_replace(
      regexp_replace(trim(coalesce(p_value,'')), '^BSP[- ]*', '', 'i'),
      '[[:space:]]+', '', 'g'
    )
  );
$$;

create or replace function medicao.normalize_client(p_value text)
returns text language sql immutable
set search_path = pg_catalog, medicao
as $$
  select regexp_replace(
    lower(replace(trim(coalesce(p_value,'')), ' - Contract', '')),
    '[^a-z0-9]', '', 'g'
  );
$$;

-- Evidências capturadas em 2026-10-05.
insert into medicao.project_context_sources
(source_system,source_asset_id,source_row_id,source_name,canonical_bsp,bsp_source,client_name,unit_name,po_number,po_date,pm_name,service_type,work_type,quote_status,total_po_value,project_closed,explicit_regime,evidence_status,source_payload)
values
('smartsheet_service_control',4190800063031172,7983226136760196,'Onshore / Offshore Service Control','25-1032','25-1032','SBM','Paraty','A2602307','2026-02-12','Alvaro Moura','Installations',null,null,null,false,'NOT_VERIFIED','CONFIRMADO','{"sheet":"Onshore / Offshore Service Control","type_of_service":"Installations"}'),
('smartsheet_service_control',4190800063031172,8511412169408388,'Onshore / Offshore Service Control','25-481','25-481','SBM','Ilhabela','P 3260229','2026-03-13','Natan Oliveira','Labour supply',null,null,null,false,'NOT_VERIFIED','CONFIRMADO','{"sheet":"Onshore / Offshore Service Control","type_of_service":"Labour supply"}'),
('smartsheet_service_control',4190800063031172,1105800502902660,'Onshore / Offshore Service Control','25-481','25-481','SBM','Ilhabela','P3260229','2026-03-13','Natan Oliveira','Labour supply',null,null,null,false,'NOT_VERIFIED','CONFIRMADO','{"sheet":"Onshore / Offshore Service Control","type_of_service":"Labour supply","possible_duplicate":true}'),
('smartsheet_service_control',4190800063031172,5609400130273156,'Onshore / Offshore Service Control','25-481','25-481','SBM','Ilhabela','P3263488','2026-04-02','Natan Oliveira','Onshore Service',null,null,null,false,'ONSHORE','CONFIRMADO','{"sheet":"Onshore / Offshore Service Control","type_of_service":"Onshore Service"}'),
('smartsheet_service_control',4190800063031172,7179605051244420,'Onshore / Offshore Service Control','26-174','26-174','PRIO','FPSO Forte','CT 4600002177','2026-02-13','Rodrigo Quintão','Labour supply',null,null,null,false,'NOT_VERIFIED','CONFIRMADO','{"sheet":"Onshore / Offshore Service Control","type_of_service":"Labour supply"}'),
('smartsheet_service_control',4190800063031172,6741084408844164,'Onshore / Offshore Service Control','25-906','25-906','PRIO','Forte','4600003299.0','2025-11-10','Rodrigo Quintão','Installations',null,null,null,false,'NOT_VERIFIED','CONFIRMADO','{"sheet":"Onshore / Offshore Service Control","type_of_service":"Installations"}'),
('smartsheet_rfq',948132130017156,6327366042455940,'2026 RFQ Status Summary','25-481','BSP-25-481','SBM','Paraty','P3260229 / P3263488 / P3284549 / P3284553 / P3286029 / P3284512','2026-03-13',null,'Service Offshore','Manpower','PO RECEIVED',8724404.04,null,'OFFSHORE','CONFIRMADO','{"sheet":"2026 RFQ Status Summary","type_serv":"Service Offshore","type_of_work":"Manpower"}'),
('smartsheet_rfq',948132130017156,6708010294644612,'2026 RFQ Status Summary','26-174','BSP-26-174','PRIO - Contract','Forte','4500140515.0','2026-03-12',null,'Service Offshore',null,'PO RECEIVED',17268.00,null,'OFFSHORE','CONFIRMADO','{"sheet":"2026 RFQ Status Summary","type_serv":"Service Offshore"}'),
('smartsheet_rfq',948132130017156,5337805577457540,'2026 RFQ Status Summary','25-906','BSP-25-906','PRIO - Contract','Forte','Contrato: 4600003299','2025-10-30',null,'Fabrication','Piping Spools','PO RECEIVED',557636.66,null,'NOT_VERIFIED','CONFIRMADO','{"sheet":"2026 RFQ Status Summary","type_serv":"Fabrication","type_of_work":"Piping Spools"}'),
('smartsheet_rfq',948132130017156,2869007196028804,'2026 RFQ Status Summary','26-581','BSP-26-581','SBM','Saquarema',null,null,null,'Fabrication','Materials','NOT QUOTED',null,null,'NOT_VERIFIED','CONFIRMADO','{"sheet":"2026 RFQ Status Summary","type_serv":"Fabrication","type_of_work":"Materials"}'),
('smartsheet_rfq',948132130017156,7994225670164356,'2026 RFQ Status Summary','25-701','BSP-25-701','SBM','Ilhabela',null,null,null,'Fabrication','Piping Spools','DECLINED BY STEP',null,null,'NOT_VERIFIED','CONFIRMADO','{"sheet":"2026 RFQ Status Summary","type_serv":"Fabrication","type_of_work":"Piping Spools"}')
on conflict (source_system,source_asset_id,source_row_id) do update set
  canonical_bsp=excluded.canonical_bsp,bsp_source=excluded.bsp_source,client_name=excluded.client_name,
  unit_name=excluded.unit_name,po_number=excluded.po_number,po_date=excluded.po_date,pm_name=excluded.pm_name,
  service_type=excluded.service_type,work_type=excluded.work_type,quote_status=excluded.quote_status,
  total_po_value=excluded.total_po_value,project_closed=excluded.project_closed,explicit_regime=excluded.explicit_regime,
  evidence_status=excluded.evidence_status,source_payload=excluded.source_payload,synced_at=now();

insert into medicao.bsp_aliases(alias_bsp,canonical_bsp,match_status,auto_match,source_reference,notes)
values ('26581','26-581','NOT_VERIFIED',false,'RDO + 2026 RFQ Status Summary',
'Formato sugere 26-581, porém RDO está em CDI e RFQ 26-581 aponta SBM/Saquarema/Fabrication. Não usar automaticamente.')
on conflict (alias_bsp,canonical_bsp) do update set
match_status=excluded.match_status,auto_match=excluded.auto_match,source_reference=excluded.source_reference,notes=excluded.notes;

insert into medicao.bsp_composite_components(source_bsp,component_bsp,match_status,auto_allocate,source_reference,notes)
values
('26-174 \ 25-906','26-174','CONFIRMADO',false,'RDO + Onshore / Offshore Service Control','Componente textual confirmado; horas sem chave para alocação automática.'),
('26-174 \ 25-906','25-906','CONFIRMADO',false,'RDO + Onshore / Offshore Service Control','Componente textual confirmado; horas sem chave para alocação automática.')
on conflict (source_bsp,component_bsp) do update set
match_status=excluded.match_status,auto_allocate=excluded.auto_allocate,source_reference=excluded.source_reference,notes=excluded.notes;

create or replace view medicao.v_project_context_summary with (security_invoker=true) as
select canonical_bsp,count(*)::int context_rows,
 array_agg(distinct client_name) filter(where client_name is not null) clients,
 array_agg(distinct unit_name) filter(where unit_name is not null) units,
 array_agg(distinct po_number) filter(where po_number is not null) purchase_orders,
 array_agg(distinct pm_name) filter(where pm_name is not null) pms,
 array_agg(distinct service_type) filter(where service_type is not null) service_types,
 array_agg(distinct work_type) filter(where work_type is not null) work_types,
 case
  when count(distinct explicit_regime) filter(where explicit_regime<>'NOT_VERIFIED')>1 then 'CONFLITANTE'
  when count(distinct explicit_regime) filter(where explicit_regime<>'NOT_VERIFIED')=1 then max(explicit_regime) filter(where explicit_regime<>'NOT_VERIFIED')
  else 'NOT_VERIFIED' end work_regime,
 case
  when count(distinct medicao.normalize_client(client_name)) filter(where client_name is not null)>1 then 'CONFLITANTE'
  when count(distinct explicit_regime) filter(where explicit_regime<>'NOT_VERIFIED')>1 then 'CONFLITANTE'
  else 'CONFIRMADO' end context_status,
 max(synced_at) synced_at
from medicao.project_context_sources group by canonical_bsp;

create or replace view medicao.v_execution_sources with (security_invoker=true) as
with base as (
 select 'RDO'::text source_family,'RDO_INDIVIDUAL_TIMESHEET'::text source_type,
 r.source_record_id,r.source_rdo_record_id parent_record_id,r.protocol,r.employee_key,r.employee_name,r.employee_function,
 r.work_date,r.bsp bsp_raw,medicao.bsp_match_key(r.bsp) bsp_match_key,r.location,r.task_description,r.source_status,
 r.rdo_status parent_status,r.source_approved,r.normal_hours,r.overtime_hours,0::numeric night_hours,0::numeric standby_hours,
 0::numeric travel_hours,0::numeric beyond_rotation_hours,r.total_hours,r.confirmed_at,r.source_updated_at,r.imported_at
 from medicao.source_rdo_timesheet_entries r where r.rdo_status='completed'
 union all
 select 'TIMESHEET','OFFSHORE_TS_TASK',t.source_record_id,t.source_weekly_timesheet_id::text,null,t.employee_key,t.employee_name,
 t.employee_function,t.work_date,t.bsp,medicao.bsp_match_key(t.bsp),t.location,t.task_description,t.source_status,t.approval_status,
 t.source_approved,t.normal_minutes::numeric/60,t.overtime_minutes::numeric/60,t.night_minutes::numeric/60,
 t.standby_minutes::numeric/60,t.travel_minutes::numeric/60,t.beyond_rotation_minutes::numeric/60,t.total_minutes::numeric/60,
 null::timestamptz,t.source_updated_at,t.imported_at from medicao.source_timesheet_entries t
)
select b.*,
 coalesce(nullif(b.employee_key,''),medicao.normalize_function(b.employee_name)) person_match_key,
 case
  when exists(select 1 from medicao.project_context_sources pc where medicao.bsp_match_key(pc.canonical_bsp)=b.bsp_match_key)
   then (select min(pc.canonical_bsp) from medicao.project_context_sources pc where medicao.bsp_match_key(pc.canonical_bsp)=b.bsp_match_key)
  when exists(select 1 from medicao.bsp_aliases a where medicao.bsp_match_key(a.alias_bsp)=b.bsp_match_key and a.match_status='CONFIRMADO' and a.auto_match)
   then (select min(a.canonical_bsp) from medicao.bsp_aliases a where medicao.bsp_match_key(a.alias_bsp)=b.bsp_match_key and a.match_status='CONFIRMADO' and a.auto_match)
  else null end canonical_bsp,
 case
  when exists(select 1 from medicao.bsp_composite_components cc where medicao.bsp_match_key(cc.source_bsp)=b.bsp_match_key) then 'COMPOSITE_AMBIGUOUS'
  when exists(select 1 from medicao.project_context_sources pc where medicao.bsp_match_key(pc.canonical_bsp)=b.bsp_match_key) then 'EXACT'
  when exists(select 1 from medicao.bsp_aliases a where medicao.bsp_match_key(a.alias_bsp)=b.bsp_match_key and a.match_status='CONFIRMADO' and a.auto_match) then 'ALIAS_CONFIRMED'
  when exists(select 1 from medicao.bsp_aliases a where medicao.bsp_match_key(a.alias_bsp)=b.bsp_match_key) then 'ALIAS_NOT_VERIFIED'
  else 'UNMATCHED' end bsp_resolution_status
from base b;

create or replace view medicao.v_reconciliation_daily with (security_invoker=true) as
with rdo as (
 select work_date,person_match_key,bsp_match_key,max(employee_name) employee_name,max(employee_function) employee_function,
 max(bsp_raw) rdo_bsp,max(canonical_bsp) canonical_bsp,max(bsp_resolution_status) bsp_resolution_status,
 sum(normal_hours) rdo_normal_hours,sum(overtime_hours) rdo_overtime_hours,sum(total_hours) rdo_total_hours,
 bool_and(source_approved) rdo_approved,array_agg(source_record_id order by source_record_id) rdo_source_ids
 from medicao.v_execution_sources where source_family='RDO' group by work_date,person_match_key,bsp_match_key
), ts as (
 select work_date,person_match_key,bsp_match_key,max(employee_name) employee_name,max(employee_function) employee_function,
 max(bsp_raw) timesheet_bsp,max(canonical_bsp) canonical_bsp,max(bsp_resolution_status) bsp_resolution_status,
 sum(normal_hours) ts_normal_hours,sum(overtime_hours) ts_overtime_hours,sum(night_hours) ts_night_hours,
 sum(standby_hours) ts_standby_hours,sum(travel_hours) ts_travel_hours,sum(beyond_rotation_hours) ts_beyond_rotation_hours,
 sum(total_hours) ts_total_hours,bool_and(source_approved) ts_approved,array_agg(source_record_id order by source_record_id) ts_source_ids
 from medicao.v_execution_sources where source_family='TIMESHEET' group by work_date,person_match_key,bsp_match_key
)
select coalesce(r.work_date,t.work_date) work_date,coalesce(r.person_match_key,t.person_match_key) person_match_key,
 coalesce(r.employee_name,t.employee_name) employee_name,coalesce(r.employee_function,t.employee_function) employee_function,
 coalesce(r.rdo_bsp,t.timesheet_bsp) bsp_raw,coalesce(r.canonical_bsp,t.canonical_bsp) canonical_bsp,
 coalesce(r.bsp_resolution_status,t.bsp_resolution_status) bsp_resolution_status,
 r.rdo_normal_hours,r.rdo_overtime_hours,r.rdo_total_hours,r.rdo_approved,r.rdo_source_ids,
 t.ts_normal_hours,t.ts_overtime_hours,t.ts_night_hours,t.ts_standby_hours,t.ts_travel_hours,t.ts_beyond_rotation_hours,
 t.ts_total_hours,t.ts_approved,t.ts_source_ids,
 case
  when coalesce(r.bsp_resolution_status,t.bsp_resolution_status) in ('COMPOSITE_AMBIGUOUS','ALIAS_NOT_VERIFIED','UNMATCHED') then 'BLOCKING_BSP'
  when r.work_date is null then 'TIMESHEET_ONLY'
  when t.work_date is null then 'RDO_ONLY'
  when abs(coalesce(r.rdo_total_hours,0)-coalesce(t.ts_total_hours,0))>0.01 then 'HOURS_MISMATCH'
  else 'MATCHED' end reconciliation_status,
 case
  when coalesce(r.bsp_resolution_status,t.bsp_resolution_status) in ('COMPOSITE_AMBIGUOUS','ALIAS_NOT_VERIFIED','UNMATCHED') then 'BLOCKING'
  when r.work_date is null or t.work_date is null then 'WARNING'
  when abs(coalesce(r.rdo_total_hours,0)-coalesce(t.ts_total_hours,0))>0.01 then 'BLOCKING'
  when not coalesce(r.rdo_approved,false) or not coalesce(t.ts_approved,false) then 'WARNING'
  else 'OK' end severity
from rdo r full join ts t on t.work_date=r.work_date and t.person_match_key=r.person_match_key and t.bsp_match_key=r.bsp_match_key;

create or replace view medicao.v_execution_project_link with (security_invoker=true) as
select e.source_family,e.source_type,e.source_record_id,e.parent_record_id,e.protocol,e.work_date,e.employee_name,e.employee_function,
 e.bsp_raw,e.canonical_bsp,e.bsp_resolution_status,e.location,rr.client_name source_client_name,
 e.normal_hours,e.overtime_hours,e.night_hours,e.standby_hours,e.travel_hours,e.beyond_rotation_hours,e.total_hours,
 e.source_status,e.parent_status,e.source_approved,pc.clients context_clients,pc.units context_units,pc.purchase_orders,pc.pms,
 pc.service_types,pc.work_types,pc.work_regime,pc.context_status,
 case
  when e.canonical_bsp is null then 'UNRESOLVED_BSP'
  when pc.context_status='CONFLITANTE' then 'CONTEXT_CONFLICT'
  when rr.client_name is not null and pc.clients is not null
   and not exists(select 1 from unnest(pc.clients) c where medicao.normalize_client(c)=medicao.normalize_client(rr.client_name))
   then 'CLIENT_MISMATCH'
  else 'LINKED' end link_status
from medicao.v_execution_sources e
left join medicao.source_rdo_records rr on e.source_family='RDO' and rr.source_record_id=e.parent_record_id
left join medicao.v_project_context_summary pc on pc.canonical_bsp=e.canonical_bsp;

comment on view medicao.v_reconciliation_daily is 'Reconciliação RDO x Timesheet por pessoa/data/BSP sem escolher fonte silenciosamente.';
comment on view medicao.v_execution_project_link is 'Vínculo entre execução e contexto comercial/onshore-offshore; divergências permanecem explícitas.';
