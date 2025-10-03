#!/usr/bin/env bash
set -euo pipefail

echo "[smoke] lint rápido em SQL (anti-queda de produção)"
fail=0
# bloqueios simples: sem CREATE USER/ROLE/PROFILE, sem DROP USER, etc.
grep -RniE 'CREATE (USER|ROLE|PROFILE)|DROP (USER|ROLE|PROFILE)|GRANT DBA' db || true
if grep -RniE 'CREATE (USER|ROLE|PROFILE)|DROP (USER|ROLE|PROFILE)|GRANT DBA' db; then
  echo "[smoke] ❌ Encontrado DDL perigoso. Remova antes do deploy."
  exit 2
fi
echo "[smoke] ✅ Lint básico OK"

# ORDS smoke (se variáveis existirem)
ORDS_BASE_URL="${ORDS_BASE_URL:-}"
BASIC_AUTH_B64="${BASIC_AUTH_B64:-}"   # base64 de user:pass (ex.: echo -n 'user:pass'|base64)
JWT_TOKEN="${JWT_TOKEN:-}"             # se usar JWT

if [[ -z "$ORDS_BASE_URL" ]]; then
  echo "[smoke] (pulei cURL ORDS — defina ORDS_BASE_URL para testar endpoints)"
  exit 0
fi

echo "[smoke] testando GET /api/otc/orders"
code=$(curl -sS -o /tmp/get_orders.json -w '%{http_code}' \
  -H "Authorization: Basic ${BASIC_AUTH_B64}" \
  "${ORDS_BASE_URL}/api/otc/orders?status=OPEN&limit=5" || true)
echo "HTTP $code"
[[ "$code" =~ ^2 ]] || { echo "[smoke] ❌ GET /orders falhou"; cat /tmp/get_orders.json || true; exit 3; }
echo "[smoke] ✅ GET /orders OK"

ORDER_ID=$(jq -r '.[0].ORDER_ID // .items[0].order_id // empty' /tmp/get_orders.json || true)
if [[ -n "$ORDER_ID" ]]; then
  echo "[smoke] testando POST /api/otc/orders/:id/approve (id=$ORDER_ID)"
  code=$(curl -sS -o /tmp/post_approve.json -w '%{http_code}' \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Basic ${BASIC_AUTH_B64}" \
    -d '{"approved_by":"smoke-ci"}' \
    "${ORDS_BASE_URL}/api/otc/orders/${ORDER_ID}/approve" || true)
  echo "HTTP $code"
  [[ "$code" =~ ^2 ]] || { echo "[smoke] ❌ POST /approve falhou"; cat /tmp/post_approve.json || true; exit 4; }
  echo "[smoke] ✅ POST /approve OK"
else
  echo "[smoke] (nenhum ORDER_ID retornado — verifique payload do GET /orders)"
fi

echo "[smoke] ✅ Finalizado"
