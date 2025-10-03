#!/usr/bin/env bash
set -euo pipefail
echo "[rollback] Este é um placeholder seguro."
echo "[rollback] Exemplo: reverter pkg e dados seed (execute manualmente via SQLcl no seu ambiente):"
cat <<'SQL'
-- Exemplo (ajuste ao seu schema antes de rodar):
-- DROP PACKAGE pkg_otc;
-- DELETE FROM order_lines WHERE order_id IN (SELECT order_id FROM orders WHERE status='APPROVED');
-- UPDATE orders SET status='OPEN' WHERE status='APPROVED';
-- COMMIT;
SQL
