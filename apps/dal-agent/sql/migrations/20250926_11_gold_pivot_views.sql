SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
 * Gold Pivot Views for Excel Integration
 * Nielsen taxonomy-backed views that export CSV files for Excel pivot tables
 *
 * Creates views compatible with existing Excel workbook structure:
 * - scout_default_view (main transaction lines)
 * - category_lookup_reference (Nielsen taxonomy reference)
 * - category_brand (aggregated category/brand analysis)
 * - tobacco (tobacco category analysis)
 * - laundry (laundry category analysis)
 */

PRINT 'Creating gold pivot views for Excel integration...';

-- Ensure gold schema exists
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name=N'gold')
    EXEC('CREATE SCHEMA gold');
GO

-- Main default view compatible with Excel "scout_default_view" sheet
CREATE OR ALTER VIEW gold.v_pivot_default
AS
SELECT
    -- Core transaction identification
    t.canonical_tx_id AS transaction_id,
    s.store_code AS storeid,                          -- String store code for Excel

    -- Nielsen category (replaces "category (wrong)")
    COALESCE(n.taxonomy_name, 'Unspecified') AS category,

    -- Product and brand information
    COALESCE(b.brand_name, 'Unknown Brand') AS brand,
    COALESCE(p.product_name, 'Unknown Product') AS product,

    -- Payment method (placeholder for future expansion)
    CAST(NULL AS varchar(32)) AS payment_method,

    -- Transaction details
    COALESCE(i.quantity, 1) AS qty,
    COALESCE(i.unit_price, 0.00) AS unit_price,
    COALESCE(i.line_amount, 0.00) AS total_price,

    -- Additional fields for pivot flexibility
    COALESCE(b.brand_name, 'Unknown Brand') AS brand_raw,
    t.txn_ts AS transaction_date,
    n.level AS nielsen_level,
    n.taxonomy_code AS nielsen_code
FROM dbo.TransactionItems i
JOIN dbo.Transactions t ON t.canonical_tx_id = i.canonical_tx_id
LEFT JOIN dbo.Products p ON p.product_id = i.product_id
LEFT JOIN dbo.Brands b ON b.brand_id = p.brand_id
LEFT JOIN dbo.Stores s ON s.store_id = t.store_id
LEFT JOIN ref.ProductNielsenMap m ON m.product_id = p.product_id
LEFT JOIN ref.NielsenTaxonomy n ON n.taxonomy_id = m.taxonomy_id AND n.level = 3;
GO

-- Category and brand aggregated view
CREATE OR ALTER VIEW gold.v_pivot_category_brand
AS
SELECT
    COALESCE(n.taxonomy_name, 'Unspecified') AS category,
    COALESCE(b.brand_name, 'Unknown Brand') AS brand,
    COUNT_BIG(*) AS line_count,
    COUNT_BIG(DISTINCT t.canonical_tx_id) AS transaction_count,
    SUM(COALESCE(i.quantity, 1)) AS total_qty,
    SUM(COALESCE(i.line_amount, 0.00)) AS total_sales,
    AVG(COALESCE(i.line_amount, 0.00)) AS avg_line_amount,
    AVG(COALESCE(i.unit_price, 0.00)) AS avg_unit_price
FROM dbo.TransactionItems i
JOIN dbo.Transactions t ON t.canonical_tx_id = i.canonical_tx_id
LEFT JOIN dbo.Products p ON p.product_id = i.product_id
LEFT JOIN dbo.Brands b ON b.brand_id = p.brand_id
LEFT JOIN ref.ProductNielsenMap m ON m.product_id = p.product_id
LEFT JOIN ref.NielsenTaxonomy n ON n.taxonomy_id = m.taxonomy_id AND n.level = 3
GROUP BY n.taxonomy_name, b.brand_name;
GO

