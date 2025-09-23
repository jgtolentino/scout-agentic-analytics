-- ==========================================
-- Performance Benchmarks: Azure SQL vs Supabase PostgreSQL
-- Scout Edge Fact Table Query Performance Analysis
-- ==========================================

-- ===========================================
-- BENCHMARK OVERVIEW
-- ===========================================

/*
Performance Comparison Framework for Scout Edge Data Analytics

Objective: Compare query performance between Azure SQL Server and Supabase PostgreSQL
Dataset: 13,149 transactions from 7 Scout stores in Metro Manila
Focus Areas: Aggregation, filtering, joins, substitution analysis

Test Environment Requirements:
- Azure SQL: Standard S2 (50 DTU) or equivalent
- Supabase: Pro tier or equivalent PostgreSQL 15+
- Network: Consistent network conditions for fair comparison
- Timing: Execute during similar load conditions

Expected Performance Baselines:
- Simple aggregations: <100ms
- Complex substitution queries: <500ms
- Multi-table joins: <200ms
- Geographic aggregations: <300ms
*/

-- ===========================================
-- BENCHMARK TEST SUITE
-- ===========================================

-- Test 1: Basic Store Performance
-- Measures fundamental aggregation speed across both platforms

/*
-- Azure SQL Version:
SET STATISTICS TIME ON;
SET STATISTICS IO ON;

SELECT
    store_id,
    municipality_name,
    COUNT(*) as transaction_count,
    AVG(CAST(total_amount AS DECIMAL(10,2))) as avg_transaction_value,
    SUM(CAST(total_amount AS DECIMAL(10,2))) as total_revenue,
    MIN(transaction_timestamp) as first_transaction,
    MAX(transaction_timestamp) as last_transaction
FROM fact_transactions_location
GROUP BY store_id, municipality_name
ORDER BY transaction_count DESC;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;

-- Expected Azure Performance: 50-100ms
-- Key Metrics: Logical reads, CPU time, elapsed time
*/

/*
-- PostgreSQL/Supabase Version:
\timing on
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT
    store_id,
    municipality_name,
    COUNT(*) as transaction_count,
    AVG(total_amount) as avg_transaction_value,
    SUM(total_amount) as total_revenue,
    MIN(transaction_timestamp) as first_transaction,
    MAX(transaction_timestamp) as last_transaction
FROM fact_transactions_location
GROUP BY store_id, municipality_name
ORDER BY transaction_count DESC;
\timing off

-- Expected PostgreSQL Performance: 40-80ms
-- Key Metrics: Planning time, execution time, buffer hits
*/

-- ===========================================
-- Test 2: Substitution Analysis Performance
-- Measures complex filtering and pattern matching speed
-- ===========================================

/*
-- Azure SQL Complex Substitution Query:
SET STATISTICS TIME ON;

SELECT
    municipality_name,
    substitution_reason,
    COUNT(*) as substitution_events,
    AVG(CAST(brand_switching_score AS DECIMAL(5,2))) as avg_switching_score,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY municipality_name) as pct_of_municipal_substitutions,
    STRING_AGG(CAST(store_id AS NVARCHAR(10)), ', ') as affected_stores
FROM fact_transactions_location
WHERE substitution_detected = 1
  AND audio_transcript IS NOT NULL
  AND LEN(audio_transcript) > 10
GROUP BY municipality_name, substitution_reason
HAVING COUNT(*) >= 5
ORDER BY municipality_name, substitution_events DESC;

SET STATISTICS TIME OFF;

-- Expected Azure Performance: 150-300ms
*/

