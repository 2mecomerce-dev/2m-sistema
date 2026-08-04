-- ============================================================
-- 0007 — Pagamentos diários ao fornecedor Bravatto
--
-- Segundo fornecedor, independente do já cadastrado (Antonio, via
-- custos/lotes). Os pedidos enviados à Bravatto não passam pelo
-- separador de etiquetas — o app só guarda o valor efetivamente
-- pago a eles em cada dia, pra manter o controle do repasse.
-- ============================================================

create table if not exists public.pagamentos_bravatto (
  data        date          not null primary key,
  valor_pago  numeric(12,2) not null default 0 check (valor_pago >= 0),
  updated_at  timestamptz   not null default now()
);

comment on table public.pagamentos_bravatto is 'Valor pago à Bravatto por dia. Fornecedor separado do de custos/lotes — não tem lotes/composição, só o valor pago.';

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
