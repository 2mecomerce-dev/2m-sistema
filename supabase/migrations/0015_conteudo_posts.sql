-- ============================================================
-- 0015 — Cronograma de conteúdo do TikTok (calendário mensal)
--
-- Substitui o controle solto de "postou/não postou" por um calendário
-- de verdade: cada post planejado (data, horário, conta, título/ideia)
-- vira uma linha, editável, marcável como feito. Vive dentro da aba
-- Marketing & TikTok (subaba "Conteúdo & Cronograma"), admin-only —
-- mesmo nível de acesso de marketing_semanal.
-- ============================================================

create table if not exists public.conteudo_posts (
  id         bigint generated always as identity primary key,
  data       date not null,
  horario    text,
  conta      text not null,
  titulo     text not null,
  ideia      text,
  feito      boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table public.conteudo_posts is 'Cronograma mensal de conteúdo do TikTok — um post planejado por linha, por conta, com meta de 3 posts/semana.';

alter table public.conteudo_posts enable row level security;

drop policy if exists conteudo_posts_admin_all on public.conteudo_posts;
create policy conteudo_posts_admin_all
  on public.conteudo_posts for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

do $$
begin
  alter publication supabase_realtime add table public.conteudo_posts;
exception when duplicate_object then
  null;
end $$;
