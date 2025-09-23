#!/usr/bin/env bash
set -euo pipefail

# ===============================
# Scout Edge Validation Runner
# - Runs Azure SQL + Supabase suites
# - Produces PASS/FAIL summary
# ===============================

# ---- Config via env ----
: "${SCOUT_REPO_ROOT:=${SCOUT_REPO_ROOT:-$PWD/scout-v7}}"

# Supabase: prefer a single URL
: "${SUPABASE_URL:?Set SUPABASE_URL, e.g. postgres://user:pass@host:5432/db}"

# Azure SQL:
#   Mode AAD:   set AZURE_SQL_MODE=aad, AZURE_SQL_SERVER=xxx.database.windows.net, AZURE_SQL_DB=dbname
#   Mode SQL:   set AZURE_SQL_MODE=sql, AZURE_SQL_SERVER=..., AZURE_SQL_DB=..., AZURE_SQL_USER=..., AZURE_SQL_PASSWORD=...
#   Mode SKIP:  set AZURE_SQL_MODE=skip to skip Azure SQL validation
: "${AZURE_SQL_MODE:?Set AZURE_SQL_MODE to 'aad', 'sql', or 'skip'}"

if [[ "$AZURE_SQL_MODE" != "skip" ]]; then
  : "${AZURE_SQL_SERVER:?Set AZURE_SQL_SERVER (e.g. mydb.database.windows.net)}"
  : "${AZURE_SQL_DB:?Set AZURE_SQL_DB (database name)}"
  if [[ "$AZURE_SQL_MODE" == "sql" ]]; then
    : "${AZURE_SQL_USER:?Set AZURE_SQL_USER for SQL auth}"
    : "${AZURE_SQL_PASSWORD:?Set AZURE_SQL_PASSWORD for SQL auth}"
  fi
fi

# ---- Files ----
AZURE_SQL="${SCOUT_REPO_ROOT}/azure/azure_validation_suite.sql"
PG_SQL="${SCOUT_REPO_ROOT}/supabase/supabase_validation_suite.sql"
UNIFIED_SQL="${SCOUT_REPO_ROOT}/validation/unified_validation_runner.sql"

# Optional quick sanity probes if your suites don't already emit them:
PG_PROBE="${SCOUT_REPO_ROOT}/validation/_pg_probe.sql"
AZ_PROBE="${SCOUT_REPO_ROOT}/validation/_az_probe.sql"

mkdir -p "${SCOUT_REPO_ROOT}/logs"
LOG_AZ="${SCOUT_REPO_ROOT}/logs/azure_validation.log"
LOG_PG="${SCOUT_REPO_ROOT}/logs/supabase_validation.log"
LOG_UNI="${SCOUT_REPO_ROOT}/logs/unified_validation.log"
LOG_SUM="${SCOUT_REPO_ROOT}/logs/summary.txt"

# ---- Helpers ----
have() { command -v "$1" >/dev/null 2>&1; }
need() { have "$1" || { echo "Missing required command: $1" >&2; exit 127; }; }

if [[ "$AZURE_SQL_MODE" != "skip" ]]; then
  need sqlcmd
fi
need psql

# ---- Run Azure SQL suite ----
if [[ "$AZURE_SQL_MODE" != "skip" ]]; then
  echo "==> Running Azure SQL validation: $AZURE_SQL" | tee "$LOG_SUM"
  if [[ "$AZURE_SQL_MODE" == "aad" ]]; then
    # AAD integrated (-G). Assumes 'az login' done and token available to sqlcmd.
    sqlcmd -G -S "$AZURE_SQL_SERVER" -d "$AZURE_SQL_DB" -I -b -i "$AZURE_SQL" | tee "$LOG_AZ"
  else
    sqlcmd -S "$AZURE_SQL_SERVER" -d "$AZURE_SQL_DB" -U "$AZURE_SQL_USER" -P "$AZURE_SQL_PASSWORD" -I -b -i "$AZURE_SQL" | tee "$LOG_AZ"
  fi
else
  echo "==> Skipping Azure SQL validation (AZURE_SQL_MODE=skip)" | tee "$LOG_SUM"
