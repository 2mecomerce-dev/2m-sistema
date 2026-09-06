-- ============================================================
-- 0014 — Respostas de Avaliações
--
-- Nova aba: o time sobe o print da avaliação (Shopee/TikTok Shop), a
-- IA (numa sessão de chat ou no agente automático agendado) lê a
-- imagem, preenche nota/texto/produto quando faltar e sugere uma
-- resposta em resposta_sugerida. O time revisa e marca como
-- respondida quando já usou no marketplace.
-- ============================================================

insert into storage.buckets (id, name, public)
values ('avaliacoes-prints', 'avaliacoes-prints', false)
on conflict (id) do nothing;

create table if not exists public.avaliacoes (
  id                bigint generated always as identity primary key,
  loja              text,
  pedido_id         text,
  produto           text,
  variacao          text,
  estrelas          integer check (estrelas between 1 and 5),
  texto             text,
  data_avaliacao    date,
  print_path        text,
  status            text not null default 'pendente' check (status in ('pendente','sugerida','respondida')),
  resposta_sugerida text,
  resposta_final    text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
comment on table public.avaliacoes is 'Avaliações de clientes (prints do Shopee/TikTok Shop) aguardando resposta. resposta_sugerida é preenchida por IA (chat ou agente automático) lendo o print em avaliacoes-prints.';

alter table public.avaliacoes enable row level security;

drop policy if exists avaliacoes_reconhecidos on public.avaliacoes;
create policy avaliacoes_reconhecidos
  on public.avaliacoes for all
  to authenticated
  using (public.is_perfil_reconhecido())
  with check (public.is_perfil_reconhecido());

do $$
begin
  alter publication supabase_realtime add table public.avaliacoes;
exception when duplicate_object then
  null;
end $$;

drop policy if exists avaliacoes_prints_select on storage.objects;
create policy avaliacoes_prints_select
  on storage.objects for select
  to authenticated
  using (bucket_id = 'avaliacoes-prints' and public.is_perfil_reconhecido());

drop policy if exists avaliacoes_prints_insert on storage.objects;
create policy avaliacoes_prints_insert
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'avaliacoes-prints' and public.is_perfil_reconhecido());

drop policy if exists avaliacoes_prints_delete on storage.objects;
create policy avaliacoes_prints_delete
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'avaliacoes-prints' and public.is_perfil_reconhecido());
