# Rates da Commercial offer

## Regra de negócio

Para calcular uma medição, o sistema deve:

1. localizar a BSP na planilha onshore/offshore;
2. localizar a proposta vinculada, normalmente iniciada por `BPP`;
3. ler a tabela `Commercial offer` da proposta;
4. cruzar a função do Timesheet com a função da proposta;
5. aplicar a tarifa somente quando BSP, categoria, função e período forem compatíveis.

O valor não deve ser copiado de outra BSP nem da tarifa genérica da base de embarque.

## Rastreabilidade

Cada importação cria um registro em `medicao.rate_sources` com BSP, proposta, nome do arquivo, seção, período e localização do documento. Cada regra em `medicao.rate_rules` aponta para essa fonte e guarda a descrição e a referência da linha da `Commercial offer`.

Quando uma medição é gerada, as linhas calculadas carregam a proposta, o arquivo, a seção e a referência da tarifa. Se não houver correspondência, a medição recebe `MISSING_RATE` e não deve ser enviada para aprovação.

## Importação normalizada

O extrator do BPP deve produzir um JSON neste formato:

```json
{
  "bsp": "25-701",
  "proposal_code": "BPP-25-701-REV-01",
  "file_name": "BPP-25-701-REV-01.xlsx",
  "source_section": "Commercial offer",
  "source_locator": "SharePoint/Onshore-Offshore/BPP-25-701-REV-01.xlsx",
  "valid_from": "2026-01-01",
  "currency": "BRL",
  "rows": [
    {
      "category": "daily",
      "employee_function": "SOLDADOR",
      "description": "Soldador - Commercial offer",
      "unit": "day",
      "rate": 1332,
      "source_reference": "Commercial offer / Labour / Soldador"
    }
  ]
}
```

Importe usando a credencial privada do banco:

```text
node scripts/import-commercial-offer.mjs caminho/para/rates.json
```

O arquivo original BPP não deve ser publicado no GitHub Pages. O próximo conector deve ler a pasta/planilha onshore-offshore e gerar esse JSON no backend, mantendo a credencial fora do navegador.
