-- Corrige a cadeia de permissões das views security_invoker usadas pela API de medição.
-- O browser não recebe acesso direto; somente o backend service_role pode atravessar as views privadas.

grant select on medicao.v_execution_sources to service_role;
grant select on medicao.v_project_context_summary to service_role;
grant select on medicao.v_reconciliation_daily to service_role;
grant select on medicao.v_execution_project_link to service_role;