-- Tobacco category slice for tobacco-specific pivot analysis
CREATE OR ALTER VIEW gold.v_pivot_tobacco
AS
SELECT
    DATENAME(weekday, t.txn_ts) AS weekday,
    COALESCE(n.taxonomy_name, 'Unspecified') AS tobacco_category,
    COUNT_BIG(*) AS transactions,
    COUNT_BIG(DISTINCT t.canonical_tx_id) AS unique_transactions,
    SUM(COALESCE(i.quantity, 1)) AS total_qty,
    AVG(COALESCE(i.quantity, 1)) AS avg_qty,
    SUM(COALESCE(i.line_amount, 0.00)) AS total_sales,
    AVG(COALESCE(i.line_amount, 0.00)) AS avg_total_price,
    AVG(COALESCE(i.unit_price, 0.00)) AS avg_unit_price,
    -- Time-based analysis
    DATEPART(hour, t.txn_ts) AS hour_of_day,
    CAST(t.txn_ts AS date) AS transaction_date
FROM dbo.TransactionItems i
JOIN dbo.Transactions t ON t.canonical_tx_id = i.canonical_tx_id
LEFT JOIN dbo.Products p ON p.product_id = i.product_id
LEFT JOIN ref.ProductNielsenMap m ON m.product_id = p.product_id
LEFT JOIN ref.NielsenTaxonomy n ON n.taxonomy_id = m.taxonomy_id AND n.level = 3
LEFT JOIN ref.NielsenTaxonomy grp ON grp.taxonomy_id = n.parent_id AND grp.level = 2
WHERE grp.taxonomy_code LIKE 'GRP_TOB_%'
   OR n.taxonomy_name LIKE '%Tobacco%'
   OR n.taxonomy_name LIKE '%Cigarette%'
   OR n.taxonomy_code LIKE 'CAT_04_%'  -- Tobacco department codes
GROUP BY
    DATENAME(weekday, t.txn_ts),
    n.taxonomy_name,
    DATEPART(hour, t.txn_ts),
    CAST(t.txn_ts AS date);
GO

-- Laundry category slice matching Excel sheet expectations
CREATE OR ALTER VIEW gold.v_pivot_laundry
AS
SELECT
    DATENAME(weekday, t.txn_ts) AS [Correct Category],    -- Matches Excel header
    COUNT_BIG(DISTINCT t.canonical_tx_id) AS [Laundry],   -- Count of unique transactions
    SUM(COALESCE(i.quantity, 1)) AS [Total Qty],
    AVG(COALESCE(i.quantity, 1)) AS [Avg Qty],
    SUM(COALESCE(i.line_amount, 0.00)) AS [Total Sales],
    AVG(COALESCE(i.line_amount, 0.00)) AS [Avg Total Price],
    COUNT_BIG(*) AS [Line Items],
    COALESCE(n.taxonomy_name, 'Unspecified') AS [Laundry Category],
    CAST(t.txn_ts AS date) AS [Date]
FROM dbo.TransactionItems i
JOIN dbo.Transactions t ON t.canonical_tx_id = i.canonical_tx_id
LEFT JOIN dbo.Products p ON p.product_id = i.product_id
LEFT JOIN dbo.Brands b ON b.brand_id = p.brand_id
LEFT JOIN ref.ProductNielsenMap m ON m.product_id = p.product_id
LEFT JOIN ref.NielsenTaxonomy n ON n.taxonomy_id = m.taxonomy_id AND n.level = 3
WHERE n.taxonomy_name LIKE '%Laundry%'
   OR n.taxonomy_name LIKE '%Detergent%'
   OR n.taxonomy_name LIKE '%Fabric%'
   OR n.taxonomy_code LIKE '%LAUND%'
   OR n.taxonomy_code LIKE '%DETER%'
   OR p.product_name LIKE '%Surf%'
   OR p.product_name LIKE '%Tide%'
   OR p.product_name LIKE '%Ariel%'
   OR p.product_name LIKE '%Downy%'
GROUP BY
    DATENAME(weekday, t.txn_ts),
    n.taxonomy_name,
    CAST(t.txn_ts AS date);
GO

