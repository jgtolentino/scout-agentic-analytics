-- =====================================================
-- NIELSEN TAXONOMY INTEGRATION: Silver Layer Enhancement
-- Applies Nielsen 6-level taxonomy to transaction items
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- =====================================================
-- Nielsen taxonomy mapping procedure for Silver layer
-- =====================================================

CREATE OR ALTER PROCEDURE dbo.sp_ApplyNielsenMappingToSilver
AS
BEGIN
    SET NOCOUNT ON;

    PRINT 'Applying Nielsen taxonomy mapping to silver.transaction_items...';

    -- Update existing transaction items with Nielsen taxonomy
    UPDATE sti
    SET
        nielsen_category_l1 = nt.Level1_Name,
        nielsen_category_l2 = nt.Level2_Name,
        nielsen_category_l3 = nt.Level3_Name,
        nielsen_brand_name = bm.nielsen_brand_name,
        nielsen_brand_id = bm.nielsen_brand_id
    FROM silver.transaction_items sti
    LEFT JOIN dbo.BrandToNielsenMapping bm
        ON LOWER(TRIM(sti.item_brand)) = LOWER(TRIM(bm.scout_brand_name))
    LEFT JOIN dbo.NielsenTaxonomy nt
        ON bm.nielsen_brand_id = nt.Brand_ID
    WHERE sti.nielsen_category_l1 IS NULL;  -- Only update unmapped items

    DECLARE @updated_count INT = @@ROWCOUNT;

    -- Handle unmapped brands by category matching
    UPDATE sti
    SET
        nielsen_category_l1 = nt.Level1_Name,
        nielsen_category_l2 = nt.Level2_Name,
        nielsen_category_l3 = nt.Level3_Name,
        nielsen_brand_name = 'Generic',
        nielsen_brand_id = CONCAT('GEN_', UPPER(LEFT(sti.item_category, 3)))
    FROM silver.transaction_items sti
    LEFT JOIN dbo.NielsenTaxonomy nt
        ON LOWER(TRIM(sti.item_category)) LIKE '%' + LOWER(TRIM(nt.Level3_Name)) + '%'
        OR LOWER(TRIM(sti.item_category)) LIKE '%' + LOWER(TRIM(nt.Level2_Name)) + '%'
    WHERE sti.nielsen_category_l1 IS NULL  -- Still unmapped after brand matching
    AND nt.Level1_Name IS NOT NULL;

    SET @updated_count = @updated_count + @@ROWCOUNT;

    -- Final fallback for completely unmapped items
    UPDATE silver.transaction_items
    SET
        nielsen_category_l1 = 'Unspecified',
        nielsen_category_l2 = 'Unspecified',
        nielsen_category_l3 = 'Other Products',
        nielsen_brand_name = 'Unknown',
        nielsen_brand_id = 'UNK_001'
    WHERE nielsen_category_l1 IS NULL;

    SET @updated_count = @updated_count + @@ROWCOUNT;

    PRINT CONCAT('Applied Nielsen mapping to ', @updated_count, ' transaction items');
END;
GO

-- =====================================================
-- Enhanced Gold layer with Nielsen analytics
-- =====================================================

-- Nielsen category performance metrics
IF EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('gold') AND name = 'nielsen_category_metrics')
BEGIN
    DROP TABLE gold.nielsen_category_metrics;
END

CREATE TABLE gold.nielsen_category_metrics (
    metric_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    nielsen_level1 NVARCHAR(200),
    nielsen_level2 NVARCHAR(200),
    nielsen_level3 NVARCHAR(200),
    metric_date DATE,

    -- Transaction metrics
    transaction_count INT,
    total_revenue DECIMAL(15,2),
    avg_transaction_value DECIMAL(10,2),
    total_quantity INT,
    unique_customers INT,

    -- Market share
    category_market_share DECIMAL(8,4),          -- % of total revenue
    transaction_share DECIMAL(8,4),              -- % of total transactions
    customer_penetration DECIMAL(8,4),           -- % of total customers

    -- Customer demographics for this category
    avg_customer_age DECIMAL(8,2),
    gender_distribution NVARCHAR(200),           -- JSON: {"Male": %, "Female": %}
    age_distribution NVARCHAR(500),              -- JSON: {"18-25": %, "26-35": %, etc.}

    -- Geographic distribution
    region_distribution NVARCHAR(MAX),           -- JSON with region performance
    top_performing_region NVARCHAR(100),

    -- Temporal patterns
    time_bucket_distribution NVARCHAR(500),      -- JSON with morning/afternoon/evening/night
    weekday_vs_weekend_ratio DECIMAL(8,4),

    -- Cross-category insights
    frequently_bought_with NVARCHAR(MAX),        -- JSON array of other categories
    substitution_risk_score DECIMAL(8,4),        -- How often customers switch away

    created_at DATETIME2 DEFAULT GETUTCDATE(),

    INDEX idx_gold_nielsen_l1 (nielsen_level1, metric_date DESC),
    INDEX idx_gold_nielsen_revenue (total_revenue DESC),
    INDEX idx_gold_nielsen_date (metric_date DESC)
) WITH (DATA_COMPRESSION = PAGE);
PRINT 'Created table: gold.nielsen_category_metrics';

