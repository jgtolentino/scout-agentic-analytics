# Scout Edge Transaction Fact Table Deployment

## Overview

This deployment creates a production-ready fact table for Scout Edge v2.0.0 transactions with NCR location enrichment and substitution event analysis. The system processes **13,149 transactions** from 7 Scout stores with comprehensive substitution detection.

## Prerequisites

- PostgreSQL 13+ or Supabase instance
- Python 3.8+ with psycopg2-binary
- Access to Scout Edge transaction data (`transactions_flat_no_ts.csv`)
- Database connection with CREATE/INSERT privileges

## Architecture

```
Scout Edge Raw Data (CSV)
         ↓
    ETL Pipeline (Python)
         ↓
┌─────────────────────────────┐
│   fact_transactions_location │ ← Main fact table
├─────────────────────────────┤
│   fact_transaction_items     │ ← Item details (normalized)
├─────────────────────────────┤
│   dim_ncr_stores            │ ← NCR location dimensions
└─────────────────────────────┘
         ↓
   Analytics Views
   (substitution_analytics.sql)
```

## Step-by-Step Deployment

### 1. Database Schema Setup

```bash
# Connect to your PostgreSQL/Supabase instance
psql "postgresql://user:password@host:port/database"

# Or for Supabase:
psql "postgresql://postgres:[YOUR-PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres"
```

Execute the schema creation:
```sql
\i /path/to/scout-v7/sql/fact_transactions_location.sql
```

**Expected Results:**
- ✅ 3 tables created: `fact_transactions_location`, `fact_transaction_items`, `dim_ncr_stores`
- ✅ 7 store mappings inserted (102, 103, 104, 108, 109, 110, 112)
- ✅ 8 indexes created for performance
- ✅ 2 utility functions: `detect_substitution_event()`, `generate_canonical_tx_id()`

### 2. Data Loading (ETL Pipeline)

Install Python dependencies:
```bash
pip install psycopg2-binary
```

Execute the ETL pipeline:
```bash
cd /path/to/scout-v7/etl

python load_scout_transactions.py \
  "/Users/tbwa/Downloads/transactions_flat_no_ts.csv" \
  "postgresql://user:password@host:port/database"
```

**Expected Output:**
```
INFO - Database connection established
INFO - Loading transactions from /Users/tbwa/Downloads/transactions_flat_no_ts.csv
INFO - Processed 100 transactions, 18 substitutions detected
INFO - Processed 200 transactions, 36 substitutions detected
...
INFO - ==================================================
INFO - ETL SUMMARY
INFO - ==================================================
INFO - Transactions processed: 13149
INFO - Substitutions detected: ~2380
INFO - Substitution rate: ~18.1%
INFO - Errors encountered: 0
INFO - ==================================================
```

### 3. Analytics Views Creation

Create the analytics views for substitution analysis:
```sql
\i /path/to/scout-v7/sql/substitution_analytics.sql
```

**Expected Results:**
- ✅ 9 analytics views created
- ✅ 1 materialized view: `mv_daily_substitution_summary`
- ✅ Performance indexes applied

### 4. Data Quality Validation

Run comprehensive validation:
```sql
\i /path/to/scout-v7/sql/validation_queries.sql
```

**Expected Validation Results:**
```sql
-- Check the overall quality score
SELECT * FROM validate_scout_data_quality();

-- Should return:
-- ✅ Completeness: Record Count PASS (13,149 records)
-- ✅ Integrity: Substitution Rate PASS (~18% substitution rate)
-- ✅ Privacy: Compliance PASS (no audio stored, no facial recognition)
```

### 5. Performance Optimization

Update table statistics and refresh materialized views:
```sql
-- Update statistics for optimal query planning
ANALYZE fact_transactions_location;
ANALYZE fact_transaction_items;
ANALYZE dim_ncr_stores;

-- Refresh materialized view
REFRESH MATERIALIZED VIEW mv_daily_substitution_summary;
```

## Verification Steps

### Core Data Integrity

```sql
-- 1. Verify record count
SELECT COUNT(*) FROM fact_transactions_location;
-- Expected: 13149

-- 2. Check store coverage
SELECT store_id, municipality_name, COUNT(*) as transactions
FROM fact_transactions_location
GROUP BY store_id, municipality_name
ORDER BY store_id;
-- Expected: 7 stores (102, 103, 104, 108, 109, 110, 112)

-- 3. Substitution detection stats
SELECT
    COUNT(*) as total_transactions,
    COUNT(*) FILTER (WHERE substitution_detected = TRUE) as substitutions,
    ROUND((COUNT(*) FILTER (WHERE substitution_detected = TRUE)::DECIMAL / COUNT(*)) * 100, 1) as substitution_rate_pct
FROM fact_transactions_location;
-- Expected: ~18% substitution rate (2,300-2,400 substitutions)
```

