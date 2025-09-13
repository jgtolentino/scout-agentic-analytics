# 🚀 Scout Agentic Analytics - Operational Runbook

## Overview
This runbook covers deployment, operation, and maintenance of the Scout v5.2 Agentic Analytics system.

## 📋 Table of Contents
1. [System Architecture](#system-architecture)
2. [Initial Deployment](#initial-deployment)
3. [Operational Procedures](#operational-procedures)
4. [Monitoring & Alerts](#monitoring--alerts)
5. [Troubleshooting](#troubleshooting)
6. [Security & Compliance](#security--compliance)

## System Architecture

### Components
- **Scout Schema**: Core analytics data (bronze → silver → gold → platinum)
- **Deep Research**: Isko SKU scraping and enrichment
- **Master Data**: Brands dictionary and products catalog
- **Agent Infrastructure**: Monitors, contracts, ledger, feed

### Data Flow
```
[Raw Data] → [Bronze] → [Silver] → [Gold] → [Platinum]
                                       ↓
                                   [Monitors]
                                       ↓
                                 [Agent Feed]
                                       ↓
                                  [Actions]
```

## Initial Deployment

### 1. Database Setup
```bash
# Apply migrations in order
supabase db push --file supabase/migrations/20250823_agentic_analytics.sql
supabase db push --file supabase/migrations/20250823_isko_ops.sql
supabase db push --file supabase/migrations/20250823_brands_products.sql

# Verify deployment
psql "$DATABASE_URL" -c "select count(*) from scout.platinum_monitors;"
psql "$DATABASE_URL" -c "select count(*) from masterdata.brands;"
```

### 2. Edge Function Deployment
```bash
# Deploy agentic-cron function
supabase functions deploy agentic-cron --no-verify-jwt

# Schedule every 15 minutes
supabase functions deploy agentic-cron --no-verify-jwt --schedule "*/15 * * * *"

# Set environment variables
supabase secrets set ISKO_MIN_QUEUED=8 ISKO_BRANDS="Oishi,Alaska,Del Monte,JTI,Peerless"
```

### 3. Worker Deployment
```bash
# Deploy Isko worker (choose one method)

# Option A: Deno Deploy
deno deploy --project=isko-worker workers/isko-worker/index.ts

# Option B: PM2 (local/VPS)
pm2 start --name isko-worker "deno run -A workers/isko-worker/index.ts"

# Option C: Docker
docker build -t isko-worker workers/isko-worker/
docker run -d --name isko-worker --env-file .env isko-worker
```

### 4. Initial Data Seeding
```bash
# Seed monitors (already in migration)
psql "$DATABASE_URL" -c "select count(*) from scout.platinum_monitors;"

# Test monitor execution
psql "$DATABASE_URL" -c "select scout.run_monitors();"

# Check agent feed
psql "$DATABASE_URL" -c "select * from scout.agent_feed order by created_at desc limit 5;"
```

## Operational Procedures

### Daily Operations

#### 1. Morning Check (9 AM)
```bash
# Check system health
curl -X POST "$SUPABASE_URL/functions/v1/agentic-cron" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY"

# Review overnight alerts
psql "$DATABASE_URL" -c "
  select severity, source, title, created_at 
  from scout.agent_feed 
  where created_at > now() - interval '12 hours'
  and severity in ('warn', 'error')
  order by created_at desc;
"

# Check contract violations
psql "$DATABASE_URL" -c "
  select table_name, column_name, check_type, row_count 
  from scout.contract_violations 
  where detected_at > now() - interval '24 hours';
"
```

#### 2. Monitor Management
```bash
# List active monitors
psql "$DATABASE_URL" -c "
  select name, window_minutes, is_enabled, last_run_at 
  from scout.platinum_monitors 
  order by name;
"

# Disable problematic monitor
psql "$DATABASE_URL" -c "
  update scout.platinum_monitors 
  set is_enabled = false 
  where name = 'monitor_name';
"

# Add new monitor
psql "$DATABASE_URL" -c "
  insert into scout.platinum_monitors (name, sql, threshold, window_minutes)
  values ('new_monitor', 'SELECT ...', 1.0, 60);
"
```

#### 3. Isko Queue Management
```bash
# Check queue status
psql "$DATABASE_URL" -c "
  select status, count(*) 
  from deep_research.sku_jobs 
  group by status;
"

# Manually enqueue jobs
psql "$DATABASE_URL" -c "
  select deep_research.rpc_enqueue_sku_job(
    '{\"brand\":\"Alaska\",\"region\":\"PH\"}'::jsonb, 
    100, 
    0
  );
"

# Review recent SKU discoveries
psql "$DATABASE_URL" -c "
  select brand, sku_name, price_min, price_max, created_at 
  from deep_research.sku_summary 
  order by created_at desc 
  limit 20;
"
```

### Weekly Operations

#### 1. Performance Review
```bash
# Monitor execution stats
psql "$DATABASE_URL" -c "
  select 
    date_trunc('day', occurred_at) as day,
    count(*) as events,
    count(distinct monitor_id) as monitors
  from scout.platinum_monitor_events
  where occurred_at > now() - interval '7 days'
  group by 1
  order by 1;
"

# Action ledger summary
psql "$DATABASE_URL" -c "
  select 
    agent,
    action_type,
    approval_status,
    status,
    count(*) as count
  from scout.platinum_agent_action_ledger
  where ts > now() - interval '7 days'
  group by 1,2,3,4
  order by count desc;
"
```

#### 2. Data Quality Check
```bash
# Run contract verifier
psql "$DATABASE_URL" -c "select scout.verify_gold_contracts();"

# Review violation trends
psql "$DATABASE_URL" -c "
  select 
    date_trunc('day', detected_at) as day,
    table_name,
    sum(row_count) as total_violations
  from scout.contract_violations
  where detected_at > now() - interval '30 days'
  group by 1,2
  order by 1 desc, 3 desc;
"
```

### Monthly Operations

#### 1. Brand Catalog Update
```bash
# Import new brands
psql "$DATABASE_URL" -c "
  insert into masterdata.brands (brand_name, company, category)
  values 
    ('New Brand 1', 'Company A', 'Category X'),
    ('New Brand 2', 'Company B', 'Category Y')
  on conflict (brand_name) do nothing;
"

# Update product catalog
psql "$DATABASE_URL" -c "
  insert into masterdata.products (brand_id, product_name, category, pack_size)
  select b.id, 'New Product', 'Category', 'Size'
  from masterdata.brands b 
  where brand_name = 'Brand Name';
"
```

#### 2. Monitor Tuning
```bash
# Review monitor performance
psql "$DATABASE_URL" -c "
  select 
    m.name,
    count(e.id) as event_count,
    avg(jsonb_array_length(e.payload)) as avg_payload_size
  from scout.platinum_monitors m
  left join scout.platinum_monitor_events e on e.monitor_id = m.id
  where e.occurred_at > now() - interval '30 days'
  group by m.name
  order by event_count desc;
"

# Adjust thresholds
psql "$DATABASE_URL" -c "
  update scout.platinum_monitors 
  set threshold = 2.0 
  where name = 'demand_spike_brand';
"
```

## Monitoring & Alerts

### Key Metrics to Track

#### System Health
- Edge function execution success rate
- Worker job completion rate
- Database connection pool usage
- API response times

#### Business Metrics
- Monitor event frequency
- Contract violation trends
- Action approval rates
- SKU discovery rate

### Alert Configuration

#### Critical Alerts (Immediate Response)
```yaml
- Monitor failures > 3 consecutive
- Contract violations > 100 in 1 hour
- Worker dead letter queue > 50 jobs
- Database connection exhaustion
```

#### Warning Alerts (Within 4 Hours)
```yaml
- Isko queue depth < minimum threshold
- Gold table query performance > 1s
- Agent action failures > 10%
- Feed backlog > 1000 unread
```

### Dashboard Queries

#### Real-time Operations Dashboard
```sql
-- Current system status
WITH system_status AS (
  SELECT 
    (SELECT COUNT(*) FROM scout.agent_feed WHERE status = 'new') as unread_feed,
    (SELECT COUNT(*) FROM deep_research.sku_jobs WHERE status = 'queued') as queued_jobs,
    (SELECT COUNT(*) FROM scout.platinum_monitor_events WHERE occurred_at > now() - interval '1 hour') as recent_events,
    (SELECT COUNT(*) FROM scout.contract_violations WHERE detected_at > now() - interval '1 hour') as recent_violations
)
SELECT * FROM system_status;
```

## Troubleshooting

### Common Issues

#### 1. Monitor Not Firing
```bash
# Check monitor definition
psql "$DATABASE_URL" -c "
  select * from scout.platinum_monitors where name = 'monitor_name';
"

# Test monitor SQL manually
psql "$DATABASE_URL" -c "[monitor SQL here]"

# Check for data availability
psql "$DATABASE_URL" -c "
  select count(*) from scout.gold_sales_15min 
  where ts > now() - interval '1 hour';
"
```

#### 2. Isko Worker Stuck
```bash
# Check stuck jobs
psql "$DATABASE_URL" -c "
  select * from deep_research.sku_jobs 
  where status = 'running' 
  and started_at < now() - interval '1 hour';
"

# Reset stuck jobs
psql "$DATABASE_URL" -c "
  update deep_research.sku_jobs 
  set status = 'queued', started_at = null 
  where status = 'running' 
  and started_at < now() - interval '1 hour';
"

# Check worker logs
pm2 logs isko-worker --lines 100
```

#### 3. Agent Feed Overflow
```bash
# Archive old feed items
psql "$DATABASE_URL" -c "
  update scout.agent_feed 
  set status = 'archived' 
  where created_at < now() - interval '30 days' 
  and status = 'read';
"

# Purge very old items
psql "$DATABASE_URL" -c "
  delete from scout.agent_feed 
  where created_at < now() - interval '90 days';
"
```

### Performance Optimization

#### 1. Slow Monitors
```sql
-- Add partial indexes for monitor queries
CREATE INDEX idx_gold_sales_15min_recent 
ON scout.gold_sales_15min (ts, brand) 
WHERE ts > now() - interval '7 days';

-- Materialized view for expensive aggregations
CREATE MATERIALIZED VIEW scout.mv_brand_weekly_avg AS
SELECT brand, 
       date_trunc('week', ts) as week,
       avg(units) as avg_units
FROM scout.gold_sales_15min
GROUP BY 1, 2;

-- Refresh schedule
CREATE OR REPLACE FUNCTION scout.refresh_materialized_views()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY scout.mv_brand_weekly_avg;
END;
$$ LANGUAGE plpgsql;
```

#### 2. RPC Optimization
```sql
-- Add result caching for expensive RPCs
CREATE TABLE scout.rpc_cache (
  function_name text,
  params_hash text,
  result jsonb,
  cached_at timestamptz,
  expires_at timestamptz,
  PRIMARY KEY (function_name, params_hash)
);

-- Cache cleanup
CREATE OR REPLACE FUNCTION scout.cleanup_rpc_cache()
RETURNS void AS $$
BEGIN
  DELETE FROM scout.rpc_cache WHERE expires_at < now();
END;
$$ LANGUAGE plpgsql;
```

## Security & Compliance

### Access Control

#### Role Definitions
```sql
-- Read-only analyst role
CREATE ROLE scout_analyst;
GRANT USAGE ON SCHEMA scout TO scout_analyst;
GRANT SELECT ON ALL TABLES IN SCHEMA scout TO scout_analyst;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA scout TO scout_analyst;

-- Agent service role
CREATE ROLE scout_agent;
GRANT USAGE ON SCHEMA scout, deep_research TO scout_agent;
GRANT SELECT, INSERT, UPDATE ON scout.platinum_agent_action_ledger TO scout_agent;
GRANT SELECT, INSERT ON scout.agent_feed TO scout_agent;
```

#### Audit Trail
```sql
-- Enable audit logging
CREATE TABLE scout.audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ts timestamptz DEFAULT now(),
  user_id uuid,
  action text,
  object_type text,
  object_id text,
  old_values jsonb,
  new_values jsonb
);

-- Audit trigger for sensitive tables
CREATE OR REPLACE FUNCTION scout.audit_trigger()
RETURNS trigger AS $$
BEGIN
  INSERT INTO scout.audit_log (user_id, action, object_type, object_id, old_values, new_values)
  VALUES (
    auth.uid(),
    TG_OP,
    TG_TABLE_NAME,
    COALESCE(NEW.id::text, OLD.id::text),
    to_jsonb(OLD),
    to_jsonb(NEW)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to action ledger
CREATE TRIGGER audit_agent_actions
AFTER INSERT OR UPDATE OR DELETE ON scout.platinum_agent_action_ledger
FOR EACH ROW EXECUTE FUNCTION scout.audit_trigger();
```

### Data Retention

#### Policy Implementation
```sql
-- 90-day retention for feed
CREATE OR REPLACE FUNCTION scout.enforce_retention_policy()
RETURNS void AS $$
BEGIN
  -- Archive to cold storage (optional)
  INSERT INTO scout_archive.agent_feed_archive
  SELECT * FROM scout.agent_feed 
  WHERE created_at < now() - interval '90 days';
  
  -- Delete from hot storage
  DELETE FROM scout.agent_feed 
  WHERE created_at < now() - interval '90 days';
  
  -- Compress monitor events
  DELETE FROM scout.platinum_monitor_events
  WHERE occurred_at < now() - interval '180 days';
END;
$$ LANGUAGE plpgsql;
```

### Compliance Checklist

- [ ] Monthly access review
- [ ] Quarterly security audit
- [ ] Data retention enforcement
- [ ] PII data masking verification
- [ ] Backup restoration test
- [ ] Disaster recovery drill

## Appendix

### Useful Queries

#### Top Performing Brands by Agent Actions
```sql
SELECT 
  b.brand_name,
  COUNT(DISTINCT al.id) as action_count,
  COUNT(DISTINCT al.id) FILTER (WHERE al.status = 'success') as successful_actions
FROM scout.platinum_agent_action_ledger al
JOIN masterdata.brands b ON al.action_payload->>'brand_id' = b.id::text
WHERE al.ts > now() - interval '30 days'
GROUP BY b.brand_name
ORDER BY action_count DESC;
```

#### Monitor Effectiveness Score
```sql
WITH monitor_stats AS (
  SELECT 
    m.name,
    COUNT(e.id) as events_generated,
    COUNT(DISTINCT al.id) as actions_triggered,
    AVG(EXTRACT(epoch FROM (al.ts - e.occurred_at))) as avg_response_time
  FROM scout.platinum_monitors m
  LEFT JOIN scout.platinum_monitor_events e ON e.monitor_id = m.id
  LEFT JOIN scout.platinum_agent_action_ledger al ON al.monitor = m.name
  WHERE e.occurred_at > now() - interval '30 days'
  GROUP BY m.name
)
SELECT 
  name,
  events_generated,
  actions_triggered,
  ROUND(actions_triggered::numeric / NULLIF(events_generated, 0) * 100, 2) as action_rate_pct,
  ROUND(avg_response_time / 60, 2) as avg_response_minutes
FROM monitor_stats
ORDER BY action_rate_pct DESC;
```

### Emergency Contacts

- **On-call Engineer**: Via PagerDuty
- **Database Admin**: #db-ops Slack channel
- **Security Team**: security@tbwa.com
- **Vendor Support**: support@supabase.com

---

**Last Updated**: August 23, 2025
**Version**: 1.0.0
**Next Review**: September 23, 2025