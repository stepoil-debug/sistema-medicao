# Regras comerciais versionadas

## Chave de seleção

Uma regra deve poder ser selecionada por:

`cliente → contrato/PO → BSP/projeto → função/evento/categoria → vigência`

Quanto mais específica a regra, maior a prioridade. Empates ou regras conflitantes devem bloquear o cálculo.

## Métodos suportados pelo domínio

- `unit_rate`: quantidade × Rate.
- `daily_factor`: dias × diária × fator.
- `daily_hourly_factor`: horas × diária × multiplicador ÷ divisor.
- `at_cost_markup`: custo × (1 + markup%).
- `rental_daily`: dias inclusivos × Rate diário, com configuração explícita para multiplicar ou ignorar quantidade.
- `manual_evidenced`: valor manual somente com justificativa e evidência anexada.

## Evidência mínima

Cada regra comercial confirmada deve registrar:

- documento fonte;
- proposta/contrato/PO e revisão;
- referência de página/seção quando disponível;
- vigência;
- usuário/data de confirmação;
- hash ou identificador da evidência.

## Alterações

A edição de uma regra nunca muda medições aprovadas. Ela só afeta versões novas ou regeneradas ainda em rascunho.
