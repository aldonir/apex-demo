Lições Aprendidas — Projeto APEX OTC Lite
========================================

Data: contínuo (atualizado conforme progresso)

1) Conexão ORDS e PDB
- Problema: `ORA-12514` ao conectar em `XEPDB1`; listener não expunha serviço.
- Ação: fallback para `FREEPDB1` e lógica de reconexão no script `apply_ords_inline.sh`.
- Resultado: Handlers aplicados com sucesso.

2) Quoting PL/SQL em ORDS
- Problema: `PLS-00103` por uso incorreto de aspas dentro de `q'[]'` e JSON com backslashes.
- Ação: padronizar `p_source => q'[ ... ]'` com `'application/json'` e JSON sem escapes desnecessários.
- Resultado: Endpoints `health`, `approve`, `lead` passaram a responder 200 OK.

3) Execução de comandos remotos (PowerShell)
- Problema: uso de `&&` em `scp/ssh` no PowerShell gerou `ParserError`.
- Ação: enviar comandos em chamadas separadas e evitar `&&`.
- Resultado: arquivos sincronizados com sucesso.

4) Estrutura de Documentação
- Valor: `docs/DEMO_SCRIPT.md` como fio condutor acelerou validação e testes.
- Decisão: manter um documento norte (`Projeto APEX-Demo.md`) com status e governança.

5) Trade-offs REST
- Decisão: handlers PL/SQL por previsibilidade; AutoREST pode ser adotado para CRUDs simples.
- Impacto: mais verboso, porém maior controle sobre segurança e auditoria.

6) Senhas e Segredos
- Prática: usar variáveis de ambiente e `.gitignore` para arquivos sensíveis.
- Risco: vazamento se commits incluírem dumps/exports sem revisão.

7) Próximas melhorias de processo
- Adicionar verificação automática pós-aplicação (SQLcl) para compilações e status de ORDS.
- Incluir checklist de segurança (ACL, roles, TLS) antes de expor endpoints.