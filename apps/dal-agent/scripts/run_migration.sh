#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
SQL="$ROOT/scripts/sql.sh"
FILE="${1:?usage: run_migration.sh <sql-file>}"

echo "🚀 Running migration: $FILE"
$SQL -i "$FILE"

echo "📚 Syncing documentation..."
"$ROOT/scripts/doc_sync.sh"

echo "✅ Migration complete with docs updated"