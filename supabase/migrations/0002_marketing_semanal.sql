-- ============================================================
-- 0002 — Marketing semanal sai do JSON e vira tabela
--
-- Antes: todos os lançamentos de mídia viviam dentro de
-- rotina_estado.dados->marketing->entries. Dois problemas:
--   1. cada save reescrevia o documento inteiro, então duas
--      pessoas salvando ao mesmo tempo se sobrescreviam;
--   2. não dava para consultar nada por SQL — o dashboard
--      precisava baixar o JSON inteiro e calcular no navegador.
--
-- Agora: uma linha por loja/semana, com ROAS e CPA calculados
-- pelo próprio banco.
-- ============================================================

create table if not exists public.marketing_semanal (
  loja           text not null,
  semana         text not null,
  investimento   numeric(12,2) not null default 0 check (investimento >= 0),
  faturamento    numeric(12,2) not null default 0 check (faturamento  >= 0),
  pedidos        integer       not null default 0 check (pedidos      >= 0),

  -- calculados pelo banco: sempre coerentes, não dá para divergir
  roas numeric generated always as (
    case when investimento > 0 then round(faturamento / investimento, 4) end
  ) stored,
  cpa numeric generated always as (
    case when pedidos > 0 then round(investimento / pedidos, 4) end
  ) stored,

  criado_em      timestamptz not null default now(),
  atualizado_em  timestamptz not null default now(),

  primary key (loja, semana)
);

comment on table  public.marketing_semanal is 'Um lançamento de mídia paga por loja e por semana. A chave (loja, semana) impede o lançamento duplicado que existia no JSON.';
comment on column public.marketing_semanal.semana is 'Rótulo digitado pelo operador, ex: "20-26/07". A ordem cronológica vem de criado_em.';
comment on column public.marketing_semanal.roas is 'faturamento / investimento. Nulo quando não houve investimento.';
comment on column public.marketing_semanal.cpa  is 'investimento / pedidos. Nulo quando não houve pedido.';

create index if not exists marketing_semanal_semana_idx on public.marketing_semanal (criado_em);

drop trigger if exists marketing_semanal_touch on public.marketing_semanal;
create or replace function public.touch_atualizado_em()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.atualizado_em := now();
  return new;
end $$;
create trigger marketing_semanal_touch
  before update on public.marketing_semanal
  for each row execute function public.touch_atualizado_em();

-- ------------------------------------------------------------
-- Migração dos dados que já estão no JSON
-- Roda uma vez; em execuções seguintes o ON CONFLICT DO NOTHING
-- protege o que o app já gravou depois.
-- ------------------------------------------------------------
with src as (
  select
    e->>'store'                as loja,
    e->>'label'                as semana,
    (e->>'invest')::numeric    as investimento,
    (e->>'revenue')::numeric   as faturamento,
    (e->>'orders')::int        as pedidos,
    ord
  from public.rotina_estado r,
       lateral jsonb_array_elements(r.dados->'marketing'->'entries') with ordinality as t(e, ord)
  where r.id = 'principal'
    and jsonb_typeof(r.dados->'marketing'->'entries') = 'array'
), dedup as (
  -- o app antigo permitia lançar a mesma loja/semana várias vezes;
  -- fica valendo o lançamento mais recente
  select distinct on (loja, semana) *
  from src
  where loja is not null and semana is not null
  order by loja, semana, ord desc
)
insert into public.marketing_semanal (loja, semana, investimento, faturamento, pedidos)
select loja, semana, coalesce(investimento,0), coalesce(faturamento,0), coalesce(pedidos,0)
from dedup
on conflict (loja, semana) do nothing;

-- ------------------------------------------------------------
-- RLS + realtime, no mesmo padrão das outras tabelas
-- ------------------------------------------------------------
alter table public.marketing_semanal enable row level security;

drop policy if exists marketing_semanal_authenticated_all on public.marketing_semanal;
create policy marketing_semanal_authenticated_all
  on public.marketing_semanal
  for all to authenticated
  using (true) with check (true);

do $$
begin
  alter publication supabase_realtime add table public.marketing_semanal;
exception when duplicate_object then
  null;
end $$;
