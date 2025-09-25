-- ========================================================================
-- Scout Platform Stored Procedures for Analytics and ETL Operations
-- Provides: Data refresh, analytics queries, performance optimization
-- ========================================================================

-- ==========================
-- 1. ETL EXECUTION PROCEDURES
-- ==========================

-- Execute complete ETL pipeline with logging
CREATE OR ALTER PROCEDURE dbo.sp_ExecuteCompleteETL
    @LogResults BIT = 1,
    @SkipDeduplication BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @StartTime DATETIME2 = GETDATE();
    DECLARE @ProcessName VARCHAR(100) = 'Complete ETL Pipeline';
    DECLARE @Status VARCHAR(50) = 'running';
    DECLARE @ErrorMessage VARCHAR(MAX) = NULL;

    BEGIN TRY
        -- Log start
        INSERT INTO dbo.ETLProcessingLog (process_name, status, execution_timestamp)
        VALUES (@ProcessName, @Status, @StartTime);
        DECLARE @LogId BIGINT = SCOPE_IDENTITY();

        -- Execute ETL steps
        IF @SkipDeduplication = 0
        BEGIN
            EXEC dbo.sp_DeduplicateTransactions;
        END

        EXEC dbo.sp_ExtractTransactionItems;
        EXEC dbo.sp_ExtractBrandSubstitutions;
        EXEC dbo.sp_BuildTransactionBaskets;
        EXEC dbo.sp_CalculateProductAssociations;
        EXEC dbo.sp_ExtractCategoryAnalytics;

        SET @Status = 'success';

        -- Update log with success
        UPDATE dbo.ETLProcessingLog
        SET status = @Status,
            processing_duration_seconds = DATEDIFF(SECOND, @StartTime, GETDATE()),
            transactions_extracted = (SELECT COUNT(*) FROM dbo.TransactionItems),
            items_extracted = (SELECT COUNT(*) FROM dbo.TransactionItems),
            brands_detected = (SELECT COUNT(DISTINCT brand_name) FROM dbo.TransactionItems WHERE brand_name IS NOT NULL)
        WHERE log_id = @LogId;

    END TRY
    BEGIN CATCH
        SET @Status = 'failed';
        SET @ErrorMessage = ERROR_MESSAGE();

        -- Log error
        UPDATE dbo.ETLProcessingLog
        SET status = @Status,
            error_details = @ErrorMessage,
            processing_duration_seconds = DATEDIFF(SECOND, @StartTime, GETDATE())
        WHERE log_id = @LogId;

        -- Re-raise error
        THROW;
    END CATCH

    IF @LogResults = 1
    BEGIN
        SELECT
            'ETL Execution Complete' as result,
            @Status as status,
            DATEDIFF(SECOND, @StartTime, GETDATE()) as duration_seconds,
            @ErrorMessage as error_message;
    END
END;
GO

-- Deduplicate transactions using ROW_NUMBER()
CREATE OR ALTER PROCEDURE dbo.sp_DeduplicateTransactions
AS
BEGIN
    SET NOCOUNT ON;

    -- Create temporary view for deduplication
    WITH DeduplicatedPayloads AS (
        SELECT
            transaction_id,
            device_id,
            store_id,
            payload_json,
            created_at,
            ROW_NUMBER() OVER (
                PARTITION BY transaction_id
                ORDER BY
                    CASE WHEN JSON_VALUE(payload_json, '$.items[0]') IS NOT NULL THEN 1 ELSE 0 END DESC,
                    COALESCE(TRY_CAST(JSON_VALUE(payload_json, '$.totals.totalItems') AS INT), 0) DESC,
                    LEN(payload_json) DESC,
                    created_at DESC
            ) as dedup_rank
        FROM dbo.PayloadTransactions
        WHERE transaction_id IS NOT NULL
          AND transaction_id != 'unspecified'
          AND store_id != '108'
    )
    -- Replace PayloadTransactions with deduplicated data
    DELETE FROM dbo.PayloadTransactions;

    INSERT INTO dbo.PayloadTransactions (transaction_id, device_id, store_id, payload_json, created_at)
    SELECT transaction_id, device_id, store_id, payload_json, created_at
    FROM DeduplicatedPayloads
    WHERE dedup_rank = 1;

    SELECT @@ROWCOUNT as deduplicated_records;
END;
GO

-- ==========================
-- 2. DATA EXTRACTION PROCEDURES
-- ==========================

