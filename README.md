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

## Execução no ambiente conectado

Com `SUPABASE_DB_URL_DASHBOARD` configurada em variável de ambiente:

```bash
npm install
npm run db:migrate
npm run measurement:check -- 2026-09-16 2026-09-26
```

O comando sincroniza as fontes, cria um BM de rascunho por BSP e mostra linhas, alertas e total calculado. As tarifas devem ser cadastradas em `medicao.rate_rules` antes de um BM poder ser aprovado/faturado.

## GitHub Pages

O `index.html` na raiz reproduz a interface do sistema de referência enviado no ZIP, incluindo painel de medição, novo boletim, boletim detalhado e controle de embarque. O workflow em `.github/workflows/deploy-pages.yml` publica a branch `main` quando o Pages está configurado como `GitHub Actions`.

O navegador consulta somente as projeções sanitizadas `public.medicao_dashboard_summary` e `public.medicao_dashboard_lines` pelo REST do Supabase. `config.js` contém apenas a URL e a chave publishable; nenhuma `service_role` ou URL de conexão do Postgres é publicada. Os dados brutos e o motor continuam protegidos no schema `medicao`.

O painel seleciona a versão mais recente de cada BSP, exibe o período real, cliente/projeto/local, quantidade de linhas, pessoas, fonte (RDO/Timesheet) e alertas. Os detalhes carregam as linhas calculadas do BM. Quando não existe tarifa em `medicao.rate_rules`, a linha aparece com valor zero e validação de tarifa pendente; isso é intencional para impedir faturamento sem regra comercial cadastrada.

URL de teste: `https://stepoil-debug.github.io/sistema-medicao/`

## Estado

Schema `medicao`, funções de sincronização/cálculo e validações implantados no banco de desenvolvimento. O ZIP e o Excel de referência não foram copiados nem alterados.
