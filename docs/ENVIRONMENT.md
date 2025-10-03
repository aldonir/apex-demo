# Environment — APEX OTC Lite

## Infraestrutura Base (VPS)

- Provedor: Oracle Cloud Free Tier (Ubuntu 22.04 LTS)
- Orquestração: Docker + Docker Compose
- Proxy Reverso: NGINX com TLS (Let’s Encrypt, auto-renew)
- Controle de versão: Git (monorepo)

## Containers Principais

### 1. `oracle-free`
- Imagem: `container-registry.oracle.com/database/free:21.3.0.0`
- Função: Banco de Dados Oracle XE 21c
- Portas: `1521` (SQL*Net), `5500` (Enterprise Manager opcional)
- Paths relevantes:
  - `$ORACLE_HOME` → `/opt/oracle/product/21c/dbhomeXE`
  - Datafiles → `/opt/oracle/oradata`
- Usuário inicial: `system`
- Schema de aplicação: `OTC_APP`

### 2. `ords`
- Imagem: `container-registry.oracle.com/database/ords:24.1` (ou similar no Docker Hub)
- Função: Oracle REST Data Services (standalone)
- Porta interna: `8181` (exposta somente localhost)
- Paths relevantes:
  - Configuração ORDS → `/opt/oracle/ords/conf`
  - Logs → `/opt/oracle/ords/logs`

### 3. `apex` (opcional, se separado)
- Imagem: `container-registry.oracle.com/database/apex:23.2`
- Função: Oracle APEX runtime (quando não embarcado no ORDS)
- Porta interna: integrada via ORDS
- Paths relevantes:
  - `$APEX_HOME` → `/opt/oracle/apex`

### 4. `nginx`
- Imagem: `nginx:stable`
- Função: Proxy reverso + TLS
- Porta externa: `443`
- Paths relevantes:
  - Configuração → `/etc/nginx/sites-enabled/fiscai_apex.conf`
  - Certificados TLS → `/etc/letsencrypt/live/<domínio>/`

## Integração de Rede

Internet (`443` HTTPS)
→ NGINX
→ ORDS (`8181`, localhost only)
→ Oracle XE 21c (`1521`)

## Variáveis de Ambiente (no `.env`)
- `DB_USER=otc_app`
- `DB_PASS=****`
- `DB_CONN=oracle:1521/XEPDB1`
- `ORDS_PORT=8181`
- `APEX_APP_ID=100`
- `NGINX_SERVER_NAME=apex.seudominio.com.br`

## Observabilidade & Manutenção

- Logs ORDS: `docker logs -f ords` ou `/opt/oracle/ords/logs/ords.log`
- Logs DB: `/opt/oracle/diag/rdbms/*/alert.log`
- Logs NGINX: `/var/log/nginx/access.log`, `/var/log/nginx/error.log`
- Healthcheck: `docker compose ps`, `docker logs`, `curl -I https://apex.seudominio.com.br/ords/`

## Backup

- Export APEX (sqlcl → `apex/app_100_min_otc.sql`)
- Export schema Oracle (`expdp otc_app/...`)
- Atualização Certbot: renovação automática (`systemctl status certbot.timer`)

## Convenções

- Execução de comandos: sempre diferenciar HOST vs CONTAINER:
  - Host VPS → comandos de docker compose, nginx, certbot.
  - Container DB → `docker exec -it oracle-free sqlplus system/...`
  - Container ORDS → `docker exec -it ords sqlcl ...`
- Idempotência: todos os scripts SQL/Shell devem poder ser reaplicados sem erros.
- Segurança: nunca commitar `.env`, senhas, certificados ou dumps.