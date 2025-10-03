#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

echo "== Preflight — APEX OTC Lite =="

# ---- Config esperada
APP_ID_DEFAULT="100"
REST_MODULE_NAME="otc_api"
SCHEMA_PREFIX="otc_"

# ---- 1) Estrutura básica
need_files=(
  "db/schema"
  "rest/ords_modules.sql"
  "docs"
)
for f in "${need_files[@]}"; do
  [[ -e "$f" ]] || { echo "ERRO: caminho ausente: $f" >&2; exit 1; }
done
echo "OK: estrutura mínima presente."

# ---- 2) Anti-duplicação de objetos (CREATE ...)
# mapeia tipo/nome por regex simples (tables/views/packages/triggers)
tmpmap="$(mktemp)"
trap 'rm -f "$tmpmap"' EXIT

# Captura linhas relevantes com arquivo
# Observação: simplificado; evita falsos positivos com comentários e replace.
grep -Rin --include="*.sql" -E "^[[:space:]]*create[[:space:]]+(or[[:space:]]+replace[[:space:]]+)?(table|view|package|trigger)[[:space:]]+" db/schema \
| sed -E 's#^(.+):([0-9]+):(.*)$#\1|\2|\3#' \
| while IFS='|' read -r file line content; do
  # normaliza
  lower="$(echo "$content" | tr '[:upper:]' '[:lower:]')"
  # extrai tipo e nome (muito comum: create table otc_xxx / create or replace view otc_xxx ...)
  if [[ "$lower" =~ create[[:space:]]+(or[[:space:]]+replace[[:space:]]+)?(table|view|package|trigger)[[:space:]]+([a-z0-9_]+) ]]; then
    type="${BASH_REMATCH[2]}"
    name="${BASH_REMATCH[3]}"
    echo "${type}|${name}|${file}:${line}" >> "$tmpmap"
  fi
done

# verifica duplicatas
if [[ -s "$tmpmap" ]]; then
  echo "Verificando duplicatas de objetos..."
  dups="$(cut -d'|' -f1-2 "$tmpmap" | sort | uniq -d || true)"
  if [[ -n "$dups" ]]; then
    echo "ERRO: Objetos duplicados detectados (mesmo tipo+nome definidos em mais de 1 arquivo):"
    while IFS= read -r key; do
      echo " - $key"
      grep -F "$key|" "$tmpmap" | cut -d'|' -f3- | sed 's/^/   -> /'
    done <<< "$dups"
    exit 2
  fi
  echo "OK: nenhuma duplicação de objetos em db/schema."
fi

# ---- 3) Padrões mínimos
# 3.1 Packages/Views/Triggers devem usar create or replace
bad_replace="$(grep -Rin --include="*.sql" -E "^[[:space:]]*create[[:space:]]+(table)[[:space:]]+" db/schema || true)"
# Tabelas: 'create table' é esperado; verificamos o inverso para packages/views/triggers:
bad_pkg_view_trg="$(grep -Rin --include="*.sql" -E "^[[:space:]]*create[[:space:]]+(view|package|trigger)[[:space:]]+[a-z0-9_]+" db/schema | grep -vi 'create or replace' || true)"
if [[ -n "$bad_pkg_view_trg" ]]; then
  echo "ERRO: Encontrado view/package/trigger SEM 'create or replace':"
  echo "$bad_pkg_view_trg"; exit 3
fi
echo "OK: padrões de 'create or replace' atendidos (exceto tabelas)."

# 3.2 Prefixo de nomenclatura
bad_prefix="$(grep -Rin --include="*.sql" -E "^[[:space:]]*create[[:space:]]+(or[[:space:]]+replace[[:space:]]+)?(table|view|package|trigger)[[:space:]]+([^[:space:]]+)" db/schema \
  | awk -F ':' '{print $1":"$2":"$3}' \
  | sed -E 's#^(.+):([0-9]+):[[:space:]]*create[[:space:]]+(or[[:space:]]+replace[[:space:]]+)?(table|view|package|trigger)[[:space:]]+([^[:space:]]+).*#\1|\2|\4#' \
  | awk -F '|' -v pref="$SCHEMA_PREFIX" '$3 !~ "^"pref {print}' || true)"
if [[ -n "$bad_prefix" ]]; then
  echo "ERRO: Objetos sem prefixo '${SCHEMA_PREFIX}':"
  echo "$bad_prefix"; exit 4
fi
echo "OK: nomenclatura com prefixo '${SCHEMA_PREFIX}'."

# ---- 4) ORDS — módulo único e rotas
if [[ -f "rest/ords_modules.sql" ]]; then
  mod_count="$(grep -i 'define_module' rest/ords_modules.sql | grep -i "${REST_MODULE_NAME}" | wc -l)"
  if [[ "$mod_count" -ne 1 ]]; then
    echo "ERRO: Esperado 1 define_module para '${REST_MODULE_NAME}', encontrado: $mod_count"
    exit 5
  fi
  # Verifica duplicação grosseira de rotas (pattern repetido + método)
  dup_routes="$(grep -Eio "define_handler\([^)]*p_pattern *=> *'[^']+'" rest/ords_modules.sql \
    | sed -E "s/.*p_pattern *=> *'([^']+)'.*/\1/" \
    | sort | uniq -d || true)"
  if [[ -n "$dup_routes" ]]; then
    echo "ERRO: Rotas ORDS duplicadas detectadas:"
    echo "$dup_routes"; exit 6
  fi
  echo "OK: ORDS módulo/rotas consistentes."
fi

# ---- 5) Export APEX — app id
if [[ -f "apex/app_100_min_otc.sql" ]]; then
  if ! grep -qi "p_application_id *=> *${APP_ID_DEFAULT}" apex/app_100_min_otc.sql; then
    echo "ERRO: Export APEX não contém p_application_id => ${APP_ID_DEFAULT}"
    exit 7
  fi
  echo "OK: Export APEX alinhado ao APP_ID ${APP_ID_DEFAULT}."
else
  echo "AVISO: Export APEX ausente (apex/app_100_min_otc.sql)."
fi

echo "== Preflight OK =="