# 2M Sistema — Central de Operações

Sistema interno de operações para e-commerce de dropshipping de calçados de couro. Ver [README.md](README.md) para stack e estrutura.

## Workflow

- O usuário autorizou fazer `git commit` + `git push` para a branch `main` automaticamente após qualquer alteração aprovada no chat, sem pedir confirmação extra a cada vez.
- Continue pedindo confirmação antes de outras ações sensíveis (mudanças em schema/migrations do Supabase que afetem dados existentes, deploy manual, etc.) a menos que autorizado à parte.
