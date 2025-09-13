#!/usr/bin/env bash
set -euo pipefail
mkdir -p docs/db
supabase db dump --schema public,auth,storage,scout,masterdata,deep_research --data-only=false > docs/db/schema_snapshot.sql
echo "✅ Schema snapshot updated at docs/db/schema_snapshot.sql"