/*
-- PostgreSQL Complex Substitution Query:
\timing on
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    municipality_name,
    substitution_reason,
    COUNT(*) as substitution_events,
    AVG(brand_switching_score) as avg_switching_score,
    ROUND((COUNT(*)::DECIMAL / SUM(COUNT(*)) OVER (PARTITION BY municipality_name)) * 100, 2) as pct_of_municipal_substitutions,
    STRING_AGG(store_id::TEXT, ', ' ORDER BY store_id) as affected_stores
FROM fact_transactions_location
WHERE substitution_detected = TRUE
  AND audio_transcript IS NOT NULL
  AND LENGTH(audio_transcript) > 10
GROUP BY municipality_name, substitution_reason
HAVING COUNT(*) >= 5
ORDER BY municipality_name, substitution_events DESC;
\timing off

-- Expected PostgreSQL Performance: 120-250ms
*/

-- ===========================================
-- Test 3: Time-Series Analysis Performance
-- Measures date-based aggregations and windowing functions
-- ===========================================

/*
-- Azure SQL Time-Series Query:
SET STATISTICS TIME ON;

WITH daily_metrics AS (
    SELECT
        CAST(transaction_timestamp AS DATE) as transaction_date,
        store_id,
        municipality_name,
        COUNT(*) as daily_transactions,
        SUM(CAST(total_amount AS DECIMAL(10,2))) as daily_revenue,
        COUNT(*) FILTER (WHERE substitution_detected = 1) as daily_substitutions
    FROM fact_transactions_location
    GROUP BY CAST(transaction_timestamp AS DATE), store_id, municipality_name
),
weekly_trends AS (
    SELECT
        transaction_date,
        store_id,
        municipality_name,
        daily_transactions,
        daily_revenue,
        daily_substitutions,
        AVG(daily_transactions) OVER (
            PARTITION BY store_id
            ORDER BY transaction_date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) as week_avg_transactions,
        daily_revenue - LAG(daily_revenue, 1) OVER (
            PARTITION BY store_id
            ORDER BY transaction_date
        ) as revenue_change
    FROM daily_metrics
)
SELECT
    store_id,
    municipality_name,
    COUNT(*) as active_days,
    AVG(daily_transactions) as avg_daily_transactions,
    AVG(daily_revenue) as avg_daily_revenue,
    AVG(daily_substitutions) as avg_daily_substitutions,
    MAX(week_avg_transactions) as peak_weekly_avg,
    SUM(CASE WHEN revenue_change > 0 THEN 1 ELSE 0 END) as revenue_growth_days
FROM weekly_trends
GROUP BY store_id, municipality_name
ORDER BY avg_daily_revenue DESC;

SET STATISTICS TIME OFF;

-- Expected Azure Performance: 200-400ms
*/

/*
-- PostgreSQL Time-Series Query:
\timing on
WITH daily_metrics AS (
    SELECT
        transaction_timestamp::DATE as transaction_date,
        store_id,
        municipality_name,
        COUNT(*) as daily_transactions,
        SUM(total_amount) as daily_revenue,
        COUNT(*) FILTER (WHERE substitution_detected = TRUE) as daily_substitutions
    FROM fact_transactions_location
    GROUP BY transaction_timestamp::DATE, store_id, municipality_name
),
weekly_trends AS (
    SELECT
        transaction_date,
        store_id,
        municipality_name,
        daily_transactions,
        daily_revenue,
        daily_substitutions,
        AVG(daily_transactions) OVER (
            PARTITION BY store_id
            ORDER BY transaction_date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) as week_avg_transactions,
        daily_revenue - LAG(daily_revenue, 1) OVER (
            PARTITION BY store_id
            ORDER BY transaction_date
        ) as revenue_change
    FROM daily_metrics
)
SELECT
    store_id,
    municipality_name,
    COUNT(*) as active_days,
    AVG(daily_transactions) as avg_daily_transactions,
    AVG(daily_revenue) as avg_daily_revenue,
    AVG(daily_substitutions) as avg_daily_substitutions,
    MAX(week_avg_transactions) as peak_weekly_avg,
    COUNT(*) FILTER (WHERE revenue_change > 0) as revenue_growth_days
FROM weekly_trends
GROUP BY store_id, municipality_name
ORDER BY avg_daily_revenue DESC;
\timing off

-- Expected PostgreSQL Performance: 180-350ms
*/

