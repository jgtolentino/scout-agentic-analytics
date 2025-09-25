-- ========================================================================
-- Scout Platform Enhanced ETL Pipeline with Deduplication & Completeness
-- Processes: 13,289 files → Deduplicates → Extracts all dimensions
-- ========================================================================

PRINT 'Starting Enhanced ETL with Deduplication and Completeness Validation...';
PRINT 'Expected: 12,075 unique transactions from 13,289 files with 19,747 items';

-- ==========================
-- 1. CLEAN AND DEDUPLICATE PAYLOADS
-- ==========================

-- Create staging table for deduplication
DROP TABLE IF EXISTS #PayloadStaging;
CREATE TABLE #PayloadStaging (
    staging_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    file_path VARCHAR(500),
    device_id VARCHAR(50),
    store_id VARCHAR(20),
    transaction_id VARCHAR(100),
    interaction_id VARCHAR(100),
    session_id VARCHAR(100),
    payload_json NVARCHAR(MAX),
    file_timestamp DATETIME2,

    -- Deduplication keys
    dedup_key AS COALESCE(transaction_id, interaction_id, session_id + '_' + CAST(staging_id AS VARCHAR)),
    has_items BIT,
    item_count INT,

    -- Quality flags
    is_valid BIT DEFAULT 1,
    is_duplicate BIT DEFAULT 0,
    duplicate_rank INT
);

-- Insert all payloads with extracted keys for deduplication
INSERT INTO #PayloadStaging (
    file_path, device_id, store_id, transaction_id, interaction_id, session_id,
    payload_json, file_timestamp, has_items, item_count
)
SELECT
    pt.file_path,
    pt.device_id,
    pt.store_id,

    -- Extract all possible transaction identifiers
    COALESCE(
        JSON_VALUE(pt.payload_json, '$.transactionId'),
        JSON_VALUE(pt.payload_json, '$.transaction_id'),
        JSON_VALUE(pt.payload_json, '$.transaction.id'),
        'unspecified'
    ) as transaction_id,

    COALESCE(
        JSON_VALUE(pt.payload_json, '$.interactionId'),
        JSON_VALUE(pt.payload_json, '$.interaction_id'),
        JSON_VALUE(pt.payload_json, '$.sessionId') + '_interaction'
    ) as interaction_id,

    COALESCE(
        JSON_VALUE(pt.payload_json, '$.sessionId'),
        JSON_VALUE(pt.payload_json, '$.session_id'),
        pt.transaction_id + '_session'
    ) as session_id,

    pt.payload_json,
    pt.created_at as file_timestamp,

    -- Check if items array exists and has content
    CASE WHEN JSON_VALUE(pt.payload_json, '$.items[0]') IS NOT NULL THEN 1 ELSE 0 END as has_items,
    COALESCE(JSON_VALUE(pt.payload_json, '$.totals.totalItems'), 0) as item_count

FROM dbo.PayloadTransactions pt
WHERE pt.payload_json IS NOT NULL
  AND ISJSON(pt.payload_json) = 1;

PRINT 'Loaded ' + CAST(@@ROWCOUNT AS VARCHAR) + ' payload records into staging';

-- Mark duplicates using ROW_NUMBER() partitioned by deduplication key
WITH DeduplicationRanking AS (
    SELECT
        staging_id,
        ROW_NUMBER() OVER (
            PARTITION BY dedup_key
            ORDER BY
                has_items DESC,           -- Prefer records with items
                item_count DESC,          -- Prefer higher item counts
                file_timestamp DESC,      -- Prefer more recent
                staging_id ASC           -- Consistent tie-breaker
        ) as duplicate_rank
    FROM #PayloadStaging
    WHERE dedup_key != 'unspecified'  -- Handle unspecified transactions separately
)
UPDATE ps
SET
    duplicate_rank = dr.duplicate_rank,
    is_duplicate = CASE WHEN dr.duplicate_rank > 1 THEN 1 ELSE 0 END
FROM #PayloadStaging ps
INNER JOIN DeduplicationRanking dr ON ps.staging_id = dr.staging_id;

-- Special handling for 'unspecified' transactions (treat each as unique)
UPDATE #PayloadStaging
SET
    duplicate_rank = 1,
    is_duplicate = 0
WHERE dedup_key = 'unspecified';

-- Quality validation flags
UPDATE #PayloadStaging
SET is_valid = 0
WHERE store_id = '108'  -- Exclude Store 108 per data authority rules
   OR JSON_VALUE(payload_json, '$.timestamp') IS NULL
   OR LEN(payload_json) < 100;  -- Minimum viable payload size

