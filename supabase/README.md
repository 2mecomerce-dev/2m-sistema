# Banco de dados (Supabase)

Projeto: `loocfbljngxrcoilcbmk`

Este diretório é a fonte de verdade do schema. Se alguém mudar alguma coisa
direto pelo painel do Supabase e não trouxer para cá, a próxima pessoa que
rodar as migrations não vai ter o mesmo banco.

## Onde mora cada dado

| Dado | Onde fica | Quem escreve |
|---|---|---|
| SKU do marketplace → nome do modelo | `apelidos` | aba **Produtos** |
| Custo de compra por modelo | `custos` | aba **Fornecedor** |
| Lotes separados (pares por dia e composição por modelo) | `lotes` | aba **Separador de Pedidos** |
| Investimento, faturamento e pedidos de mídia por loja/semana | `marketing_semanal` | aba **Rotina → Marketing & TikTok** |
| Checklist da rotina, tarefas, TikTok e lista de lojas | `rotina_estado` (documento JSON, `id = 'principal'`) | aba **Rotina** |
| Alíquotas, comissão/frete por canal e custos fixos de precificação | `precificacao_config` (documento JSON, `id = 'principal'`) | aba **Precificação** |
| Produtos cadastrados para precificação (custo + taxa fixa) | `precificacao_produtos` | aba **Precificação** |
| Histórico de fechamento semanal da rotina (% concluído, itens feitos/total) | `rotina_fechamentos` | aba **Rotina** (botão "Fechar semana e reiniciar") |

O dashboard da aba **Relatórios** não tem tabela própria: ele deriva tudo de
`lotes`, `custos` e `marketing_semanal`.

A aba **Metas** também não tem tabela própria: deriva o faturamento e CPA do
mês de `marketing_semanal.data_fim`, e o % de atividades do mês de
`rotina_fechamentos`. Os níveis e faixas de bônus ficam hardcoded no
`index.html` (não são dado do usuário, são regra de negócio).

## Views de leitura

Criadas para conferir os números do dashboard direto no SQL Editor, sem abrir
o app:

| View | Responde a pergunta |
|---|---|
| `vw_vendas_diarias` | Quantos pares saíram em cada dia? |
| `vw_vendas_modelo_dia` | Quantos pares de cada modelo saíram em cada dia? |
| `vw_vendas_por_modelo` | Quais modelos sustentam o faturamento? (curva ABC + custo) |
| `vw_marketing_consolidado` | Como foi cada semana de mídia somando todas as lojas? |
| `vw_marketing_por_loja` | Qual loja está rendendo e qual está queimando caixa? |

Exemplos:

```sql
-- volume dos últimos 30 dias
select * from vw_vendas_diarias
where dia >= current_date - 29
order by dia;

-- curva ABC: os modelos que fazem 80% do volume
select * from vw_vendas_por_modelo where classe_abc = 'A';

-- evolução do ROAS semana a semana
select semana, investimento, faturamento, roas, cpa
from vw_marketing_consolidado
order by primeiro_lancamento;
```

## Como aplicar

No painel do Supabase → **SQL Editor**, rode os arquivos de `migrations/` na
ordem, um de cada vez:

1. `0001_base_schema.sql`
2. `0002_marketing_semanal.sql`
3. `0003_views_dashboard.sql`
4. `0004_precificacao.sql`
5. `0005_metas.sql`

Todos são idempotentes — rodar de novo num banco que já tem dados não apaga
nada. A `0002` copia os lançamentos de marketing que hoje estão dentro do JSON
de `rotina_estado` para a tabela nova; o JSON antigo continua lá como backup e
pode ser limpo depois que você confirmar que a aba Marketing está lendo certo.

### Atenção na 0001: RLS

A `0001` liga Row Level Security nas tabelas e libera acesso apenas para
usuários **autenticados**. Isso é o que impede que a chave `anon` — que está
publicada dentro do `index.html`, como é normal em app estático — dê acesso de
leitura e escrita do banco inteiro para qualquer pessoa que abrir o código
fonte da página.

O app já tem tela de login, então ele continua funcionando normalmente. Se
depois de rodar a migration algo parar de carregar, é sinal de que aquela
chamada está acontecendo antes do login — e não de que a política está errada.

## O que ainda não foi normalizado

`rotina_estado` continua sendo um documento JSON único. Isso significa que
**cada save reescreve o documento inteiro**: se duas pessoas mexerem no
checklist ao mesmo tempo, a última a salvar apaga o que a outra fez. Foi
aceitável enquanto era só checklist; conforme a aba crescer, o caminho é
quebrar em tabelas (`rotina_itens`, `tarefas`, `tiktok_posts`, `lojas`), como
já foi feito com o marketing.
