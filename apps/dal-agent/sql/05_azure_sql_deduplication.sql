-- ========================================================================
-- Scout Platform Azure SQL Server Deduplication ETL
-- Strategy: Bulk load ALL files → Deduplicate using SQL → Extract dimensions
-- ========================================================================

PRINT 'Starting Azure SQL Server Deduplication ETL Pipeline...';

-- ==========================
-- 1. CREATE STAGING TABLE FOR BULK LOAD
-- ==========================

-- Drop and recreate staging table for clean bulk load
IF OBJECT_ID('dbo.PayloadTransactionsStaging', 'U') IS NOT NULL
    DROP TABLE dbo.PayloadTransactionsStaging;

CREATE TABLE dbo.PayloadTransactionsStaging (
    staging_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    transaction_id VARCHAR(100),
    device_id VARCHAR(50),
    store_id VARCHAR(20),
    file_path VARCHAR(500),
    payload_json NVARCHAR(MAX),
    file_timestamp DATETIME2,
    created_at DATETIME2 DEFAULT GETDATE(),

    -- Quality metrics
    has_items BIT,
    item_count INT,
    payload_size INT,

    -- Indexes for deduplication performance
    INDEX IX_Staging_TransactionId (transaction_id),
    INDEX IX_Staging_DeviceStore (device_id, store_id),
    INDEX IX_Staging_Timestamp (file_timestamp)
);

PRINT 'Created staging table for bulk load';

-- ==========================
-- 2. AZURE SQL DEDUPLICATION LOGIC
-- ==========================

-- Create view for deduplication analysis
CREATE OR ALTER VIEW dbo.v_PayloadDeduplication AS
WITH DeduplicationRanking AS (
    SELECT
        staging_id,
        transaction_id,
        device_id,
        store_id,
        file_path,
        payload_json,
        file_timestamp,
        has_items,
        item_count,
        payload_size,

        -- Deduplication ranking using ROW_NUMBER()
        ROW_NUMBER() OVER (
            PARTITION BY transaction_id
            ORDER BY
                has_items DESC,              -- Prefer files with items
                item_count DESC,             -- Prefer more items
                payload_size DESC,           -- Prefer larger payloads
                file_timestamp DESC,         -- Prefer newer files
                staging_id ASC               -- Consistent tie-breaker
        ) as dedup_rank,

        -- Count duplicates per transaction
        COUNT(*) OVER (PARTITION BY transaction_id) as duplicate_count

    FROM dbo.PayloadTransactionsStaging
    WHERE transaction_id IS NOT NULL
      AND transaction_id != 'unspecified'
      AND store_id != '108'  -- Exclude Store 108 per data authority rules
      AND payload_json IS NOT NULL
      AND ISJSON(payload_json) = 1
)
SELECT *,
    CASE WHEN dedup_rank = 1 THEN 0 ELSE 1 END as is_duplicate
FROM DeduplicationRanking;

PRINT 'Created deduplication analysis view';

-- ==========================
-- 3. DEDUPLICATED PAYLOAD SELECTION
-- ==========================

-- Clear target table and insert deduplicated records
TRUNCATE TABLE dbo.PayloadTransactions;

-- Insert only the best version of each transaction (rank = 1)
INSERT INTO dbo.PayloadTransactions (
    transaction_id,
    device_id,
    store_id,
    file_path,
    payload_json,
    created_at
)
SELECT
    transaction_id,
    device_id,
    store_id,
    file_path,
    payload_json,
    file_timestamp as created_at
FROM dbo.v_PayloadDeduplication
WHERE dedup_rank = 1;  -- Only keep the best version

DECLARE @total_staged INT = (SELECT COUNT(*) FROM dbo.PayloadTransactionsStaging);
DECLARE @duplicates_removed INT = (SELECT COUNT(*) FROM dbo.v_PayloadDeduplication WHERE is_duplicate = 1);
DECLARE @final_records INT = (SELECT COUNT(*) FROM dbo.PayloadTransactions);

PRINT 'Deduplication Results:';
PRINT '  Total files staged: ' + CAST(@total_staged AS VARCHAR);
PRINT '  Duplicates removed: ' + CAST(@duplicates_removed AS VARCHAR);
PRINT '  Final unique records: ' + CAST(@final_records AS VARCHAR);
PRINT '  Deduplication rate: ' + CAST(ROUND(@duplicates_removed * 100.0 / @total_staged, 2) AS VARCHAR) + '%';

