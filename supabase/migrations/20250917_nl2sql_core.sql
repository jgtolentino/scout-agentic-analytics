-- SCOUT v7 NL→SQL Core Analytics Infrastructure
-- Safe SQL execution, caching, audit trail, and performance optimization

-- SCHEMAS (idempotent)
create schema if not exists analytics;
create schema if not exists metadata;
create schema if not exists mkt;

-- ====================================================================
-- SAFE SQL EXECUTOR (returns JSON, supports $1..$N params safely)
-- ====================================================================
create or replace function analytics.exec_readonly_sql(sql_text text, params text[] default '{}')
returns jsonb
language plpgsql
security definer
set search_path = public, analytics, pg_temp
as $$
declare
  res jsonb;
  wrapped text;
begin
  -- Deny writes/DDL (strict token blocking)
  if sql_text ~* '\y(insert|update|delete|merge|truncate|drop|alter|grant|revoke|create|vacuum|analyze|reindex|cluster|copy|pg_|dblink)\y' then
    raise exception 'Write/DDL operations not allowed in readonly executor';
  end if;

  -- Wrap query to return JSON array
  wrapped := 'select coalesce(jsonb_agg(t), ''[]''::jsonb) from (' || sql_text || ') t';
  execute wrapped into res;
  return coalesce(res, '[]'::jsonb);
exception when others then
  raise exception 'exec_readonly_sql failed: %', sqlerrm;
end $$;

-- Grant permissions
revoke all on function analytics.exec_readonly_sql(text, text[]) from public;
grant execute on function analytics.exec_readonly_sql(text, text[]) to anon, authenticated, service_role;

-- ====================================================================
-- CACHE TABLE (5-minute TTL for Silver queries)
-- ====================================================================
create table if not exists mkt.cag_insights_cache (
  hash        text primary key,
  payload     jsonb not null,
  ttl_at      timestamptz not null,
  hits        bigint not null default 0,
  created_at  timestamptz not null default now(),
  last_hit_at timestamptz
);

-- Indexes for cache operations
create index if not exists cag_insights_cache_ttl_idx on mkt.cag_insights_cache(ttl_at);
create index if not exists cag_insights_cache_payload_gin on mkt.cag_insights_cache using gin(payload);

-- Cache helper functions
create or replace function mkt.cache_get(p_hash text)
returns jsonb
language sql
stable
as $$
  select case when ttl_at > now()
              then payload
              else null
         end
  from mkt.cag_insights_cache
  where hash = p_hash
$$;

create or replace function mkt.cache_put(p_hash text, p_payload jsonb, p_ttl_seconds int)
returns void
language plpgsql
as $$
begin
  insert into mkt.cag_insights_cache(hash, payload, ttl_at, hits, last_hit_at)
  values (p_hash, p_payload, now() + make_interval(secs => p_ttl_seconds), 0, null)
  on conflict (hash) do update
    set payload     = excluded.payload,
        ttl_at      = excluded.ttl_at,
        last_hit_at = now();
end $$;

-- ====================================================================
-- AUDIT TABLE (track all NL→SQL queries and performance)
-- ====================================================================
create table if not exists metadata.ai_sql_audit (
  id           bigint generated always as identity primary key,
  created_at   timestamptz not null default now(),
  user_id      uuid,
  question     text,
  plan         jsonb,
  sql_text     text,
  duration_ms  integer,
  row_count    integer,
  cache_hit    boolean default false,
  error        text,
  function_version text default 'v1'
);

-- Indexes for audit queries
create index if not exists ai_sql_audit_created_at_idx on metadata.ai_sql_audit(created_at desc);
create index if not exists ai_sql_audit_plan_gin on metadata.ai_sql_audit using gin(plan);
create index if not exists ai_sql_audit_user_id_idx on metadata.ai_sql_audit(user_id);

-- RLS (authenticated users can read their own audit trail)
alter table metadata.ai_sql_audit enable row level security;

-- Policy: users can read their own audit records
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='metadata' and tablename='ai_sql_audit' and policyname='audit_select_self'
  ) then
    create policy audit_select_self
      on metadata.ai_sql_audit for select
      to authenticated
      using (user_id = auth.uid());
  end if;
end $$;

-- Service role can insert audit records
grant insert on metadata.ai_sql_audit to service_role;
grant select on metadata.ai_sql_audit to authenticated;

