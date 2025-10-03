# Demo OTC: Oracle XE + APEX + ORDS (Free Tier)

Este roteiro documenta como preparar o ambiente, aplicar os artefatos do monorepo e testar os endpoints ORDS, além de instruções mínimas para criar a aplicação APEX (APP_ID=100) no schema `OTC_APP`.

## Pré-requisitos
- Docker e docker-compose instalados na VPS.
- Imagens oficiais:
  - `oracle-free` (Oracle XE 21c)
  - `ords`/`ords24` (ORDS 24.x)
  - `apex` (APEX 23.x, opcional; XE pode já incluir APEX)
- Porta HTTP externa do ORDS mapeada para `8181` na VPS.

## Estrutura do Monorepo
- `db/schema/*.sql`: tabelas, views, triggers, packages (idempotentes)
- `rest/*.sql`: módulos, templates, handlers e enable do ORDS
- `apex/`: export da app APEX (opcional; instruções abaixo)
- `scripts/apply_ords_inline.sh`: aplica schema e ORDS dentro do container do Oracle
- `rest/examples.http`: exemplos de requisições para testes

## Aplicar Schema e ORDS
1. Subir containers com `docker-compose` da VPS (assegure o container `oracle-free` e o `ords` rodando; o ORDS deve expor `8181`).
2. Executar o script inline no host (sem credenciais sensíveis hardcoded):
   - `PDB_NAME` padrão: `FREEPDB1` (fallback para `XEPDB1`)
   - `SCHEMA` padrão: `OTC_APP`
   - `OTC_APP_PWD` padrão: `otcapp` (defina um valor seguro via env)

   Exemplo:
   - `bash scripts/apply_ords_inline.sh`
   - ou: `PDB_NAME=FREEPDB1 OTC_APP_PWD='<sua_senha_segura>' bash scripts/apply_ords_inline.sh`

3. O script realiza:
   - `ALTER SESSION SET CONTAINER=<PDB>` e `CURRENT_SCHEMA=OTC_APP`
   - Criação/garantia de `otc_orders`, `otc_order_items`, `otc_leads_emails`, sequências e triggers
   - `CREATE OR REPLACE PACKAGE otc_pkg_approve`
   - Grants idempotentes: `INHERIT PRIVILEGES` para `ORDS_METADATA` em `SYS` e `SYSTEM`
   - `ords.enable_schema` com mapping `otc` e base path `api/otc/`
   - Módulos `otc_api`: `health`, `orders` e `orders/:id/approve`
   - Template/handler `site/lead` (POST) para capturar e-mails de leads

## Testes dos Endpoints ORDS
Base URL: `http://<host>:8181/ords/otc/api/otc/`

- Saúde:
  - `GET /health`
  - Esperado: `{"status":"ok"}`
- Listagem de pedidos:
  - `GET /orders`
  - Esperado: objeto com `items` e `count` (inicialmente vazio)
- Captura de lead:
  - `POST /site/lead` com `Content-Type: application/x-www-form-urlencoded`
  - Body: `email=test@example.com&source=web`
  - Esperado: `{"ok":true}` (idempotente retorna `{"ok":true,"dup":true}`)
- Aprovação de pedido (exige um pedido existente):
  - Criar pedido de exemplo (SQL, como `OTC_APP`):
    ```sql
    insert into otc_orders(id, status, created_at)
    values (otc_seq_orders.nextval, 'PENDING', sysdate);
    commit;
    ```
  - `POST /orders/:id/approve` substituindo `:id` pelo ID criado
  - Esperado: `{"approved":true}` e `status='APPROVED'`

Você pode usar `rest/examples.http` para rodar estes testes via cliente `.http`.

## Instruções APEX (APP_ID=100)
Objetivo: criar uma aplicação mínima “OTC Minimal” com páginas de relatórios para `OTC_APP`.

1. Acessar APEX: `http://<host>:8181/ords/`
2. Entrar como Admin (Workspace `INTERNAL`) e criar um Workspace, por exemplo `OTC_APP_WS`, associado ao schema `OTC_APP`.
3. Criar um usuário desenvolvedor no workspace `OTC_APP_WS`.
4. Logar no workspace `OTC_APP_WS` e criar a aplicação:
   - ID: `100`
   - Nome: `OTC Minimal`
   - Tema padrão
5. Páginas sugeridas:
   - “Orders” (Interactive Report) em `OTC_ORDERS`
   - “Order Items” (Interactive Report) em `OTC_ORDER_ITEMS`
   - “Leads” (Interactive Report) em `OTC_LEADS_EMAILS`
6. Validações mínimas:
   - Garantir que colunas obrigatórias (`email`, `status`) não sejam nulas ao inserir/editar.
7. Ação de Aprovação (opcional):
   - Adicionar botão/ação que chame `otc_pkg_approve.approve(:P<n>_ID)` na página de detalhe do pedido.

### Exportar a aplicação (gerar `apex/app_100_min_otc.sql`)
Você pode exportar via UI do APEX:
- Em “Export/Import” > “Export” > selecione a aplicação `100` e salve o arquivo.
- Adicione o arquivo ao monorepo em `apex/app_100_min_otc.sql`.

Alternativas (dependendo do container):
- `APEXExport.jar` (se disponível) via Java: `java -jar APEXExport.jar -workspace <WS> -applicationid 100`
- SQLcl `apex export` (se instalado): `apex export -applicationid 100 -workspace <WS>`

## Observações de Segurança e Idempotência
- Não versione senhas reais. Use variáveis de ambiente para `OTC_APP_PWD`.
- Scripts SQL usam `CREATE OR REPLACE` e blocos anônimos idempotentes.
- Grants e enables podem ser reaplicados sem erro.

## Troubleshooting
- `ORA-12514` em conexões SQL*Plus: verifique o service name (`FREEPDB1` vs `XEPDB1`) e listener.
- `PLS-00306` em `ords.define_parameter`: rever tipos/nomes dos parâmetros; handlers PL/SQL devem usar `q'[ ... ]'` com aspas corretas.
- `404` nos endpoints: confirmar porta externa (ex.: `8181`) e base path `/ords/otc/api/otc/`.

## Compatibilidade
- Testado com Oracle XE 21c, APEX 23.x, ORDS 24.x.
- Endpoints e scripts compatíveis com `docker-compose` da VPS.