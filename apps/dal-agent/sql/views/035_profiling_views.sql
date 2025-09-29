-- =============================================================================
-- Consumer Demographic Profiling Views
-- Gender, age, and demographic analysis for consumer insights
-- Created: 2025-09-28
-- =============================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- =============================================================================
-- GOLD · Demographics base analysis
-- =============================================================================
CREATE OR ALTER VIEW gold.v_demographics AS
SELECT
    CONVERT(date, si.TransactionDate) AS d,
    ISNULL(f.gender,'Unknown')        AS gender,
    CASE
        WHEN TRY_CONVERT(int,f.age) BETWEEN 10 AND 17 THEN '10-17'
        WHEN TRY_CONVERT(int,f.age) BETWEEN 18 AND 24 THEN '18-24'
        WHEN TRY_CONVERT(int,f.age) BETWEEN 25 AND 34 THEN '25-34'
        WHEN TRY_CONVERT(int,f.age) BETWEEN 35 AND 44 THEN '35-44'
        WHEN TRY_CONVERT(int,f.age) BETWEEN 45 AND 54 THEN '45-54'
        WHEN TRY_CONVERT(int,f.age) >= 55 THEN '55+'
        ELSE 'Unknown'
    END AS age_band,
    ISNULL(s.Region, 'Unknown') AS region,
    COUNT_BIG(*) AS tx_count,
    SUM(TRY_CONVERT(decimal(18,2), f.transaction_value)) AS revenue,
    AVG(TRY_CONVERT(decimal(18,2), f.transaction_value)) AS avg_transaction_value,
    AVG(TRY_CONVERT(decimal(18,2), f.basket_size)) AS avg_basket_size
FROM dbo.SalesInteractions si
LEFT JOIN canonical.SalesInteractionFact f ON f.canonical_tx_id = si.canonical_tx_id
LEFT JOIN dbo.v_flat_export_sheet p ON p.Transaction_ID = si.canonical_tx_id
LEFT JOIN dbo.Stores s ON s.StoreID = TRY_CONVERT(int, REPLACE(p.Location, 'Store_', ''))
GROUP BY CONVERT(date, si.TransactionDate),
         ISNULL(f.gender,'Unknown'),
         CASE
             WHEN TRY_CONVERT(int,f.age) BETWEEN 10 AND 17 THEN '10-17'
             WHEN TRY_CONVERT(int,f.age) BETWEEN 18 AND 24 THEN '18-24'
             WHEN TRY_CONVERT(int,f.age) BETWEEN 25 AND 34 THEN '25-34'
             WHEN TRY_CONVERT(int,f.age) BETWEEN 35 AND 44 THEN '35-44'
             WHEN TRY_CONVERT(int,f.age) BETWEEN 45 AND 54 THEN '45-54'
             WHEN TRY_CONVERT(int,f.age) >= 55 THEN '55+'
             ELSE 'Unknown'
         END,
         ISNULL(s.Region, 'Unknown');
GO

-- =============================================================================
-- GOLD · Gender-based purchasing patterns
-- =============================================================================
CREATE OR ALTER VIEW gold.v_gender_purchasing_patterns AS
SELECT
    CONVERT(date, si.TransactionDate) AS d,
    ISNULL(f.gender,'Unknown') AS gender,
    ISNULL(b.BrandName, 'Unknown') AS brand_name,
    ISNULL(p.Category, 'Unknown') AS category,
    COUNT_BIG(*) AS purchase_count,
    SUM(TRY_CONVERT(decimal(18,2), f.transaction_value)) AS total_spent,
    AVG(TRY_CONVERT(decimal(18,2), f.transaction_value)) AS avg_transaction_value
FROM dbo.SalesInteractions si
LEFT JOIN canonical.SalesInteractionFact f ON f.canonical_tx_id = si.canonical_tx_id
LEFT JOIN dbo.SalesInteractionBrands b ON b.InteractionID = si.InteractionID
LEFT JOIN dbo.v_flat_export_sheet p ON p.Transaction_ID = si.canonical_tx_id
WHERE f.gender IS NOT NULL AND f.gender != 'Unknown'
GROUP BY CONVERT(date, si.TransactionDate),
         ISNULL(f.gender,'Unknown'),
         ISNULL(b.BrandName, 'Unknown'),
         ISNULL(p.Category, 'Unknown');
GO

