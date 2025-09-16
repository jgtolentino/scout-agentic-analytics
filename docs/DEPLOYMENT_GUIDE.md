# Market Intelligence System Deployment Guide

## Prerequisites

### System Requirements
- PostgreSQL 14+ with Supabase extensions
- Python 3.9+ with pip
- Node.js 18+ with Deno runtime
- Supabase CLI v1.100+
- Git for version control

### Environment Setup
```bash
# Install Supabase CLI
npm install -g supabase

# Verify installation  
supabase --version

# Install Python dependencies
pip install psycopg2-binary pandas python-dotenv fuzzywuzzy python-levenshtein

# Verify Deno runtime
deno --version
```

## Database Setup

### 1. Initialize Supabase Project
```bash
# Navigate to project directory
cd /Users/tbwa/scout-v7/

# Initialize if not already done
supabase init

# Link to existing project (if applicable)
supabase link --project-ref your-project-ref

# Start local development
supabase start
```

### 2. Apply Database Migrations
```bash
# Apply core market intelligence schema
supabase db reset

# Verify migration status
supabase db status

# Check for drift detection
supabase db diff
```

### 3. Validate Database Schema
```sql
-- Connect to database and verify tables
\c postgres
\dt metadata.*
\dv analytics.*

-- Check function definitions
\df metadata.get_brand_intelligence
\df metadata.match_brands_with_intelligence
```

## ETL Pipeline Deployment

### 1. Configure Environment Variables
```bash
# Create environment file
cat > .env << EOF
SUPABASE_URL=your-supabase-url
SUPABASE_SERVICE_KEY=your-service-role-key
PGDATABASE_URI=your-postgres-connection-string
EOF

# Secure the file
chmod 600 .env
```

### 2. Execute ETL Scripts
```bash
# Load market intelligence data
cd etl/
python3 market_intelligence_loader.py

# Verify data loading
python3 -c "
import psycopg2
conn = psycopg2.connect('your-connection-string')
cur = conn.cursor()
cur.execute('SELECT COUNT(*) FROM metadata.market_intelligence')
print(f'Market intelligence records: {cur.fetchone()[0]}')
"

# Load pricing data
python3 price_tracker.py

# Verify pricing data
python3 -c "
import psycopg2
conn = psycopg2.connect('your-connection-string')
cur = conn.cursor() 
cur.execute('SELECT COUNT(*) FROM metadata.retail_pricing')
print(f'Pricing records: {cur.fetchone()[0]}')
"

# Enhance brand detection
python3 brand_enrichment.py

# Verify brand intelligence
python3 -c "
import psycopg2
conn = psycopg2.connect('your-connection-string')
cur = conn.cursor()
cur.execute('SELECT COUNT(*) FROM metadata.brand_detection_intelligence')
print(f'Brand intelligence records: {cur.fetchone()[0]}')
"
```

### 3. Data Validation
```bash
# Run comprehensive data validation
python3 -c "
import psycopg2
from decimal import Decimal

conn = psycopg2.connect('your-connection-string')
cur = conn.cursor()

# Validate market intelligence
cur.execute('SELECT category, market_size_php FROM metadata.market_intelligence')
for category, size in cur.fetchall():
    if size and size > 0:
        print(f'✅ {category}: ₱{size:,.0f}M')
    else:
        print(f'❌ {category}: Invalid market size')

# Validate pricing data
cur.execute('SELECT sku, srp_php FROM metadata.retail_pricing LIMIT 5')
for sku, price in cur.fetchall():
    if price and price > Decimal('0'):
        print(f'✅ {sku}: ₱{price}')
    else:
        print(f'❌ {sku}: Invalid price')

conn.close()
"
```

## Edge Functions Deployment

### 1. Deploy API Functions
```bash
# Deploy brand intelligence API
supabase functions deploy brand-intelligence

# Deploy market benchmarks API  
supabase functions deploy market-benchmarks

# Deploy price analytics API
supabase functions deploy price-analytics

# Verify deployments
supabase functions list
```

### 2. Test API Endpoints
```bash
# Test brand intelligence
curl -X GET "https://your-project.supabase.co/functions/v1/brand-intelligence?brand=Safeguard" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json"

# Test market benchmarks
curl -X GET "https://your-project.supabase.co/functions/v1/market-benchmarks/category/bar_soap" \
  -H "Authorization: Bearer YOUR_ANON_KEY"

# Test price analytics
curl -X GET "https://your-project.supabase.co/functions/v1/price-analytics/product/safeguard_pure_white_55g" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

### 3. API Performance Testing
```bash
# Install performance testing tools
npm install -g artillery