-- ==========================
-- 4. ENHANCED TRANSACTION ITEMS EXTRACTION
-- ==========================

-- Clear existing data for complete reload
TRUNCATE TABLE dbo.TransactionItems;

-- Extract items with deduplication already applied
INSERT INTO dbo.TransactionItems (
    transaction_id,
    interaction_id,
    product_name,
    brand_name,
    generic_name,
    local_name,
    category,
    subcategory,
    sku,
    barcode,
    quantity,
    unit,
    unit_price,
    total_price,
    weight_grams,
    volume_ml,
    pack_size,
    is_substitution,
    original_product_requested,
    original_brand_requested,
    substitution_reason,
    customer_accepted_substitution,
    suggested_alternatives,
    detection_method,
    brand_confidence,
    product_confidence,
    is_impulse_buy,
    is_promoted_item,
    customer_request_type,
    audio_context,
    created_at
)
SELECT
    pt.transaction_id,
    JSON_VALUE(pt.payload_json, '$.interactionId') as interaction_id,

    -- Enhanced product extraction with null handling
    NULLIF(TRIM(JSON_VALUE(items.value, '$.productName')), '') as product_name,
    NULLIF(TRIM(JSON_VALUE(items.value, '$.brandName')), '') as brand_name,
    NULLIF(TRIM(JSON_VALUE(items.value, '$.genericName')), '') as generic_name,
    NULLIF(TRIM(JSON_VALUE(items.value, '$.localName')), '') as local_name,
    NULLIF(TRIM(JSON_VALUE(items.value, '$.category')), '') as category,
    NULLIF(TRIM(JSON_VALUE(items.value, '$.subcategory')), '') as subcategory,
    NULLIF(TRIM(JSON_VALUE(items.value, '$.sku')), '') as sku,
    NULLIF(TRIM(JSON_VALUE(items.value, '$.barcode')), '') as barcode,

    -- Quantities with validation
    CASE WHEN TRY_CAST(JSON_VALUE(items.value, '$.quantity') AS INT) > 0
         THEN TRY_CAST(JSON_VALUE(items.value, '$.quantity') AS INT)
         ELSE 1 END as quantity,
    NULLIF(TRIM(JSON_VALUE(items.value, '$.unit')), '') as unit,
    TRY_CAST(JSON_VALUE(items.value, '$.unitPrice') AS DECIMAL(10,2)) as unit_price,
    TRY_CAST(JSON_VALUE(items.value, '$.totalPrice') AS DECIMAL(10,2)) as total_price,

    -- Product characteristics
    TRY_CAST(JSON_VALUE(items.value, '$.weight') AS INT) as weight_grams,
    TRY_CAST(JSON_VALUE(items.value, '$.volume') AS INT) as volume_ml,
    JSON_VALUE(items.value, '$.packSize') as pack_size,

    -- Substitution tracking
    COALESCE(TRY_CAST(JSON_VALUE(items.value, '$.isSubstitution') AS BIT), 0) as is_substitution,
    JSON_VALUE(items.value, '$.originalProductRequested') as original_product_requested,
    JSON_VALUE(items.value, '$.originalBrandRequested') as original_brand_requested,
    JSON_VALUE(items.value, '$.substitutionReason') as substitution_reason,
    TRY_CAST(JSON_VALUE(items.value, '$.customerRequest.acceptedSuggestion') AS BIT) as customer_accepted_substitution,
    JSON_QUERY(items.value, '$.suggestedAlternatives') as suggested_alternatives,

    -- Detection and AI confidence
    JSON_VALUE(items.value, '$.detectionMethod') as detection_method,
    TRY_CAST(JSON_VALUE(items.value, '$.brandConfidence') AS DECIMAL(3,2)) as brand_confidence,
    TRY_CAST(JSON_VALUE(items.value, '$.confidence') AS DECIMAL(3,2)) as product_confidence,

    -- Purchase context
    COALESCE(TRY_CAST(JSON_VALUE(items.value, '$.isImpulseBuy') AS BIT), 0) as is_impulse_buy,
    COALESCE(TRY_CAST(JSON_VALUE(items.value, '$.isPromoted') AS BIT), 0) as is_promoted_item,
    JSON_VALUE(items.value, '$.customerRequest.requestType') as customer_request_type,

    -- Audio and notes
    COALESCE(JSON_VALUE(items.value, '$.notes'), JSON_VALUE(items.value, '$.audioContext')) as audio_context,

    GETDATE() as created_at

