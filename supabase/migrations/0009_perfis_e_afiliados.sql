-- ============================================================
-- 0009 — Perfis de acesso (admin vs. restrito) + Central de Afiliados
--
-- Até aqui, TODA a segurança das tabelas era "qualquer usuário
-- autenticado pode ler/escrever tudo" (using(true)). Isso era ok
-- enquanto só Breno e Murilo tinham login. Agora que um funcionário
-- (Central de Afiliados) vai ter login próprio, isso vira uma falha:
-- esconder abas no menu não impede alguém de abrir o console do
-- navegador e chamar a API do Supabase direto.
--
-- Este arquivo:
--   1. cria perfis_usuario (quem é admin, quem é acesso restrito)
--   2. cria as tabelas da Central de Afiliados (visíveis pra admin E
--      pra quem tem qualquer perfil reconhecido)
--   3. troca a política "authenticated pode tudo" de todas as tabelas
--      existentes por "só admin pode tudo"
-- ============================================================

-- ------------------------------------------------------------
-- 1. Perfis de usuário
-- ------------------------------------------------------------
create table if not exists public.perfis_usuario (
  email       text primary key,
  role        text not null check (role in ('admin','afiliados')),
  nome        text,
  created_at  timestamptz not null default now()
);

comment on table public.perfis_usuario is 'Quem pode logar no sistema e com que nível de acesso. "admin" vê tudo; qualquer outro papel só vê o que a própria política de cada tabela liberar explicitamente pra ele.';

alter table public.perfis_usuario enable row level security;

-- qualquer autenticado pode LER perfis (só email/nome/role, nada sensível —
-- é o que o front usa pra decidir o que mostrar depois do login)
drop policy if exists perfis_usuario_select_all on public.perfis_usuario;
create policy perfis_usuario_select_all
  on public.perfis_usuario for select
  to authenticated
  using (true);

-- só admin pode criar/alterar/remover perfis — senão um funcionário
-- restrito poderia se autopromover
drop policy if exists perfis_usuario_admin_write on public.perfis_usuario;
create policy perfis_usuario_admin_write
  on public.perfis_usuario for insert
  to authenticated
  with check (exists (select 1 from public.perfis_usuario p where p.email = (auth.jwt() ->> 'email') and p.role = 'admin'));

drop policy if exists perfis_usuario_admin_update on public.perfis_usuario;
create policy perfis_usuario_admin_update
  on public.perfis_usuario for update
  to authenticated
  using (exists (select 1 from public.perfis_usuario p where p.email = (auth.jwt() ->> 'email') and p.role = 'admin'))
  with check (exists (select 1 from public.perfis_usuario p where p.email = (auth.jwt() ->> 'email') and p.role = 'admin'));

drop policy if exists perfis_usuario_admin_delete on public.perfis_usuario;
create policy perfis_usuario_admin_delete
  on public.perfis_usuario for delete
  to authenticated
  using (exists (select 1 from public.perfis_usuario p where p.email = (auth.jwt() ->> 'email') and p.role = 'admin'));

-- seed: os dois logins que já existiam viram admin
insert into public.perfis_usuario (email, role, nome) values
  ('brenomeirellessilva@gmail.com', 'admin', 'Breno'),
  ('murilomeireles17@gmail.com', 'admin', 'Murilo'),
  ('luiz10hrd@gmail.com', 'afiliados', 'Luiz')
on conflict (email) do nothing;

-- ------------------------------------------------------------
-- funções helper (security definer pra não entrar em recursão de RLS
-- ao consultar perfis_usuario de dentro da política de outra tabela)
-- ------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1 from public.perfis_usuario p
    where p.email = (auth.jwt() ->> 'email') and p.role = 'admin'
  );
$$;

create or replace function public.is_perfil_reconhecido()
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1 from public.perfis_usuario p
    where p.email = (auth.jwt() ->> 'email')
  );
$$;

comment on function public.is_admin() is 'true se o e-mail logado tem role=admin em perfis_usuario. Usado nas políticas de RLS das tabelas que só admin pode ver.';
comment on function public.is_perfil_reconhecido() is 'true se o e-mail logado tem qualquer linha em perfis_usuario (admin ou não). Usado nas tabelas da Central de Afiliados, que admin e o time de afiliados dividem.';

