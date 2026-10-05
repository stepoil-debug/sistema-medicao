# Segurança e autorização

## Princípio

O GitHub Pages é somente a camada de interface. Credenciais privilegiadas, alteração de Rates, aprovação, fechamento e faturamento não podem depender de JavaScript público.

## Modelo proposto

- `anon`: sem acesso a dados internos de medição.
- `authenticated`: acesso apenas quando existir registro ativo em `medicao.user_access`.
- `viewer`: consulta.
- `measurement`: prepara e revisa rascunhos.
- `pm`: aprova revisão interna / envio ao cliente.
- `finance`: registra faturamento.
- `admin`: administração do domínio.
- `service_role`: integrações e automações controladas.

## Escrita

Tabelas internas não recebem INSERT/UPDATE/DELETE direto do navegador. Operações sensíveis entram por RPCs/Edge Functions que:

1. exigem sessão autenticada;
2. verificam `auth.uid()` e perfil interno;
3. validam o status atual e a transição desejada;
4. gravam evento de auditoria;
5. congelam snapshot ao aprovar;
6. rejeitam alteração de versões aprovadas/faturadas.

## Views

Views destinadas ao Data API usam `security_invoker = true`. Grants são explícitos para resistir à mudança de exposição automática da Data API do Supabase em 2026.

## Pendência operacional

A migration de hardening é adicionada ao repositório, mas deve ser aplicada somente após provisionar os usuários autorizados, para não bloquear o site atual.
