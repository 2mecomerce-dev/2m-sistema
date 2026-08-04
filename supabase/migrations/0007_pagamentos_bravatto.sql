-- ============================================================
-- 0007 — Repasse diário para o fornecedor Bravatto
--
-- O fornecedor foi dividido: metade do valor de cada lote continua
-- indo pro fornecedor já cadastrado (custos/lotes), a outra metade
-- vai pra um segundo fornecedor (Bravatto), pago à parte. Essa
-- tabela guarda só o valor efetivamente pago à Bravatto em cada
-- dia, pra bater com o valor devido (metade do lote do dia) na
-- hora do acerto — que acontece no mesmo dia que os pedidos saem.
-- ============================================================

create table if not exists public.pagamentos_bravatto (
  data        date          not null primary key,
  valor_pago  numeric(12,2) not null default 0 check (valor_pago >= 0),
  updated_at  timestamptz   not null default now()
);

comment on table public.pagamentos_bravatto is 'Valor pago à Bravatto por dia. Fornecedor separado do de custos/lotes — recebe metade do valor do lote do dia.';

drop trigger if exists pagamentos_bravatto_touch on public.pagamentos_bravatto;
create trigger pagamentos_bravatto_touch
  before update on public.pagamentos_bravatto
  for each row execute function public.touch_updated_at();

alter table public.pagamentos_bravatto enable row level security;

drop policy if exists pagamentos_bravatto_authenticated_all on public.pagamentos_bravatto;
create policy pagamentos_bravatto_authenticated_all
  on public.pagamentos_bravatto
  for all to authenticated
  using (true) with check (true);

do $$
begin
  alter publication supabase_realtime add table public.pagamentos_bravatto;
exception when duplicate_object then
  null;
end $$;
