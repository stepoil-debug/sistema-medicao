# Target Model V1

Este documento registra o comportamento desejado observado no modelo fornecido pela STEP. Ele não substitui contrato, proposta ou PO.

## Fluxo

`Rascunho → Revisão PM → Enviado ao cliente → Aprovado → Faturado`

## Período de referência

O modelo trabalha com ciclo `26 → 25`. A implementação mantém essa convenção como `TARGET_REFERENCE`; contratos podem sobrescrever por configuração futura.

## Seções do BM

1. Diárias + over stay.
2. Horas extras / adicional noturno.
3. Logística.
4. Mobilização / desmobilização de equipe.
5. Habitat / ferramental.
6. Rentals.
7. Consumíveis.
8. Mob/desmob de materiais quando aplicável.

## Eventos do histograma

| Código | Significado de interface | Tratamento comercial |
| --- | --- | --- |
| E | Embarcado | depende de regra confirmada |
| P | MOB / embarque | depende de regra confirmada |
| D | Desembarque | depende de regra confirmada |
| HO | Hotel pré-embarque | depende de regra confirmada |
| EC | Embarque cancelado | modelo demonstra fator parcial; validar contrato |
| DO | Dobra | modelo demonstra fator de diária; validar contrato |

## Fórmulas observadas no modelo

- diária: quantidade de dias × Rate diário × fator aplicável;
- horas derivadas da diária: horas × diária × multiplicador ÷ divisor de horas;
- consumíveis: quantidade × valor unitário;
- rentals: dias inclusivos × valor diário; a planilha observada não multiplica a coluna de quantidade, portanto o motor suporta `quantityMode=ignore|multiply`;
- logística `at cost + markup`: suportada pelo motor, mas o percentual e a base precisam estar confirmados.

Nenhuma dessas fórmulas deve gerar valor financeiro se a regra comercial não estiver marcada como confirmada.