-- Nielsen brand performance within categories
IF EXISTS (SELECT * FROM sys.tables WHERE schema_id = SCHEMA_ID('gold') AND name = 'nielsen_brand_metrics')
BEGIN
    DROP TABLE gold.nielsen_brand_metrics;
END

CREATE TABLE gold.nielsen_brand_metrics (
    metric_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    nielsen_brand_id NVARCHAR(50),
    nielsen_brand_name NVARCHAR(200),
    nielsen_category_l1 NVARCHAR(200),
    nielsen_category_l2 NVARCHAR(200),
    metric_date DATE,

    -- Performance metrics
    transaction_count INT,
    total_revenue DECIMAL(15,2),
    total_quantity INT,
    avg_price_per_unit DECIMAL(10,2),

    -- Market position within category
    category_share DECIMAL(8,4),                 -- Share within Nielsen category
    rank_in_category INT,                        -- 1 = top brand in category
    brand_loyalty_index DECIMAL(8,4),            -- How often customers rebuy this brand

    -- Customer profile
    primary_customer_age_group NVARCHAR(20),
    primary_customer_gender NVARCHAR(10),
    customer_affluence_index DECIMAL(8,4),       -- Based on avg transaction values

    -- Competitive analysis
    main_competitor_brand NVARCHAR(200),
    competitive_pressure_score DECIMAL(8,4),     -- How much competition exists
    price_premium_vs_category DECIMAL(8,4),      -- Price vs category average

    created_at DATETIME2 DEFAULT GETUTCDATE(),

    INDEX idx_gold_brand_category (nielsen_category_l1, category_share DESC),
    INDEX idx_gold_brand_performance (total_revenue DESC),
    INDEX idx_gold_brand_date (metric_date DESC)
) WITH (DATA_COMPRESSION = PAGE);
PRINT 'Created table: gold.nielsen_brand_metrics';

