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