-- =============================================================================
-- GOLD · Age cohort analysis
-- =============================================================================
CREATE OR ALTER VIEW gold.v_age_cohort_analysis AS
WITH age_segments AS (
    SELECT
        CONVERT(date, si.TransactionDate) AS d,
        CASE
            WHEN TRY_CONVERT(int,f.age) BETWEEN 18 AND 24 THEN 'Gen Z (18-24)'
            WHEN TRY_CONVERT(int,f.age) BETWEEN 25 AND 34 THEN 'Millennials (25-34)'
            WHEN TRY_CONVERT(int,f.age) BETWEEN 35 AND 44 THEN 'Gen X (35-44)'
            WHEN TRY_CONVERT(int,f.age) BETWEEN 45 AND 54 THEN 'Baby Boomers (45-54)'
            WHEN TRY_CONVERT(int,f.age) >= 55 THEN 'Seniors (55+)'
            ELSE 'Unknown'
        END AS generation,
        COUNT_BIG(*) AS transaction_count,
        SUM(TRY_CONVERT(decimal(18,2), f.transaction_value)) AS total_revenue,
        AVG(TRY_CONVERT(decimal(18,2), f.transaction_value)) AS avg_transaction_value,
        AVG(TRY_CONVERT(decimal(18,2), f.basket_size)) AS avg_basket_size,
        COUNT_BIG(DISTINCT b.BrandName) AS unique_brands_purchased
    FROM dbo.SalesInteractions si
    LEFT JOIN canonical.SalesInteractionFact f ON f.canonical_tx_id = si.canonical_tx_id
    LEFT JOIN dbo.SalesInteractionBrands b ON b.InteractionID = si.InteractionID
    GROUP BY CONVERT(date, si.TransactionDate),
             CASE
                 WHEN TRY_CONVERT(int,f.age) BETWEEN 18 AND 24 THEN 'Gen Z (18-24)'
                 WHEN TRY_CONVERT(int,f.age) BETWEEN 25 AND 34 THEN 'Millennials (25-34)'
                 WHEN TRY_CONVERT(int,f.age) BETWEEN 35 AND 44 THEN 'Gen X (35-44)'
                 WHEN TRY_CONVERT(int,f.age) BETWEEN 45 AND 54 THEN 'Baby Boomers (45-54)'
                 WHEN TRY_CONVERT(int,f.age) >= 55 THEN 'Seniors (55+)'
                 ELSE 'Unknown'
             END
)
SELECT
    d,
    generation,
    transaction_count,
    total_revenue,
    avg_transaction_value,
    avg_basket_size,
    unique_brands_purchased,
    -- Market share calculation
    CASE
        WHEN SUM(transaction_count) OVER (PARTITION BY d) > 0
        THEN CAST(transaction_count AS decimal(10,4)) / SUM(transaction_count) OVER (PARTITION BY d)
        ELSE 0
    END AS market_share_by_transactions
FROM age_segments;
GO

-- =============================================================================
-- GOLD · Regional demographic distribution
-- =============================================================================
CREATE OR ALTER VIEW gold.v_regional_demographics AS
SELECT
    CONVERT(date, si.TransactionDate) AS d,
    ISNULL(s.Region, 'Unknown') AS region,
    ISNULL(s.ProvinceName, 'Unknown') AS province,
    ISNULL(f.gender,'Unknown') AS gender,
    CASE
        WHEN TRY_CONVERT(int,f.age) BETWEEN 18 AND 34 THEN 'Young Adults (18-34)'
        WHEN TRY_CONVERT(int,f.age) BETWEEN 35 AND 54 THEN 'Middle Age (35-54)'
        WHEN TRY_CONVERT(int,f.age) >= 55 THEN 'Mature (55+)'
        ELSE 'Unknown'
    END AS age_segment,
    COUNT_BIG(*) AS customer_count,
    SUM(TRY_CONVERT(decimal(18,2), f.transaction_value)) AS total_spending,
    AVG(TRY_CONVERT(decimal(18,2), f.transaction_value)) AS avg_transaction_value
FROM dbo.SalesInteractions si
LEFT JOIN canonical.SalesInteractionFact f ON f.canonical_tx_id = si.canonical_tx_id
LEFT JOIN dbo.v_flat_export_sheet p ON p.Transaction_ID = si.canonical_tx_id
LEFT JOIN dbo.Stores s ON s.StoreID = TRY_CONVERT(int, REPLACE(p.Location, 'Store_', ''))
GROUP BY CONVERT(date, si.TransactionDate),
         ISNULL(s.Region, 'Unknown'),
         ISNULL(s.ProvinceName, 'Unknown'),
         ISNULL(f.gender,'Unknown'),
         CASE
             WHEN TRY_CONVERT(int,f.age) BETWEEN 18 AND 34 THEN 'Young Adults (18-34)'
             WHEN TRY_CONVERT(int,f.age) BETWEEN 35 AND 54 THEN 'Middle Age (35-54)'
             WHEN TRY_CONVERT(int,f.age) >= 55 THEN 'Mature (55+)'
             ELSE 'Unknown'
         END;
