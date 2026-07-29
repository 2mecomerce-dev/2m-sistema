-- ============================================================
-- 0003 — Views de leitura para o dashboard
--
-- O dashboard do app calcula tudo no navegador, a partir do
-- histórico que já está em memória. Estas views existem para:
--   • conferir os mesmos números direto no Supabase (SQL Editor);
--   • servir de base para relatórios externos ou export;
--   • deixar explícito, em SQL, como cada métrica é definida.
--
-- security_invoker = true faz a view respeitar a RLS de quem
-- consulta, em vez de rodar com os poderes do dono.
-- ============================================================

-- ------------------------------------------------------------
-- Pares separados por dia
-- ------------------------------------------------------------
create or replace view public.vw_vendas_diarias
with (security_invoker = true) as
select
  l.date_key                        as dia,
  sum(l.total)::bigint              as pares,
  count(*)::int                     as lotes,
  count(*) filter (where l.backdated)::int as lotes_retroativos
from public.lotes l
group by l.date_key;

comment on view public.vw_vendas_diarias is 'Volume diário de pares separados. Base do gráfico de evolução.';

-- ------------------------------------------------------------
-- Pares por modelo, dia a dia (composição do lote expandida)
-- ------------------------------------------------------------
create or replace view public.vw_vendas_modelo_dia
with (security_invoker = true) as
select
  l.date_key                          as dia,
  m.key                               as modelo,
  sum((m.value #>> '{}')::numeric)::bigint as pares
from public.lotes l
cross join lateral jsonb_each(l.composicao) as m
where jsonb_typeof(l.composicao) = 'object'
group by l.date_key, m.key;

comment on view public.vw_vendas_modelo_dia is 'Composição dos lotes explodida em linhas. Lotes antigos sem composição não aparecem aqui.';

-- ------------------------------------------------------------
-- Ranking de modelos: volume, participação, curva ABC e custo
-- ------------------------------------------------------------
create or replace view public.vw_vendas_por_modelo
with (security_invoker = true) as
with base as (
  select modelo, sum(pares)::bigint as pares
  from public.vw_vendas_modelo_dia
  group by modelo
), com_share as (
  select
    b.modelo,
    b.pares,
    round(100.0 * b.pares / nullif(sum(b.pares) over (), 0), 2) as share_pct,
    round(100.0 * sum(b.pares) over (order by b.pares desc rows between unbounded preceding and current row)
          / nullif(sum(b.pares) over (), 0), 2) as acumulado_pct
  from base b
)
select
  s.modelo,
  s.pares,
  s.share_pct,
  s.acumulado_pct,
  case when s.acumulado_pct <= 80 then 'A'
       when s.acumulado_pct <= 95 then 'B'
       else 'C' end                          as classe_abc,
  c.custo                                    as custo_unitario,
  round(c.custo * s.pares, 2)                as custo_total
from com_share s
left join public.custos c on c.modelo = s.modelo;

comment on view public.vw_vendas_por_modelo is 'Curva ABC de modelos: classe A são os que somam 80% do volume. custo_total fica nulo quando o modelo não tem custo cadastrado.';

-- ------------------------------------------------------------
-- Marketing consolidado por semana (todas as lojas somadas)
-- ------------------------------------------------------------
create or replace view public.vw_marketing_consolidado
with (security_invoker = true) as
select
  m.semana,
  count(*)::int                                      as lojas_reportadas,
  sum(m.investimento)                                as investimento,
  sum(m.faturamento)                                 as faturamento,
  sum(m.pedidos)::bigint                             as pedidos,
  round(sum(m.faturamento) / nullif(sum(m.investimento), 0), 2) as roas,
  round(sum(m.investimento) / nullif(sum(m.pedidos), 0), 2)     as cpa,
  round(sum(m.faturamento)  / nullif(sum(m.pedidos), 0), 2)     as ticket_medio,
  min(m.criado_em)                                   as primeiro_lancamento
from public.marketing_semanal m
group by m.semana;

comment on view public.vw_marketing_consolidado is 'Uma linha por semana com todas as lojas somadas. Ordene por primeiro_lancamento para ter a sequência cronológica.';

-- ------------------------------------------------------------
-- Desempenho por loja, com o veredito frente às metas
-- ------------------------------------------------------------
create or replace view public.vw_marketing_por_loja
with (security_invoker = true) as
select
  m.loja,
  m.semana,
  m.investimento,
  m.faturamento,
  m.pedidos,
  m.roas,
  m.cpa,
  round(m.faturamento / nullif(m.pedidos, 0), 2) as ticket_medio,
  m.criado_em
from public.marketing_semanal m;

comment on view public.vw_marketing_por_loja is 'Espelho da marketing_semanal com ticket médio pronto, para comparar lojas lado a lado.';
