# Conhecimento consolidado do modelo de referência

Este documento registra conclusões da análise do material enviado. Os arquivos originais permanecem fora deste repositório e não foram modificados.

## Fluxo observado

O modelo apresenta uma área de medição com categorias de resumo, diárias/overstay, horas extras/noturno, logística, mobilização/desmobilização, habitat, rentals e consumíveis. O boletim percorre estados equivalentes a rascunho, revisão do PM, envio ao cliente, aprovação e faturamento.

## Fontes de valor

- Diárias e eventos de embarque: histograma/controle operacional.
- Horas extras e noturnas: apontamentos de horas.
- Logística: lançamentos logísticos.
- Habitat, rentals e consumíveis: bases próprias e documentos de suporte.
- Mobilização/desmobilização: eventos operacionais e regras do contrato.

## Pontos que o novo sistema deve corrigir

- O painel de referência possui cálculos heurísticos diferentes do módulo dedicado de medição; deve existir um único motor de cálculo.
- A planilha tem abas com links incompletos, totais em branco e referências a BSPs diferentes; a importação deve validar a origem antes de aceitar valores.
- Fórmulas de alguns histogramas usam intervalos parciais; o sistema deve trabalhar com registros normalizados, não com posições fixas de células.
- PO, BM emitido, BM atual e saldo precisam ser calculados a partir do contrato e do histórico aprovado, com trilha de auditoria.
- O PDF deve ser uma saída do resultado versionado, não uma fonte de cálculo.

## Decisão de produto

Timesheet e RDO serão fontes operacionais. A medição será um produto independente, responsável por importar, validar, calcular, versionar e aprovar o resultado.

## Engenharia reversa do sistema de referência

O acesso autorizado à plataforma de referência confirmou quatro blocos que devem ser preservados no layout próprio:

1. **Histograma Offshore**: painel, histograma, lançamentos e planejamento de embarque. A unidade operacional e a BSP são filtros de primeira classe; o planejamento mantém embarque, desembarque, folga, férias e status programado/embarcado/folga/base.
2. **Timesheet Offshore**: o lançamento é organizado por colaborador → embarque → semana → dia. Cada dia guarda evento, BSP, tarefa, número da tarefa, entrada, saída, início/fim de H.E., horas normais, extras, noturno, total e observações. O embarque possui status de entrega pendente/parcial/completo; a semana recebida é marcada com data e usuário.
3. **Rates**: o cadastro é hierárquico Cliente → Embarcação/Unidade → BSP → Função. Cada função pode possuir diária de embarque, dobra, hotel, hora extra e adicional noturno, com status ativo/inativo. O sistema aceita mais de uma proposta por contexto, mas somente a regra ativa e vigente deve calcular.
4. **Boletim de Medição**: o BM fica dentro da BSP e percorre as seções Timesheets, Logística Mob/Desmob, Habitat, Locação, Consumíveis e Mob/Desmob de Materiais. A geração separa cabeçalho/PO, horas do Timesheet, mão de obra, logística e resumo; o histórico mantém BMs anteriores e saldo da PO.

### Regras funcionais incorporadas

- A medição usa uma cópia própria dos dados; uma correção de BM não altera RDO ou Timesheet.
- O Timesheet aprovado/locked é priorizado. O RDO concluído é fallback quando não houver Timesheet aprovado para o mesmo BSP e período.
- O dia calcula horas normais e extras a partir dos horários; o adicional noturno é mantido como categoria própria e pode ser confirmado pela regra contratual.
- O décimo quinto dia em diante pode ser classificado como dobra no histograma, mas a regra de faturamento deve ficar parametrizada por contrato, nunca hard-coded na planilha.
- Toda linha calculada mantém sistema, tabela, id original, data, função, quantidade, rate, valor e fonte da proposta.
- A confirmação de rate é uma etapa explícita: o sistema localiza o cadastro, preenche a função/valores, permite edição e só então recalcula o rascunho.

### Estrutura local adicionada

A migration `20261001170000_reference_measurement_workflow.sql` adiciona ao schema isolado `medicao`:

- snapshots de períodos semanais e dias do Timesheet;
- linhas de logística por transporte/hotel/outros;
- linhas complementares para habitat, rentals, consumíveis e mob/desmob de materiais;
- etapas de aprovação do BM;
- visão consolidada de seções para o layout.

Nenhuma tabela operacional do RDO ou Timesheet é alterada por essa estrutura.
