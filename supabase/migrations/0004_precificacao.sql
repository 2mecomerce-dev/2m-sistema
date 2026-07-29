-- ============================================================
-- 0004 — Precificação de produtos
--
-- Calcula o preço de venda em Shopee, TikTok Shop e Mercado Livre
-- a partir de custo + taxa fixa, usando a mesma lógica de markup
-- sobre custos variáveis (imposto, comissão, frete, ads, risco e
-- margem desejada) da planilha original de precificação.
--
-- precificacao_config: documento único (id = principal) com as
-- alíquotas/percentuais e custos fixos que alimentam o cálculo.
-- precificacao_produtos: uma linha por produto (custo + taxa fixa),
-- cadastrado uma única vez — o preço nos 3 canais é derivado no
-- app a partir daqui, sem repetir dado por canal.
-- ============================================================

create table if not exists public.precificacao_config (
  id          text primary key default 'principal',
  dados       jsonb       not null default '{}'::jsonb,
  updated_at  timestamptz not null default now()
);

comment on table public.precificacao_config is 'Documento único (id = principal) com Simples Nacional, ads, risco, margem desejada, custos fixos e comissão/frete de cada canal.';

create table if not exists public.precificacao_produtos (
  id             text primary key,
  nome           text not null,
  custo_produto  numeric(10,2) not null default 0 check (custo_produto >= 0),
  taxa_fixa      numeric(10,2) not null default 0 check (taxa_fixa >= 0),
  updated_at     timestamptz not null default now()
);

comment on table  public.precificacao_produtos is 'Um produto por linha (custo + taxa fixa). O preço em cada canal é calculado no app, não armazenado.';
comment on column public.precificacao_produtos.taxa_fixa is 'Taxa fixa por pedido (embalagem/etiqueta), somada ao custo do produto para formar o custo base.';

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['precificacao_config','precificacao_produtos'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_touch', t);
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.touch_updated_at()',
      t || '_touch', t
    );
  end loop;
end $$;

alter table public.precificacao_config    enable row level security;
alter table public.precificacao_produtos  enable row level security;

do $$
declare t text;
begin
  foreach t in array array['precificacao_config','precificacao_produtos'] loop
    execute format('drop policy if exists %I on public.%I', t || '_authenticated_all', t);
    execute format(
      'create policy %I on public.%I for all to authenticated using (true) with check (true)',
      t || '_authenticated_all', t
    );
  end loop;
end $$;

do $$
declare t text;
begin
  foreach t in array array['precificacao_config','precificacao_produtos'] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then
      null;
    end;
  end loop;
end $$;
