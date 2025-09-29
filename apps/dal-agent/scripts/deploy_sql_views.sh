#!/usr/bin/env bash
set -euo pipefail

echo "=== SQL Views Deployment ==="

# Find views directory
VIEWS_DIR="sql/views"
if [[ ! -d "$VIEWS_DIR" ]]; then
  echo "No sql/views directory found"
  exit 1
fi

# Count SQL files
SQL_FILES=($(find "$VIEWS_DIR" -name "*.sql" | sort))
echo "Found ${#SQL_FILES[@]} SQL files to deploy"

# Deploy each view file
for sql_file in "${SQL_FILES[@]}"; do
  echo "Deploying: $sql_file"
  if [[ -x scripts/sql.sh ]]; then
    ./scripts/sql.sh -i "$sql_file" || echo "Failed to deploy $sql_file"
  else
    echo "No sql.sh wrapper available - manual deployment needed"
  fi
done

echo "=== View deployment complete ==="