-- ===========================================
-- Test 4: Full-Text Search Performance
-- Measures audio transcript analysis speed
-- ===========================================

/*
-- Azure SQL Full-Text Search:
SET STATISTICS TIME ON;

SELECT
    store_id,
    municipality_name,
    COUNT(*) as total_matches,
    COUNT(*) FILTER (WHERE substitution_detected = 1) as substitution_matches,
    AVG(CAST(brand_switching_score AS DECIMAL(5,2))) as avg_switching_score,
    STRING_AGG(
        CASE
            WHEN LEN(audio_transcript) > 100
            THEN LEFT(audio_transcript, 97) + '...'
            ELSE audio_transcript
        END,
        ' | '
    ) as sample_transcripts
FROM fact_transactions_location
WHERE audio_transcript LIKE '%brand%'
   OR audio_transcript LIKE '%prefer%'
   OR audio_transcript LIKE '%instead%'
   OR audio_transcript LIKE '%different%'
   OR audio_transcript LIKE '%substitute%'
GROUP BY store_id, municipality_name
HAVING COUNT(*) >= 3
ORDER BY substitution_matches DESC, total_matches DESC;

SET STATISTICS TIME OFF;

-- Expected Azure Performance: 300-600ms (depends on indexing)
*/

/*
-- PostgreSQL Full-Text Search:
\timing on
SELECT
    store_id,
    municipality_name,
    COUNT(*) as total_matches,
    COUNT(*) FILTER (WHERE substitution_detected = TRUE) as substitution_matches,
    AVG(brand_switching_score) as avg_switching_score,
    STRING_AGG(
        CASE
            WHEN LENGTH(audio_transcript) > 100
            THEN SUBSTRING(audio_transcript, 1, 97) || '...'
            ELSE audio_transcript
        END,
        ' | '
        ORDER BY transaction_timestamp DESC
    ) as sample_transcripts
FROM fact_transactions_location
WHERE audio_transcript ILIKE ANY(ARRAY['%brand%', '%prefer%', '%instead%', '%different%', '%substitute%'])
GROUP BY store_id, municipality_name
HAVING COUNT(*) >= 3
ORDER BY substitution_matches DESC, total_matches DESC;
\timing off

-- Expected PostgreSQL Performance: 250-500ms
*/

-- ===========================================
-- Test 5: Join Performance with Items Table
-- Measures multi-table query performance
-- ===========================================

/*
-- Azure SQL Join Performance:
SET STATISTICS TIME ON;

SELECT
    ft.store_id,
    ft.municipality_name,
    COUNT(DISTINCT ft.canonical_tx_id) as unique_transactions,
    COUNT(fi.item_id) as total_items,
    AVG(CAST(fi.unit_price AS DECIMAL(10,2))) as avg_item_price,
    COUNT(DISTINCT fi.brand_name) as unique_brands,
    COUNT(DISTINCT fi.category) as unique_categories,
    SUM(CAST(fi.total_price AS DECIMAL(10,2))) as total_item_value,
    COUNT(*) FILTER (WHERE ft.substitution_detected = 1) as substitution_transactions,
    CAST(COUNT(*) FILTER (WHERE ft.substitution_detected = 1) AS DECIMAL(10,2)) / COUNT(DISTINCT ft.canonical_tx_id) * 100 as substitution_rate_pct
FROM fact_transactions_location ft
INNER JOIN fact_transaction_items fi ON ft.canonical_tx_id = fi.canonical_tx_id
WHERE fi.brand_name IS NOT NULL
  AND fi.unit_price > 0
GROUP BY ft.store_id, ft.municipality_name
ORDER BY total_item_value DESC;

SET STATISTICS TIME OFF;

-- Expected Azure Performance: 100-250ms
*/

