# Engenharia reversa da plataforma de referência

Este documento registra a estrutura funcional observada na plataforma de referência e o que foi incorporado ao Sistema de Medição. A referência foi usada para reproduzir arquitetura de navegação, nomenclatura, filtros e fluxos; dados privados e registros específicos da plataforma não foram copiados.

## Mapa de módulos

| Módulo observado | Replicação no Sistema de Medição | Fonte atual |
| --- | --- | --- |
| Histograma Offshore | Tela de presença, headcount, dias, horas e fonte por BSP | Snapshot sanitizado de RDO/Timesheet |
| Timesheet Offshore | Tabela de leitura dos lançamentos individualizados, com horas normais e extras | `medicao.source_people` e `medicao.source_lines` |
| Nomeações | Quadro de etapas para solicitação, validação e formação de equipe | Cards derivados dos BSPs; integração de nomeações pendente |
| Transporte | Área de solicitações e mobilização/desmobilização | Estrutura de tela pronta; sem fonte conectada |
| Hospedagem | Área de hotel pré-embarque e diárias | Estrutura de tela pronta; sem fonte conectada |
| Passagens Aéreas | Área de reservas, trechos e custo | Estrutura de tela pronta; sem fonte conectada |
| Reembolsos | Área de despesas e aprovação financeira | Estrutura de tela pronta; sem fonte conectada |
| Colaboradores | Cadastro consolidado por pessoa, função e BSP | RDO/Timesheet sincronizados |
| Rates | Catálogo por cliente, unidade, BSP e função, com diária, extra e noturno | `medicao.rate_catalog` / `medicao.rate_rules` |
| Boletim de Medição | Painel, novo BM, controle de embarque, cálculo e histórico | Motor SQL e snapshots do schema `medicao` |
| Custos | Visão consolidada por tipo de custo e BSP | Tela pronta; fontes de custo pendentes |
| Relatórios | Exportações CSV de medição, embarques, pendências, timesheet e headcount | Projeções atuais do schema `medicao` |
| Configurações | Cadastros mestres e status das integrações | Tela de acompanhamento; persistência de cadastros ainda separada |
| Flow Track | Monitoramento das sincronizações, cálculo e pendências | Histórico funcional mínimo do ciclo atual |

## Regras preservadas

- O Histograma e o controle de embarque devem ficar vinculados à BSP.
- A pessoa é identificada por nome, função, BSP e datas presentes.
- O Timesheet aprovado tem prioridade; o RDO concluído é fallback quando não há Timesheet disponível.
- O BM é um resultado derivado e revisável: os lançamentos de origem não são alterados pela edição do BM.
- Rate não localizado não é substituído por valor inventado. A linha fica pendente e o BM não deve ser aprovado/faturado até a confirmação.
- A tela de Rates aceita a confirmação por cliente, unidade, BSP e função, incluindo diária, dobra, hotel, hora extra e adicional noturno.
- As projeções públicas do GitHub Pages são sanitizadas; o cálculo, dados brutos, RLS e sincronização permanecem no schema isolado `medicao`.

## Estado das integrações

Na primeira sincronização validada do ambiente foram encontrados 18 documentos de RDO e 70 lançamentos individuais concluídos. A fonte `offshore_ts` não retornou semanas/tarefas no período consultado. Por isso a interface mostra os dados reais do RDO e sinaliza o Timesheet como aguardando dados, sem mascarar essa ausência.

As telas de logística, custos, nomeações e configurações já seguem a organização da referência, mas não devem apresentar registros fictícios. Quando suas fontes forem conectadas, os mesmos componentes podem receber as linhas sem alterar o cálculo do BM.

## Fluxo operacional replicado

```text
RDO / Timesheet
      ↓
Sincronização no schema medicao
      ↓
Histograma e controle de embarque por BSP
      ↓
Rates confirmados por cliente/função
      ↓
Geração do BM em rascunho
      ↓
Revisão → aprovação → relatório / faturamento
```
