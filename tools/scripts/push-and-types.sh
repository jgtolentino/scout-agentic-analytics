#!/usr/bin/env bash
set -euo pipefail
supabase db push
supabase gen types typescript --linked --schema public,auth,storage,scout,masterdata,deep_research > apps/web/src/lib/supabase.types.ts
echo "✅ Migrations pushed & types regenerated."
git status --porcelain