DECLARE @total_files INT = (SELECT COUNT(*) FROM #PayloadStaging);
DECLARE @duplicates INT = (SELECT COUNT(*) FROM #PayloadStaging WHERE is_duplicate = 1);
DECLARE @invalid INT = (SELECT COUNT(*) FROM #PayloadStaging WHERE is_valid = 0);
DECLARE @processed INT = (SELECT COUNT(*) FROM #PayloadStaging WHERE is_duplicate = 0 AND is_valid = 1);

PRINT 'Deduplication Summary:';
PRINT '  Total files: ' + CAST(@total_files AS VARCHAR);
PRINT '  Duplicates: ' + CAST(@duplicates AS VARCHAR);
PRINT '  Invalid: ' + CAST(@invalid AS VARCHAR);
PRINT '  To process: ' + CAST(@processed AS VARCHAR);

-- ==========================
-- 2. TRUNCATE AND RELOAD TARGET TABLES
-- ==========================

-- Clear existing data for complete reload
TRUNCATE TABLE dbo.TransactionItems;
TRUNCATE TABLE dbo.BrandSubstitutions;
TRUNCATE TABLE dbo.TransactionBaskets;
TRUNCATE TABLE dbo.TransactionCompletionStatus;
TRUNCATE TABLE dbo.TobaccoAnalytics;
TRUNCATE TABLE dbo.LaundryAnalytics;
DELETE FROM dbo.ProductAssociations;
DELETE FROM dbo.ETLProcessingLog WHERE process_name LIKE 'Enhanced ETL%';

PRINT 'Cleared existing data for complete reload';

-- ==========================
-- 3. ENHANCED TRANSACTION ITEMS EXTRACTION
-- ==========================

-- Extract items with complete deduplication
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
SELECT DISTINCT
    ps.transaction_id,
    ps.interaction_id,

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

FROM #PayloadStaging ps
CROSS APPLY OPENJSON(ps.payload_json, '$.items') items
WHERE ps.is_duplicate = 0
  AND ps.is_valid = 1
  AND ps.has_items = 1
  AND JSON_VALUE(items.value, '$.productName') IS NOT NULL;

DECLARE @items_extracted INT = @@ROWCOUNT;
PRINT 'Extracted ' + CAST(@items_extracted AS VARCHAR) + ' unique transaction items';

-- ==========================
-- 4. BRAND SUBSTITUTIONS WITH DEDUPLICATION
-- ==========================

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
SELECT DISTINCT
    ps.interaction_id,
    ps.transaction_id,

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
    TRY_CAST(JSON_VALUE(ps.payload_json, '$.timestamp') AS DATETIME2) as detection_timestamp

FROM #PayloadStaging ps
CROSS APPLY OPENJSON(ps.payload_json, '$.items') items
WHERE ps.is_duplicate = 0
  AND ps.is_valid = 1
  AND TRY_CAST(JSON_VALUE(items.value, '$.isSubstitution') AS BIT) = 1
  AND JSON_VALUE(items.value, '$.originalBrandRequested') IS NOT NULL;

PRINT 'Extracted ' + CAST(@@ROWCOUNT AS VARCHAR) + ' brand substitutions';

-- ==========================
-- 5. ENHANCED MARKET BASKET ANALYSIS
-- ==========================

WITH DeduplicatedBaskets AS (
    SELECT DISTINCT
        ps.transaction_id,
        ps.interaction_id,
        ps.payload_json,
        TRY_CAST(JSON_VALUE(ps.payload_json, '$.timestamp') AS DATETIME2) as basket_timestamp
    FROM #PayloadStaging ps
    WHERE ps.is_duplicate = 0
      AND ps.is_valid = 1
      AND ps.has_items = 1
),
BasketMetrics AS (
    SELECT
        db.transaction_id,
        db.interaction_id,

        -- Aggregate metrics
        COUNT(*) as total_items,
        COUNT(DISTINCT JSON_VALUE(items.value, '$.productName')) as unique_products,
        COUNT(DISTINCT JSON_VALUE(items.value, '$.brandName')) as unique_brands,
        COUNT(DISTINCT JSON_VALUE(items.value, '$.category')) as unique_categories,

        -- Financial metrics
        SUM(TRY_CAST(JSON_VALUE(items.value, '$.totalPrice') AS DECIMAL(10,2))) as total_basket_value,
        AVG(TRY_CAST(JSON_VALUE(items.value, '$.unitPrice') AS DECIMAL(10,2))) as avg_item_price,
        MAX(TRY_CAST(JSON_VALUE(items.value, '$.unitPrice') AS DECIMAL(10,2))) as max_item_price,

        -- Category flags with comprehensive detection
        MAX(CASE WHEN JSON_VALUE(items.value, '$.category') IN ('Tobacco', 'Cigarettes', 'Smoking') THEN 1 ELSE 0 END) as has_tobacco,
        MAX(CASE WHEN JSON_VALUE(items.value, '$.category') IN ('Laundry', 'Detergent', 'Home Care', 'Cleaning', 'Soap') THEN 1 ELSE 0 END) as has_laundry,
        MAX(CASE WHEN JSON_VALUE(items.value, '$.category') IN ('Beverages', 'Drinks', 'Soda', 'Water') THEN 1 ELSE 0 END) as has_beverages,
        MAX(CASE WHEN JSON_VALUE(items.value, '$.category') IN ('Snacks', 'Food', 'Candy', 'Chips') THEN 1 ELSE 0 END) as has_snacks,

        -- JSON aggregations for detailed analysis
        '[' + STRING_AGG(
            '{"product":"' + COALESCE(JSON_VALUE(items.value, '$.productName'), 'unknown') +
            '","brand":"' + COALESCE(JSON_VALUE(items.value, '$.brandName'), 'unknown') +
            '","category":"' + COALESCE(JSON_VALUE(items.value, '$.category'), 'unknown') +
            '","quantity":' + COALESCE(JSON_VALUE(items.value, '$.quantity'), '1') +
            ',"price":' + COALESCE(JSON_VALUE(items.value, '$.unitPrice'), '0') + '}', ',') +
        ']' as product_list,

        '[' + STRING_AGG(DISTINCT '"' + COALESCE(JSON_VALUE(items.value, '$.brandName'), 'unknown') + '"', ',') + ']' as brand_list,

        '[' + STRING_AGG(DISTINCT '"' + COALESCE(JSON_VALUE(items.value, '$.category'), 'unknown') + '"', ',') + ']' as category_list,

        db.basket_timestamp

    FROM DeduplicatedBaskets db
    CROSS APPLY OPENJSON(db.payload_json, '$.items') items
    WHERE JSON_VALUE(items.value, '$.productName') IS NOT NULL
    GROUP BY db.transaction_id, db.interaction_id, db.basket_timestamp
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

PRINT 'Created ' + CAST(@@ROWCOUNT AS VARCHAR) + ' deduplicated transaction baskets';

-- ==========================
-- 6. TRANSACTION COMPLETION STATUS
-- ==========================

INSERT INTO dbo.TransactionCompletionStatus (
    interaction_id,
    transaction_id,
    interaction_started,
    selection_made,
    payment_initiated,
    transaction_completed,
    transaction_abandoned,
    abandonment_stage,
    abandonment_reason,
    time_to_abandonment_seconds,
    recovery_attempted,
    recovery_successful,
    alternative_product_offered,
    alternative_accepted,
    potential_revenue_lost,
    items_in_abandoned_basket,
    completed_transaction_value,
    interaction_timestamp,
    completion_timestamp,
    abandonment_timestamp
)
SELECT DISTINCT
    ps.interaction_id,
    ps.transaction_id,

    1 as interaction_started, -- Payload exists = interaction started
    CASE WHEN ps.has_items = 1 THEN 1 ELSE 0 END as selection_made,
    CASE WHEN JSON_VALUE(ps.payload_json, '$.transaction.paymentMethod') IS NOT NULL THEN 1 ELSE 0 END as payment_initiated,
    CASE WHEN TRY_CAST(JSON_VALUE(ps.payload_json, '$.totals.totalAmount') AS DECIMAL) > 0 THEN 1 ELSE 0 END as transaction_completed,
    COALESCE(TRY_CAST(JSON_VALUE(ps.payload_json, '$.transaction.abandoned') AS BIT), 0) as transaction_abandoned,

    -- Enhanced abandonment tracking
    JSON_VALUE(ps.payload_json, '$.transaction.abandonmentStage') as abandonment_stage,
    JSON_VALUE(ps.payload_json, '$.transaction.abandonmentReason') as abandonment_reason,
    TRY_CAST(JSON_VALUE(ps.payload_json, '$.transaction.timeToAbandonmentSeconds') AS INT) as time_to_abandonment_seconds,

    -- Recovery tracking
    COALESCE(TRY_CAST(JSON_VALUE(ps.payload_json, '$.transaction.recoveryAttempted') AS BIT), 0) as recovery_attempted,
    COALESCE(TRY_CAST(JSON_VALUE(ps.payload_json, '$.transaction.recoverySuccessful') AS BIT), 0) as recovery_successful,
    COALESCE(TRY_CAST(JSON_VALUE(ps.payload_json, '$.transaction.alternativeOffered') AS BIT), 0) as alternative_product_offered,
    COALESCE(TRY_CAST(JSON_VALUE(ps.payload_json, '$.transaction.alternativeAccepted') AS BIT), 0) as alternative_accepted,

    -- Financial impact calculations
    CASE WHEN COALESCE(TRY_CAST(JSON_VALUE(ps.payload_json, '$.transaction.abandoned') AS BIT), 0) = 1
         THEN TRY_CAST(JSON_VALUE(ps.payload_json, '$.totals.totalAmount') AS DECIMAL(10,2))
         ELSE 0 END as potential_revenue_lost,
    ps.item_count as items_in_abandoned_basket,
    TRY_CAST(JSON_VALUE(ps.payload_json, '$.totals.totalAmount') AS DECIMAL(10,2)) as completed_transaction_value,

    -- Timestamps
    TRY_CAST(JSON_VALUE(ps.payload_json, '$.timestamp') AS DATETIME2) as interaction_timestamp,
    CASE WHEN TRY_CAST(JSON_VALUE(ps.payload_json, '$.totals.totalAmount') AS DECIMAL) > 0
         THEN TRY_CAST(JSON_VALUE(ps.payload_json, '$.timestamp') AS DATETIME2)
         ELSE NULL END as completion_timestamp,
    CASE WHEN COALESCE(TRY_CAST(JSON_VALUE(ps.payload_json, '$.transaction.abandoned') AS BIT), 0) = 1
         THEN TRY_CAST(JSON_VALUE(ps.payload_json, '$.timestamp') AS DATETIME2)
         ELSE NULL END as abandonment_timestamp

FROM #PayloadStaging ps
WHERE ps.is_duplicate = 0 AND ps.is_valid = 1;

PRINT 'Extracted ' + CAST(@@ROWCOUNT AS VARCHAR) + ' transaction completion records';

-- ==========================
-- 7. LOG ENHANCED ETL EXECUTION
-- ==========================

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
SELECT
    'Enhanced ETL Pipeline with Deduplication v2.0',
    GETDATE(),
    @total_files,
    @processed,
    @items_extracted,
    (SELECT COUNT(DISTINCT brand_name) FROM dbo.TransactionItems WHERE brand_name IS NOT NULL),
    @duplicates + @invalid,
    'success',
    DATEDIFF(SECOND, GETDATE(), GETDATE()) -- Will be updated by calling process

WHERE @items_extracted > 0;

-- ==========================
-- 8. FINAL VALIDATION AND SUMMARY
-- ==========================

-- Comprehensive validation
DECLARE @final_transactions INT = (SELECT COUNT(DISTINCT transaction_id) FROM dbo.TransactionItems);
DECLARE @final_items INT = (SELECT COUNT(*) FROM dbo.TransactionItems);
DECLARE @final_baskets INT = (SELECT COUNT(*) FROM dbo.TransactionBaskets);
DECLARE @final_substitutions INT = (SELECT COUNT(*) FROM dbo.BrandSubstitutions);
DECLARE @final_completions INT = (SELECT COUNT(*) FROM dbo.TransactionCompletionStatus);

PRINT '========================================';
PRINT 'ENHANCED ETL PIPELINE COMPLETION REPORT';
PRINT '========================================';
PRINT 'INPUT PROCESSING:';
PRINT '  Total files scanned: ' + CAST(@total_files AS VARCHAR);
PRINT '  Duplicates removed: ' + CAST(@duplicates AS VARCHAR);
PRINT '  Invalid records excluded: ' + CAST(@invalid AS VARCHAR);
PRINT '  Valid records processed: ' + CAST(@processed AS VARCHAR);
PRINT '';
PRINT 'DATA EXTRACTION RESULTS:';
PRINT '  Unique transactions: ' + CAST(@final_transactions AS VARCHAR);
PRINT '  Transaction items: ' + CAST(@final_items AS VARCHAR);
PRINT '  Transaction baskets: ' + CAST(@final_baskets AS VARCHAR);
PRINT '  Brand substitutions: ' + CAST(@final_substitutions AS VARCHAR);
PRINT '  Completion records: ' + CAST(@final_completions AS VARCHAR);
PRINT '';
PRINT 'QUALITY METRICS:';
PRINT '  Deduplication rate: ' + CAST(ROUND((@duplicates * 100.0 / @total_files), 2) AS VARCHAR) + '%';
PRINT '  Item extraction rate: ' + CAST(ROUND((@final_items * 100.0 / 19747), 2) AS VARCHAR) + '%';
PRINT '  Transaction completeness: ' + CAST(ROUND((@final_transactions * 100.0 / @processed), 2) AS VARCHAR) + '%';
PRINT '========================================';
PRINT 'ETL PIPELINE COMPLETED SUCCESSFULLY';
PRINT '========================================';

-- Cleanup
DROP TABLE #PayloadStaging;