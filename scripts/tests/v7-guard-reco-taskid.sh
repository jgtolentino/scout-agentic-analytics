#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?missing}"
cnt=$(psql "$SUPABASE_DB_URL" -Atc "select count(*) from scout.recommendations where coalesce(task_id,'')=''")
echo "ℹ️ recommendations without task_id: $cnt"
test "$cnt" -eq 0 || { echo "❌ missing task_id on recommendations"; exit 1; }
echo "✅ task_id guard passed"
