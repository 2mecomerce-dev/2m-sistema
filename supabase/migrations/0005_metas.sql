-- ============================================================
-- 0005 — Suporte a Metas
--
-- Metas precisa de duas coisas que ainda não existiam:
--   1. A semana do marketing hoje só tem um rótulo digitado
--      (ex: "20/07 a 26/07"), sem data de verdade — impossível
--      somar "faturamento do mês" com isso. Adiciona data_inicio
--      e data_fim.
--   2. Não existe histórico de quando a rotina semanal foi
--      fechada nem qual foi o % concluído — precisa disso pra
--      calcular "atividades do mês".
-- ============================================================

alter table public.marketing_semanal
  add column if not exists data_inicio date,
  add column if not exists data_fim    date;

comment on column public.marketing_semanal.data_inicio is 'Início do período selecionado no formulário. Nulo em lançamentos antigos (antes do seletor de datas existir).';
comment on column public.marketing_semanal.data_fim is 'Fim do período. Usado para decidir a qual mês o lançamento pertence, nas Metas.';

create table if not exists public.rotina_fechamentos (
  id             text primary key,
  fechado_em     timestamptz not null default now(),
  pct_concluido  numeric     not null default 0 check (pct_concluido >= 0 and pct_concluido <= 100),
  itens_feitos   integer     not null default 0 check (itens_feitos >= 0),
  itens_total    integer     not null default 0 check (itens_total >= 0)
);

comment on table public.rotina_fechamentos is 'Um registro por clique em "Fechar semana e reiniciar" na aba Rotina. Base do % de atividades do mês usado nas Metas.';

create index if not exists rotina_fechamentos_fechado_em_idx on public.rotina_fechamentos (fechado_em);

alter table public.rotina_fechamentos enable row level security;

drop policy if exists rotina_fechamentos_authenticated_all on public.rotina_fechamentos;
create policy rotina_fechamentos_authenticated_all
  on public.rotina_fechamentos
  for all to authenticated
  using (true) with check (true);

do $$
begin
  alter publication supabase_realtime add table public.rotina_fechamentos;
exception when duplicate_object then
  null;
end $$;
