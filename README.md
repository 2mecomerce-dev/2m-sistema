# Central de Operações 2M Commerce

Sistema interno de operações para e-commerce de dropshipping de calçados de couro.

## Estrutura

```
central-2m/
├── src/
│   ├── index.html          # Sistema principal (HTML + JS)
│   └── apps-script.js      # Código do Google Apps Script
├── docs/
│   └── prompt-lovable.md   # Prompt para rebuild em React no Lovable
└── README.md
```

## Funcionalidades

- **Separador de Pedidos**: Upload de PDF de etiquetas → lista numerada pro WhatsApp
- **Fornecedor**: Cálculo de pagamento ao fornecedor por período
- **Produtos**: Cadastro de SKU → apelido (ex: 070, CRAZY HORSE)
- **Sincronia**: Conexão com Google Sheets via JSONP (Apps Script)

## Banco de Dados

Google Sheets com 3 abas: `apelidos`, `custos`, `lotes`

Comunicação via JSONP (script tag injection) — sem CORS.

**URL do Apps Script:**
```
https://script.google.com/macros/s/AKfycbxgRtUg4VusLeP3HMuyRbnkItiFJVXAEvyUXZJrzrlTd0MuvqHgrFyZU1FGBu7KE6rrbQ/exec
```

## Como usar

1. Abrir `src/index.html` no Chrome
2. O sistema conecta automaticamente à planilha
3. Soltar PDF de etiquetas → copiar lista → colar no WhatsApp

## Stack

- Frontend: HTML + CSS + JavaScript vanilla
- PDF: pdf.js (CDN)
- Backend: Google Apps Script + Google Sheets
- Comunicação: JSONP
- Tipografia: Plus Jakarta Sans + JetBrains Mono