FROM dbo.PayloadTransactions pt
CROSS APPLY OPENJSON(pt.payload_json, '$.items') items
WHERE JSON_VALUE(pt.payload_json, '$.items') IS NOT NULL
  AND JSON_VALUE(items.value, '$.productName') IS NOT NULL;

DECLARE @items_extracted INT = @@ROWCOUNT;
PRINT 'Extracted ' + CAST(@items_extracted AS VARCHAR) + ' unique transaction items from deduplicated data';

-- ==========================
-- 5. BRAND SUBSTITUTIONS
-- ==========================

TRUNCATE TABLE dbo.BrandSubstitutions;

INSERT INTO dbo.BrandSubstitutions (
    interaction_id,
    transaction_id,
    original_brand,
    original_product,
    original_sku,
    substituted_brand,
    substituted_product,
    substituted_sku,
    substitution_reason,
    suggestion_accepted,
    customer_requested,
    original_price,
    substituted_price,
    confidence_score,
    detection_timestamp
)
SELECT
    JSON_VALUE(pt.payload_json, '$.interactionId') as interaction_id,
    pt.transaction_id,

    -- Original request
    JSON_VALUE(items.value, '$.originalBrandRequested') as original_brand,
    JSON_VALUE(items.value, '$.originalProductRequested') as original_product,
    JSON_VALUE(items.value, '$.originalSku') as original_sku,

    -- Actual substitution
    JSON_VALUE(items.value, '$.brandName') as substituted_brand,
    JSON_VALUE(items.value, '$.productName') as substituted_product,
    JSON_VALUE(items.value, '$.sku') as substituted_sku,

    -- Substitution context
    JSON_VALUE(items.value, '$.substitutionReason') as substitution_reason,
    TRY_CAST(JSON_VALUE(items.value, '$.customerRequest.acceptedSuggestion') AS BIT) as suggestion_accepted,
    CASE WHEN JSON_VALUE(items.value, '$.customerRequest.requestType') = 'customer_substitution' THEN 1 ELSE 0 END as customer_requested,

    -- Pricing impact
    TRY_CAST(JSON_VALUE(items.value, '$.originalPrice') AS DECIMAL(10,2)) as original_price,
    TRY_CAST(JSON_VALUE(items.value, '$.unitPrice') AS DECIMAL(10,2)) as substituted_price,

    TRY_CAST(JSON_VALUE(items.value, '$.confidence') AS DECIMAL(3,2)) as confidence_score,
    TRY_CAST(JSON_VALUE(pt.payload_json, '$.timestamp') AS DATETIME2) as detection_timestamp

FROM dbo.PayloadTransactions pt
CROSS APPLY OPENJSON(pt.payload_json, '$.items') items
WHERE TRY_CAST(JSON_VALUE(items.value, '$.isSubstitution') AS BIT) = 1
  AND JSON_VALUE(items.value, '$.originalBrandRequested') IS NOT NULL;

PRINT 'Extracted ' + CAST(@@ROWCOUNT AS VARCHAR) + ' brand substitutions';

-- ==========================
-- 6. TRANSACTION BASKETS
-- ==========================

TRUNCATE TABLE dbo.TransactionBaskets;