# Create performance test config
cat > artillery-config.yml << EOF
config:
  target: 'https://your-project.supabase.co'
  phases:
    - duration: 60
      arrivalRate: 10
  defaults:
    headers:
      Authorization: 'Bearer YOUR_ANON_KEY'
      Content-Type: 'application/json'
scenarios:
  - name: "Brand Intelligence API"
    requests:
      - get:
          url: "/functions/v1/brand-intelligence?brand=Safeguard"
  - name: "Market Benchmarks API" 
    requests:
      - get:
          url: "/functions/v1/market-benchmarks/category/bar_soap"
EOF

# Run performance tests
artillery run artillery-config.yml
```

## Production Deployment

### 1. Environment Configuration
```bash
# Production environment variables
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_SERVICE_KEY="your-service-role-key"
export ENVIRONMENT="production"

# Database connection pooling
export PGPOOL_MAX_CONNECTIONS=20
export PGPOOL_IDLE_TIMEOUT=30000
```

### 2. Database Performance Tuning
```sql
-- Apply production indexes
CREATE INDEX CONCURRENTLY idx_brand_metrics_category ON metadata.brand_metrics(category);
CREATE INDEX CONCURRENTLY idx_retail_pricing_brand ON metadata.retail_pricing(brand_name);
CREATE INDEX CONCURRENTLY idx_market_intelligence_category ON metadata.market_intelligence(category);

-- Update table statistics
ANALYZE metadata.market_intelligence;
ANALYZE metadata.brand_metrics;
ANALYZE metadata.retail_pricing;

-- Enable query performance monitoring
ALTER SYSTEM SET log_min_duration_statement = 1000;
SELECT pg_reload_conf();
```

### 3. Security Configuration
```sql
-- Create read-only role for analytics
CREATE ROLE analytics_reader;
GRANT USAGE ON SCHEMA metadata TO analytics_reader;
GRANT USAGE ON SCHEMA analytics TO analytics_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA metadata TO analytics_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO analytics_reader;

-- Create API service role
CREATE ROLE market_intelligence_api;
GRANT analytics_reader TO market_intelligence_api;
GRANT EXECUTE ON FUNCTION metadata.get_brand_intelligence TO market_intelligence_api;
GRANT EXECUTE ON FUNCTION metadata.match_brands_with_intelligence TO market_intelligence_api;
```

### 4. Backup Configuration
```bash
# Configure automated backups
cat > backup-script.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/backups/market-intelligence"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup market intelligence schema
pg_dump -h your-host -U postgres -n metadata -n analytics \
  --verbose --clean --create \
  -f "$BACKUP_DIR/market_intelligence_$DATE.sql"

# Compress backup
gzip "$BACKUP_DIR/market_intelligence_$DATE.sql"

# Cleanup old backups (keep 30 days)
find $BACKUP_DIR -name "*.gz" -mtime +30 -delete

echo "Backup completed: market_intelligence_$DATE.sql.gz"
EOF

chmod +x backup-script.sh

# Schedule via cron
(crontab -l ; echo "0 2 * * * /path/to/backup-script.sh") | crontab -
```

## Monitoring & Observability

### 1. Application Monitoring
```sql
-- Create monitoring views
CREATE OR REPLACE VIEW monitoring.system_health AS
SELECT 
  'market_intelligence' as component,
  COUNT(*) as record_count,
  MAX(updated_at) as last_update,
  CASE 
    WHEN MAX(updated_at) > NOW() - INTERVAL '1 day' THEN 'healthy'
    WHEN MAX(updated_at) > NOW() - INTERVAL '7 days' THEN 'stale'
    ELSE 'critical'
  END as status
FROM metadata.market_intelligence
UNION ALL
SELECT 
  'brand_metrics' as component,
  COUNT(*) as record_count,
  MAX(updated_at) as last_update,
  CASE 
    WHEN MAX(updated_at) > NOW() - INTERVAL '1 day' THEN 'healthy'
    WHEN MAX(updated_at) > NOW() - INTERVAL '7 days' THEN 'stale' 
    ELSE 'critical'
  END as status
FROM metadata.brand_metrics;
```

### 2. Performance Metrics
```bash
# Create performance monitoring script
cat > monitor-performance.py << 'EOF'
import psycopg2
import time
import json
from datetime import datetime

def check_api_performance():
    """Monitor API response times and database performance"""
    
    conn = psycopg2.connect("your-connection-string")
    cur = conn.cursor()
    
    # Test query performance
    start_time = time.time()
    cur.execute("SELECT * FROM analytics.brand_performance_dashboard LIMIT 10")
    query_time = (time.time() - start_time) * 1000
    
    # Check data freshness
    cur.execute("SELECT MAX(updated_at) FROM metadata.market_intelligence")
    last_update = cur.fetchone()[0]
    
    metrics = {
        "timestamp": datetime.now().isoformat(),
        "query_time_ms": round(query_time, 2),
        "last_data_update": last_update.isoformat() if last_update else None,
        "status": "healthy" if query_time < 1000 else "slow"
    }
    
    print(json.dumps(metrics, indent=2))
    
    conn.close()

