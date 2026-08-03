-- ============================================================
-- 0006 — Faturamento das Metas passa a ser manual
--
-- O faturamento usado pra bater nível na aba Metas estava sendo
-- somado automaticamente das entradas semanais de Marketing & TikTok
-- (que servem pra acompanhar ROAS/CPA de mídia paga, não são o
-- faturamento real da operação). Isso gerava número errado.
--
-- Agora o faturamento oficial do mês é digitado manualmente, uma vez
-- por mês, direto do Upseller. CPA continua vindo do Marketing
-- (isso está correto) e atividades continua vindo do checklist da
-- Rotina.
-- ============================================================

create table if not exists public.metas_faturamento (
  ano          int         not null,
  mes          int         not null check (mes between 1 and 12),
  faturamento  numeric(12,2) not null default 0 check (faturamento >= 0),
  updated_at   timestamptz not null default now(),
  primary key (ano, mes)
);

comment on table public.metas_faturamento is 'Faturamento oficial do mês, digitado manualmente (fonte: Upseller). Usado como o número de faturamento nas Metas — não é derivado de marketing_semanal.';

drop trigger if exists metas_faturamento_touch on public.metas_faturamento;
create trigger metas_faturamento_touch
  before update on public.metas_faturamento
  for each row execute function public.touch_updated_at();

alter table public.metas_faturamento enable row level security;

drop policy if exists metas_faturamento_authenticated_all on public.metas_faturamento;
create policy metas_faturamento_authenticated_all
  on public.metas_faturamento
  for all to authenticated
  using (true) with check (true);

do $$
begin
  alter publication supabase_realtime add table public.metas_faturamento;
exception when duplicate_object then
  null;
end $$;