### Privacy Compliance

```sql
-- Verify privacy settings
SELECT
    COUNT(*) FILTER (WHERE audio_stored = FALSE) as no_audio_stored,
    COUNT(*) FILTER (WHERE facial_recognition = FALSE) as no_facial_recognition,
    COUNT(*) FILTER (WHERE anonymization_level = 'high') as high_anonymization
FROM fact_transactions_location;
-- Expected: All counts should equal 13,149 (100% compliance)
```

### Location Enrichment

```sql
-- Check NCR location coverage
SELECT
    region,
    province_name,
    COUNT(DISTINCT municipality_name) as unique_municipalities,
    COUNT(*) as total_transactions
FROM fact_transactions_location
GROUP BY region, province_name;
-- Expected: region='NCR', province_name='Metro Manila', 7 unique municipalities
```

## Analytics Query Examples

### Substitution Rate by Municipality
```sql
SELECT * FROM v_substitution_by_location;
```

### Brand Switching Patterns
```sql
SELECT * FROM v_brand_switching_patterns
WHERE substitution_events >= 10
ORDER BY substitution_events DESC;
```

### Daily Trends
```sql
SELECT * FROM v_daily_substitution_trends
WHERE transaction_date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY transaction_date DESC;
```

### Executive Dashboard
```sql
SELECT * FROM v_substitution_dashboard;
```

## Monitoring & Maintenance

### Daily Health Check
```sql
-- Quick health check function
SELECT * FROM validate_scout_data_quality();
```

### Weekly Materialized View Refresh
```sql
-- Set up automated refresh (adjust schedule as needed)
REFRESH MATERIALIZED VIEW mv_daily_substitution_summary;
```

### Monthly Data Quality Report
```sql
-- Run comprehensive validation
\i /path/to/scout-v7/sql/validation_queries.sql
```

## Troubleshooting

### Common Issues

**1. Connection Failed**
```bash
# Check connection string format
psql "postgresql://user:password@host:port/database" -c "SELECT version();"
```

**2. ETL Script Errors**
```bash
# Check CSV file exists and is readable
head -n 5 /Users/tbwa/Downloads/transactions_flat_no_ts.csv

# Verify Python dependencies
pip list | grep psycopg2
```

**3. Substitution Detection Issues**
```sql
-- Check transcript coverage
SELECT
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE audio_transcript IS NOT NULL) as with_transcript,
    ROUND((COUNT(*) FILTER (WHERE audio_transcript IS NOT NULL)::DECIMAL / COUNT(*)) * 100, 1) as coverage_pct
FROM fact_transactions_location;
-- Expected: >95% transcript coverage
```

### Performance Issues

**Slow Query Performance:**
```sql
-- Check index usage
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM v_substitution_by_location;

-- Reindex if needed
REINDEX TABLE fact_transactions_location;
```

**Large Result Sets:**
```sql
-- Use date filters for better performance
SELECT * FROM v_daily_substitution_trends
WHERE transaction_date >= CURRENT_DATE - INTERVAL '30 days';
```

## Security Considerations

1. **Data Privacy**: All audio recordings are flagged as `audio_stored = FALSE`
2. **Facial Recognition**: Disabled (`facial_recognition = FALSE`)
3. **Anonymization**: High-level anonymization applied
4. **Access Control**: Limit database access to authorized personnel only
5. **Data Retention**: 30-day retention policy enforced

## Support

For technical issues or questions:

1. **Database Issues**: Check PostgreSQL logs and connection parameters
2. **ETL Issues**: Review Python script output and CSV file format
3. **Analytics Issues**: Verify view dependencies and data freshness
4. **Performance Issues**: Check index usage and query execution plans

## File Structure

```
scout-v7/
├── sql/
│   ├── fact_transactions_location.sql    # Schema and functions
│   ├── substitution_analytics.sql        # Analytics views
│   └── validation_queries.sql           # Data quality checks
├── etl/
│   └── load_scout_transactions.py       # ETL pipeline
└── docs/
    └── DEPLOYMENT_INSTRUCTIONS.md       # This file
```

## Success Criteria

✅ **Data Completeness**: 13,149 transactions loaded
✅ **Store Coverage**: All 7 Scout stores present
✅ **Substitution Detection**: ~18% substitution rate detected
✅ **Privacy Compliance**: 100% audio/facial privacy compliance
✅ **Location Enrichment**: NCR municipality mapping complete
✅ **Performance**: Sub-second query response times
✅ **Data Quality**: >95% validation score achieved

---

**Deployment Complete** 🎉

Your Scout Edge fact table is ready for production analytics operations with comprehensive substitution tracking and NCR location analysis.