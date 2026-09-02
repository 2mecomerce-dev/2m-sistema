-- ============================================================
-- 0011 — Cadastro de conta só pra e-mail pré-autorizado
--
-- Vamos habilitar uma tela de "criar conta" pra facilitar o acesso de
-- novos usuários (ex.: Luiz, Central de Afiliados). Mas criar conta não
-- pode ser livre pra qualquer e-mail — só quem já está em
-- perfis_usuario (adicionado à mão pelo admin) pode se cadastrar.
--
-- Isso é reforçado direto no auth.users via trigger, não só escondido
-- na tela: mesmo que alguém chame supabase.auth.signUp() manualmente
-- pelo console do navegador com um e-mail qualquer, o cadastro falha.
-- ============================================================

create or replace function public.check_email_autorizado()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.perfis_usuario
    where email = lower(new.email)
  ) then
    raise exception 'Este e-mail não está autorizado a criar uma conta. Peça para o administrador liberar antes.';
  end if;
  return new;
end;
$$;

comment on function public.check_email_autorizado() is 'Bloqueia signup no auth.users pra qualquer e-mail que não esteja pré-cadastrado em perfis_usuario.';

drop trigger if exists auth_users_check_email_autorizado on auth.users;
create trigger auth_users_check_email_autorizado
  before insert on auth.users
  for each row execute function public.check_email_autorizado();
