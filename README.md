# APEX-Demo OTC

Objetivo
- Demonstrar um mini fluxo OTC (submit/approve e simulação de total de fatura) com APEX 23.x, ORDS 24.x e Oracle Database 21c XE, usando pacote central pkg_otc e REST sob /api/otc.

Stack
- Oracle APEX 23.x (App ID 100; páginas: P000, P100, P110, P200, P210, P300, P400, P900, P910)
- ORDS 24.x (REST: /api/otc/..., autenticação Basic ou JWT)
- Oracle Database 21c XE
- Pacote PL/SQL central: pkg_otc (submit, approve, simulate_invoice_total)

Estrutura de pastas
- db/
  - schema/           -> DDL idempotente (tabelas, sinônimos, grants)
  - packages/         -> pkg_otc (spec/body) e utilitários
- ords/
  - modules/          -> definições de REST (/api/otc)
- apex/
  - app/              -> export da aplicação APEX (APP_ID=100)
- tools/
  - codex_cli.py      -> utilitário para gerar/exportar artefatos (APEX/ORDS/DB)
- tests/
  - sql/              -> smoke tests SQLcl/SQL*Plus
  - http/             -> cURL/HTTPie para REST
- build/              -> artefatos gerados (não versionados)

Geração de artefatos (tools/codex_cli.py)
- Pré-requisitos: Python 3.9+, SQLcl/SQL*Plus e ORDS instalados e acessíveis no PATH.
- Exemplos:
  - Gerar/exportar tudo (DB, ORDS, APEX) para build/
    - python3 tools/codex_cli.py gen --app 100 --out build --env dev
  - Exportar APEX app (APP_ID=100)
    - python3 tools/codex_cli.py export-apex --app 100 --file build/apex_app_100.sql
  - Exportar ORDS módulo /api/otc
    - python3 tools/codex_cli.py export-ords --module otc --file build/ords_otc.sql
  - Aplicar artefatos no banco (DDL/PLSQL)
    - python3 tools/codex_cli.py apply-db --conn "app_user/password@XE" --src db

Como testar (smoke tests)
- SQLcl/SQL*Plus (PL/SQL)
  - sql app_user/password@XE
  - @db/schema/tables.sql
  - @db/packages/pkg_otc.pks
  - @db/packages/pkg_otc.pkb
  - begin
      apex_debug.enable; -- fallback para dbms_output se APEX não disponível
      dbms_output.enable(null);
      dbms_output.put_line('simulate: '||
        pkg_otc.simulate_invoice_total(p_order_id => 1001));
    end;
    /
- ORDS (REST)
  - Basic Auth:
    - curl -u api_user:secret -X POST \
      -H "Content-Type: application/json" \
      -d '{"order_id":1001}' \
      http://localhost:8080/ords/api/otc/v1/orders/submit
  - JWT:
    - curl -H "Authorization: Bearer <JWT_TOKEN>" -X POST \
      -H "Content-Type: application/json" \
      -d '{"order_id":1001}' \
      http://localhost:8080/ords/api/otc/v1/orders/approve
  - Simulação:
    - http POST :8080/ords/api/otc/v1/orders/1001/simulate
- APEX
  - Importar o app exportado em apex/app/, executar a App 100 e navegar pelas páginas (ex.: P100 Home, P200 Ordem, P300 Aprovação).
  - Ver logs de execução via apex_debug (ou dbms_output quando fora do APEX).

Notas
- Princípios: mínimo privilégio, binds, DDL idempotente, auditabilidade via apex_debug/dbms_output.
- Ajuste conexões e credenciais conforme seu ambiente (dev/test/prod).
