# Arquitetura V1 — Sistema de Medição STEP

## Objetivo

Transformar dados operacionais aprovados em um Boletim de Medição versionado, rastreável e auditável, sem alterar as fontes RDO/Timesheet e sem recalcular silenciosamente um BM histórico.

## Camadas

```text
RDO / Timesheet / Histograma / Logística / Habitat / Rentals / Consumíveis
                              ↓
                       SOURCE SNAPSHOT
                              ↓
          Contract / PO / Rate Card / Commercial Rule
                              ↓
                         CALCULATION
                              ↓
                    Measurement Version
                              ↓
      validations → review PM → client → approved → invoiced
                              ↓
                    IMMUTABLE SNAPSHOT
                              ↓
                 Invoice Backup / PDF / Excel
```

### 1. Fontes operacionais

As tabelas `offshore_rdo` e `offshore_ts` continuam sendo somente leitura para o domínio de medição. A medição importa os dados necessários para tabelas próprias e preserva os identificadores de origem.

### 2. Contexto comercial

O cálculo financeiro só é liberado quando existir uma regra comercial confirmada e vigente para a combinação aplicável de cliente, contrato/PO, BSP, função/evento, período e categoria.

Uma taxa encontrada em planilha ou protótipo não vira regra universal. Ela deve possuir evidência e vigência.

### 3. Motor único

Tela, PDF, Excel e API devem usar o mesmo resultado calculado. Funções puras em `src/domain/` servem como especificação executável das fórmulas; o banco mantém a versão persistida e auditável.

### 4. Versionamento

Cada geração cria uma nova versão. Uma versão aprovada ou faturada nunca deve ser reescrita com novos dados operacionais. Correções posteriores produzem nova versão/revisão.

### 5. Snapshots

No momento da aprovação são congelados:

- contexto de cliente/BSP/PO/período;
- linhas operacionais usadas;
- eventos do histograma;
- Rates e regras comerciais aplicadas;
- validações;
- totais por seção e total geral;
- evidências e hashes.

### 6. Saídas

O Invoice Backup é uma saída da versão congelada, e não uma fonte de cálculo. PDF e Excel devem carregar número do BM, período, PO, cliente/unidade, seções aplicáveis, memória de cálculo, evidências e saldo.
