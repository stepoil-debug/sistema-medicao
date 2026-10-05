# Sistema de Medição STEP

Repositório oficial do novo sistema de medição da STEP Oil & Gas.

- Repositório: `stepoil-debug/sistema-medicao`
- Site: `https://stepoil-debug.github.io/sistema-medicao/`
- Branch publicada: `main`
- Backend: Supabase `INTRANET STEP ONE`

## Objetivo

Consolidar dados operacionais, aplicar regras comerciais comprovadas, gerar Boletins de Medição versionados e produzir Invoice Backup/PDF/Excel com rastreabilidade completa.

```text
RDO / Timesheet / Histograma / outras fontes
                    ↓
             snapshot de origem
                    ↓
        contrato / PO / Rates / regras
                    ↓
              motor de cálculo
                    ↓
               BM rascunho
                    ↓
 revisão PM → cliente → aprovação → faturamento
                    ↓
            snapshot imutável
```

## Princípios obrigatórios

1. Um único motor de cálculo para tela, PDF, Excel e API.
2. Nenhuma regra financeira é inventada.
3. Rate deve possuir contexto, vigência e evidência.
4. Cada linha aponta para a origem operacional e comercial.
5. Timesheet/RDO são fontes; a medição mantém cópia própria.
6. BM aprovado/faturado é imutável. Correção gera nova versão.
7. Alteração de Rates nunca reescreve histórico aprovado.
8. GitHub Pages é somente frontend; operações privilegiadas ficam no Supabase/backend.

## Modelo funcional alvo

O ZIP de referência da STEP define a experiência desejada:

- ciclo de referência 26/25;
- fluxo `Rascunho → Revisão PM → Enviado ao cliente → Aprovado → Faturado`;
- Diárias + Over Stay;
- Horas Extras / Noturno;
- Logística;
- Mob/Desmob;
- Habitat/Ferramental;
- Rentals;
- Consumíveis;
- Invoice Backup como saída final da medição.

Os códigos de histograma E/P/D/HO/EC/DO são preservados como semântica operacional. O tratamento financeiro só é aplicado quando a regra comercial correspondente estiver confirmada.

## Estrutura do repositório

```text
.github/workflows/      CI e deploy do GitHub Pages
docs/                   arquitetura, regras e decisões
src/domain/             especificação executável do motor de cálculo
supabase/migrations/    banco, segurança, snapshots e workflow
tests/                  testes unitários do domínio
index.html              interface publicada atual
config.js               URL/chave publicável do Supabase
scripts/                inspeção, sync e verificação do banco
```

## Domínio de cálculo V1

`src/domain/` não contém Rates hard-coded. As funções recebem a regra já confirmada e bloqueiam o cálculo quando `confirmed !== true`.

Métodos suportados:

- quantidade × Rate;
- diária × dias × fator;
- horas × diária × multiplicador ÷ divisor;
- at cost + markup;
- rental por dias inclusivos com política explícita de quantidade;
- consumível quantidade × unitário.

Execute:

```bash
npm ci
npm test
```

## Banco

O schema `medicao` permanece isolado das fontes `offshore_rdo` e `offshore_ts`.

A migration `20261005130000_measurement_v1_foundation.sql` prepara:

- autorização interna por usuário/role;
- eventos de histograma;
- termos de regra comercial;
- evidências;
- eventos de workflow;
- snapshots imutáveis;
- RLS para tabelas complementares;
- remoção de execução anônima da confirmação privilegiada de Rates.

**Importante:** esta migration deve ser aplicada somente depois de provisionar os usuários autorizados em `medicao.user_access`. Ela está versionada no repositório para revisão e rollout controlado.

## Segurança

O frontend usa somente chave publishable. Nunca publicar `service_role`, secret key, URL Postgres ou credencial administrativa.

As views/API novas devem usar grants explícitos e, quando aplicável, `security_invoker = true`.

## GitHub Pages

O workflow de deploy executa `npm test` antes da publicação. Se o motor de medição falhar nos testes, a versão não é enviada ao Pages.

## Documentação principal

- `docs/architecture-v1.md`
- `docs/target-model-v1.md`
- `docs/commercial-rules.md`
- `docs/security-model.md`
- `docs/implementation-status.md`
- `docs/conhecimento-do-modelo.md`
- `docs/referencia-modular.md`

## Estado

A interface legada/protótipo continua publicada durante a transição. A V1 adiciona a fundação de domínio, segurança, snapshots, regras versionadas e CI sem apagar as integrações existentes.
