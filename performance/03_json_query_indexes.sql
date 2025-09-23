-- ==========================================
-- JSON Query Performance Indexes
-- Optimized indexes for Scout Edge JSON payload queries
-- ==========================================

-- This file contains index definitions that optimize JSON querying for both:
-- - Azure SQL Server (computed columns + traditional indexes)
-- - PostgreSQL/Supabase (GIN indexes on JSONB + extracted value indexes)

-- ==========================================
-- AZURE SQL SERVER INDEXES
-- ==========================================

/*
-- Execute these on Azure SQL Server for optimal JSON query performance

-- 1. Computed Columns for Frequently Queried JSON Paths
ALTER TABLE dbo.fact_transactions_location
ADD
    transaction_id_computed AS JSON_VALUE(payload_json, '$.transactionId'),
    store_id_computed AS CAST(JSON_VALUE(payload_json, '$.storeId') AS INT),
    municipality_computed AS JSON_VALUE(payload_json, '$.location.municipality'),
    region_computed AS JSON_VALUE(payload_json, '$.location.region'),
    brand_matched_computed AS CAST(JSON_VALUE(payload_json, '$.qualityFlags.brandMatched') AS BIT),
    location_verified_computed AS CAST(JSON_VALUE(payload_json, '$.qualityFlags.locationVerified') AS BIT),
    substitution_detected_computed AS CAST(JSON_VALUE(payload_json, '$.qualityFlags.substitutionDetected') AS BIT),
    basket_item_count_computed AS JSON_VALUE(payload_json, '$.basket.itemCount'),
    transaction_total_computed AS CAST(JSON_VALUE(payload_json, '$.basket.totalAmount') AS DECIMAL(10,2)),
    latitude_computed AS CAST(JSON_VALUE(payload_json, '$.location.geo.lat') AS DECIMAL(10,8)),
    longitude_computed AS CAST(JSON_VALUE(payload_json, '$.location.geo.lon') AS DECIMAL(11,8));

-- 2. Primary Lookup Indexes
CREATE NONCLUSTERED INDEX IX_fact_transactions_location_transaction_id
ON dbo.fact_transactions_location (transaction_id_computed)
INCLUDE (canonical_tx_id, data_quality_score, created_at);

CREATE NONCLUSTERED INDEX IX_fact_transactions_location_store_id
ON dbo.fact_transactions_location (store_id_computed)
INCLUDE (transaction_id_computed, data_quality_score, created_at);

-- 3. Geographic Query Optimization
CREATE NONCLUSTERED INDEX IX_fact_transactions_location_geography
ON dbo.fact_transactions_location (region_computed, municipality_computed)
INCLUDE (store_id_computed, latitude_computed, longitude_computed);

CREATE NONCLUSTERED INDEX IX_fact_transactions_location_coordinates
ON dbo.fact_transactions_location (latitude_computed, longitude_computed)
WHERE latitude_computed IS NOT NULL AND longitude_computed IS NOT NULL;

-- 4. Quality Flags Performance
CREATE NONCLUSTERED INDEX IX_fact_transactions_location_quality_flags
ON dbo.fact_transactions_location (brand_matched_computed, location_verified_computed, substitution_detected_computed)
INCLUDE (store_id_computed, data_quality_score);

-- 5. Business Analytics Indexes
CREATE NONCLUSTERED INDEX IX_fact_transactions_location_basket_analysis
ON dbo.fact_transactions_location (basket_item_count_computed, transaction_total_computed)
INCLUDE (store_id_computed, substitution_detected_computed);

CREATE NONCLUSTERED INDEX IX_fact_transactions_location_data_quality
ON dbo.fact_transactions_location (data_quality_score DESC)
INCLUDE (store_id_computed, brand_matched_computed, location_verified_computed);

-- 6. Time-Series Analysis
CREATE NONCLUSTERED INDEX IX_fact_transactions_location_temporal
ON dbo.fact_transactions_location (created_at DESC)
INCLUDE (store_id_computed, data_quality_score, transaction_id_computed);

-- 7. JSON Full-Text Search (if needed for transcripts)
-- CREATE FULLTEXT INDEX ON dbo.fact_transactions_location (payload_json)
-- KEY INDEX PK_fact_transactions_location;

-- Performance Validation Query
-- This query should use computed column indexes
/*
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    store_id_computed,
    municipality_computed,
    COUNT(*) as transaction_count,
    AVG(data_quality_score) as avg_quality,
    AVG(basket_item_count_computed) as avg_items
FROM dbo.fact_transactions_location
WHERE region_computed = 'NCR'
  AND brand_matched_computed = 1
  AND created_at >= DATEADD(day, -30, GETDATE())
GROUP BY store_id_computed, municipality_computed
ORDER BY transaction_count DESC;
*/