-- Procedure to populate Nielsen metrics
CREATE OR ALTER PROCEDURE dbo.sp_PopulateNielsenMetrics
    @TargetDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @TargetDate IS NULL
        SET @TargetDate = CAST(GETUTCDATE() AS DATE);

    PRINT CONCAT('Populating Nielsen metrics for date: ', @TargetDate);

    -- Populate Nielsen category metrics
    INSERT INTO gold.nielsen_category_metrics (
        nielsen_level1, nielsen_level2, nielsen_level3, metric_date,
        transaction_count, total_revenue, avg_transaction_value, total_quantity,
        unique_customers, category_market_share, transaction_share,
        avg_customer_age, gender_distribution, region_distribution
    )
    SELECT
        sti.nielsen_category_l1,
        sti.nielsen_category_l2,
        sti.nielsen_category_l3,
        st.transaction_date,

        -- Transaction metrics
        COUNT(DISTINCT st.canonical_tx_id) as transaction_count,
        SUM(sti.item_total) as total_revenue,
        AVG(sti.item_total) as avg_transaction_value,
        SUM(sti.item_quantity) as total_quantity,
        COUNT(DISTINCT st.customer_facial_id) as unique_customers,

        -- Market share calculations
        CAST(SUM(sti.item_total) * 100.0 / SUM(SUM(sti.item_total)) OVER() AS DECIMAL(8,4)) as category_market_share,
        CAST(COUNT(DISTINCT st.canonical_tx_id) * 100.0 / SUM(COUNT(DISTINCT st.canonical_tx_id)) OVER() AS DECIMAL(8,4)) as transaction_share,

        -- Demographics
        AVG(CAST(st.customer_age AS FLOAT)) as avg_customer_age,
        (
            SELECT
                CONCAT('{"Male":',
                       CAST(COUNT(CASE WHEN st2.customer_gender = 'Male' THEN 1 END) * 100.0 / COUNT(*) AS INT),
                       ',"Female":',
                       CAST(COUNT(CASE WHEN st2.customer_gender = 'Female' THEN 1 END) * 100.0 / COUNT(*) AS INT),
                       '}')
            FROM silver.transactions st2
            INNER JOIN silver.transaction_items sti2 ON st2.canonical_tx_id = sti2.canonical_tx_id
            WHERE st2.transaction_date = @TargetDate
            AND sti2.nielsen_category_l1 = sti.nielsen_category_l1
        ) as gender_distribution,

        -- Region distribution
        (
            SELECT
                CONCAT('[', STRING_AGG(
                    CONCAT('{"region":"', ss.region, '","revenue":', SUM(sti3.item_total), '}'), ','
                ), ']')
            FROM silver.transactions st3
            INNER JOIN silver.transaction_items sti3 ON st3.canonical_tx_id = sti3.canonical_tx_id
            INNER JOIN silver.stores ss ON st3.store_id = ss.store_id
            WHERE st3.transaction_date = @TargetDate
            AND sti3.nielsen_category_l1 = sti.nielsen_category_l1
            GROUP BY ss.region
        ) as region_distribution

    FROM silver.transactions st
    INNER JOIN silver.transaction_items sti ON st.canonical_tx_id = sti.canonical_tx_id
    WHERE st.transaction_date = @TargetDate
    AND sti.nielsen_category_l1 IS NOT NULL
    GROUP BY sti.nielsen_category_l1, sti.nielsen_category_l2, sti.nielsen_category_l3, st.transaction_date;

    DECLARE @category_count INT = @@ROWCOUNT;

    -- Populate Nielsen brand metrics
    INSERT INTO gold.nielsen_brand_metrics (
        nielsen_brand_id, nielsen_brand_name, nielsen_category_l1, nielsen_category_l2,
        metric_date, transaction_count, total_revenue, total_quantity,
        avg_price_per_unit, category_share, rank_in_category,
        primary_customer_age_group, primary_customer_gender
    )
    SELECT
        sti.nielsen_brand_id,
        sti.nielsen_brand_name,
        sti.nielsen_category_l1,
        sti.nielsen_category_l2,
        st.transaction_date,

        -- Performance metrics
        COUNT(DISTINCT st.canonical_tx_id) as transaction_count,
        SUM(sti.item_total) as total_revenue,
        SUM(sti.item_quantity) as total_quantity,
        AVG(sti.unit_price) as avg_price_per_unit,

        -- Category share
        CAST(SUM(sti.item_total) * 100.0 / SUM(SUM(sti.item_total)) OVER(PARTITION BY sti.nielsen_category_l1) AS DECIMAL(8,4)) as category_share,
        ROW_NUMBER() OVER(PARTITION BY sti.nielsen_category_l1 ORDER BY SUM(sti.item_total) DESC) as rank_in_category,

        -- Customer demographics
        (
            SELECT TOP 1
                CASE
                    WHEN st2.customer_age BETWEEN 18 AND 25 THEN '18-25'
                    WHEN st2.customer_age BETWEEN 26 AND 35 THEN '26-35'
                    WHEN st2.customer_age BETWEEN 36 AND 45 THEN '36-45'
                    WHEN st2.customer_age BETWEEN 46 AND 55 THEN '46-55'
                    ELSE '55+'
                END
            FROM silver.transactions st2
            INNER JOIN silver.transaction_items sti2 ON st2.canonical_tx_id = sti2.canonical_tx_id
            WHERE st2.transaction_date = @TargetDate
            AND sti2.nielsen_brand_id = sti.nielsen_brand_id
            GROUP BY
                CASE
                    WHEN st2.customer_age BETWEEN 18 AND 25 THEN '18-25'
                    WHEN st2.customer_age BETWEEN 26 AND 35 THEN '26-35'
                    WHEN st2.customer_age BETWEEN 36 AND 45 THEN '36-45'
                    WHEN st2.customer_age BETWEEN 46 AND 55 THEN '46-55'
                    ELSE '55+'
                END
            ORDER BY COUNT(*) DESC
        ) as primary_customer_age_group,

        (
            SELECT TOP 1 st2.customer_gender
            FROM silver.transactions st2
            INNER JOIN silver.transaction_items sti2 ON st2.canonical_tx_id = sti2.canonical_tx_id
            WHERE st2.transaction_date = @TargetDate
            AND sti2.nielsen_brand_id = sti.nielsen_brand_id
            GROUP BY st2.customer_gender
            ORDER BY COUNT(*) DESC
        ) as primary_customer_gender

    FROM silver.transactions st
    INNER JOIN silver.transaction_items sti ON st.canonical_tx_id = sti.canonical_tx_id
    WHERE st.transaction_date = @TargetDate
    AND sti.nielsen_brand_id IS NOT NULL
    GROUP BY
        sti.nielsen_brand_id, sti.nielsen_brand_name,
        sti.nielsen_category_l1, sti.nielsen_category_l2,
        st.transaction_date;

    DECLARE @brand_count INT = @@ROWCOUNT;

    PRINT CONCAT('Populated ', @category_count, ' Nielsen category metrics');
    PRINT CONCAT('Populated ', @brand_count, ' Nielsen brand metrics');