GO

-- =============================================================================
-- GOLD · Customer lifetime value estimation
-- =============================================================================
CREATE OR ALTER VIEW gold.v_customer_lifetime_patterns AS
WITH customer_metrics AS (
    SELECT
        ISNULL(f.gender,'Unknown') AS gender,
        CASE
            WHEN TRY_CONVERT(int,f.age) BETWEEN 18 AND 24 THEN '18-24'
            WHEN TRY_CONVERT(int,f.age) BETWEEN 25 AND 34 THEN '25-34'
            WHEN TRY_CONVERT(int,f.age) BETWEEN 35 AND 44 THEN '35-44'
            WHEN TRY_CONVERT(int,f.age) BETWEEN 45 AND 54 THEN '45-54'
            WHEN TRY_CONVERT(int,f.age) >= 55 THEN '55+'
            ELSE 'Unknown'
        END AS age_band,
        COUNT_BIG(*) AS total_transactions,
        SUM(TRY_CONVERT(decimal(18,2), f.transaction_value)) AS total_revenue,
        AVG(TRY_CONVERT(decimal(18,2), f.transaction_value)) AS avg_transaction_value,
        MIN(si.TransactionDate) AS first_transaction,
        MAX(si.TransactionDate) AS last_transaction,
        DATEDIFF(DAY, MIN(si.TransactionDate), MAX(si.TransactionDate)) AS customer_lifespan_days
    FROM dbo.SalesInteractions si
    LEFT JOIN canonical.SalesInteractionFact f ON f.canonical_tx_id = si.canonical_tx_id
    GROUP BY ISNULL(f.gender,'Unknown'),
             CASE
                 WHEN TRY_CONVERT(int,f.age) BETWEEN 18 AND 24 THEN '18-24'
                 WHEN TRY_CONVERT(int,f.age) BETWEEN 25 AND 34 THEN '25-34'
                 WHEN TRY_CONVERT(int,f.age) BETWEEN 35 AND 44 THEN '35-44'
                 WHEN TRY_CONVERT(int,f.age) BETWEEN 45 AND 54 THEN '45-54'
                 WHEN TRY_CONVERT(int,f.age) >= 55 THEN '55+'
                 ELSE 'Unknown'
             END
)
SELECT
    gender,
    age_band,
    total_transactions,
    total_revenue,
    avg_transaction_value,
    first_transaction,
    last_transaction,
    customer_lifespan_days,
    CASE
        WHEN customer_lifespan_days > 0
        THEN total_transactions * 1.0 / customer_lifespan_days * 30  -- Transactions per month
        ELSE 0
    END AS estimated_monthly_frequency,
    CASE
        WHEN customer_lifespan_days > 0
        THEN total_revenue / customer_lifespan_days * 365  -- Annualized revenue
        ELSE total_revenue
    END AS estimated_annual_value
FROM customer_metrics;
GO

-- =============================================================================
-- GOLD · Enhanced demographics with comprehensive brand catalog
-- =============================================================================
CREATE OR ALTER VIEW gold.v_demographics_with_brands AS
SELECT
    CONVERT(date, si.TransactionDate) AS d,
    ISNULL(f.gender,'Unknown') AS gender,
    CASE
        WHEN TRY_CONVERT(int,f.age) BETWEEN 10 AND 17 THEN '10-17'
        WHEN TRY_CONVERT(int,f.age) BETWEEN 18 AND 24 THEN '18-24'
        WHEN TRY_CONVERT(int,f.age) BETWEEN 25 AND 34 THEN '25-34'
        WHEN TRY_CONVERT(int,f.age) BETWEEN 35 AND 44 THEN '35-44'
        WHEN TRY_CONVERT(int,f.age) BETWEEN 45 AND 54 THEN '45-54'
        WHEN TRY_CONVERT(int,f.age) >= 55 THEN '55+'
        ELSE 'Unknown'
    END AS age_band,
    ISNULL(s.Region, 'Unknown') AS region,
    ISNULL(s.ProvinceName, 'Unknown') AS province,
    ISNULL(s.MunicipalityName, 'Unknown') AS city,

    -- Brand information from SalesInteractionBrands
    ISNULL(sib.BrandName, 'Unknown') AS brand_name,
    ISNULL(sib.Confidence, 0) AS brand_confidence,
    ISNULL(sib.Source, 'Unknown') AS brand_source,

    -- Brand catalog information
    ISNULL(bc.category, 'Unknown') AS brand_category,
    ISNULL(bc.data_quality, 'Unknown') AS brand_data_quality,
    bc.total_transactions AS brand_total_transactions,
    bc.total_sales AS brand_total_sales,

    COUNT_BIG(*) AS tx_count,
    SUM(TRY_CONVERT(decimal(18,2), f.transaction_value)) AS revenue,
    AVG(TRY_CONVERT(decimal(18,2), f.transaction_value)) AS avg_transaction_value,
    AVG(TRY_CONVERT(decimal(18,2), f.basket_size)) AS avg_basket_size

