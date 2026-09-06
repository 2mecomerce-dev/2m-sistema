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

O agente agendado (rotina "2M Sistema - Revisão de sugestões", 2x por dia)
usa o conector MCP do Supabase (acesso admin, ignora RLS) restrito por
instrução a só usar `execute_sql` na tabela `public.sugestoes` — nunca em
nenhuma outra tabela, nunca DDL, nunca `auth.users`. Ver a definição
completa da rotina (`RemoteTrigger get trig_01VtyKA5B96Hf8gMnLBtQMWg`) se
precisar ajustar o prompt dela.

## Fila de avaliações (`public.avaliacoes`)

Aba "Respostas de Avaliações" (menu Ferramentas, só admin vê): o time
sobe o print de uma avaliação do Shopee/TikTok Shop (só a loja é
obrigatória — nota/texto/produto podem ficar em branco). O print vai pro
bucket privado `avaliacoes-prints` no Storage; a linha correspondente em
`public.avaliacoes` guarda `print_path`, `loja`, `pedido_id`, `produto`,
`variacao`, `estrelas`, `texto`, `status` (`pendente|sugerida|respondida`),
`resposta_sugerida`, `resposta_final`.

Quando o Breno (ou Murilo/Luiz) pedir numa conversa pra ver as avaliações
pendentes: consulte `avaliacoes` com `status <> 'respondida'`, gere uma
`signed URL` do print (`sb.storage...createSignedUrl` via SQL não dá — se
precisar ver a imagem de dentro de uma sessão de chat, use o Supabase MCP
pra achar o `print_path` e peça a URL pública/assinada, ou peça o print
direto no chat) e depois de ler a imagem: preencha `estrelas`/`texto`/
`produto` que estiverem faltando e escreva uma resposta em
`resposta_sugerida`, curta, no tom da marca (2M — caloroso mas
profissional; agradece avaliação positiva, pede desculpa + oferece
solução via chat da loja pra negativa), atualizando `status = 'sugerida'`.

**Ainda não faz parte do agente automático agendado** — a rotina de
sugestões não tem como baixar/ver os prints (bucket privado, sem
ferramenta de Storage no toolset dela). Se o Breno pedir pra automatizar
isso também, a opção mais simples é tornar `avaliacoes-prints` público
(os paths já são não-adivinháveis) pra rotina conseguir baixar o print
via `curl` e ler com a ferramenta Read — **confirme com o Breno antes**
de mudar o bucket pra público, é uma troca de privacidade por automação.