*/

-- ==========================================
-- POSTGRESQL/SUPABASE INDEXES
-- ==========================================

/*
-- Execute these on PostgreSQL/Supabase for optimal JSONB query performance

-- 1. Primary GIN Index on JSONB Column
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fact_transactions_location_payload_gin
ON fact_transactions_location USING GIN (payload_json);

-- 2. Specific Path Indexes for Frequent Queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fact_transactions_location_transaction_id
ON fact_transactions_location USING BTREE ((payload_json ->> 'transactionId'));

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fact_transactions_location_store_id
ON fact_transactions_location USING BTREE (((payload_json ->> 'storeId')::INTEGER));

-- 3. Geographic Query Optimization
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fact_transactions_location_municipality
ON fact_transactions_location USING BTREE ((payload_json -> 'location' ->> 'municipality'));

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fact_transactions_location_region
ON fact_transactions_location USING BTREE ((payload_json -> 'location' ->> 'region'));

-- Composite geographic index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fact_transactions_location_geo_composite
ON fact_transactions_location USING BTREE (
    (payload_json -> 'location' ->> 'region'),
    (payload_json -> 'location' ->> 'municipality')
);

-- Spatial index for coordinates (if PostGIS is available)
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fact_transactions_location_coordinates
-- ON fact_transactions_location USING GIST (
--     ST_Point(
--         (payload_json -> 'location' -> 'geo' ->> 'lon')::DOUBLE PRECISION,
--         (payload_json -> 'location' -> 'geo' ->> 'lat')::DOUBLE PRECISION
--     )
-- );

-- 4. Quality Flags Optimization
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fact_transactions_location_brand_matched
ON fact_transactions_location USING BTREE (((payload_json -> 'qualityFlags' ->> 'brandMatched')::BOOLEAN))
WHERE (payload_json -> 'qualityFlags' ->> 'brandMatched')::BOOLEAN = TRUE;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fact_transactions_location_location_verified
ON fact_transactions_location USING BTREE (((payload_json -> 'qualityFlags' ->> 'locationVerified')::BOOLEAN))
WHERE (payload_json -> 'qualityFlags' ->> 'locationVerified')::BOOLEAN = TRUE;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fact_transactions_location_substitution_detected
ON fact_transactions_location USING BTREE (((payload_json -> 'qualityFlags' ->> 'substitutionDetected')::BOOLEAN))
WHERE (payload_json -> 'qualityFlags' ->> 'substitutionDetected')::BOOLEAN = TRUE;

-- 5. Business Analytics Indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fact_transactions_location_item_count
ON fact_transactions_location USING BTREE (((payload_json -> 'basket' ->> 'itemCount')::INTEGER));

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fact_transactions_location_total_amount
ON fact_transactions_location USING BTREE (((payload_json -> 'basket' ->> 'totalAmount')::DECIMAL));

-- 6. Composite Quality Score Index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fact_transactions_location_quality_composite
ON fact_transactions_location USING BTREE (
    data_quality_score DESC,
    ((payload_json ->> 'storeId')::INTEGER),
    created_at DESC
);

-- 7. Time-Series Analysis
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fact_transactions_location_temporal
ON fact_transactions_location USING BTREE (created_at DESC)
INCLUDE (canonical_tx_id, data_quality_score);

-- 8. Basket Items Array Optimization (GIN for array operations)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fact_transactions_location_basket_items
ON fact_transactions_location USING GIN ((payload_json -> 'basket' -> 'items'));

-- Performance Validation Query
-- This query should use the JSONB indexes efficiently
/*
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    payload_json -> 'location' ->> 'municipality' as municipality,
    (payload_json ->> 'storeId')::INTEGER as store_id,
    COUNT(*) as transaction_count,
    AVG(data_quality_score) as avg_quality,
    AVG((payload_json -> 'basket' ->> 'itemCount')::INTEGER) as avg_items,
    COUNT(*) FILTER (WHERE (payload_json -> 'qualityFlags' ->> 'substitutionDetected')::BOOLEAN = TRUE) as substitution_count
FROM fact_transactions_location
WHERE payload_json -> 'location' ->> 'region' = 'NCR'
  AND (payload_json -> 'qualityFlags' ->> 'brandMatched')::BOOLEAN = TRUE
  AND created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY
    payload_json -> 'location' ->> 'municipality',
    (payload_json ->> 'storeId')::INTEGER
ORDER BY transaction_count DESC;
*/

