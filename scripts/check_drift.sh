#!/usr/bin/env bash
set -euo pipefail

# ===== Config =====
: "${EXPORT_BASE:=http://localhost:3001}"
: "${AZSQL_HOST:=sqltbwaprojectscoutserver.database.windows.net}"
: "${AZSQL_DB:=flat_scratch}"
: "${AZSQL_USER:=sqladmin}"
: "${AZSQL_PASS:=Azure_pw26}"
: "${MIN_EXPECTED_ROWS:=1}"

echo "🔍 Checking data drift for Scout exports..."

check_export_rows() {
  local export_type="$1"
  local min_expected="$2"

  echo ">> Checking ${export_type} export..."

  # Get SQL from API endpoint
  local sql
  sql=$(curl -fsSL "${EXPORT_BASE}/api/export/${export_type}" -X POST -H "Content-Type: application/json" -d "{}" | jq -r '.sql')

  if [[ "$sql" == "null" || -z "$sql" ]]; then
    echo "❌ FAIL: Could not get SQL for ${export_type}"
    return 1
  fi

  # Count rows using SQL (remove ORDER BY for counting)
  local count_sql
  count_sql=$(echo "$sql" | sed 's/ORDER BY[^;]*;//i')

  local row_count
  row_count=$(sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER" -P "$AZSQL_PASS" -C -W -h -1 -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM (${count_sql}) t" | tr -d '\r\n ')

  echo "   Rows found: ${row_count}"

  if [[ "${row_count:-0}" -lt "$min_expected" ]]; then
    echo "❌ DRIFT: ${export_type} rows=${row_count} < min_expected=${min_expected}"
    return 2
  fi

  echo "✅ OK: ${export_type} has ${row_count} rows (>= ${min_expected})"
  return 0
}

# Check all three exports
exports_checked=0
drift_errors=0

for export_type in "flat-actual" "flat-v24" "crosstab-v10"; do
  if check_export_rows "$export_type" "$MIN_EXPECTED_ROWS"; then
    ((exports_checked++))
  else
    ((drift_errors++))
  fi
done

echo ""
echo "📊 Drift Check Summary:"
echo "   Exports checked: ${exports_checked}/3"
echo "   Drift errors: ${drift_errors}"

if [[ "$drift_errors" -gt 0 ]]; then
  echo "❌ DRIFT DETECTED: ${drift_errors} export(s) below threshold"
  exit 2
else
  echo "✅ All exports passed drift check"
  exit 0
fi