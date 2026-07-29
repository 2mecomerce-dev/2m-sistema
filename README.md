# Central de Operações 2M Commerce

Sistema interno de operações para e-commerce de dropshipping de calçados de couro.

## Estrutura

```
2m-sistema/
├── index.html              # Sistema principal (HTML + CSS + JS)
├── docs/
│   └── prompt-lovable.md   # Prompt original de especificação do sistema
└── README.md
```

## Funcionalidades

- **Separador de Pedidos**: Upload de PDF de etiquetas → lista numerada pro WhatsApp
- **Fornecedor**: Cálculo de pagamento ao fornecedor por período
- **Produtos**: Cadastro de SKU → apelido (ex: 070, CRAZY HORSE)
- **Sincronia**: Conexão com Supabase (Postgres + Realtime) — todos os colaboradores veem os mesmos dados, em qualquer dispositivo, atualizados instantaneamente

## Banco de Dados

Supabase (Postgres) com 3 tabelas: `apelidos`, `custos`, `lotes`.

O cliente conecta direto via `@supabase/supabase-js` (CDN) e assina mudanças em tempo real (Realtime) nas 3 tabelas, então uma alteração feita por um colaborador aparece automaticamente na tela dos outros, sem precisar recarregar a página. `localStorage` é usado como cache local para o sistema continuar funcionando offline.

## Como usar

1. Abrir `index.html` no Chrome (ou acessar a URL publicada no Vercel)
2. O sistema conecta automaticamente ao Supabase
3. Soltar PDF de etiquetas → copiar lista → colar no WhatsApp

## Stack

- Frontend: HTML + CSS + JavaScript vanilla
- PDF: pdf.js (CDN)
- Backend: Supabase (Postgres + Realtime)
- Hospedagem: Vercel
- Tipografia: Plus Jakarta Sans + JetBrains Mono