-- Extract transaction items from payloads
CREATE OR ALTER PROCEDURE dbo.sp_ExtractTransactionItems
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE dbo.TransactionItems;

    INSERT INTO dbo.TransactionItems (
        transaction_id, interaction_id, product_name, brand_name, generic_name,
        local_name, category, subcategory, sku, quantity, unit, unit_price,
        total_price, is_substitution, original_product_requested,
        original_brand_requested, detection_method, brand_confidence,
        product_confidence, customer_request_type, audio_context, created_at
    )
    SELECT
        pt.transaction_id,
        JSON_VALUE(pt.payload_json, '$.interactionId') as interaction_id,
        NULLIF(TRIM(JSON_VALUE(items.value, '$.productName')), '') as product_name,
        NULLIF(TRIM(JSON_VALUE(items.value, '$.brandName')), '') as brand_name,
        NULLIF(TRIM(JSON_VALUE(items.value, '$.genericName')), '') as generic_name,
        NULLIF(TRIM(JSON_VALUE(items.value, '$.localName')), '') as local_name,
        NULLIF(TRIM(JSON_VALUE(items.value, '$.category')), '') as category,
        NULLIF(TRIM(JSON_VALUE(items.value, '$.subcategory')), '') as subcategory,
        NULLIF(TRIM(JSON_VALUE(items.value, '$.sku')), '') as sku,
        COALESCE(TRY_CAST(JSON_VALUE(items.value, '$.quantity') AS INT), 1) as quantity,
        NULLIF(TRIM(JSON_VALUE(items.value, '$.unit')), '') as unit,
        TRY_CAST(JSON_VALUE(items.value, '$.unitPrice') AS DECIMAL(10,2)) as unit_price,
        TRY_CAST(JSON_VALUE(items.value, '$.totalPrice') AS DECIMAL(10,2)) as total_price,
        COALESCE(TRY_CAST(JSON_VALUE(items.value, '$.isSubstitution') AS BIT), 0) as is_substitution,
        JSON_VALUE(items.value, '$.originalProductRequested') as original_product_requested,
        JSON_VALUE(items.value, '$.originalBrandRequested') as original_brand_requested,
        JSON_VALUE(items.value, '$.detectionMethod') as detection_method,
        TRY_CAST(JSON_VALUE(items.value, '$.brandConfidence') AS DECIMAL(3,2)) as brand_confidence,
        TRY_CAST(JSON_VALUE(items.value, '$.confidence') AS DECIMAL(3,2)) as product_confidence,
        JSON_VALUE(items.value, '$.customerRequest.requestType') as customer_request_type,
        COALESCE(JSON_VALUE(items.value, '$.notes'), JSON_VALUE(items.value, '$.audioContext')) as audio_context,
        GETDATE() as created_at
    FROM dbo.PayloadTransactions pt
    CROSS APPLY OPENJSON(pt.payload_json, '$.items') items
    WHERE JSON_VALUE(pt.payload_json, '$.items') IS NOT NULL
      AND JSON_VALUE(items.value, '$.productName') IS NOT NULL;

    SELECT @@ROWCOUNT as items_extracted;
END;
GO

-- ==========================
-- 3. ANALYTICS PROCEDURES
-- ==========================

-- Get tobacco analytics with demographics
CREATE OR ALTER PROCEDURE dbo.sp_GetTobaccoAnalytics
    @StartDate DATETIME2 = NULL,
    @EndDate DATETIME2 = NULL,
    @StoreId VARCHAR(20) = NULL,
    @AgeGroup VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        COUNT(*) as total_transactions,
        COUNT(DISTINCT t.customer_age) as unique_customers,
        AVG(CAST(t.customer_age AS FLOAT)) as avg_customer_age,
        t.customer_gender,
        t.brand_name,
        t.product_type,
        COUNT(CASE WHEN t.is_payday_period = 1 THEN 1 END) as payday_purchases,
        COUNT(CASE WHEN t.purchased_with_alcohol = 1 THEN 1 END) as with_alcohol,
        COUNT(CASE WHEN t.purchased_with_snacks = 1 THEN 1 END) as with_snacks,
        AVG(t.hour_of_day) as avg_purchase_hour,
        STRING_AGG(DISTINCT CAST(t.spoken_terms AS VARCHAR(MAX)), ', ') as common_terms
    FROM dbo.TobaccoAnalytics t
    WHERE (@StartDate IS NULL OR t.purchase_time >= @StartDate)
      AND (@EndDate IS NULL OR t.purchase_time <= @EndDate)
      AND (@StoreId IS NULL OR EXISTS (
          SELECT 1 FROM dbo.TransactionItems ti
          INNER JOIN dbo.PayloadTransactions pt ON ti.transaction_id = pt.transaction_id
          WHERE ti.transaction_id = t.transaction_id AND pt.store_id = @StoreId
      ))
      AND (@AgeGroup IS NULL OR (
          (@AgeGroup = 'young' AND t.customer_age BETWEEN 18 AND 30) OR
          (@AgeGroup = 'adult' AND t.customer_age BETWEEN 31 AND 50) OR
          (@AgeGroup = 'mature' AND t.customer_age > 50)
      ))
    GROUP BY t.customer_gender, t.brand_name, t.product_type
    ORDER BY total_transactions DESC;
