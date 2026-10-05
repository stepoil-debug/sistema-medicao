# Integração RDO × Timesheet × Onshore/Offshore — 2026-10-05

## Fontes

### Execução
- `offshore_rdo.rdos`
- `offshore_rdo.individual_timesheets`
- `offshore_ts.*` / `medicao.source_timesheet_*`

### Contexto de projeto/comercial
- Smartsheet `Onshore / Offshore Service Control` — sheet `4190800063031172`
- Smartsheet `2026 RFQ Status Summary` — sheet `948132130017156`

## Regra de vínculo

A execução e o contexto são tratados separadamente.

```text
RDO / Timesheet
  → pessoa
  → data
  → BSP raw
  → normalização controlada
  → BSP canônica
  → contexto cliente/unidade/PO/serviço
  → regime explícito quando houver
  → reconciliação
```

Nenhuma divergência BLOCKING é resolvida automaticamente.

## Estado dos BSPs com RDO

| BSP do RDO | Situação | Contexto |
| --- | --- | --- |
| 25-1032 | EXACT / LINKED | SBM · Paraty · PO A2602307 · Installations · regime NOT_VERIFIED |
| 25-481 | EXACT / CONTEXT_CONFLICT | SBM; Ilhabela/Paraty; Labour supply + Onshore Service + Service Offshore; múltiplas POs |
| 25-701 | EXACT / CLIENT_MISMATCH | RDO = BW/Cidade de Vitória; RFQ localizado = SBM/Ilhabela/Fabrication |
| 26-174 \ 25-906 | COMPOSITE_AMBIGUOUS | componentes 26-174 e 25-906 existem, mas as horas não podem ser divididas automaticamente |
| 26581 | ALIAS_NOT_VERIFIED | formato pode sugerir 26-581, mas RDO = CDI e RFQ 26-581 = SBM/Saquarema/Fabrication |

## Reconciliação atual

O módulo `offshore_ts` não possui dados standalone aprovados para os registros atuais.

- 25-1032: RDO_ONLY, 48 linhas, 642,04 h.
- 25-481: RDO_ONLY, 2 linhas, 24,00 h.
- 25-701: RDO_ONLY, 8 linhas, 96,00 h.
- 26-174 \ 25-906: BLOCKING_BSP, 5 pessoas/dia agregadas, 120,00 h; existem dois RDOs concluídos no mesmo dia para a mesma equipe.
- 26581: BLOCKING_BSP, 2 linhas de RDO concluído consideradas na camada de medição, 52,00 h.

Os individual timesheets atuais permanecem `pending_confirmation`; nenhuma linha está confirmada/assinada.

## Views V2

- `medicao.v_project_context_summary`
- `medicao.v_execution_sources`
- `medicao.v_reconciliation_daily`
- `medicao.v_execution_project_link`

## Regime Onshore/Offshore

Somente valores explícitos são classificados automaticamente:

- `Service Offshore` → OFFSHORE
- `Onshore Service` → ONSHORE
- demais tipos → NOT_VERIFIED até existir evidência adicional.

Não classificar por nome de tabela, embarcação, cliente ou localização isoladamente.

## Próxima etapa de frontend

O visual do ZIP não será alterado.

A tela `Área de Medição` poderá consumir agregados de projeto/contexto.
Dados nominais de colaboradores, Timesheet e RDO não devem ser expostos anonimamente pelo GitHub Pages. Para `Medição e Embarque`, a integração nominal deverá usar sessão autenticada antes de liberar os dados reais.
