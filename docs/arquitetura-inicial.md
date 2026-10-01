# Arquitetura inicial

## Direção recomendada

Começar como um monólito modular com fronteiras claras. Isso mantém a primeira versão simples de operar, mas evita acoplamento que dificulte separar serviços no futuro.

Módulos previstos:

- `cadastros`: contratos, PO, projeto/BSP, cliente, embarcação, pessoas e funções.
- `fontes`: importação e consulta de Timesheet, RDO, histograma e lançamentos.
- `regras`: tarifas, tipos de hora, diárias, períodos e regras específicas do contrato.
- `medicao`: fechamento de período, cálculo, memória de cálculo e versionamento.
- `workflow`: rascunho, revisão PM, envio ao cliente, aprovação e faturamento.
- `documentos`: geração de Excel/PDF e anexos/evidências.
- `auditoria`: usuário, data, ação, versão e justificativa.

## Separação essencial

O sistema não deve recalcular valores diretamente na interface. A interface apenas solicita uma execução ao motor de cálculo e apresenta o resultado retornado.

O motor deve receber uma entrada versionada, por exemplo:

```text
contrato + período + regras vigentes + apontamentos aprovados + evidências
```

E devolver:

```text
linhas calculadas + totais por categoria + alertas + fontes utilizadas + versão
```

## Integração com Timesheet

A primeira integração deve ser somente leitura ou por importação controlada. O sistema de medição não deve editar o Timesheet. Cada registro importado deve manter:

- identificador original;
- colaborador;
- data e período;
- projeto/BSP/PO;
- tipo de hora;
- quantidade de horas ou dias;
- tarifa aplicada;
- status de aprovação;
- data da importação e versão da origem.

## Idempotência

Importar o mesmo registro duas vezes não pode duplicar a medição. O identificador da origem e a versão do registro devem compor uma chave única.

## Fechamento do período

Ao fechar um período, o sistema deve congelar a fotografia usada no cálculo. Alterações posteriores no Timesheet devem gerar alerta e exigir reprocessamento/versionamento, nunca alterar silenciosamente um BM já aprovado.

## Controles obrigatórios

- apontamento sem projeto, PO, tarifa ou aprovação;
- duplicidade de apontamento;
- colaborador fora do período;
- horas acima do limite configurado;
- lançamento sem evidência no RDO quando a regra exigir;
- valor acima do saldo contratual;
- categoria sem regra de preço;
- divergência entre total calculado e documento gerado.