-- ------------------------------------------------------------
-- 2. Central de Afiliados
-- ------------------------------------------------------------
create table if not exists public.afiliados_leads (
  id                    bigint generated always as identity primary key,
  col                   text not null,
  handle                text not null,
  loja                  text,
  origem                text,
  score                 integer,
  categoria             text,
  receita_30d           numeric(12,2),
  engajamento           text,
  seguidores            text,
  views_medio           text,
  comissao_media        text,
  canal_contato         text,
  fast_growing          boolean not null default false,
  marcas_parceiras      text,
  proximo_passo_label   text,
  proximo_passo         text,
  resultado_livre       text,
  observacao            text,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
comment on table public.afiliados_leads is 'Pipeline de criadores/afiliados em prospecção — um card por criador, movido entre estágios (coluna col).';

create table if not exists public.afiliados_amostras (
  id             bigint generated always as identity primary key,
  semana_inicio  date not null,
  semana_fim     date not null,
  criador        text not null,
  loja           text,
  modelo         text,
  tamanho        text,
  data_envio     date,
  score          integer,
  forma_contato  text,
  resultado      text,
  decisao        text,
  observacao     text,
  created_at     timestamptz not null default now()
);
comment on table public.afiliados_amostras is 'Registro semanal de amostras (pares) enviadas a criadores — limite de 3/semana. Modelo referencia o mesmo apelido usado no resto do sistema (tabela apelidos).';

create table if not exists public.afiliados_tasks (
  id           bigint generated always as identity primary key,
  col          text not null,
  titulo       text not null,
  prioridade   text,
  prazo        text,
  relacionado  text,
  responsavel  text,
  selo         text,
  selo_tipo    text,
  obs          text,
  created_at   timestamptz not null default now()
);
comment on table public.afiliados_tasks is 'Demandas variáveis da Central de Afiliados (kanban), separado da rotina fixa semanal que fica em afiliados_estado.';

create table if not exists public.afiliados_estado (
  id          text primary key default 'principal',
  dados       jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now()
);
comment on table public.afiliados_estado is 'Documento único com a rotina semanal fixa (categorias/itens marcáveis) e os números de meta/comissão da Central de Afiliados.';

alter table public.afiliados_leads    enable row level security;
alter table public.afiliados_amostras enable row level security;
alter table public.afiliados_tasks    enable row level security;
alter table public.afiliados_estado   enable row level security;

drop policy if exists afiliados_leads_reconhecidos on public.afiliados_leads;
create policy afiliados_leads_reconhecidos on public.afiliados_leads for all to authenticated using (public.is_perfil_reconhecido()) with check (public.is_perfil_reconhecido());

drop policy if exists afiliados_amostras_reconhecidos on public.afiliados_amostras;
create policy afiliados_amostras_reconhecidos on public.afiliados_amostras for all to authenticated using (public.is_perfil_reconhecido()) with check (public.is_perfil_reconhecido());

drop policy if exists afiliados_tasks_reconhecidos on public.afiliados_tasks;
create policy afiliados_tasks_reconhecidos on public.afiliados_tasks for all to authenticated using (public.is_perfil_reconhecido()) with check (public.is_perfil_reconhecido());

drop policy if exists afiliados_estado_reconhecidos on public.afiliados_estado;
create policy afiliados_estado_reconhecidos on public.afiliados_estado for all to authenticated using (public.is_perfil_reconhecido()) with check (public.is_perfil_reconhecido());

do $$
begin
  alter publication supabase_realtime add table public.afiliados_leads;
  alter publication supabase_realtime add table public.afiliados_amostras;
  alter publication supabase_realtime add table public.afiliados_tasks;
  alter publication supabase_realtime add table public.afiliados_estado;
exception when duplicate_object then
  null;
end $$;

-- ------------------------------------------------------------
-- 3. Trava o resto do sistema para admin only
-- (troca as políticas antigas "authenticated pode tudo" por "só admin")
-- ------------------------------------------------------------
drop policy if exists "authenticated full access" on public.apelidos;
drop policy if exists apelidos_authenticated_all on public.apelidos;
create policy apelidos_admin_all on public.apelidos for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "authenticated full access" on public.custos;
drop policy if exists custos_authenticated_all on public.custos;
create policy custos_admin_all on public.custos for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "authenticated full access" on public.lotes;
drop policy if exists lotes_authenticated_all on public.lotes;
create policy lotes_admin_all on public.lotes for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "authenticated full access" on public.rotina_estado;
drop policy if exists rotina_estado_authenticated_all on public.rotina_estado;
create policy rotina_estado_admin_all on public.rotina_estado for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists marketing_semanal_authenticated_all on public.marketing_semanal;
create policy marketing_semanal_admin_all on public.marketing_semanal for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists precificacao_config_authenticated_all on public.precificacao_config;
create policy precificacao_config_admin_all on public.precificacao_config for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists precificacao_produtos_authenticated_all on public.precificacao_produtos;
create policy precificacao_produtos_admin_all on public.precificacao_produtos for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists rotina_fechamentos_authenticated_all on public.rotina_fechamentos;
create policy rotina_fechamentos_admin_all on public.rotina_fechamentos for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists metas_faturamento_authenticated_all on public.metas_faturamento;
create policy metas_faturamento_admin_all on public.metas_faturamento for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists pagamentos_bravatto_authenticated_all on public.pagamentos_bravatto;
create policy pagamentos_bravatto_admin_all on public.pagamentos_bravatto for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists videos_destaque_authenticated_all on public.videos_destaque;
create policy videos_destaque_admin_all on public.videos_destaque for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists devolucoes_authenticated_all on public.devolucoes;
create policy devolucoes_admin_all on public.devolucoes for all to authenticated using (public.is_admin()) with check (public.is_admin());