WITH BasketMetrics AS (
    SELECT
        pt.transaction_id,
        JSON_VALUE(pt.payload_json, '$.interactionId') as interaction_id,

        -- Aggregate metrics from items
        COUNT(*) as total_items,
        COUNT(DISTINCT JSON_VALUE(items.value, '$.productName')) as unique_products,
        COUNT(DISTINCT JSON_VALUE(items.value, '$.brandName')) as unique_brands,
        COUNT(DISTINCT JSON_VALUE(items.value, '$.category')) as unique_categories,

        -- Financial metrics
        SUM(TRY_CAST(JSON_VALUE(items.value, '$.totalPrice') AS DECIMAL(10,2))) as total_basket_value,
        AVG(TRY_CAST(JSON_VALUE(items.value, '$.unitPrice') AS DECIMAL(10,2))) as avg_item_price,
        MAX(TRY_CAST(JSON_VALUE(items.value, '$.unitPrice') AS DECIMAL(10,2))) as max_item_price,

        -- Category flags
        MAX(CASE WHEN JSON_VALUE(items.value, '$.category') IN ('Tobacco', 'Cigarettes', 'Smoking') THEN 1 ELSE 0 END) as has_tobacco,
        MAX(CASE WHEN JSON_VALUE(items.value, '$.category') IN ('Laundry', 'Detergent', 'Home Care', 'Cleaning', 'Soap') THEN 1 ELSE 0 END) as has_laundry,
        MAX(CASE WHEN JSON_VALUE(items.value, '$.category') IN ('Beverages', 'Drinks', 'Soda', 'Water') THEN 1 ELSE 0 END) as has_beverages,
        MAX(CASE WHEN JSON_VALUE(items.value, '$.category') IN ('Snacks', 'Food', 'Candy', 'Chips') THEN 1 ELSE 0 END) as has_snacks,

        -- JSON aggregations
        '[' + STRING_AGG(
            '{"product":"' + COALESCE(JSON_VALUE(items.value, '$.productName'), 'unknown') +
            '","brand":"' + COALESCE(JSON_VALUE(items.value, '$.brandName'), 'unknown') +
            '","category":"' + COALESCE(JSON_VALUE(items.value, '$.category'), 'unknown') +
            '","quantity":' + COALESCE(JSON_VALUE(items.value, '$.quantity'), '1') +
            ',"price":' + COALESCE(JSON_VALUE(items.value, '$.unitPrice'), '0') + '}', ',') +
        ']' as product_list,

        '[' + STRING_AGG(DISTINCT '"' + COALESCE(JSON_VALUE(items.value, '$.brandName'), 'unknown') + '"', ',') + ']' as brand_list,

        '[' + STRING_AGG(DISTINCT '"' + COALESCE(JSON_VALUE(items.value, '$.category'), 'unknown') + '"', ',') + ']' as category_list,

        TRY_CAST(JSON_VALUE(pt.payload_json, '$.timestamp') AS DATETIME2) as basket_timestamp

    FROM dbo.PayloadTransactions pt
    CROSS APPLY OPENJSON(pt.payload_json, '$.items') items
    WHERE JSON_VALUE(pt.payload_json, '$.items') IS NOT NULL
      AND JSON_VALUE(items.value, '$.productName') IS NOT NULL
    GROUP BY pt.transaction_id, pt.payload_json
)
INSERT INTO dbo.TransactionBaskets (
    transaction_id,
    interaction_id,
    total_items,
    unique_products,
    unique_brands,
    unique_categories,
    total_basket_value,
    avg_item_price,
    max_item_price,
    product_list,
    brand_list,
    category_list,
    has_tobacco,
    has_laundry,
    has_beverages,
    has_snacks,
    basket_timestamp
)
SELECT * FROM BasketMetrics;

PRINT 'Created ' + CAST(@@ROWCOUNT AS VARCHAR) + ' transaction baskets from deduplicated data';

-- ==========================
-- 7. FINAL DEDUPLICATION SUMMARY
-- ==========================

-- Generate comprehensive deduplication report
SELECT
    'Deduplication Summary' as report_section,
    @total_staged as total_files_staged,
    @duplicates_removed as duplicates_removed,
    @final_records as unique_transactions,
    ROUND(@duplicates_removed * 100.0 / @total_staged, 2) as deduplication_rate_pct,
    @items_extracted as items_extracted,
    (SELECT COUNT(*) FROM dbo.TransactionBaskets) as baskets_created,
    (SELECT COUNT(*) FROM dbo.BrandSubstitutions) as substitutions_found;

-- Log successful completion
INSERT INTO dbo.ETLProcessingLog (
    process_name,
    execution_timestamp,
    files_processed,
    transactions_extracted,
    items_extracted,
    brands_detected,
    errors_encountered,
    status,
    processing_duration_seconds
)
VALUES (
    'Azure SQL Server Deduplication ETL v1.0',
    GETDATE(),
    @total_staged,
    @final_records,
    @items_extracted,
    (SELECT COUNT(DISTINCT brand_name) FROM dbo.TransactionItems WHERE brand_name IS NOT NULL),
    @duplicates_removed,  -- Treating duplicates as "errors encountered"
    'success',
    0  -- Will be updated by calling process
);

-- Cleanup staging table
DROP TABLE dbo.PayloadTransactionsStaging;
DROP VIEW dbo.v_PayloadDeduplication;

PRINT '========================================';
PRINT 'AZURE SQL SERVER DEDUPLICATION COMPLETE';
PRINT 'Processed ' + CAST(@final_records AS VARCHAR) + ' unique transactions';
PRINT 'Removed ' + CAST(@duplicates_removed AS VARCHAR) + ' duplicates';
PRINT 'Extracted ' + CAST(@items_extracted AS VARCHAR) + ' items';
PRINT '========================================';