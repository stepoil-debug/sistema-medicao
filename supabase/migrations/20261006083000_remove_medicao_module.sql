-- Rollback emergencial do módulo Sistema de Medição STEP.
-- Incidente 2026-10-06: remove somente objetos exclusivos de medição.
-- NÃO altera users, RDO, Timesheet, Suprimentos ou tabelas operacionais externas.

begin;

drop view if exists public.medicao_live_execution cascade;
drop view if exists public.medicao_live_reconciliation cascade;
drop view if exists public.medicao_live_context cascade;
drop view if exists public.medicao_live_bms cascade;
drop view if exists public.medicao_dashboard_people cascade;
drop view if exists public.medicao_dashboard_lines cascade;
drop view if exists public.medicao_dashboard_summary cascade;
drop view if exists public.medicao_measurement_sections cascade;
drop view if exists public.medicao_rate_catalog cascade;

drop function if exists public.medicao_current_access() cascade;
drop function if exists public.medicao_confirm_rate_catalog(uuid, text, text, text, char, jsonb, text, text) cascade;

drop schema if exists medicao_api cascade;
drop schema if exists medicao cascade;

notify pgrst, 'reload schema';

commit;