END;
GO

-- Get laundry analytics with co-purchase patterns
CREATE OR ALTER PROCEDURE dbo.sp_GetLaundryAnalytics
    @StartDate DATETIME2 = NULL,
    @EndDate DATETIME2 = NULL,
    @StoreId VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        COUNT(*) as total_transactions,
        l.brand_name,
        l.product_type,
        l.size_description,
        AVG(CAST(l.customer_age AS FLOAT)) as avg_customer_age,
        l.customer_gender,
        COUNT(CASE WHEN l.is_payday_period = 1 THEN 1 END) as payday_purchases,
        COUNT(CASE WHEN l.has_detergent = 1 THEN 1 END) as with_detergent,
        COUNT(CASE WHEN l.has_bar_soap = 1 THEN 1 END) as with_bar_soap,
        COUNT(CASE WHEN l.has_fabric_softener = 1 THEN 1 END) as with_fabric_softener,
        STRING_AGG(DISTINCT CAST(l.spoken_terms AS VARCHAR(MAX)), ', ') as common_terms
    FROM dbo.LaundryAnalytics l
    WHERE (@StartDate IS NULL OR l.purchase_time >= @StartDate)
      AND (@EndDate IS NULL OR l.purchase_time <= @EndDate)
      AND (@StoreId IS NULL OR EXISTS (
          SELECT 1 FROM dbo.TransactionItems ti
          INNER JOIN dbo.PayloadTransactions pt ON ti.transaction_id = pt.transaction_id
          WHERE ti.transaction_id = l.transaction_id AND pt.store_id = @StoreId
      ))
    GROUP BY l.brand_name, l.product_type, l.size_description, l.customer_gender
    ORDER BY total_transactions DESC;
END;
GO

-- Get market basket recommendations
CREATE OR ALTER PROCEDURE dbo.sp_GetMarketBasketRecommendations
    @ProductName VARCHAR(200),
    @MinSupport DECIMAL(5,4) = 0.01,
    @MinConfidence DECIMAL(5,4) = 0.3,
    @MinLift DECIMAL(6,2) = 1.1
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 10
        pa.product_b as recommended_product,
        pa.brand_b as recommended_brand,
        pa.category_b as recommended_category,
        pa.support,
        pa.confidence,
        pa.lift,
        pa.transactions_together,
        CONCAT(
            'Customers who buy ', @ProductName, ' also buy ', pa.product_b,
            ' (', FORMAT(pa.confidence, 'P1'), ' of the time)'
        ) as recommendation_text
    FROM dbo.ProductAssociations pa
    WHERE pa.product_a = @ProductName
      AND pa.support >= @MinSupport
      AND pa.confidence >= @MinConfidence
      AND pa.lift >= @MinLift
    ORDER BY pa.lift DESC, pa.confidence DESC;
END;
GO

-- ==========================
-- 4. REPORTING PROCEDURES
-- ==========================

-- Generate store performance report
CREATE OR ALTER PROCEDURE dbo.sp_GetStorePerformanceReport
    @StoreId VARCHAR(20) = NULL,
    @StartDate DATETIME2 = NULL,
    @EndDate DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        pt.store_id,
        COUNT(DISTINCT pt.transaction_id) as total_transactions,
        COUNT(DISTINCT ti.interaction_id) as total_interactions,
        SUM(ti.quantity) as total_items_sold,
        COUNT(DISTINCT ti.brand_name) as unique_brands,
        COUNT(DISTINCT ti.category) as unique_categories,
        AVG(ti.unit_price) as avg_item_price,
        COUNT(CASE WHEN ti.is_substitution = 1 THEN 1 END) as substitutions_made,
        COUNT(CASE WHEN ti.category IN ('Tobacco', 'Cigarettes') THEN 1 END) as tobacco_items,
        COUNT(CASE WHEN ti.category IN ('Laundry', 'Detergent') THEN 1 END) as laundry_items,

        -- Performance metrics
        CAST(COUNT(CASE WHEN ti.is_substitution = 1 THEN 1 END) AS FLOAT) /
        NULLIF(COUNT(*), 0) * 100 as substitution_rate_pct,

        CAST(SUM(ti.quantity) AS FLOAT) /
        NULLIF(COUNT(DISTINCT pt.transaction_id), 0) as avg_items_per_transaction

    FROM dbo.PayloadTransactions pt
    INNER JOIN dbo.TransactionItems ti ON pt.transaction_id = ti.transaction_id
    WHERE (@StoreId IS NULL OR pt.store_id = @StoreId)
      AND (@StartDate IS NULL OR pt.created_at >= @StartDate)
      AND (@EndDate IS NULL OR pt.created_at <= @EndDate)
    GROUP BY pt.store_id
    ORDER BY total_transactions DESC;