/*
-- PostgreSQL Join Performance:
\timing on
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    ft.store_id,
    ft.municipality_name,
    COUNT(DISTINCT ft.canonical_tx_id) as unique_transactions,
    COUNT(fi.item_id) as total_items,
    AVG(fi.unit_price) as avg_item_price,
    COUNT(DISTINCT fi.brand_name) as unique_brands,
    COUNT(DISTINCT fi.category) as unique_categories,
    SUM(fi.total_price) as total_item_value,
    COUNT(*) FILTER (WHERE ft.substitution_detected = TRUE) as substitution_transactions,
    ROUND((COUNT(*) FILTER (WHERE ft.substitution_detected = TRUE)::DECIMAL / COUNT(DISTINCT ft.canonical_tx_id)) * 100, 2) as substitution_rate_pct
FROM fact_transactions_location ft
INNER JOIN fact_transaction_items fi ON ft.canonical_tx_id = fi.canonical_tx_id
WHERE fi.brand_name IS NOT NULL
  AND fi.unit_price > 0
GROUP BY ft.store_id, ft.municipality_name
ORDER BY total_item_value DESC;
\timing off

-- Expected PostgreSQL Performance: 80-200ms
*/

-- ===========================================
-- PERFORMANCE OPTIMIZATION RECOMMENDATIONS
-- ===========================================

/*
Azure SQL Optimization:
1. Ensure columnstore indexes on fact tables for analytics
2. Update statistics regularly: UPDATE STATISTICS fact_transactions_location
3. Consider partitioning by transaction_date for large datasets
4. Use OPTION (RECOMPILE) for parameter-sensitive queries
5. Monitor sys.dm_exec_query_stats for slow queries

CREATE NONCLUSTERED COLUMNSTORE INDEX ix_fact_transactions_analytics
ON fact_transactions_location (store_id, municipality_name, total_amount, substitution_detected, transaction_timestamp);

PostgreSQL Optimization:
1. Ensure proper indexes on commonly queried columns
2. Use VACUUM ANALYZE regularly for statistics updates
3. Consider partial indexes for filtered queries
4. Enable pg_stat_statements for query monitoring
5. Use EXPLAIN (ANALYZE, BUFFERS) to identify bottlenecks

CREATE INDEX CONCURRENTLY ix_fact_transactions_substitution
ON fact_transactions_location (substitution_detected, municipality_name, transaction_timestamp)
WHERE substitution_detected = TRUE;

CREATE INDEX CONCURRENTLY ix_fact_transactions_audio_search
ON fact_transactions_location USING gin(to_tsvector('english', audio_transcript))
WHERE audio_transcript IS NOT NULL;
*/

-- ===========================================
-- BENCHMARK RESULTS TEMPLATE
-- ===========================================

/*
PERFORMANCE BENCHMARK RESULTS

Test Environment:
- Azure SQL: [Tier/DTU]
- PostgreSQL: [Version/Resources]
- Dataset: 13,149 transactions
- Network: [Latency/Bandwidth]

Results Summary:
┌─────────────────────────┬─────────────┬─────────────┬─────────────┐
│ Test Case               │ Azure SQL   │ PostgreSQL  │ Winner      │
├─────────────────────────┼─────────────┼─────────────┼─────────────┤
│ Basic Aggregation       │ {azure_t1}  │ {pg_t1}     │ {winner_t1} │
│ Substitution Analysis   │ {azure_t2}  │ {pg_t2}     │ {winner_t2} │
│ Time-Series Analysis    │ {azure_t3}  │ {pg_t3}     │ {winner_t3} │
│ Full-Text Search        │ {azure_t4}  │ {pg_t4}     │ {winner_t4} │
│ Multi-Table Joins       │ {azure_t5}  │ {pg_t5}     │ {winner_t5} │
├─────────────────────────┼─────────────┼─────────────┼─────────────┤
│ Average Performance     │ {azure_avg} │ {pg_avg}    │ {winner}    │
└─────────────────────────┴─────────────┴─────────────┴─────────────┘

Key Findings:
• {finding_1}
• {finding_2}
• {finding_3}

Recommendations:
• {recommendation_1}
• {recommendation_2}
• {recommendation_3}

Test Date: {test_date}
Tester: {tester_name}
*/