fi

# ---- Run Supabase (Postgres) suite ----
echo "==> Running Supabase validation: $PG_SQL" | tee -a "$LOG_SUM"
psql "$SUPABASE_URL" -v ON_ERROR_STOP=1 -f "$PG_SQL" | tee "$LOG_PG"

# ---- Run unified comparison (assumed Postgres target) ----
echo "==> Running unified comparison: $UNIFIED_SQL" | tee -a "$LOG_SUM"
psql "$SUPABASE_URL" -v ON_ERROR_STOP=1 -f "$UNIFIED_SQL" | tee "$LOG_UNI"

# ---- Quick probes (optional, resilient) ----
# If present, these should output single-row metrics we parse below.
# Different expected counts for different data sources:
SUPABASE_EXPECT=13149    # Scout Edge transactions (audio-based purchases)
AZURE_EXPECT=81532       # Azure SQL interactions (facial recognition events)
THRESHOLD=0.02           # 2%

# Calculate ranges for Supabase (Scout Edge)
MIN_ROWS_PG=$(python - <<PY
import math; print(math.floor(${SUPABASE_EXPECT}*(1-${THRESHOLD})))
PY
)
MAX_ROWS_PG=$(python - <<PY
import math; print(math.ceil(${SUPABASE_EXPECT}*(1+${THRESHOLD})))
PY
)

# Calculate ranges for Azure SQL
MIN_ROWS_AZ=$(python - <<PY
import math; print(math.floor(${AZURE_EXPECT}*(1-${THRESHOLD})))
PY
)
MAX_ROWS_AZ=$(python - <<PY
import math; print(math.ceil(${AZURE_EXPECT}*(1+${THRESHOLD})))
PY
)

PG_ROWS=""
AZ_ROWS=""
PG_SUBS_BAD=""
PG_LOC_MUNI_MISS=""
PG_LOC_GEOM_MISS=""
AZ_SUBS_BAD=""
AZ_LOC_MUNI_MISS=""
AZ_LOC_GEOM_MISS=""

if [[ -f "$PG_PROBE" ]]; then
  PG_OUT=$(psql "$SUPABASE_URL" -v ON_ERROR_STOP=1 -At -f "$PG_PROBE" || true)
  # expected output order (one row each): rows, subs_violations, miss_muni, miss_geom
  PG_ROWS=$(echo "$PG_OUT" | sed -n '1p')
  PG_SUBS_BAD=$(echo "$PG_OUT" | sed -n '2p')
  PG_LOC_MUNI_MISS=$(echo "$PG_OUT" | sed -n '3p')
  PG_LOC_GEOM_MISS=$(echo "$PG_OUT" | sed -n '4p')
fi

if [[ -f "$AZ_PROBE" ]]; then
  if [[ "$AZURE_SQL_MODE" == "aad" ]]; then
    AZ_OUT=$(sqlcmd -G -S "$AZURE_SQL_SERVER" -d "$AZURE_SQL_DB" -I -b -h-1 -W -i "$AZ_PROBE" | tr -d ' \r' || true)
  else
    AZ_OUT=$(sqlcmd -S "$AZURE_SQL_SERVER" -d "$AZURE_SQL_DB" -U "$AZURE_SQL_USER" -P "$AZURE_SQL_PASSWORD" -I -b -h-1 -W -i "$AZ_PROBE" | tr -d ' \r' || true)
  fi
  # same order: rows, subs_violations, miss_muni, miss_geom
  AZ_ROWS=$(echo "$AZ_OUT" | sed -n '1p')
  AZ_SUBS_BAD=$(echo "$AZ_OUT" | sed -n '2p')
  AZ_LOC_MUNI_MISS=$(echo "$AZ_OUT" | sed -n '3p')
  AZ_LOC_GEOM_MISS=$(echo "$AZ_OUT" | sed -n '4p')
fi

# ---- Summarize with thresholds ----
pass_fail() { [[ "$1" -eq 0 ]] && echo "PASS" || echo "FAIL"; }

check_pg_rows=0; check_pg_subs=0; check_pg_loc=0
check_az_rows=0; check_az_subs=0; check_az_loc=0

