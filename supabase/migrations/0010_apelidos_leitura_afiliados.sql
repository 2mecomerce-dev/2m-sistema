-- ============================================================
-- 0010 — apelidos: leitura liberada pra qualquer perfil reconhecido
--
-- A Central de Afiliados precisa listar os modelos (apelidos) reais no
-- Controle de Amostras, mas o funcionário de afiliados não deve poder
-- cadastrar/editar produtos nem ver custos. Split leitura x escrita.
-- ============================================================

drop policy if exists apelidos_admin_all on public.apelidos;

create policy apelidos_select_reconhecidos
  on public.apelidos for select
  to authenticated
  using (public.is_perfil_reconhecido());

create policy apelidos_admin_insert
  on public.apelidos for insert
  to authenticated
  with check (public.is_admin());

create policy apelidos_admin_update
  on public.apelidos for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy apelidos_admin_delete
  on public.apelidos for delete
  to authenticated
  using (public.is_admin());