*/

-- ==========================================
-- INDEX MONITORING AND MAINTENANCE
-- ==========================================

/*
-- Azure SQL Server - Index Usage Monitoring
SELECT
    i.name AS index_name,
    s.user_seeks,
    s.user_scans,
    s.user_lookups,
    s.user_updates,
    CASE
        WHEN s.user_seeks + s.user_scans + s.user_lookups = 0 THEN 0
        ELSE ROUND((s.user_seeks + s.user_scans + s.user_lookups) * 100.0 /
             (s.user_seeks + s.user_scans + s.user_lookups + s.user_updates), 2)
    END AS usage_efficiency_pct
FROM sys.dm_db_index_usage_stats s
INNER JOIN sys.indexes i ON s.object_id = i.object_id AND s.index_id = i.index_id
WHERE OBJECT_NAME(s.object_id) = 'fact_transactions_location'
ORDER BY usage_efficiency_pct DESC;

-- PostgreSQL - Index Usage Monitoring
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan AS index_scans,
    idx_tup_read AS tuples_read,
    idx_tup_fetch AS tuples_fetched,
    CASE
        WHEN idx_scan = 0 THEN 0
        ELSE ROUND(idx_tup_fetch::NUMERIC / idx_scan, 2)
    END AS avg_tuples_per_scan
FROM pg_stat_user_indexes
WHERE tablename = 'fact_transactions_location'
ORDER BY idx_scan DESC;

-- Index Size Analysis (PostgreSQL)
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    idx_scan,
    CASE
        WHEN idx_scan = 0 THEN 'UNUSED'
        WHEN idx_scan < 100 THEN 'LOW_USAGE'
        ELSE 'ACTIVE'
    END AS usage_category
FROM pg_stat_user_indexes
WHERE tablename = 'fact_transactions_location'
ORDER BY pg_relation_size(indexrelid) DESC;
*/

-- ==========================================
-- PERFORMANCE BENCHMARKS
-- ==========================================

/*
Expected Performance Improvements:

1. Transaction ID Lookups: 5-10x faster
   - Before: 50-100ms table scan
   - After: 5-15ms index seek

2. Store-based Filtering: 3-8x faster
   - Before: 100-200ms JSON parsing
   - After: 15-40ms computed column lookup

3. Geographic Queries: 10-20x faster
   - Before: 200-500ms full JSON scan
   - After: 20-50ms composite index

4. Quality Flag Analysis: 5-15x faster
   - Before: 100-300ms JSON extraction
   - After: 10-30ms bitmap index operations

5. Complex Analytics: 2-5x faster
   - Before: 500ms-2s multi-table operations
   - After: 100-500ms index-optimized queries

Total Query Performance Improvement: 60-80% average
Memory Usage Reduction: 40-60% for large result sets
Index Storage Overhead: ~15-25% of table size
*/

-- ==========================================
-- MAINTENANCE SCHEDULE
-- ==========================================

/*
Recommended Maintenance:

Azure SQL Server:
- Weekly: UPDATE STATISTICS on computed columns
- Monthly: REBUILD indexes with FILLFACTOR = 90
- Quarterly: Review index usage and remove unused indexes

PostgreSQL/Supabase:
- Weekly: ANALYZE fact_transactions_location
- Monthly: REINDEX CONCURRENTLY on high-usage indexes
- Quarterly: Review pg_stat_user_indexes for optimization opportunities

Index Health Monitoring:
- Monitor query performance with EXPLAIN ANALYZE
- Track index usage statistics
- Alert on index scan ratios < 80%
- Monitor index fragmentation levels
*/