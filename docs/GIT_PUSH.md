Guia de Git — Preparar e Realizar Push
=====================================

Objetivo: padronizar inicialização e push do repositório do projeto.

1) Preparar .gitignore
- Criar/atualizar `.gitignore` com:
  - `env/.env`
  - `infra/ords/params/*.properties`
  - `*.dmp`, `*.log`
  - `apex/app_*_export*.sql` (opcional)
  - `.DS_Store`, `Thumbs.db`

2) Inicializar repositório
```
git init
git add .
git commit -m "chore(repo): init monorepo APEX OTC Lite"
```

3) Configurar remoto (exemplos)
- GitHub (HTTPS):
```
git remote add origin https://github.com/<org>/<repo>.git
```
- GitHub (SSH):
```
git remote add origin git@github.com:<org>/<repo>.git
```
- Bitbucket:
```
git remote add origin git@bitbucket.org:<org>/<repo>.git
```

4) Push
```
git branch -M main
git push -u origin main
```

5) Boas práticas
- Commits pequenos e descritivos (prefixos: feat, fix, chore, docs, ci).
- Evitar versionar segredos e dumps grandes.
- Releases: tags com export APEX e changelog.
- Branches: `main` estável, `feat/*`, `fix/*`, `docs/*`.

6) Troubleshooting
- Remote inexistente: `git remote -v` para verificar.
- Auth falhando: testar HTTPS vs. SSH, atualizar token/chave.