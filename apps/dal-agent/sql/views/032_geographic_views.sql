-- =============================================================================
-- Geographic Dashboard Views
-- Temporal aggregations for geographic analysis (daily, weekly, monthly)
-- Created: 2025-09-28
-- =============================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- =============================================================================
-- GOLD · Geographic base view (daily transactions by region/province)
-- Uses flat export sheet for geographic data since canonical table doesn't have region/province
-- =============================================================================
CREATE OR ALTER VIEW gold.v_geo_daily AS
SELECT
    CONVERT(date, si.TransactionDate) AS d,
    ISNULL(s.Region, 'Unknown') AS region,
    ISNULL(s.ProvinceName, 'Unknown') AS province,
    ISNULL(s.MunicipalityName, 'Unknown') AS city,
    COUNT_BIG(*) AS tx_count,
    SUM(TRY_CONVERT(decimal(18,2), f.transaction_value)) AS revenue
FROM dbo.SalesInteractions si
LEFT JOIN canonical.SalesInteractionFact f ON f.canonical_tx_id = si.canonical_tx_id
LEFT JOIN dbo.v_flat_export_sheet p ON p.Transaction_ID = si.canonical_tx_id
LEFT JOIN dbo.Stores s ON s.StoreID = TRY_CONVERT(int, REPLACE(p.Location, 'Store_', ''))
GROUP BY CONVERT(date, si.TransactionDate),
         ISNULL(s.Region, 'Unknown'),
         ISNULL(s.ProvinceName, 'Unknown'),
         ISNULL(s.MunicipalityName, 'Unknown');
GO

-- =============================================================================
-- GOLD · Weekly geographic aggregation
-- =============================================================================
CREATE OR ALTER VIEW gold.v_geo_weekly AS
SELECT
    DATEPART(WEEK, d) AS wk,
    YEAR(d) AS yr,
    region,
    province,
    city,
    SUM(tx_count) AS tx_count,
    SUM(revenue) AS revenue
FROM gold.v_geo_daily
GROUP BY DATEPART(WEEK, d), YEAR(d), region, province, city;
GO

-- =============================================================================
-- GOLD · Monthly geographic aggregation
-- =============================================================================
CREATE OR ALTER VIEW gold.v_geo_monthly AS
SELECT
    FORMAT(d,'yyyy-MM') AS ym,
    region,
    province,
    city,
    SUM(tx_count) AS tx_count,
    SUM(revenue) AS revenue
FROM gold.v_geo_daily
GROUP BY FORMAT(d,'yyyy-MM'), region, province, city;
GO

-- Geographic dashboard views created successfully