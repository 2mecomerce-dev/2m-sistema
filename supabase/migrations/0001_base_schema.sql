-- ============================================================
-- 0001 — Schema base
-- Formaliza as tabelas que o app já usa, com tipos corretos,
-- índices, RLS e realtime. É idempotente: pode rodar de novo
-- num banco que já tem dados, sem perder nada.
-- ============================================================

-- ------------------------------------------------------------
-- apelidos — de que modelo é cada SKU do marketplace
-- ------------------------------------------------------------
create table if not exists public.apelidos (
  sku         text primary key,
  apelido     text        not null,
  updated_at  timestamptz not null default now()
);

comment on table  public.apelidos is 'SKU do marketplace → nome do modelo usado internamente.';
comment on column public.apelidos.sku is 'Código do anúncio, como vem no PDF do pedido.';

-- ------------------------------------------------------------
-- custos — quanto o fornecedor cobra por par de cada modelo
-- ------------------------------------------------------------
create table if not exists public.custos (
  modelo      text primary key,
  custo       numeric(10,2) not null check (custo >= 0),
  updated_at  timestamptz   not null default now()
);

comment on table public.custos is 'Custo unitário de compra por modelo. Base do cálculo de pagamento ao fornecedor e da margem no dashboard.';

-- ------------------------------------------------------------
-- lotes — o que foi separado em cada dia
-- ------------------------------------------------------------
create table if not exists public.lotes (
  id            text primary key,
  date_key      date        not null,
  date_label    text,
  total         integer     not null check (total >= 0),
  composicao    jsonb       not null default '{}'::jsonb,
  timestamp_ms  bigint,
  backdated     boolean     not null default false,
  created_at    timestamptz not null default now()
);

comment on table  public.lotes is 'Um registro por lote separado. É a fonte de verdade do volume de vendas.';
comment on column public.lotes.composicao is 'Mapa {modelo: quantidade de pares}. Lotes antigos podem vir vazios.';
comment on column public.lotes.backdated is 'true quando o lote foi lançado numa data anterior à do registro.';

-- date_key nasceu como texto em algumas instalações; normaliza para date
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'lotes'
      and column_name = 'date_key' and data_type <> 'date'
  ) then
    alter table public.lotes alter column date_key type date using date_key::date;
  end if;
end $$;

create index if not exists lotes_date_key_idx   on public.lotes (date_key desc);
create index if not exists lotes_composicao_gin on public.lotes using gin (composicao);

-- ------------------------------------------------------------
-- rotina_estado — checklist, tarefas, TikTok e lista de lojas
-- Continua como documento JSON. O marketing saiu daqui na 0002.
-- ------------------------------------------------------------
create table if not exists public.rotina_estado (
  id          text primary key,
  dados       jsonb       not null default '{}'::jsonb,
  updated_at  timestamptz not null default now()
);

comment on table public.rotina_estado is 'Documento único (id = principal) com rotina semanal, tarefas, TikTok e lista de lojas. Cada save reescreve o documento inteiro.';

-- ------------------------------------------------------------
-- atualizado_em automático
-- ------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''   -- exigido pelo linter do Supabase: função sem search_path é vetor de ataque
as $$
begin
  new.updated_at := now();
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['apelidos','custos','rotina_estado'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_touch', t);
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.touch_updated_at()',
      t || '_touch', t
    );
  end loop;
end $$;

-- ------------------------------------------------------------
-- RLS — o app tem tela de login, então quem lê e escreve é
-- sempre um usuário autenticado. Sem isso, a chave anon que
-- está no index.html dá acesso ao banco inteiro para qualquer um.
--
-- As políticas são propositalmente amplas (using true): este é um
-- sistema interno onde as duas pessoas da operação enxergam
-- exatamente os mesmos dados. O linter do Supabase aponta isso como
-- "RLS Policy Always True" — é um aviso esperado, não um bug. Se um
-- dia houver perfis com acesso diferente, é aqui que a regra muda.
-- ------------------------------------------------------------
alter table public.apelidos       enable row level security;
alter table public.custos         enable row level security;
alter table public.lotes          enable row level security;
alter table public.rotina_estado  enable row level security;

do $$
declare t text;
begin
  foreach t in array array['apelidos','custos','lotes','rotina_estado'] loop
    execute format('drop policy if exists %I on public.%I', t || '_authenticated_all', t);
    execute format(
      'create policy %I on public.%I for all to authenticated using (true) with check (true)',
      t || '_authenticated_all', t
    );
  end loop;
end $$;

-- ------------------------------------------------------------
-- Realtime — todo mundo vê a mesma coisa, na hora
-- ------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['apelidos','custos','lotes','rotina_estado'] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then
      null;
    end;
  end loop;
end $$;
