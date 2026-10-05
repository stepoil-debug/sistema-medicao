# Status de implementação

## CONFIRMADO

- Repositório oficial: `stepoil-debug/sistema-medicao`.
- Publicação: GitHub Pages a partir da branch `main`.
- Backend atual: Supabase `INTRANET STEP ONE`.
- Fontes operacionais existentes: `offshore_rdo` e `offshore_ts`.
- Domínio isolado `medicao` já existe no banco/repositório.
- Modelo fornecido contém fluxo do BM, eventos de histograma e seções de Invoice Backup.

## TARGET_REFERENCE

- ciclo 26/25;
- fluxo Rascunho → Revisão PM → Enviado ao cliente → Aprovado → Faturado;
- seções de diária, horas, logística, mob/desmob, habitat, rentals e consumíveis;
- códigos E/P/D/HO/EC/DO.

## NOT_VERIFIED / CONFIRM_WITH_CLIENT

- Rate aplicável a cada BSP/contrato;
- multiplicador de dobra por contrato;
- fator de embarque cancelado por contrato;
- multiplicador/divisor de HE e adicional noturno por contrato;
- fórmula definitiva de logística e Mob/Desmob;
- comportamento de quantidade em Rentals quando houver múltiplas unidades.

## Bloqueio financeiro

Quando qualquer regra necessária estiver sem confirmação/evidência, o BM pode ser montado como memória operacional, porém o valor financeiro daquela linha permanece bloqueado e recebe validação explícita.
