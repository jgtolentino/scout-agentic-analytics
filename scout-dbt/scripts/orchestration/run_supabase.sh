#!/bin/bash
set -euo pipefail

echo "🐘 Running dbt for Supabase target..."

# Export credentials from environment
export SUPABASE_PASS="${SUPABASE_PASS:-Postgres_26}"

# Run dbt commands
cd scout-dbt

# Install dependencies
dbt deps --target supabase

# Run models
dbt run --target supabase --select bronze
dbt run --target supabase --select silver
dbt run --target supabase --select gold

# Run tests
dbt test --target supabase

# Generate docs
dbt docs generate --target supabase

echo "✅ Supabase dbt run complete"
