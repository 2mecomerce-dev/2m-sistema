-- ============================================================
-- 0012 — Sugestões de melhoria (botão de feedback no sistema)
--
-- Qualquer pessoa logada (admin ou perfil restrito) pode deixar uma
-- sugestão/problema direto de dentro do sistema, em qualquer tela.
-- Vira uma fila de trabalho: status novo → em_andamento → concluído.
-- Só admin marca status ou apaga (evita o time restrito reescrever o
-- histórico de outros); qualquer perfil reconhecido pode ler tudo, pra
-- não duplicar sugestão parecida e acompanhar o que já foi resolvido.
-- ============================================================

create table if not exists public.sugestoes (
  id           bigint generated always as identity primary key,
  autor_email  text not null,
  autor_nome   text,
  mensagem     text not null,
  tela         text,
  status       text not null default 'novo' check (status in ('novo','em_andamento','concluido')),
  resposta     text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
comment on table public.sugestoes is 'Sugestões de melhoria deixadas pelo time direto no sistema — fila de trabalho pra evolução contínua do produto.';

alter table public.sugestoes enable row level security;

drop policy if exists sugestoes_select_reconhecidos on public.sugestoes;
create policy sugestoes_select_reconhecidos
  on public.sugestoes for select
  to authenticated
  using (public.is_perfil_reconhecido());

drop policy if exists sugestoes_insert_reconhecidos on public.sugestoes;
create policy sugestoes_insert_reconhecidos
  on public.sugestoes for insert
  to authenticated
  with check (public.is_perfil_reconhecido());

drop policy if exists sugestoes_update_admin on public.sugestoes;
create policy sugestoes_update_admin
  on public.sugestoes for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists sugestoes_delete_admin on public.sugestoes;
create policy sugestoes_delete_admin
  on public.sugestoes for delete
  to authenticated
  using (public.is_admin());

do $$
begin
  alter publication supabase_realtime add table public.sugestoes;
exception when duplicate_object then
  null;
end $$;
