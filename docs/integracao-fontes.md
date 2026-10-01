# Integração com as fontes existentes

## Fonte confirmada

O banco disponível no ambiente é PostgreSQL/Supabase. A integração foi validada por catálogo, sem copiar nem alterar dados das fontes.

### RDO

- `offshore_rdo.rdos`: cabeçalho do RDO, data, BSP, cliente, projeto e status.
- `offshore_rdo.individual_timesheets`: colaborador, função, data, horas normais, horas extras, total e confirmação.
- O motor usa RDO com status `completed` como fonte de fallback.

### Timesheet

- `offshore_ts.weekly_timesheets`: cabeçalho semanal e status.
- `offshore_ts.timesheet_days`: dia do apontamento e validações.
- `offshore_ts.task_entries`: linhas de atividade, minutos normais, extras, noturnos, standby, viagem e fora da rotação.
- `offshore_ts.campaigns` e `offshore_ts.campaign_members`: projeto/BSP/PO e identificação do colaborador.
- `offshore_ts.approvals`: aprovação por nível.
- O motor prioriza linhas de Timesheet aprovadas/locked quando existirem.

## Regra de prioridade

1. Timesheet estruturado com status aprovado ou locked.
2. Se não houver Timesheet aprovado para o BSP/período, RDO concluído.
3. Se nenhuma fonte existir, o BM é criado com erro `NO_SOURCE_DATA`.

Essa regra evita duplicidade entre RDO e Timesheet e mantém o BM rastreável.

## Segurança

Os dados são copiados para tabelas de snapshot no schema `medicao`. A aplicação de medição não atualiza RDO nem Timesheet. O schema interno possui RLS e não é acessível pelo browser; o acesso deve ocorrer por backend com credencial privada.

## Situação encontrada na primeira sincronização

No ambiente validado havia 18 RDOs, dos quais 16 concluídos e 70 apontamentos individuais associados a RDO concluído. O conjunto `offshore_ts` estava sem registros. Por isso os primeiros BMs foram gerados a partir do fallback do RDO, com alerta de fonte não confirmada.

