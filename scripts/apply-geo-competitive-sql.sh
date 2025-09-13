#!/bin/bash
set -euo pipefail

# Apply geo and competitive analysis SQL changes

echo "Applying geo and competitive analysis SQL changes..."

# Check if the SQL file exists
if [ ! -f "supabase/sql/dal/2025-08-14_geo_competitive.sql" ]; then
  echo "Error: SQL file not found at supabase/sql/dal/2025-08-14_geo_competitive.sql"
  exit 1
fi

# Apply the SQL using Supabase CLI
echo "Executing SQL via Supabase..."
npx supabase db push --db-url "${DATABASE_URL:-postgresql://postgres:postgres@localhost:54322/postgres}" < supabase/sql/dal/2025-08-14_geo_competitive.sql

echo "✅ Geo and competitive analysis SQL applied successfully!"

# Optional: Seed demo data
read -p "Do you want to seed demo competitor data? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Seeding demo competitor data..."
  npx supabase db push --db-url "${DATABASE_URL:-postgresql://postgres:postgres@localhost:54322/postgres}" <<'SQL'
  insert into scout.ext_competitor_sales_by_region_daily(dte, region, brand, revenue_php) values
    (current_date - 3, 'Metro Manila', 'Brand X', 320000),
    (current_date - 2, 'Metro Manila', 'Brand X', 305000),
    (current_date - 1, 'Metro Manila', 'Brand X', 315000),
    (current_date - 3, 'Cebu', 'Brand Y', 140000),
    (current_date - 2, 'Cebu', 'Brand Y', 145000),
    (current_date - 1, 'Cebu', 'Brand Y', 150000),
    (current_date - 3, 'Davao', 'Brand Z', 85000),
    (current_date - 2, 'Davao', 'Brand Z', 87000),
    (current_date - 1, 'Davao', 'Brand Z', 90000)
  on conflict do nothing;
SQL
  echo "✅ Demo data seeded!"
fi