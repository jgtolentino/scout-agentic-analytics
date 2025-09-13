#!/usr/bin/env bash
# Complete ETL service role setup with minimal privileges
set -euo pipefail

echo "Setting up least-privileged etl_svc role..."

:bruno run '
psql "$BRUNO_SECRET_db_url_admin" -v ON_ERROR_STOP=1 <<SQL
-- Create role if not exists
do $
begin
  if not exists (select 1 from pg_roles where rolname = '\''etl_svc'\'') then
    create role etl_svc login password :pw;
    raise notice '\''Created etl_svc role'\'';
  else
    raise notice '\''etl_svc role already exists'\'';
  end if;
end$;

-- Revoke all default privileges first
revoke all on schema public from etl_svc;
revoke all on all tables in schema public from etl_svc;
revoke all on all sequences in schema public from etl_svc;
revoke all on all functions in schema public from etl_svc;

-- Grant minimal schema access
grant usage on schema scout to etl_svc;

-- ETL-specific table permissions
grant select, insert, update on scout.bronze_edge_raw to etl_svc;
grant select, insert, update on scout.silver_transactions to etl_svc;
grant select, insert, update on scout.gold_analytics to etl_svc;
grant select, insert, update on scout.etl_queue to etl_svc;
grant select, insert, update on scout.etl_failures to etl_svc;
grant select, insert, update on scout.etl_watermarks to etl_svc;

-- Grant sequence permissions for ID generation
grant usage on all sequences in schema scout to etl_svc;

-- Grant execute on ETL functions only
grant execute on function scout.transform_edge_bronze_to_silver() to etl_svc;
grant execute on function scout.process_etl_queue() to etl_svc;
grant execute on function scout.mark_etl_failure(uuid, text) to etl_svc;

-- Set conservative resource limits
alter role etl_svc set statement_timeout = '\''60s'\'';
alter role etl_svc set lock_timeout = '\''10s'\'';
alter role etl_svc set idle_in_transaction_session_timeout = '\''5min'\'';
alter role etl_svc set work_mem = '\''256MB'\'';

-- Future objects in scout schema
alter default privileges in schema scout grant select, insert, update on tables to etl_svc;
alter default privileges in schema scout grant usage on sequences to etl_svc;

-- Audit setup
comment on role etl_svc is '\''Limited ETL service account - created $(date -Is)'\'';

-- Verify permissions
select 
  '\''Schema permissions:'\'' as check_type,
  has_schema_privilege('\''etl_svc'\'', '\''scout'\'', '\''usage'\'') as scout_usage
union all
select 
  '\''Table permissions:'\'',
  has_table_privilege('\''etl_svc'\'', '\''scout.bronze_edge_raw'\'', '\''insert'\'')
union all
select 
  '\''Function permissions:'\'',
  has_function_privilege('\''etl_svc'\'', '\''scout.transform_edge_bronze_to_silver()'\'', '\''execute'\'');
SQL
' pw="$BRUNO_SECRET_db_password"

echo "✅ etl_svc role configured with minimal privileges"
'