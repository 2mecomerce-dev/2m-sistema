# 2M Sistema — Central de Operações

Sistema interno de operações para e-commerce de dropshipping de calçados de couro. Ver [README.md](README.md) para stack e estrutura.

## Workflow

- O usuário autorizou fazer `git commit` + `git push` para a branch `main` automaticamente após qualquer alteração aprovada no chat, sem pedir confirmação extra a cada vez.
- Continue pedindo confirmação antes de outras ações sensíveis (mudanças em schema/migrations do Supabase que afetem dados existentes, deploy manual, etc.) a menos que autorizado à parte.

## Fila de sugestões (`public.sugestoes`)

O sistema tem um botão flutuante (💡, canto inferior direito, visível pra
qualquer usuário logado) onde o time deixa sugestões de melhoria e
problemas do dia a dia direto de dentro do app. Isso vira uma fila de
trabalho na tabela `public.sugestoes` (colunas: `autor_email`,
`autor_nome`, `mensagem`, `tela`, `status` `novo|em_andamento|concluido`,
`resposta`, `created_at`, `updated_at`).

**O usuário autorizou explicitamente (2026-09-05) um agente autônomo
agendado que revisa essa fila periodicamente sozinho, sem sessão de chat
aberta, e já implementa + faz commit/push direto na `main` do que
conseguir resolver.** Isso estende a autorização de auto-commit acima:
não é preciso "aprovação no chat" item a item pra essa fila específica —
a aprovação já foi dada de antemão para este fluxo.

Ao rodar essa revisão (seja no agente agendado, seja numa sessão normal
comigo), sempre que houver itens com `status = 'novo'` ou `'em_andamento'`:

1. Leia a mensagem, a `tela` de origem e o `autor_nome` pra entender o
   contexto antes de mexer no código.
2. Se for uma melhoria de UI/UX, um bug, uma inconsistência visual ou
   uma pequena funcionalidade nova e o escopo estiver claro: implemente,
   teste no Claude Browser (abrir o preview, simular o estado da tela
   como já é feito neste projeto, conferir console sem erros) antes de
   subir, e então `git commit` + `git push` para `main` — sem pedir
   confirmação, isso já está pré-autorizado.
3. Depois de resolver, atualize a linha em `sugestoes`: `status =
   'concluido'` e `resposta` com uma frase curta explicando o que foi
   feito (ex.: "Adicionado filtro por loja no pipeline — commit abc123").
4. **Não faça sozinho** (marque `status = 'em_andamento'` com uma
   `resposta` explicando o que falta e pare aí, sem tentar adivinhar):
   mudanças em schema/migrations do Supabase que afetem dados
   existentes, qualquer ação destrutiva ou irreversível, decisões de
   negócio ambíguas (ex.: mudar regra de comissão, mudar pesos do
   score), ou pedidos vagos demais pra implementar com segurança sem
   perguntar. Isso continua exigindo confirmação humana, igual descrito
   acima.
5. Se um item não fizer sentido ou for duplicado de outro já resolvido,
   pode marcar `concluido` com uma `resposta` explicando por quê, em vez
   de deixar parado na fila pra sempre.
