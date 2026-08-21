-- ============================================================
-- 0008 — Análise de Dados: vídeos de destaque (TikTok) e devoluções
--
-- A nova aba "Análise de Dados" tem 5 blocos. 3 deles (top/bottom
-- modelos, produtos parados, desempenho por loja) são calculados em
-- cima de dados que já existem (lotes, marketing_semanal) — não
-- precisam de tabela nova. Os outros 2 não têm como ser derivados do
-- que já é registrado, então ganham tabela própria:
--   - qual vídeo do TikTok teve mais alcance/pedidos na semana
--   - motivo de cada devolução (não só a quantidade)
-- ============================================================

create table if not exists public.videos_destaque (
  id                  bigint generated always as identity primary key,
  data                date          not null,
  conta               text          not null,
  video               text          not null,
  alcance             integer       not null default 0 check (alcance >= 0),
  pedidos_atribuidos  integer       not null default 0 check (pedidos_atribuidos >= 0),
  observacao          text,
  created_at          timestamptz   not null default now()
);

comment on table public.videos_destaque is 'Um vídeo postado no TikTok por semana/conta, com alcance e pedidos atribuídos — pra saber o que replicar em vez de só postar por postar.';

create index if not exists videos_destaque_data_idx on public.videos_destaque (data desc);

alter table public.videos_destaque enable row level security;

drop policy if exists videos_destaque_authenticated_all on public.videos_destaque;
create policy videos_destaque_authenticated_all
  on public.videos_destaque
  for all to authenticated
  using (true) with check (true);

do $$
begin
  alter publication supabase_realtime add table public.videos_destaque;
exception when duplicate_object then
  null;
end $$;

-- ------------------------------------------------------------

create table if not exists public.devolucoes (
  id           bigint generated always as identity primary key,
  data         date          not null,
  produto      text          not null,
  loja         text,
  motivo       text          not null,
  observacao   text,
  created_at   timestamptz   not null default now()
);

comment on table public.devolucoes is 'Um registro por devolução/troca, com o motivo — pra entender a causa e não só o volume.';

create index if not exists devolucoes_data_idx on public.devolucoes (data desc);

alter table public.devolucoes enable row level security;

drop policy if exists devolucoes_authenticated_all on public.devolucoes;
create policy devolucoes_authenticated_all
  on public.devolucoes
  for all to authenticated
  using (true) with check (true);

do $$
begin
  alter publication supabase_realtime add table public.devolucoes;
exception when duplicate_object then
  null;
end $$;
