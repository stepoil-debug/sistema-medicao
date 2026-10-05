# Sistema de Medição STEP

Repositório oficial do Sistema de Medição da STEP Oil & Gas.

**Produção:** https://stepoil-debug.github.io/sistema-medicao/

## Interface oficial

O frontend legado foi removido por completo. O site agora possui somente o novo modelo:

- **Área de medição** — carteira de BSPs, KPIs, pendências, status e abertura do BM.
- **Medição e embarque** — histograma/apontamentos provenientes de RDO e Timesheet.
- **Ferramental / Habitat** — estrutura do módulo sem dados fictícios enquanto a fonte não estiver integrada.
- **Rates** — leitura do catálogo comercial confirmado; edição fica bloqueada no frontend público.

Não existe fallback para a interface anterior e o runtime legado `support.js` foi excluído.

## Dados

O frontend lê somente projeções do domínio de medição:

- `public.medicao_dashboard_summary`
- `public.medicao_dashboard_people`
- `public.medicao_measurement_sections`
- `public.medicao_dashboard_lines`
- `public.medicao_rate_catalog`

Valores que não existem nas fontes reais não são inventados. Onde a integração ainda não existe, a tela mostra **aguardando integração**.

## Arquitetura

```text
RDO / Timesheet / Histograma / fontes complementares
                    ↓
              snapshot da fonte
                    ↓
       contrato / PO / Rates / regras
                    ↓
             motor de cálculo
                    ↓
                BM versionado
                    ↓
 revisão PM → cliente → aprovação → faturamento
                    ↓
            snapshot imutável
                    ↓
          Invoice Backup / PDF / Excel
```

A base técnica permanece em:

- `src/domain/` — motor de cálculo sem Rates hard-coded.
- `supabase/migrations/` — schema, segurança, evidências e snapshots.
- `tests/` — testes do motor e da estrutura do frontend.
- `docs/architecture-v1.md` — arquitetura oficial.
- `docs/target-model-v1.md` — comportamento do modelo enviado pela STEP.
- `docs/commercial-rules.md` — regras comerciais e evidência.
- `docs/security-model.md` — autenticação/RLS e escrita protegida.
- `docs/implementation-status.md` — status de confirmação das regras.

## Segurança

GitHub Pages é somente frontend. A chave publicada é a chave publicável do Supabase; nenhuma `service_role` ou credencial Postgres é enviada ao navegador.

Criação de BM, alteração de Rate, aprovação e faturamento permanecem protegidos até a implantação do controle autenticado descrito na migration V1.

## Qualidade e deploy

```bash
npm ci
npm test
```

O GitHub Pages só publica a `main` quando os testes passam.
