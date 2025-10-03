#!/usr/bin/env bash
set -euo pipefail

# Config
PDB_NAME=${PDB_NAME:-freepdb1}
SCHEMA=${SCHEMA:-OTC_APP}
BASE_DIR=${BASE_DIR:-$HOME/app/apex-demo}

echo "[INFO] Preparing container directories..."
docker exec oracle-free bash -lc 'mkdir -p /home/oracle/work/db/schema /home/oracle/work/rest'

echo "[INFO] Copying schema SQL files into container..."
docker cp "$BASE_DIR/db/schema/tables.sql" oracle-free:/home/oracle/work/db/schema/tables.sql
docker cp "$BASE_DIR/db/schema/leads.sql" oracle-free:/home/oracle/work/db/schema/leads.sql
docker cp "$BASE_DIR/db/schema/packages.sql" oracle-free:/home/oracle/work/db/schema/packages.sql

echo "[INFO] Copying ORDS REST scripts into container..."
docker cp "$BASE_DIR/rest/ords_enable.sql" oracle-free:/home/oracle/work/rest/ords_enable.sql
docker cp "$BASE_DIR/rest/ords_modules.sql" oracle-free:/home/oracle/work/rest/ords_modules.sql
docker cp "$BASE_DIR/rest/ords_site_leads.sql" oracle-free:/home/oracle/work/rest/ords_site_leads.sql

echo "[INFO] Applying scripts via sqlplus as SYSDBA with CURRENT_SCHEMA=$SCHEMA..."
docker exec oracle-free bash -lc "sqlplus -S / as sysdba <<'SQL' 
ALTER SESSION SET CONTAINER=${PDB_NAME};
ALTER SESSION SET CURRENT_SCHEMA=${SCHEMA};
@/home/oracle/work/db/schema/tables.sql
@/home/oracle/work/db/schema/leads.sql
@/home/oracle/work/db/schema/packages.sql
@/home/oracle/work/rest/ords_enable.sql
@/home/oracle/work/rest/ords_modules.sql
@/home/oracle/work/rest/ords_site_leads.sql
SQL"

echo "[INFO] Done. Test endpoints:"
echo "  curl -i http://localhost:8181/ords/otc/api/otc/health"
echo "  curl -i http://localhost:8181/ords/otc/api/otc/orders"
echo "  curl -i -X POST http://localhost:8181/ords/otc/api/otc/orders/1/approve"
echo "  curl -i -X POST -d 'email=test@example.com&source=web' http://localhost:8181/ords/otc/api/otc/site/lead"