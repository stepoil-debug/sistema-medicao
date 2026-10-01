# Sistema de Medição

Sistema independente para consolidar dados operacionais, calcular medições e gerar boletins para revisão, aprovação e faturamento.

## Objetivo

Transformar dados aprovados do Timesheet, RDO e demais fontes de custo em um boletim de medição rastreável. O sistema deve gerar a medição automaticamente como rascunho, mantendo validações e aprovação humana antes do envio ao cliente ou faturamento.

## Princípios

- Independência do Timesheet, RDO e sistemas legados por meio de integrações/adaptadores.
- Um único motor de cálculo para tela, Excel, PDF e API.
- Rastreabilidade: cada valor medido deve apontar para sua origem.
- Reprocessamento seguro e idempotente.
- Separação entre dados brutos, regras de negócio, resultado calculado e aprovação.
- Nenhum faturamento automático sem aprovação explícita.

## Fluxo inicial

```text
Timesheet/RDO/outras fontes
              ↓
     importação e validação
              ↓
      motor de cálculo
              ↓
       BM em rascunho
              ↓
 revisão PM → cliente → faturamento
```

## Escopo inicial

1. Cadastro de contratos, POs, projetos/BSPs, períodos e regras de preço.
2. Importação de apontamentos aprovados do Timesheet.
3. Associação de apontamentos ao RDO e às evidências operacionais.
4. Cálculo de diárias, horas normais, horas extras/noturnas, mobilização e desmobilização.
5. Inclusão modular de logística, habitat, rentals e consumíveis.
6. Geração de BM em rascunho, memória de cálculo, PDF e Excel.
7. Histórico de versões, validações, aprovação e auditoria.

## Estrutura atual

- `docs/`: decisões, modelo de domínio e conhecimento do sistema de referência.
- `src/`: reservado para o código do produto.
- `tests/`: reservado para testes do motor de cálculo e integrações.

## Estado

Repositório inicial criado em fase de descoberta e arquitetura. O ZIP e o Excel de referência não foram copiados nem alterados.

