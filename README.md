# Sistema de Medição STEP

Repositório oficial do Sistema de Medição da STEP Oil & Gas.

**Site:** https://stepoil-debug.github.io/sistema-medicao/

## Interface de referência

A interface publicada é baseada **literalmente** no ZIP de referência fornecido pela STEP.

Foram restaurados sem redesenho:

- `Area de Medicao.dc.html`
- `Medicao e Embarque.dc.html`
- `Ferramental Habitat.dc.html`
- `Painel BSP.dc.html`
- `Painel BSP - lateral.dc.html`
- `Painel BSP - etapas.dc.html`
- `support.js`

O `index.html` é uma cópia literal de `Area de Medicao.dc.html`, para que o endereço principal do GitHub Pages abra diretamente a tela original da Área de Medição.

A versão reinterpretada criada anteriormente foi removida: `app.js`, `styles.css` e `config.js` não participam mais da interface.

## Fidelidade

Os arquivos restaurados foram comparados com os artefatos extraídos do ZIP e validados por igualdade de conteúdo. O CI também testa que:

- `index.html` e `Area de Medicao.dc.html` são iguais;
- o runtime `dc` original está presente;
- as dimensões originais `1680 × 1010` foram preservadas;
- a navegação original entre as telas permanece.

## Backend

O schema `medicao`, migrations, motor de cálculo e documentação técnica permanecem no repositório para a integração de dados futura. Eles não alteram o visual original do ZIP.

A próxima etapa de integração deve substituir somente as fontes de dados internas do modelo, preservando o HTML, a hierarquia visual e a experiência do ZIP.