if [[ -n "$PG_ROWS" ]]; then
  if (( PG_ROWS < MIN_ROWS_PG || PG_ROWS > MAX_ROWS_PG )); then check_pg_rows=1; fi
fi
if [[ -n "$PG_SUBS_BAD" ]]; then
  if (( PG_SUBS_BAD > 0 )); then check_pg_subs=1; fi
fi
if [[ -n "$PG_LOC_MUNI_MISS" && -n "$PG_LOC_GEOM_MISS" ]]; then
  if (( PG_LOC_MUNI_MISS > 0 || PG_LOC_GEOM_MISS > 0 )); then check_pg_loc=1; fi
fi

if [[ -n "$AZ_ROWS" ]]; then
  if (( AZ_ROWS < MIN_ROWS_AZ || AZ_ROWS > MAX_ROWS_AZ )); then check_az_rows=1; fi
fi
if [[ -n "$AZ_SUBS_BAD" ]]; then
  if (( AZ_SUBS_BAD > 0 )); then check_az_subs=1; fi
fi
if [[ -n "$AZ_LOC_MUNI_MISS" && -n "$AZ_LOC_GEOM_MISS" ]]; then
  if (( AZ_LOC_MUNI_MISS > 0 || AZ_LOC_GEOM_MISS > 0 )); then check_az_loc=1; fi
fi

{
  echo
  echo "==================== Summary ===================="
  echo "Expected rows (different data sources):"
  printf "  Supabase (Scout Edge transactions): %d (tolerance ±%d%% ⇒ [%d..%d])\n" "$SUPABASE_EXPECT" "$(awk "BEGIN{print ${THRESHOLD}*100}")" "$MIN_ROWS_PG" "$MAX_ROWS_PG"
  printf "  Azure SQL (facial interactions): %d (tolerance ±%d%% ⇒ [%d..%d])\n" "$AZURE_EXPECT" "$(awk "BEGIN{print ${THRESHOLD}*100}")" "$MIN_ROWS_AZ" "$MAX_ROWS_AZ"
  echo
  echo "Supabase:"
  printf "  Row count .......... %s" "${PG_ROWS:-N/A}"; [[ -n "$PG_ROWS" ]] && printf "  [%s]\n" "$(pass_fail $check_pg_rows)" || echo
  printf "  Substitution checks  %s" "${PG_SUBS_BAD:-N/A}"; [[ -n "$PG_SUBS_BAD" ]] && printf "  [%s]\n" "$(pass_fail $check_pg_subs)" || echo
  printf "  Location completeness (miss muni / geom): %s / %s" "${PG_LOC_MUNI_MISS:-N/A}" "${PG_LOC_GEOM_MISS:-N/A}"
  if [[ -n "$PG_LOC_MUNI_MISS" && -n "$PG_LOC_GEOM_MISS" ]]; then printf "  [%s]\n" "$(pass_fail $check_pg_loc)"; else echo; fi
  echo
  echo "Azure SQL:"
  printf "  Row count .......... %s" "${AZ_ROWS:-N/A}"; [[ -n "$AZ_ROWS" ]] && printf "  [%s]\n" "$(pass_fail $check_az_rows)" || echo
  printf "  Substitution checks  %s" "${AZ_SUBS_BAD:-N/A}"; [[ -n "$AZ_SUBS_BAD" ]] && printf "  [%s]\n" "$(pass_fail $check_az_subs)" || echo
  printf "  Location completeness (miss muni / geom): %s / %s" "${AZ_LOC_MUNI_MISS:-N/A}" "${AZ_LOC_GEOM_MISS:-N/A}"
  if [[ -n "$AZ_LOC_MUNI_MISS" && -n "$AZ_LOC_GEOM_MISS" ]]; then printf "  [%s]\n" "$(pass_fail $check_az_loc)"; else echo; fi
  echo
  echo "Logs:"
  echo "  Azure   -> $LOG_AZ"
  echo "  Supabase-> $LOG_PG"
  echo "  Unified -> $LOG_UNI"
  echo "==============================================="
} | tee -a "$LOG_SUM"

echo "Done."