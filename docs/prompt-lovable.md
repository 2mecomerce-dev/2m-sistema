# Central de Operações 2M Commerce

Sistema interno de operações para e-commerce de dropshipping de calçados de couro. Usado por 3 pessoas em computadores diferentes. Todos acessam o mesmo link e os mesmos dados.

## ARQUITETURA

- Frontend: React + TypeScript + Tailwind CSS
- Banco de dados: Google Sheets (via Google Apps Script)
- Comunicação: JSONP (script tag injection) — NÃO usar fetch() pois Google Apps Script bloqueia por CORS
- Hospedagem: Lovable

## CONEXÃO COM GOOGLE SHEETS (CRÍTICO)

A comunicação com o Google Sheets usa JSONP (injeção de tag script). Isso é OBRIGATÓRIO porque fetch() não funciona com Google Apps Script devido a redirecionamentos CORS.

### URL da API:
```
https://script.google.com/macros/s/AKfycbxgRtUg4VusLeP3HMuyRbnkItiFJVXAEvyUXZJrzrlTd0MuvqHgrFyZU1FGBu7KE6rrbQ/exec
```

### Função de comunicação (usar exatamente isso):

```typescript
const GS_URL = 'https://script.google.com/macros/s/AKfycbxgRtUg4VusLeP3HMuyRbnkItiFJVXAEvyUXZJrzrlTd0MuvqHgrFyZU1FGBu7KE6rrbQ/exec';

function gsCall(action: string, payload?: any): Promise<any> {
  return new Promise((resolve) => {
    const cbName = '_gs_' + Date.now() + '_' + Math.random().toString(36).slice(2, 6);
    const params = new URLSearchParams({ action, callback: cbName });
    if (payload) params.set('body', JSON.stringify(payload));

    const script = document.createElement('script');
    const timeout = setTimeout(() => {
      cleanup();
      resolve({ ok: false, error: 'timeout' });
    }, 20000);

    function cleanup() {
      clearTimeout(timeout);
      delete (window as any)[cbName];
      if (script.parentNode) script.parentNode.removeChild(script);
    }

    (window as any)[cbName] = function (data: any) {
      cleanup();
      resolve(data || { ok: false, error: 'resposta vazia' });
    };

    script.src = GS_URL + '?' + params.toString();
    script.onerror = function () {
      cleanup();
      resolve({ ok: false, error: 'falha na conexão' });
    };
    document.head.appendChild(script);
  });
}
```

### Ações disponíveis na API:

| Ação | Payload | Descrição |
|------|---------|-----------|
| `ping` | nenhum | Testa conexão. Retorna `{ ok: true }` |
| `pullAll` | nenhum | Retorna todos os dados: `{ ok: true, data: { apelidos: [...], custos: [...], lotes: [...] } }` |
| `setAlias` | `{ sku: string, apelido: string }` | Salva/atualiza um produto |
| `delAlias` | `{ sku: string }` | Remove um produto |
| `setCusto` | `{ modelo: string, custo: number }` | Salva/atualiza custo de um modelo |
| `setLote` | `{ id, data, itens, total, custoTotal }` | Registra um lote |
| `delLote` | `{ id: string }` | Exclui um lote |

### Formato dos dados retornados por pullAll:

```typescript
interface PullAllResponse {
  ok: boolean;
  data: {
    apelidos: Array<{ sku: string; apelido: string }>;
    custos: Array<{ modelo: string; custo: number }>;
    lotes: Array<{
      id: string;
      data: string; // "DD/MM/AAAA"
      itens: Array<{ modelo: string; cor: string; tamanho: string; qty: number }>;
      total: number;
      custoTotal: number;
    }>;
  };
}
```

### Comportamento de sincronização:

1. **Ao abrir o sistema**: chamar `pullAll` e carregar todos os dados. Mostrar tela de carregamento até completar.
2. **Após QUALQUER alteração de dados** (salvar produto, alterar custo, registrar lote, excluir lote): disparar auto-sync com debounce de 2 segundos que envia TUDO para a planilha (todos apelidos + todos custos + todos lotes).
3. Se o sync falhar, manter os dados locais e tentar novamente na próxima alteração.
4. Guardar dados também no localStorage como cache para carregamento rápido.

### Código do auto-sync:

