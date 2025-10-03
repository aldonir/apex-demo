Project Rules — APEX OTC Lite
Ambiente de trabalho

Somente VPS (Oracle Cloud Free Tier).

Containers baseados em imagens oficiais do Docker Hub (oracle-free, ords, apex).

Git como controle de versão (monorepo com db/, apex/, rest/, infra/, docs/).

Processo para resolver bugs

Identificar o bug.

Reproduzir o bug.

Analisar o código fonte.

Propor uma solução.

Aguardar autorização para aplicar solução.

Se autorizado, aplicar a solução.

Testar a solução.

Documentar o bug e a solução.

Output Style

Builder → respostas diretas e aplicáveis.

Formato → plano curto (bullet points), blocos de código quando necessário.

Regras adicionais para APEX OTC Lite (Docker/Oracle)

Sempre alinhar scripts e instruções à documentação oficial Oracle APEX/ORDS/DB.

Scripts devem ser compatíveis com o ambiente Docker Hub utilizado (imagens oficiais Oracle Free, ORDS, APEX).

Ao sugerir comandos SQL/PLSQL ou shell, preferir execução via docker exec no container correspondente.

Respeitar paths e convenções da imagem oficial (ex.: /opt/oracle/ords/conf, $ORACLE_HOME, $APEX_HOME).

Validar saúde da stack via docker compose ps + docker logs antes de aplicar alterações.

Toda recomendação deve indicar onde deve rodar: se é no host (VPS Ubuntu) ou em um container (DB, ORDS).

Scripts e artefatos devem ser idempotentes, podendo ser reaplicados sem quebrar o ambiente.

Export/Import de aplicações APEX deve ser feito via SQLcl ou utilitário oficial.

Nunca versionar credenciais, parâmetros sensíveis ou arquivos .env.

Padrão de commits: Conventional Commits (ex.: feat(apex): add approval page P210).

Branches: main (estável), dev (integração), feat/*, fix/*.

Toda mudança deve vir acompanhada de atualização em docs/ (ex.: DEMO_SCRIPT, OPERATIONS, SECURITY).