if __name__ == "__main__":
    check_api_performance()
EOF

python3 monitor-performance.py
```

### 3. Alert Configuration
```bash
# Configure monitoring alerts
cat > alert-config.json << EOF
{
  "alerts": [
    {
      "name": "Data Freshness Alert",
      "condition": "last_update > 24h",
      "severity": "warning",
      "notification": "email"
    },
    {
      "name": "API Response Time Alert", 
      "condition": "response_time > 2000ms",
      "severity": "critical",
      "notification": "slack"
    },
    {
      "name": "ETL Job Failure Alert",
      "condition": "etl_status = failed", 
      "severity": "critical",
      "notification": "email,slack"
    }
  ]
}
EOF
```

## Maintenance Procedures

### 1. Data Refresh Schedule
```bash
# Create maintenance script
cat > maintenance.sh << 'EOF'
#!/bin/bash

echo "Starting market intelligence maintenance..."

# Refresh market data (monthly)
if [[ $(date +%d) == "01" ]]; then
    echo "Refreshing market intelligence data..."
    python3 etl/market_intelligence_loader.py --refresh
fi

# Update pricing data (weekly)
if [[ $(date +%w) == "1" ]]; then
    echo "Updating pricing data..."
    python3 etl/price_tracker.py --update
fi

# Refresh analytics views (daily)
psql -c "REFRESH MATERIALIZED VIEW CONCURRENTLY analytics.brand_performance_dashboard;"
psql -c "REFRESH MATERIALIZED VIEW CONCURRENTLY analytics.category_deep_dive;"

# Update statistics
psql -c "ANALYZE metadata.market_intelligence;"
psql -c "ANALYZE metadata.brand_metrics;"

echo "Maintenance completed successfully"
EOF

chmod +x maintenance.sh

# Schedule maintenance
(crontab -l ; echo "0 3 * * * /path/to/maintenance.sh >> /var/log/maintenance.log 2>&1") | crontab -
```

### 2. Health Checks
```bash
# System health check
cat > health-check.sh << 'EOF'
#!/bin/bash

echo "=== Market Intelligence System Health Check ==="

# Database connectivity
if psql -c "SELECT 1" > /dev/null 2>&1; then
    echo "✅ Database connection: OK"
else
    echo "❌ Database connection: FAILED"
    exit 1
fi

# Data integrity
RECORD_COUNT=$(psql -t -c "SELECT COUNT(*) FROM metadata.market_intelligence")
if [ "$RECORD_COUNT" -gt 0 ]; then
    echo "✅ Market intelligence data: $RECORD_COUNT records"
else
    echo "❌ Market intelligence data: No records found"
fi

# API endpoints
if curl -f -s "https://your-project.supabase.co/functions/v1/brand-intelligence" > /dev/null; then
    echo "✅ Brand Intelligence API: OK" 
else
    echo "❌ Brand Intelligence API: FAILED"
fi

echo "=== Health Check Complete ==="
EOF

chmod +x health-check.sh
./health-check.sh
```

## Troubleshooting

### Common Issues

**ETL Script Failures**:
```bash
# Check Python dependencies
pip install --upgrade psycopg2-binary pandas

# Verify database connection
python3 -c "import psycopg2; conn = psycopg2.connect('your-string'); print('Connection OK')"

# Check log files
tail -f /var/log/market-intelligence-etl.log
```

**API Response Issues**:
```bash
# Check Supabase function logs
supabase functions logs brand-intelligence

# Test local function
supabase functions serve --no-verify-jwt
curl http://localhost:54321/functions/v1/brand-intelligence
```

**Performance Issues**:
```sql
-- Check slow queries
SELECT query, calls, total_time, mean_time 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;

-- Check index usage
SELECT schemaname, tablename, attname, n_distinct, correlation 
FROM pg_stats 
WHERE schemaname IN ('metadata', 'analytics');
```

### Recovery Procedures

**Data Corruption Recovery**:
1. Stop ETL processes
2. Restore from latest backup
3. Verify data integrity
4. Resume ETL operations

**API Service Recovery**:
1. Check function deployment status
2. Redeploy affected functions
3. Verify database connectivity
4. Test endpoint functionality

This deployment guide provides comprehensive instructions for setting up, deploying, and maintaining the market intelligence system in production environments.