-- ============================================================
-- 0013 — Sugestões: permite qualquer perfil reconhecido atualizar
--
-- A conta técnica que o agente automático usa pra resolver a fila de
-- sugestões (public.sugestoes) tem perfil restrito (role='afiliados',
-- igual ao Luiz) — de propósito, pra não ter acesso nenhum às tabelas
-- financeiras/admin do sistema, só ao que é is_perfil_reconhecido().
--
-- Isso exige abrir o UPDATE de sugestoes (status/resposta) pra
-- qualquer perfil reconhecido, não só admin. Segue o mesmo padrão de
-- confiança que o afiliados_* já usa entre Breno/Murilo/Luiz — DELETE
-- continua admin-only, então ninguém restrito apaga o histórico.
-- ============================================================

drop policy if exists sugestoes_update_admin on public.sugestoes;
create policy sugestoes_update_reconhecidos
  on public.sugestoes for update
  to authenticated
  using (public.is_perfil_reconhecido())
  with check (public.is_perfil_reconhecido());