END;
GO

-- Generate brand substitution report
CREATE OR ALTER PROCEDURE dbo.sp_GetBrandSubstitutionReport
    @OriginalBrand VARCHAR(100) = NULL,
    @MinOccurrences INT = 5
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        bs.original_brand,
        bs.substituted_brand,
        COUNT(*) as substitution_count,
        AVG(bs.price_difference) as avg_price_impact,
        COUNT(CASE WHEN bs.suggestion_accepted = 1 THEN 1 END) as accepted_count,
        COUNT(CASE WHEN bs.customer_requested = 1 THEN 1 END) as customer_requested_count,

        -- Acceptance rate
        CAST(COUNT(CASE WHEN bs.suggestion_accepted = 1 THEN 1 END) AS FLOAT) /
        NULLIF(COUNT(*), 0) * 100 as acceptance_rate_pct,

        -- Most common reason
        (SELECT TOP 1 substitution_reason
         FROM dbo.BrandSubstitutions bs2
         WHERE bs2.original_brand = bs.original_brand
           AND bs2.substituted_brand = bs.substituted_brand
         GROUP BY substitution_reason
         ORDER BY COUNT(*) DESC) as most_common_reason

    FROM dbo.BrandSubstitutions bs
    WHERE (@OriginalBrand IS NULL OR bs.original_brand = @OriginalBrand)
    GROUP BY bs.original_brand, bs.substituted_brand
    HAVING COUNT(*) >= @MinOccurrences
    ORDER BY substitution_count DESC, acceptance_rate_pct DESC;
END;
GO

-- ==========================
-- 5. MAINTENANCE PROCEDURES
-- ==========================

-- Clean old audit logs
CREATE OR ALTER PROCEDURE dbo.sp_CleanAuditLogs
    @RetentionDays INT = 90
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CutoffDate DATETIME2 = DATEADD(DAY, -@RetentionDays, GETDATE());

    DELETE FROM dbo.VisionAnalysisAudit
    WHERE processing_timestamp < @CutoffDate;

    DELETE FROM dbo.ETLProcessingLog
    WHERE execution_timestamp < @CutoffDate
    AND status = 'success';  -- Keep failed logs longer

    SELECT
        @@ROWCOUNT as records_cleaned,
        @CutoffDate as cutoff_date;
END;
GO

-- Refresh materialized analytics
CREATE OR ALTER PROCEDURE dbo.sp_RefreshAnalytics
AS
BEGIN
    SET NOCOUNT ON;

    -- Recalculate product associations
    EXEC dbo.sp_CalculateProductAssociations;

    -- Update category-specific analytics
    EXEC dbo.sp_ExtractCategoryAnalytics;

    -- Update completion status
    TRUNCATE TABLE dbo.TransactionCompletionStatus;
    INSERT INTO dbo.TransactionCompletionStatus (
        interaction_id, transaction_id, interaction_started,
        selection_made, transaction_completed, interaction_timestamp
    )
    SELECT
        JSON_VALUE(pt.payload_json, '$.interactionId'),
        pt.transaction_id,
        1 as interaction_started,
        CASE WHEN EXISTS (SELECT 1 FROM dbo.TransactionItems ti WHERE ti.transaction_id = pt.transaction_id) THEN 1 ELSE 0 END,
        CASE WHEN TRY_CAST(JSON_VALUE(pt.payload_json, '$.totals.totalAmount') AS DECIMAL) > 0 THEN 1 ELSE 0 END,
        pt.created_at
    FROM dbo.PayloadTransactions pt;

    SELECT 'Analytics refresh complete' as result;
END;
GO

PRINT 'Created 12 stored procedures for Scout Analytics Platform';
PRINT 'ETL: sp_ExecuteCompleteETL, sp_DeduplicateTransactions, sp_ExtractTransactionItems';
PRINT 'Analytics: sp_GetTobaccoAnalytics, sp_GetLaundryAnalytics, sp_GetMarketBasketRecommendations';
PRINT 'Reporting: sp_GetStorePerformanceReport, sp_GetBrandSubstitutionReport';
PRINT 'Maintenance: sp_CleanAuditLogs, sp_RefreshAnalytics';

-- Grant execute permissions (adjust as needed for your security model)
-- GRANT EXECUTE ON dbo.sp_ExecuteCompleteETL TO [scout_etl_role];
-- GRANT EXECUTE ON dbo.sp_GetTobaccoAnalytics TO [scout_analytics_role];
-- GRANT EXECUTE ON dbo.sp_GetLaundryAnalytics TO [scout_analytics_role];
-- Add other GRANT statements as needed