-- Category lookup reference for Excel category reference sheet
CREATE OR ALTER VIEW gold.v_category_lookup_reference
AS
SELECT DISTINCT
    n.taxonomy_name AS [Correct Category],
    n.taxonomy_code AS [Category Code],
    n.level AS [Level],
    -- Get example products for each category
    (SELECT TOP 1 p2.product_name
     FROM ref.ProductNielsenMap m2
     JOIN dbo.Products p2 ON p2.product_id = m2.product_id
     WHERE m2.taxonomy_id = n.taxonomy_id
     ORDER BY p2.product_name) AS [Example SKU],
    -- Get example brand for each category
    (SELECT TOP 1 b2.brand_name
     FROM ref.ProductNielsenMap m2
     JOIN dbo.Products p2 ON p2.product_id = m2.product_id
     JOIN dbo.Brands b2 ON b2.brand_id = p2.brand_id
     WHERE m2.taxonomy_id = n.taxonomy_id
     ORDER BY b2.brand_name) AS [Example Brand],
    -- Category hierarchy information
    dept.taxonomy_name AS [Department],
    grp.taxonomy_name AS [Product Group],
    -- Usage statistics
    (SELECT COUNT(*)
     FROM ref.ProductNielsenMap m3
     WHERE m3.taxonomy_id = n.taxonomy_id) AS [Mapped Products],
    -- Parent codes for reference
    dept.taxonomy_code AS [Department Code],
    grp.taxonomy_code AS [Group Code]
FROM ref.NielsenTaxonomy n
LEFT JOIN ref.NielsenTaxonomy grp ON grp.taxonomy_id = n.parent_id AND grp.level = 2
LEFT JOIN ref.NielsenTaxonomy dept ON dept.taxonomy_id = grp.parent_id AND dept.level = 1
WHERE n.level = 3  -- Only show Level 3 categories for pivot use
ORDER BY dept.taxonomy_name, grp.taxonomy_name, n.taxonomy_name;
GO

-- Summary view for overall Nielsen coverage statistics
CREATE OR ALTER VIEW gold.v_nielsen_coverage_summary
AS
SELECT
    'Nielsen Taxonomy Coverage' AS report_type,
    -- Taxonomy counts
    (SELECT COUNT(*) FROM ref.NielsenTaxonomy WHERE level = 1) AS departments,
    (SELECT COUNT(*) FROM ref.NielsenTaxonomy WHERE level = 2) AS product_groups,
    (SELECT COUNT(*) FROM ref.NielsenTaxonomy WHERE level = 3) AS categories,
    -- Product mapping coverage
    (SELECT COUNT(*) FROM dbo.Products) AS total_products,
    (SELECT COUNT(DISTINCT product_id) FROM ref.ProductNielsenMap) AS mapped_products,
    CAST(100.0 * (SELECT COUNT(DISTINCT product_id) FROM ref.ProductNielsenMap)
         / NULLIF((SELECT COUNT(*) FROM dbo.Products), 0) AS decimal(5,2)) AS product_coverage_pct,
    -- Transaction coverage
    (SELECT COUNT(*) FROM dbo.TransactionItems) AS total_transaction_items,
    (SELECT COUNT(*)
     FROM dbo.TransactionItems i
     JOIN dbo.Products p ON p.product_id = i.product_id
     JOIN ref.ProductNielsenMap m ON m.product_id = p.product_id) AS mapped_transaction_items,
    CAST(100.0 * (SELECT COUNT(*)
                  FROM dbo.TransactionItems i
                  JOIN dbo.Products p ON p.product_id = i.product_id
                  JOIN ref.ProductNielsenMap m ON m.product_id = p.product_id)
         / NULLIF((SELECT COUNT(*) FROM dbo.TransactionItems), 0) AS decimal(5,2)) AS transaction_coverage_pct,
    -- Brand coverage
    (SELECT COUNT(DISTINCT brand_name) FROM ref.BrandCategoryRules) AS mapped_brands,
    (SELECT COUNT(DISTINCT brand_name) FROM ref.BrandCategoryRules WHERE rule_source = 'nielsen_1100') AS nielsen_1100_brands;
GO

PRINT 'Gold pivot views created successfully';
PRINT '';
PRINT 'Views created:';
PRINT '  gold.v_pivot_default - Main transaction export for Excel';
PRINT '  gold.v_pivot_category_brand - Category/brand aggregations';
PRINT '  gold.v_pivot_tobacco - Tobacco category analysis';
PRINT '  gold.v_pivot_laundry - Laundry category analysis';
PRINT '  gold.v_category_lookup_reference - Category reference table';
PRINT '  gold.v_nielsen_coverage_summary - Coverage statistics';
PRINT '';
PRINT 'Next steps:';
PRINT '1. Run: make pivots-export to generate CSV files';
PRINT '2. Point Excel sheets to corresponding CSV files in out/pivots/';
GO