FROM dbo.SalesInteractions si
LEFT JOIN canonical.SalesInteractionFact f ON f.canonical_tx_id = si.canonical_tx_id
LEFT JOIN dbo.v_flat_export_sheet p ON p.Transaction_ID = si.canonical_tx_id
LEFT JOIN dbo.Stores s ON s.StoreID = TRY_CONVERT(int, REPLACE(p.Location, 'Store_', ''))
LEFT JOIN dbo.SalesInteractionBrands sib ON sib.InteractionID = si.InteractionID
LEFT JOIN dbo.brand_sku_catalog bc ON bc.brand_name = sib.BrandName

GROUP BY CONVERT(date, si.TransactionDate),
         ISNULL(f.gender,'Unknown'),
         CASE
             WHEN TRY_CONVERT(int,f.age) BETWEEN 10 AND 17 THEN '10-17'
             WHEN TRY_CONVERT(int,f.age) BETWEEN 18 AND 24 THEN '18-24'
             WHEN TRY_CONVERT(int,f.age) BETWEEN 25 AND 34 THEN '25-34'
             WHEN TRY_CONVERT(int,f.age) BETWEEN 35 AND 44 THEN '35-44'
             WHEN TRY_CONVERT(int,f.age) BETWEEN 45 AND 54 THEN '45-54'
             WHEN TRY_CONVERT(int,f.age) >= 55 THEN '55+'
             ELSE 'Unknown'
         END,
         ISNULL(s.Region, 'Unknown'),
         ISNULL(s.ProvinceName, 'Unknown'),
         ISNULL(s.MunicipalityName, 'Unknown'),
         ISNULL(sib.BrandName, 'Unknown'),
         ISNULL(sib.Confidence, 0),
         ISNULL(sib.Source, 'Unknown'),
         ISNULL(bc.category, 'Unknown'),
         ISNULL(bc.data_quality, 'Unknown'),
         bc.total_transactions,
         bc.total_sales;
GO

-- =============================================================================
-- GOLD · Brand performance by demographics
-- =============================================================================
CREATE OR ALTER VIEW gold.v_brand_demographics_performance AS
SELECT
    bc.brand_name,
    bc.category AS brand_category,
    bc.total_transactions AS catalog_transactions,
    bc.total_sales AS catalog_sales,
    bc.data_quality AS brand_data_quality,

    -- Demographic breakdown
    COUNT(CASE WHEN f.gender = 'Male' THEN 1 END) AS male_customers,
    COUNT(CASE WHEN f.gender = 'Female' THEN 1 END) AS female_customers,
    COUNT(CASE WHEN TRY_CONVERT(int,f.age) BETWEEN 18 AND 34 THEN 1 END) AS young_adults,
    COUNT(CASE WHEN TRY_CONVERT(int,f.age) BETWEEN 35 AND 54 THEN 1 END) AS middle_age,
    COUNT(CASE WHEN TRY_CONVERT(int,f.age) >= 55 THEN 1 END) AS mature_adults,

    -- Regional breakdown
    COUNT(CASE WHEN s.Region = 'NCR' THEN 1 END) AS ncr_customers,
    COUNT(CASE WHEN s.Region != 'NCR' AND s.Region IS NOT NULL THEN 1 END) AS provincial_customers,

    -- Performance metrics
    COUNT_BIG(*) AS total_interactions,
    SUM(TRY_CONVERT(decimal(18,2), f.transaction_value)) AS total_revenue,
    AVG(TRY_CONVERT(decimal(18,2), f.transaction_value)) AS avg_transaction_value,
    AVG(sib.Confidence) AS avg_brand_confidence

FROM dbo.brand_sku_catalog bc
LEFT JOIN dbo.SalesInteractionBrands sib ON sib.BrandName = bc.brand_name
LEFT JOIN dbo.SalesInteractions si ON si.InteractionID = sib.InteractionID
LEFT JOIN canonical.SalesInteractionFact f ON f.canonical_tx_id = si.canonical_tx_id
LEFT JOIN dbo.v_flat_export_sheet p ON p.Transaction_ID = si.canonical_tx_id
LEFT JOIN dbo.Stores s ON s.StoreID = TRY_CONVERT(int, REPLACE(p.Location, 'Store_', ''))

GROUP BY bc.brand_name, bc.category, bc.total_transactions, bc.total_sales, bc.data_quality;
GO

PRINT 'Consumer demographic profiling views with brand integration created successfully.';