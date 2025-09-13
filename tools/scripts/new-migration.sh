#!/usr/bin/env bash
set -euo pipefail
name="${1:-feature}"
ts=$(date +%Y%m%d%H%M%S)
file="supabase/migrations/${ts}_${name}.sql"
mkdir -p supabase/migrations
: > "$file"
echo "Created $file"
echo "👉 Add SQL to that file, then run: supabase db push && supabase gen types ..."