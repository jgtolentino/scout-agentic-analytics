#!/usr/bin/env bash
set -euo pipefail
mkdir -p .tmp
echo "🔍 Generating drift.sql (remote vs repo)…"
supabase db diff --linked --use-migra -f .tmp/drift.sql || true
if [ -s .tmp/drift.sql ]; then
  echo "❌ Drift detected. See .tmp/drift.sql"
  exit 2
else
  echo "✅ No drift."
fi