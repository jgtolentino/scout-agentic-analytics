#!/usr/bin/env bash
set -euo pipefail

# Usage: export_complete_data.sh <name> "<SQL>"
name="$1"; shift
sql="$*"

HOST="sqltbwaprojectscoutserver.database.windows.net"
DB="flat_scratch"
USER="sqladmin"
PASS="Azure_pw26"

# Export to CSV using sqlcmd
out="exports/${name}"
mkdir -p exports

echo ">> Writing ${out}"
sqlcmd -S "$HOST" -d "$DB" -U "$USER" -P "$PASS" -C -l 60 -W -s"," -h -1 \
  -Q "SET NOCOUNT ON; $sql" -o "$out"
echo "OK: $out"