END;
GO

-- =====================================================
-- Enhanced flattened export with Nielsen taxonomy
-- =====================================================

CREATE OR ALTER VIEW dbo.v_nielsen_enhanced_flat_export AS
SELECT
    -- Core transaction identity
    st.canonical_tx_id as Transaction_ID,
    sti.item_total as Transaction_Value,
    st.item_count as Basket_Size,

    -- Nielsen taxonomy (standardized categories)
    sti.nielsen_category_l1 as Category_L1,
    sti.nielsen_category_l2 as Category_L2,
    sti.nielsen_category_l3 as Category_L3,
    sti.nielsen_brand_name as Brand,

    -- Time dimensions
    CASE
        WHEN DATEPART(hour, st.created_date) BETWEEN 6 AND 11 THEN 'Morning'
        WHEN DATEPART(hour, st.created_date) BETWEEN 12 AND 17 THEN 'Afternoon'
        WHEN DATEPART(hour, st.created_date) BETWEEN 18 AND 21 THEN 'Evening'
        ELSE 'Night'
    END as Daypart,

    -- Demographics (standardized)
    st.demographics_combined as Demographics_Age_Gender_Role,

    -- Week classification
    CASE
        WHEN DATEPART(weekday, st.transaction_date) IN (1, 7) THEN 'Weekend'
        ELSE 'Weekday'
    END as Weekday_vs_Weekend,

    -- Transaction time
    CAST(st.created_date AS TIME) as Time_of_Transaction,

    -- Location (hierarchical)
    CONCAT(ss.region, ' > ', ss.province, ' > ', ss.city, ' > ', ss.barangay) as Location,

    -- Market basket (other items in same transaction)
    (
        SELECT STRING_AGG(
            CONCAT(sti2.nielsen_brand_name, ' (', sti2.nielsen_category_l2, ')'),
            ', '
        )
        FROM silver.transaction_items sti2
        WHERE sti2.canonical_tx_id = st.canonical_tx_id
        AND sti2.item_id != sti.item_id
    ) as Other_Products,

    -- Substitution analysis
    CASE
        WHEN EXISTS (
            SELECT 1 FROM gold.substitution_patterns sp
            WHERE sp.from_sku = sti.sku_code
            OR sp.to_sku = sti.sku_code
        ) THEN 1
        ELSE 0
    END as Was_Substitution,

    -- Export metadata
    GETUTCDATE() as Export_Timestamp,

    -- Nielsen-specific fields
    sti.nielsen_brand_id as Nielsen_Brand_ID,
    ncm.category_market_share as Category_Market_Share,
    ncm.rank_in_category as Brand_Rank_In_Category,
    st.conversation_score as Conversation_Intelligence_Score

FROM silver.transactions st
INNER JOIN silver.transaction_items sti ON st.canonical_tx_id = sti.canonical_tx_id
LEFT JOIN silver.stores ss ON st.store_id = ss.store_id
LEFT JOIN gold.nielsen_brand_metrics ncm ON sti.nielsen_brand_id = ncm.nielsen_brand_id
    AND st.transaction_date = ncm.metric_date
WHERE st.json_extraction_success = 1
  AND sti.nielsen_category_l1 IS NOT NULL;
GO

PRINT '======================================';
PRINT 'NIELSEN INTEGRATION COMPLETE!';
PRINT '======================================';
PRINT 'Enhanced Features:';
PRINT '✅ Nielsen taxonomy mapping in Silver layer';
PRINT '✅ Nielsen category performance metrics';
PRINT '✅ Nielsen brand performance tracking';
PRINT '✅ Enhanced flat export with Nielsen fields';
PRINT '✅ Market share and competitive analysis';
PRINT '✅ Demographic and geographic insights by Nielsen category';
PRINT '';
PRINT 'Execute Nielsen mapping: EXEC dbo.sp_ApplyNielsenMappingToSilver';
PRINT 'Populate metrics: EXEC dbo.sp_PopulateNielsenMetrics';