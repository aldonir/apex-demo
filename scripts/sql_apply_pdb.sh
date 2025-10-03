#!/usr/bin/env bash
set -euo pipefail

PDB_NAME=${PDB_NAME:-freepdb1}
SQL_FILE=${1:?Usage: sql_apply_pdb.sh <sql_file> [connect_string]}
CONNECT_STR=${2:-"/ as sysdba"}

cat <<SQL | sqlplus -S "$CONNECT_STR"
ALTER SESSION SET CONTAINER=$PDB_NAME;
@$SQL_FILE
SQL