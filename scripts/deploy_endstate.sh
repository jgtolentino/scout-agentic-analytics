#!/usr/bin/env bash
set -euo pipefail
: "${AZSQL_HOST:?}"; : "${AZSQL_DB:?}"; : "${AZSQL_USER:?}"; : "${AZSQL_PASS:?}"

./scripts/run_sql.sh sql/10_dbo_endstate_tables.sql
./scripts/run_sql.sh sql/11_dbo_endstate_ops.sql
./scripts/run_sql.sh sql/12_dbo_endstate_views.sql

# Validate
sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER" -P "$AZSQL_PASS" -l 60 -Q "EXEC dbo.sp_health_dbo_endstate;"

# If v24 adapter exists, install validator and run it once under reader to prove contract
if [ -f sql/13_v24_adapter.sql ]; then
  ./scripts/run_sql.sh sql/14_v24_validate.sql
  # Use reader to execute validator (principle of least privilege)
  if [ -n "${AZSQL_USER_READER:-}" ] && [ -n "${AZSQL_PASS_READER:-}" ]; then
    ./scripts/validate_v24.sh || { echo 'v24 validation FAILED'; exit 1; }
  else
    echo "SKIP v24 validation run (reader creds not provided)";
  fi
fi