-- ===========================================
-- AUTOMATED BENCHMARK SCRIPT
-- ===========================================

/*
#!/usr/bin/env python3
"""
Automated Performance Benchmark Suite
Compares Azure SQL vs PostgreSQL Scout Edge performance
"""

import time
import statistics
import pandas as pd
import sqlalchemy as sa
from contextlib import contextmanager

class PerformanceBenchmark:
    def __init__(self, azure_conn_str, pg_conn_str):
        self.azure_engine = sa.create_engine(azure_conn_str)
        self.pg_engine = sa.create_engine(pg_conn_str)
        self.results = []

    @contextmanager
    def timer(self, platform, test_name):
        start_time = time.perf_counter()
        try:
            yield
        finally:
            end_time = time.perf_counter()
            duration = (end_time - start_time) * 1000  # Convert to ms
            self.results.append({
                'platform': platform,
                'test': test_name,
                'duration_ms': duration
            })
            print(f"{platform} {test_name}: {duration:.2f}ms")

    def run_test(self, test_name, azure_query, pg_query, iterations=5):
        print(f"\nRunning {test_name}...")

        # Azure SQL Tests
        for i in range(iterations):
            with self.timer('Azure SQL', test_name):
                result = pd.read_sql(azure_query, self.azure_engine)

        # PostgreSQL Tests
        for i in range(iterations):
            with self.timer('PostgreSQL', test_name):
                result = pd.read_sql(pg_query, self.pg_engine)

    def generate_report(self):
        df = pd.DataFrame(self.results)

        # Calculate statistics
        summary = df.groupby(['platform', 'test'])['duration_ms'].agg([
            'mean', 'median', 'std', 'min', 'max'
        ]).round(2)

        print("\nBENCHMARK SUMMARY:")
        print("=" * 60)
        print(summary)

        # Calculate winners
        avg_by_platform = df.groupby(['test', 'platform'])['duration_ms'].mean().unstack()
        winners = avg_by_platform.idxmin(axis=1)

        print("\nWINNERS BY TEST:")
        print("-" * 30)
        for test, winner in winners.items():
            print(f"{test}: {winner}")

        return summary

# Usage example:
# benchmark = PerformanceBenchmark(azure_conn_str, pg_conn_str)
# benchmark.run_test("Basic Aggregation", azure_query_1, pg_query_1)
# benchmark.run_test("Substitution Analysis", azure_query_2, pg_query_2)
# benchmark.generate_report()
*/

-- ===========================================
-- CONTINUOUS MONITORING SETUP
-- ===========================================

/*
-- Azure SQL Performance Monitoring Query:
SELECT
    q.query_id,
    qt.query_sql_text,
    rs.avg_duration / 1000.0 as avg_duration_ms,
    rs.avg_cpu_time / 1000.0 as avg_cpu_time_ms,
    rs.avg_logical_io_reads,
    rs.count_executions,
    rs.last_execution_time
FROM sys.query_store_query q
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_runtime_stats rs ON q.query_id = rs.query_id
WHERE qt.query_sql_text LIKE '%fact_transactions_location%'
  AND rs.last_execution_time >= DATEADD(day, -7, GETUTCDATE())
ORDER BY rs.avg_duration DESC;

-- PostgreSQL Performance Monitoring Query:
SELECT
    query,
    calls,
    total_time / calls as avg_time_ms,
    mean_time as avg_execution_time_ms,
    stddev_time,
    rows / calls as avg_rows,
    100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) as hit_percent
FROM pg_stat_statements
WHERE query LIKE '%fact_transactions_location%'
  AND calls > 10
ORDER BY mean_time DESC
LIMIT 20;
*/

-- END OF PERFORMANCE BENCHMARK SUITE