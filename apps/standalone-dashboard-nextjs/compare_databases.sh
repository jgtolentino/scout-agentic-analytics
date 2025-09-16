#!/bin/bash
set -euo pipefail

echo "========================================="
echo "DATABASE COMPARISON: LOCAL vs REMOTE"
echo "========================================="

# Remote Supabase connection string (using pooler)
REMOTE_DB="postgres://postgres.cxzllzyxwpyptfretryc:Postgres_26@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres"
LOCAL_DB="host=127.0.0.1 port=54322 user=supabase_admin dbname=postgres sslmode=disable"

echo ""
echo "=== REMOTE SUPABASE ANALYSIS ==="
echo "Connection: $REMOTE_DB"
psql "$REMOTE_DB" -c "
SELECT 'REMOTE SUPABASE - SCHEMAS AND TABLES' as analysis_type;
SELECT 
  schemaname as schema,
  tablename as table,
  case when schemaname = 'public' then 'Default'
       when schemaname like 'pg_%' then 'System'
       when schemaname = 'information_schema' then 'Metadata'
       when schemaname in ('auth', 'storage', 'realtime') then 'Supabase Core'
       when schemaname in ('etl', 'silver', 'gold', 'dim') then 'ETL Pipeline'
       else 'Custom'
  end as category
FROM pg_tables 
WHERE schemaname NOT IN ('information_schema', 'pg_catalog', 'pg_toast', 'pg_stat_tmp')
ORDER BY 
  case when schemaname in ('etl', 'silver', 'gold', 'dim') then 1
       when schemaname in ('auth', 'storage') then 2
       when schemaname = 'public' then 3
       else 4
  end,
  schemaname, tablename;
" 2>/dev/null || echo "❌ Remote Supabase connection failed"

echo ""
echo "=== REMOTE EXTENSIONS ==="
psql "$REMOTE_DB" -c "
SELECT 'INSTALLED EXTENSIONS' as info;
SELECT extname as extension, extversion as version
FROM pg_extension 
WHERE extname NOT IN ('plpgsql')
ORDER BY extname;
" 2>/dev/null || echo "❌ Could not fetch extensions"

echo ""
echo "=== LOCAL CONTAINER ANALYSIS ==="
if docker inspect supabase_db_tbwa >/dev/null 2>&1; then
  echo "Container Status: $(docker inspect supabase_db_tbwa --format='{{.State.Status}}')"
  echo "Health: $(docker inspect supabase_db_tbwa --format='{{.State.Health.Status}}')"
  
  if [ "$(docker inspect supabase_db_tbwa --format='{{.State.Status}}')" = "running" ]; then
    echo "Connection: $LOCAL_DB"
    PGPASSWORD="Postgres_26" psql "$LOCAL_DB" -c "
    SELECT 'LOCAL CONTAINER - SCHEMAS AND TABLES' as analysis_type;
    SELECT 
      schemaname as schema,
      tablename as table,
      case when schemaname = 'public' then 'Default'
           when schemaname like 'pg_%' then 'System'
           when schemaname = 'information_schema' then 'Metadata'
           when schemaname in ('etl', 'silver', 'gold', 'dim') then 'ETL Pipeline'
           else 'Custom'
      end as category
    FROM pg_tables 
    WHERE schemaname NOT IN ('information_schema', 'pg_catalog', 'pg_toast', 'pg_stat_tmp')
    ORDER BY 
      case when schemaname in ('etl', 'silver', 'gold', 'dim') then 1
           when schemaname = 'public' then 2
           else 3
      end,
      schemaname, tablename;
    " 2>/dev/null || echo "❌ Local container connection failed"
    
    echo ""
    echo "=== LOCAL EXTENSIONS ==="
    PGPASSWORD="Postgres_26" psql "$LOCAL_DB" -c "
    SELECT 'LOCAL EXTENSIONS' as info;
    SELECT extname as extension, extversion as version
    FROM pg_extension 
    WHERE extname NOT IN ('plpgsql')
    ORDER BY extname;
    " 2>/dev/null || echo "❌ Could not fetch local extensions"
  else
    echo "❌ Local container is not running"
  fi
else
  echo "❌ Local container not found"
fi

echo ""
echo "=== SUMMARY ==="
echo "This comparison shows:"
echo "1. Schemas and tables in both databases"
echo "2. Extension differences between local and remote"
echo "3. ETL pipeline implementation status"
echo "4. Supabase-specific schemas (auth, storage, realtime)"
echo ""
echo "Key Differences Expected:"
echo "- Remote: Full Supabase auth/storage/realtime schemas"
echo "- Local: Minimal PostgreSQL with custom ETL schemas"
echo "- ETL schemas should exist in both if migrations ran successfully"

