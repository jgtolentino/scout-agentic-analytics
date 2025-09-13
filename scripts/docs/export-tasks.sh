#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?missing}"
OUT="docs/TASKS.md"
TMP="$(mktemp)"
psql "$SUPABASE_DB_URL" -At <<'SQL' > "$TMP"
select '| '||task_id||' | '||replace(title,'|','/')||' | '||exec_kind||' | '||status||' | '||to_char(created_at,'YYYY-MM-DD')||' |'
from scout.tasks
order by created_at desc
limit 200;
SQL

awk -v now="$(date -Iseconds)" '
BEGIN{print "### Export at " now "\n\n| task_id | title | exec_kind | status | created_at |\n|---|---|---|---|---|"}
{print}
' "$TMP" > "$TMP.table"

awk '
BEGIN{inblk=0}
/<!-- BEGIN:SNAPSHOT -->/ {print; print ""; system("cat '\''" ARGV[1] "'\''"); skip=1; inblk=1; next}
/<!-- END:SNAPSHOT -->/ {print; inblk=0; next}
{ if (!inblk) print }
' "$TMP.table" "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"

echo "✅ Wrote snapshot into $OUT"
