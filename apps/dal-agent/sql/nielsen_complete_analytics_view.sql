-- Nielsen-Enhanced Complete Analytics View
-- Captures ALL 12,192 transactions with Nielsen taxonomy integration
-- Fixes the 6,136 transaction gap caused by strict filtering

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Create enhanced analytics view that includes ALL transactions
CREATE OR ALTER VIEW dbo.v_nielsen_complete_analytics AS
WITH EnhancedTransactions AS (
    SELECT
        v.canonical_tx_id,
        CAST(v.txn_ts AS date) AS transaction_date,
        v.store_id,
        v.store_name,
        COALESCE(v.daypart, 'Unknown') as daypart,

        -- Enhanced brand mapping with Nielsen taxonomy
        CASE
            WHEN NULLIF(LTRIM(RTRIM(v.brand)),'') IS NOT NULL
            THEN LTRIM(RTRIM(v.brand))
            ELSE 'Unknown Brand'
        END AS brand,

        -- Enhanced category mapping with Nielsen fallback
        CASE
            WHEN bcm.brand_name IS NOT NULL AND tc.category_name IS NOT NULL
            THEN tc.category_name  -- Use Nielsen category if mapped
            WHEN NULLIF(LTRIM(RTRIM(v.category)),'') IS NOT NULL
            THEN LTRIM(RTRIM(v.category))  -- Use original category
            ELSE 'Unspecified'  -- Default for missing categories
        END AS category,

        -- Nielsen taxonomy enrichment
        CASE
            WHEN bcm.brand_name IS NOT NULL AND td.department_name IS NOT NULL
            THEN td.department_name
            ELSE 'General Merchandise'  -- Default department
        END AS nielsen_department,

        -- Enhanced category with Nielsen intelligence
        CASE
            WHEN bcm.brand_name IS NOT NULL AND tc.category_name IS NOT NULL
            THEN tc.category_name
            WHEN NULLIF(LTRIM(RTRIM(v.category)),'') IS NOT NULL
            THEN LTRIM(RTRIM(v.category))
            ELSE 'Unspecified'
        END AS enhanced_category,

        TRY_CONVERT(int, v.total_items) as total_items,
        TRY_CONVERT(decimal(18,2), v.total_amount) as total_amount,

        -- Data quality flags
        CASE WHEN v.daypart IS NULL THEN 1 ELSE 0 END as missing_daypart,
        CASE WHEN NULLIF(LTRIM(RTRIM(v.brand)),'') IS NULL THEN 1 ELSE 0 END as missing_brand,
        CASE WHEN NULLIF(LTRIM(RTRIM(v.category)),'') IS NULL THEN 1 ELSE 0 END as missing_category,
        CASE WHEN bcm.brand_name IS NOT NULL THEN 1 ELSE 0 END as nielsen_mapped

    FROM dbo.v_transactions_flat_production v
    LEFT JOIN dbo.BrandCategoryMapping bcm ON LTRIM(RTRIM(v.brand)) = bcm.brand_name
    LEFT JOIN dbo.TaxonomyCategories tc ON bcm.category_id = tc.category_id
    LEFT JOIN dbo.TaxonomyCategoryGroups tcg ON tc.category_group_id = tcg.category_group_id
    LEFT JOIN dbo.TaxonomyDepartments td ON tcg.department_id = td.department_id
)
SELECT
    transaction_date as date,
    store_id,
    store_name,
    daypart,
    brand,
    enhanced_category as category,
    nielsen_department,
    COUNT(*) as txn_count,
    SUM(total_items) as items_sum,
    SUM(total_amount) as amount_sum,

    -- Data quality metrics
    SUM(missing_daypart) as missing_daypart_count,
    SUM(missing_brand) as missing_brand_count,
    SUM(missing_category) as missing_category_count,
    SUM(nielsen_mapped) as nielsen_mapped_count,

    -- Quality percentage
    CAST(SUM(nielsen_mapped) * 100.0 / COUNT(*) AS DECIMAL(5,1)) as nielsen_coverage_pct

FROM EnhancedTransactions
GROUP BY
    transaction_date,
    store_id,
    store_name,
    daypart,
    brand,
    enhanced_category,
    nielsen_department;
GO

PRINT 'Nielsen Complete Analytics View created successfully';

-- Create validation procedure
CREATE OR ALTER PROCEDURE sp_ValidateNielsenCompleteAnalytics
AS
BEGIN
    SET NOCOUNT ON;

    PRINT 'Nielsen Complete Analytics Validation Report';
    PRINT '=============================================';
    PRINT '';

    DECLARE @OriginalTransactions INT, @EnhancedRecords INT, @EnhancedVolume INT;
    DECLARE @UnspecifiedCount INT, @NielsenMappedVolume INT;

    -- Get counts
    SELECT @OriginalTransactions = COUNT(*) FROM v_transactions_flat_production;
    SELECT @EnhancedRecords = COUNT(*) FROM v_nielsen_complete_analytics;
    SELECT @EnhancedVolume = SUM(txn_count) FROM v_nielsen_complete_analytics;
    SELECT @UnspecifiedCount = SUM(txn_count) FROM v_nielsen_complete_analytics WHERE category = 'Unspecified';
    SELECT @NielsenMappedVolume = SUM(nielsen_mapped_count) FROM v_nielsen_complete_analytics;

    PRINT 'Transaction Coverage:';
    PRINT 'Original transactions: ' + CAST(@OriginalTransactions AS NVARCHAR(10));
    PRINT 'Enhanced volume captured: ' + CAST(@EnhancedVolume AS NVARCHAR(10));
    PRINT 'Coverage: ' + CAST((@EnhancedVolume * 100.0 / @OriginalTransactions) AS NVARCHAR(10)) + '%';
    PRINT '';

    PRINT 'Nielsen Integration:';
    PRINT 'Nielsen-mapped transactions: ' + CAST(@NielsenMappedVolume AS NVARCHAR(10));
    PRINT 'Unspecified transactions: ' + CAST(@UnspecifiedCount AS NVARCHAR(10));
    PRINT 'Data quality: ' + CAST(((@EnhancedVolume - @UnspecifiedCount) * 100.0 / @EnhancedVolume) AS NVARCHAR(10)) + '%';
    PRINT '';

    -- Show top categories
    PRINT 'Top Categories by Volume:';
    SELECT TOP 10
        category,
        SUM(txn_count) as transactions,
        CAST(SUM(txn_count) * 100.0 / @EnhancedVolume AS DECIMAL(5,1)) as percentage
    FROM v_nielsen_complete_analytics
    GROUP BY category
    ORDER BY SUM(txn_count) DESC;

END;
GO

PRINT 'Nielsen validation procedure created successfully';