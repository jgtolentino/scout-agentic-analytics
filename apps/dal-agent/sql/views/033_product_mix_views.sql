-- =============================================================================
-- Product Mix & Brand Performance Views
-- Category and brand analysis with Pareto distribution
-- Created: 2025-09-28
-- =============================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- =============================================================================
-- GOLD · Category performance (period-agnostic base)
-- =============================================================================
CREATE OR ALTER VIEW gold.v_product_categories AS
SELECT
    CONVERT(date, si.TransactionDate) AS d,
    ISNULL(p.Category, 'Unknown')     AS category_name,
    COUNT_BIG(*)                      AS tx_count,
    SUM(TRY_CONVERT(decimal(18,2), f.transaction_value)) AS revenue
FROM dbo.SalesInteractions si
LEFT JOIN canonical.SalesInteractionFact f ON f.canonical_tx_id = si.canonical_tx_id
LEFT JOIN dbo.v_flat_export_sheet p        ON p.Transaction_ID     = si.canonical_tx_id
GROUP BY CONVERT(date, si.TransactionDate), ISNULL(p.Category,'Unknown');
GO

-- =============================================================================
-- GOLD · Brand performance analysis
-- =============================================================================
CREATE OR ALTER VIEW gold.v_brand_performance AS
SELECT
    CONVERT(date, si.TransactionDate) AS d,
    ISNULL(b.BrandName, 'Unknown')    AS brand_name,
    COUNT_BIG(*)                      AS tx_count,
    SUM(TRY_CONVERT(decimal(18,2), f.transaction_value)) AS revenue
FROM dbo.SalesInteractions si
LEFT JOIN canonical.SalesInteractionFact f ON f.canonical_tx_id = si.canonical_tx_id
LEFT JOIN dbo.SalesInteractionBrands b     ON b.InteractionID    = si.InteractionID
GROUP BY CONVERT(date, si.TransactionDate), ISNULL(b.BrandName,'Unknown');
GO

-- =============================================================================
-- GOLD · Pareto (80/20) distribution analysis per day
-- =============================================================================
CREATE OR ALTER VIEW gold.v_product_pareto AS
WITH base AS (
    SELECT
        d,
        brand_name,
        revenue,
        ROW_NUMBER() OVER (PARTITION BY d ORDER BY revenue DESC) AS rn,
        SUM(revenue) OVER (PARTITION BY d) AS rev_total
    FROM gold.v_brand_performance
    WHERE revenue > 0
),
acc AS (
    SELECT
        d,
        brand_name,
        revenue,
        rn,
        SUM(revenue) OVER (PARTITION BY d ORDER BY rn) AS rev_cume,
        rev_total
    FROM base
)
SELECT
    d,
    brand_name,
    revenue,
    CASE
        WHEN rev_total > 0 THEN rev_cume / rev_total
        ELSE 0
    END AS cume_share
FROM acc;
GO

-- =============================================================================
-- GOLD · Category market share view
-- =============================================================================
CREATE OR ALTER VIEW gold.v_category_market_share AS
WITH daily_totals AS (
    SELECT d, SUM(revenue) AS total_daily_revenue
    FROM gold.v_product_categories
    GROUP BY d
)
SELECT
    pc.d,
    pc.category_name,
    pc.tx_count,
    pc.revenue,
    CASE
        WHEN dt.total_daily_revenue > 0
        THEN pc.revenue / dt.total_daily_revenue
        ELSE 0
    END AS market_share_pct
FROM gold.v_product_categories pc
INNER JOIN daily_totals dt ON pc.d = dt.d;
GO

-- Product mix and brand performance views created successfully