```typescript
let autoSyncTimer: NodeJS.Timeout | null = null;

function autoSync(aliasMap: Record<string,string>, custoMap: Record<string,number>, history: Lote[]) {
  if (autoSyncTimer) clearTimeout(autoSyncTimer);
  autoSyncTimer = setTimeout(async () => {
    for (const sku of Object.keys(aliasMap)) {
      await gsCall('setAlias', { sku, apelido: aliasMap[sku] });
    }
    for (const modelo of Object.keys(custoMap)) {
      await gsCall('setCusto', { modelo, custo: custoMap[modelo] });
    }
    for (const h of history) {
      await gsCall('setLote', h);
    }
  }, 2000);
}
```

Chamar `autoSync()` dentro de toda função que modifica dados (salvar produto, salvar custo, registrar lote, excluir lote).

---

## PÁGINAS DO SISTEMA

### Layout geral:
- Sidebar escura à esquerda (grafite #15171E) com logo "2M Commerce - Central de Operações" e menu
- Barra superior com título da página, badge de status de conexão (online/offline/erro), data de hoje
- Área de conteúdo com fundo cinza claro (#ECEFF4)
- Responsivo: em mobile, sidebar vira menu hambúrguer

### Menu lateral (sidebar):
- **Separador de Pedidos** (ícone de caixa)
- **Fornecedor** (ícone de cifrão)
- Controle de Estoque (marcado "em breve", desabilitado)
- Devoluções (marcado "em breve", desabilitado)
- Relatórios (marcado "em breve", desabilitado)
- **Produtos** (ícone de etiqueta, seção "Cadastros")
- **Sincronia** (ícone de globo, seção "Sistema")

---

## PÁGINA 1: SEPARADOR DE PEDIDOS

### Descrição:
O usuário faz upload de um PDF de etiquetas de envio. O sistema extrai automaticamente de cada página o SKU, cor, tamanho e quantidade, e gera uma lista numerada pronta pra copiar e colar no WhatsApp do fornecedor.

### Componentes:

**KPIs no topo (4 cards):**
- Pedidos hoje (total de pares registrados na data de hoje)
- No lote atual (pares do PDF carregado)
- Modelos distintos (variações no lote)
- SKUs pendentes (sem apelido cadastrado)

**Card "Etiquetas do dia":**
- Área de drag-and-drop para upload de PDF (aceita múltiplos)
- Status de leitura: "Lendo PDF...", "X pedido(s) lidos", ou erro
- Usar biblioteca pdf.js via CDN: `https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js`

**Card "Lista de separação" (visual de ticket/manifesto):**
- Cabeçalho escuro com data e total de pares
- Lista monoespaçada com zebra-striping
- Formato de cada linha: `{numero}. {APELIDO} {COR} ({TAMANHO})`
  - Ex: `1. 070 MARROM (42)`
- QTD > 1 mesma variação: prefixo com quantidade, negrito
  - Ex: `*(2) 070 MARROM (38)*`
- 2 variações diferentes na mesma etiqueta: juntar com " + ", negrito
  - Ex: `*070 MARROM (40) + 070 PRETO (40)*`
- Botões: "Copiar lista pro WhatsApp" (copia com asteriscos pra negrito), "Registrar lote do dia", "Limpar"
- Link discreto "Registrar para outro dia" que abre seletor de data (não permite futuro)

**Painel de SKUs pendentes (amarelo, só aparece quando há pendentes):**
- Para cada SKU desconhecido, mostra: SKU, descrição da etiqueta, sugestão automática de apelido
- Campo pré-preenchido com a sugestão para o usuário confirmar
- Ao salvar, atualiza a lista imediatamente

### Extração do PDF:

Cada página do PDF contém uma etiqueta com tabela: SKU | Descrição | Variação | QTD.

A extração usa coordenadas dos itens de texto via `page.getTextContent()`:
1. Encontrar headers "SKU", "Variação", "QTD" (busca tolerante a acentos usando normalize NFD)
2. SKU: número de 8-14 dígitos colado com texto (ex: `1734428113Botina`) — extrair via regex `(\d{8,14})[A-Za-z]`
3. Cor: identificar na variação usando lista fixa: MARROM, PRETO, AZUL, BRANCO, VERDE, VERMELHO, AMARELO, CINZA, BEGE, CARAMELO, CAQUI, VINHO, LARANJA, ROSA, DOURADO, PRATA, NUDE
4. Tamanho: número de 2-3 dígitos na variação
5. Quando há 2 cores diferentes na mesma página: emparelhar cada cor com o tamanho de coordenada X mais próxima

### Sugestão de apelido:

Quando um SKU não tem apelido cadastrado, o sistema lê a Descrição da etiqueta e sugere um apelido baseado em palavras-chave:
- Contém "070" ou "Chelsea" → sugere "070"
- Contém "Crazy Horse" → sugere "CRAZY HORSE"
- Contém "Mocassim" → sugere "MOCASSIM"
- Contém "Knit" ou "Bay Shore" → sugere "KNIT"
- Contém "Camurça" → sugere "CAMURÇA"
- Contém "Blogueira" ou "207" → sugere "207"
- Contém código tipo "- 207" no final → sugere o código

---

## PÁGINA 2: FORNECEDOR (Pagamento ao Fornecedor)

### Descrição:
Calcula quanto se deve ao fornecedor com base nos lotes registrados × custo por modelo.

### Componentes:

**KPIs (3 cards):**
- Total a pagar (R$)
- Pares no período
- Sem custo definido (modelos sem custo)

**Filtro de período (tabs/pills):**
- Hoje | Esta semana | Este mês | Tudo | Período personalizado (dois date inputs)

**Tabela "Valor por modelo":**
| Modelo | Pares | Custo unit. | Subtotal |

**Tabela "Custo por modelo":**
Lista de modelos com input numérico para custo unitário (R$). Ao alterar, recalcula e sincroniza.

---

## PÁGINA 3: PRODUTOS (Cadastros)

### Descrição:
Tabela de mapeamento SKU → Apelido.

- Tabela: SKU | Apelido | Botão excluir (ícone lixeira)
- Formulário pra adicionar: input SKU + input Apelido + botão Adicionar
- Edição inline do apelido
- Exclusão com modal de confirmação (NÃO usar window.confirm, criar modal próprio)

### Produtos pré-cadastrados (dados iniciais):
| SKU | Apelido |
|-----|---------|
| 1734428113 | 070 |
| 1733803583 | 070 |
| 1734428091 | 070 |
| 1735858314 | 070 |
| 1735858308 | 070 |
| 1735858240 | CRAZY HORSE |
| 2387944176 | NKIT |
| 1734607569 | MOCASSIM |

---

## PÁGINA 4: SINCRONIA

### Descrição:
Mostra status da conexão com Google Sheets e permite ações manuais.

- Badge de status: offline (cinza) / conectado (verde) / sincronizando (azul pulsante) / erro (vermelho)
- Campo de URL do Apps Script (pré-preenchido)
- Botões: Conectar, Sincronizar (puxar da planilha), Enviar tudo à planilha, Desconectar
- Log de sincronização: lista com timestamp, mensagem e status (ok/erro/info)
- Passo a passo de configuração

---

## DESIGN

### Cores:
- Sidebar: `#15171E` → `#1D212B`
- Canvas: `#ECEFF4`
- Cards: `#FFFFFF`
- Acento: `#0E9F85` (verde-teal)
- Alerta: `#B45309` / `#FBEEDC` (âmbar)
- Perigo: `#D14343`
- Bordas: `#E3E8F0`

### Tipografia:
- Interface: Plus Jakarta Sans (Google Fonts)
- Números/código/lista: JetBrains Mono (Google Fonts)

### Componentes:
- Toast: notificação arredondada no rodapé, some após 2.4s
- Modal de confirmação: overlay + card centralizado (nunca usar window.confirm)
- Cards com sombras suaves e hover com elevação
- KPIs com ícones e números grandes animados

---

## COMPORTAMENTO AO ABRIR

1. Mostrar tela de carregamento "Conectando à planilha..."
2. Chamar gsCall('ping') para verificar conexão
3. Se conectar: chamar gsCall('pullAll'), carregar dados, mostrar sistema
4. Se falhar: tentar carregar do localStorage como fallback, mostrar badge "offline"
5. Toda alteração subsequente salva no localStorage E sincroniza com a planilha via autoSync

## IMPORTANTE

- NUNCA usar fetch() para comunicar com Google Sheets — usar APENAS a função gsCall via JSONP (script tag injection)
- NUNCA usar window.confirm() ou window.alert() — criar componentes React próprios
- O sistema deve funcionar em Chrome desktop E Chrome mobile
- localStorage é cache, Google Sheets é a fonte da verdade
- Usar pdf.js via CDN para extração de PDF, não instalar via npm
