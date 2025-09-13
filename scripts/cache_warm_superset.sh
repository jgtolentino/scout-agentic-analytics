#!/usr/bin/env bash
set -euo pipefail
SUPERSET_URL="${SUPERSET_URL:?}"
SUPERSET_TOKEN="${SUPERSET_TOKEN:?}"
CRITICAL_IDS_FILE="${1:-platform/superset/critical_dash_ids.txt}"

while read -r CHART_ID; do
  [ -z "$CHART_ID" ] && continue
  curl -sS -X POST "$SUPERSET_URL/api/v1/chart/$CHART_ID/data" \
    -H "Authorization: Bearer $SUPERSET_TOKEN" -H "Content-Type: application/json" \
    -d '{"force": false}' >/dev/null
  echo "Warmed chart $CHART_ID"
done < "$CRITICAL_IDS_FILE"