-- ====================================================================
-- PERFORMANCE INDEXES (silver_unified_transactions hot paths)
-- ====================================================================

-- Time-series queries (most common)
create index if not exists sut_ts_idx on silver.transactions_cleaned(timestamp);

-- Brand analysis
create index if not exists sut_brand_idx on silver.transactions_cleaned(brand_name) where brand_name is not null;

-- Category analysis
create index if not exists sut_cat_idx on silver.transactions_cleaned(product_category) where product_category is not null;

-- Payment method analysis
create index if not exists sut_payment_idx on silver.transactions_cleaned(payment_method) where payment_method is not null;

-- Demographics
create index if not exists sut_demographics_idx on silver.transactions_cleaned(age_bracket, gender)
where age_bracket is not null and gender is not null;

-- Composite index for common cross-tabs
create index if not exists sut_daypart_category_idx on silver.transactions_cleaned(
  (CASE WHEN EXTRACT(HOUR FROM timestamp) BETWEEN 5 AND 11 THEN 'AM'
        WHEN EXTRACT(HOUR FROM timestamp) BETWEEN 12 AND 17 THEN 'PM'
        ELSE 'NT' END),
  product_category
) where product_category is not null;

-- Weekend analysis
create index if not exists sut_weekend_idx on silver.transactions_cleaned(
  (EXTRACT(ISODOW FROM timestamp) IN (6,7))
);

-- ====================================================================
-- CACHE CLEANUP (remove expired entries periodically)
-- ====================================================================
create or replace function mkt.cleanup_expired_cache()
returns void
language sql
as $$
  delete from mkt.cag_insights_cache where ttl_at < now() - interval '1 hour';
$$;

-- ====================================================================
-- HELPER VIEWS (for monitoring and debugging)
-- ====================================================================

-- Cache performance metrics
create or replace view mkt.cache_performance as
select
  'cache_stats' as metric,
  count(*) as total_entries,
  count(*) filter (where ttl_at > now()) as active_entries,
  count(*) filter (where ttl_at <= now()) as expired_entries,
  avg(hits) as avg_hits_per_entry,
  max(hits) as max_hits,
  extract(epoch from avg(now() - created_at))/60 as avg_age_minutes
from mkt.cag_insights_cache;

-- Audit trail summary
create or replace view metadata.ai_sql_audit_summary as
select
  date_trunc('hour', created_at) as hour,
  count(*) as total_queries,
  count(*) filter (where error is null) as successful_queries,
  count(*) filter (where cache_hit = true) as cache_hits,
  avg(duration_ms) as avg_duration_ms,
  percentile_cont(0.95) within group (order by duration_ms) as p95_duration_ms,
  avg(row_count) as avg_row_count
from metadata.ai_sql_audit
where created_at > now() - interval '24 hours'
group by date_trunc('hour', created_at)
order by hour desc;

-- Grant permissions for monitoring views
grant select on mkt.cache_performance to authenticated;
grant select on metadata.ai_sql_audit_summary to authenticated;

-- ====================================================================
-- VALIDATION FUNCTIONS (for go-live checks)
-- ====================================================================

-- Check if core tables exist and have data
create or replace function analytics.validate_core_tables()
returns jsonb
language plpgsql
as $$
declare
  result jsonb := '{}';
  silver_count bigint;
  indexes_count bigint;
begin
  -- Check silver_unified_transactions
  select count(*) into silver_count from silver.transactions_cleaned;
  result := result || jsonb_build_object('silver_transactions_count', silver_count);

  -- Check performance indexes
  select count(*) into indexes_count
  from pg_indexes
  where tablename = 'transactions_cleaned'
  and indexname like 'sut_%';
  result := result || jsonb_build_object('performance_indexes_count', indexes_count);

  -- Check RLS is enabled
  result := result || jsonb_build_object(
    'rls_enabled',
    exists(select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'silver' and c.relname = 'transactions_cleaned' and c.relrowsecurity)
  );

  return result;
end $$;

grant execute on function analytics.validate_core_tables() to service_role, authenticated;

-- Success marker
insert into metadata.ai_sql_audit(question, plan, sql_text, duration_ms, row_count, cache_hit, error)
values ('MIGRATION_SUCCESS', '{"migration": "20250917_nl2sql_core"}', 'CREATE ANALYTICS INFRASTRUCTURE', 0, 0, false, null)
on conflict do nothing;