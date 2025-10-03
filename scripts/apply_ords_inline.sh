#!/usr/bin/env bash
set -euo pipefail

PDB_NAME=${PDB_NAME:-FREEPDB1}
SCHEMA=${SCHEMA:-OTC_APP}
BASE_DIR=${BASE_DIR:-$HOME/app/apex-demo}
OTC_APP_PWD=${OTC_APP_PWD:-otcapp}

tmpfile=$(mktemp /tmp/ords_apply.XXXXXX.sql)
trap 'rm -f "$tmpfile"' EXIT

{
  echo "ALTER SESSION SET CONTAINER=${PDB_NAME};"
  echo "ALTER SESSION SET CURRENT_SCHEMA=${SCHEMA};"
  cat "$BASE_DIR/db/schema/tables.sql"; echo ""; echo "";
  cat "$BASE_DIR/db/schema/leads.sql"; echo ""; echo "";
  cat "$BASE_DIR/db/schema/packages.sql"; echo ""; echo "";
} > "$tmpfile"

echo "[INFO] Applying schema scripts (SYSDBA) via stdin..."
docker exec -i oracle-free bash -lc "sqlplus -S / as sysdba" < "$tmpfile"

echo "[INFO] Granting INHERIT PRIVILEGES on SYS and SYSTEM to ORDS_METADATA in PDB..."
docker exec -i oracle-free bash -lc "sqlplus -S / as sysdba" <<SQL
ALTER SESSION SET CONTAINER=${PDB_NAME};
GRANT INHERIT PRIVILEGES ON USER SYS TO ORDS_METADATA;
GRANT INHERIT PRIVILEGES ON USER SYSTEM TO ORDS_METADATA;
SQL

ordsfile=$(mktemp /tmp/ords_apply2.XXXXXX.sql)
trap 'rm -f "$ordsfile"' EXIT
{
  echo "ALTER SESSION SET CURRENT_SCHEMA=${SCHEMA};"
  cat "$BASE_DIR/rest/ords_enable.sql"; echo ""; echo "";
  cat "$BASE_DIR/rest/ords_modules.sql"; echo ""; echo "";
  cat "$BASE_DIR/rest/ords_site_leads.sql"; echo ""; echo "";
} > "$ordsfile"

echo "[INFO] Applying ORDS scripts (SYSTEM) via stdin..."
echo "[INFO] Ensuring ${SCHEMA} has a known password in ${PDB_NAME}..."
docker exec -i oracle-free bash -lc "sqlplus -S / as sysdba" <<SQL
ALTER SESSION SET CONTAINER=${PDB_NAME};
ALTER USER ${SCHEMA} IDENTIFIED BY "${OTC_APP_PWD}";
SQL

echo "[INFO] Applying ORDS scripts (as ${SCHEMA}) via stdin..."
echo "[DEBUG] ORDS apply content preview (first 200 lines):"
nl -ba "$ordsfile" | sed -n '1,200p'
# Try primary PDB, then fallbacks
if ! docker exec -i oracle-free bash -lc "sqlplus -L -S ${SCHEMA}/${OTC_APP_PWD}@localhost/${PDB_NAME}" < "$ordsfile"; then
  echo "[WARN] Connection to ${PDB_NAME} failed. Trying FREEPDB1 then XEPDB1..."
  if ! docker exec -i oracle-free bash -lc "sqlplus -L -S ${SCHEMA}/${OTC_APP_PWD}@localhost/FREEPDB1" < "$ordsfile"; then
    docker exec -i oracle-free bash -lc "sqlplus -L -S ${SCHEMA}/${OTC_APP_PWD}@localhost/XEPDB1" < "$ordsfile"
  fi
fi

echo "[INFO] Completed applying scripts."