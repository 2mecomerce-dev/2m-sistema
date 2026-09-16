-- ============================================================
-- 0016 — Impulsionamento por post + teto mensal
--
-- O controle de impulsionamento (ads no TikTok) sai da tela separada
-- de Desempenho e passa a viver dentro de cada post do cronograma de
-- conteúdo: ao criar/editar um post, dá pra marcar se ele vai ser
-- impulsionado e quanto. A soma de valor_impulso do mês (impulsionar
-- = true) é comparada a um teto fixo de R$500/mês na UI.
-- ============================================================

alter table public.conteudo_posts
  add column if not exists impulsionar boolean not null default false,
  add column if not exists valor_impulso numeric(10,2);

comment on column public.conteudo_posts.impulsionar is 'Se este post vai ser impulsionado com ads no TikTok.';
comment on column public.conteudo_posts.valor_impulso is 'Valor em R$ planejado/investido pra impulsionar este post — soma no teto mensal de R$500.';
