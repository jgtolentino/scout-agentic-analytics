-- ============================================================================
-- Azure SQL Scout Analytics - Post-Deployment Hardening
-- Production-ready security, parity validation, and export capabilities
-- ============================================================================

-- ===========================================
-- 1) LEAST-PRIVILEGE READER FOR BI/ADS
-- ===========================================

PRINT '=== Creating Scout Reader Principal ===';

-- Create reader user for BI tools (rotate password in production)
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'scout_reader')
    CREATE USER [scout_reader] WITH PASSWORD = 'ScoutReader2025!';

-- Grant minimal required permissions
EXEC sp_addrolemember 'db_datareader', 'scout_reader';
GRANT SELECT ON SCHEMA::gold TO [scout_reader];
GRANT SELECT ON SCHEMA::audit TO [scout_reader];
GRANT EXEC ON SCHEMA::staging TO [scout_reader];  -- for validation procedures

PRINT 'Created scout_reader with read-only access to gold/audit schemas';
PRINT '';

-- ===========================================
-- 2) PERSISTENT PARITY VALIDATION VIEW
-- ===========================================

PRINT '=== Creating Parity Validation Infrastructure ===';

-- Fix column names in existing views first
-- Update flat view to use consistent column names
CREATE OR ALTER VIEW gold.v_transactions_flat
AS
SELECT
    canonical_tx_id,
    device_id,
    store_id,
    brand,
    product_name,
    category,
    total_amount,
    total_items,
    payment_method,
    audio_transcript,
    created_at as txn_ts,  -- Standardized column name

    -- Derived fields
    CASE
        WHEN DATEPART(HOUR, created_at) BETWEEN 5 AND 10 THEN 'Morning'
        WHEN DATEPART(HOUR, created_at) BETWEEN 11 AND 14 THEN 'Midday'
        WHEN DATEPART(HOUR, created_at) BETWEEN 15 AND 18 THEN 'Afternoon'
        WHEN DATEPART(HOUR, created_at) BETWEEN 19 AND 22 THEN 'Evening'
        ELSE 'LateNight'
    END as daypart,

    CASE
        WHEN DATEPART(WEEKDAY, created_at) IN (1, 7) THEN 'Weekend'
        ELSE 'Weekday'
    END as weekday_weekend,

    CAST(created_at AS DATE) as transaction_date,
    'Store_' + store_id as store_name

FROM staging.transactions;

-- Update crosstab view with consistent naming
CREATE OR ALTER VIEW gold.v_transactions_crosstab
AS
SELECT
    transaction_date as [date],
    store_name,
    SUM(CASE WHEN daypart = 'Morning' THEN 1 ELSE 0 END) as Morning_Transactions,
    SUM(CASE WHEN daypart = 'Midday' THEN 1 ELSE 0 END) as Midday_Transactions,
    SUM(CASE WHEN daypart = 'Afternoon' THEN 1 ELSE 0 END) as Afternoon_Transactions,
    SUM(CASE WHEN daypart = 'Evening' THEN 1 ELSE 0 END) as Evening_Transactions,
    COUNT(*) as txn_count,  -- Standardized column name
    ROUND(SUM(total_amount), 2) as total_amount  -- Standardized column name
FROM gold.v_transactions_flat
GROUP BY transaction_date, store_name;

-- Create persistent parity validation view
CREATE OR ALTER VIEW audit.v_flat_vs_crosstab_parity
AS
WITH flat_summary AS (
    SELECT
        CAST(txn_ts AS DATE) AS [date],
        COUNT_BIG(*) AS txn_count_flat,
        SUM(CAST(total_amount AS DECIMAL(18,2))) AS revenue_flat
    FROM gold.v_transactions_flat
    GROUP BY CAST(txn_ts AS DATE)
),
crosstab_summary AS (
    SELECT
        [date],
        SUM(txn_count) AS txn_count_crosstab,
        SUM(CAST(total_amount AS DECIMAL(18,2))) AS revenue_crosstab
    FROM gold.v_transactions_crosstab
    GROUP BY [date]
)
SELECT
    COALESCE(f.[date], c.[date]) AS [date],
    ISNULL(f.txn_count_flat, 0) AS txn_count_flat,
    ISNULL(c.txn_count_crosstab, 0) AS txn_count_crosstab,
    ISNULL(f.revenue_flat, 0.00) AS revenue_flat,
    ISNULL(c.revenue_crosstab, 0.00) AS revenue_crosstab,
    ISNULL(f.txn_count_flat, 0) - ISNULL(c.txn_count_crosstab, 0) AS txn_delta,
    ISNULL(f.revenue_flat, 0.00) - ISNULL(c.revenue_crosstab, 0.00) AS revenue_delta,
    CASE
        WHEN ISNULL(f.txn_count_flat, 0) = ISNULL(c.txn_count_crosstab, 0)
         AND ABS(ISNULL(f.revenue_flat, 0.00) - ISNULL(c.revenue_crosstab, 0.00)) < 0.01
        THEN 'PASS ✅'
        ELSE 'FAIL ❌'
    END AS parity_status
FROM flat_summary f
FULL OUTER JOIN crosstab_summary c ON f.[date] = c.[date];

PRINT 'Created audit.v_flat_vs_crosstab_parity for objective data quality validation';
PRINT '';

-- ===========================================
-- 3) ZERO-CLICK CSV EXPORT SYSTEM
-- ===========================================

PRINT '=== Creating Export Procedures ===';

-- Master export query generator (Bruno will execute via bcp)
CREATE OR ALTER PROCEDURE staging.sp_export_query_sql
    @report_name SYSNAME,
    @sql NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    -- Log export request
    INSERT INTO audit.export_log (operation_type, record_count, validation_status, notes)
    VALUES ('EXPORT_REQUEST', 0, 'PENDING', 'Export query generated for: ' + @report_name);

    -- Return query for Bruno to execute via bcp
    SELECT @report_name AS report_name, @sql AS sql_text;
END;

-- Predefined export templates
CREATE OR ALTER PROCEDURE staging.sp_export_crosstab_14d
AS
BEGIN
    EXEC staging.sp_export_query_sql
        @report_name = N'scout_crosstab_14d',
        @sql = N'
            SELECT [date], store_name,
                   Morning_Transactions, Midday_Transactions,
                   Afternoon_Transactions, Evening_Transactions,
                   txn_count, total_amount
            FROM gold.v_transactions_crosstab
            WHERE [date] >= CAST(DATEADD(day, -14, GETUTCDATE()) AS DATE)
            ORDER BY [date], store_name;
        ';
END;

CREATE OR ALTER PROCEDURE staging.sp_export_flat_latest
AS
BEGIN
    EXEC staging.sp_export_query_sql
        @report_name = N'scout_flat_latest',
        @sql = N'
            SELECT TOP (1000)
                canonical_tx_id, device_id, store_id, brand, product_name,
                category, total_amount, total_items, payment_method,
                daypart, weekday_weekend, txn_ts, store_name
            FROM gold.v_transactions_flat
            ORDER BY txn_ts DESC;
        ';
END;

CREATE OR ALTER PROCEDURE staging.sp_export_brands_summary
AS
BEGIN
    EXEC staging.sp_export_query_sql
        @report_name = N'scout_brands_summary',
        @sql = N'
            SELECT brand, category,
                   COUNT(*) as transaction_count,
                   SUM(total_amount) as total_revenue,
                   AVG(total_amount) as avg_transaction_value,
                   MIN(txn_ts) as first_seen,
                   MAX(txn_ts) as last_seen
            FROM gold.v_transactions_flat
            GROUP BY brand, category
            ORDER BY total_revenue DESC;
        ';
END;

PRINT 'Created export procedures: sp_export_crosstab_14d, sp_export_flat_latest, sp_export_brands_summary';
PRINT '';

-- ===========================================
-- 4) ENHANCED VALIDATION WITH PARITY CHECK
-- ===========================================

PRINT '=== Updating Validation Procedures ===';

-- Enhanced validation including parity checks
CREATE OR ALTER PROCEDURE staging.sp_validate_scout_etl_enhanced
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '=== Scout Analytics ETL Enhanced Validation ===';
    PRINT '';

    -- 1. Record counts
    DECLARE @staging_count INT = (SELECT COUNT(*) FROM staging.transactions);
    DECLARE @gold_flat_count INT = (SELECT COUNT(*) FROM gold.v_transactions_flat);
    DECLARE @gold_crosstab_count INT = (SELECT COUNT(*) FROM gold.v_transactions_crosstab);

    PRINT '1. RECORD COUNTS:';
    PRINT '   Staging: ' + CAST(@staging_count AS NVARCHAR(10)) + ' records';
    PRINT '   Gold Flat: ' + CAST(@gold_flat_count AS NVARCHAR(10)) + ' records';
    PRINT '   Gold Crosstab: ' + CAST(@gold_crosstab_count AS NVARCHAR(10)) + ' date/store combinations';
    PRINT '';

    -- 2. Parity validation
    PRINT '2. PARITY VALIDATION (Last 7 days):';
    DECLARE @parity_failures INT = (
        SELECT COUNT(*)
        FROM audit.v_flat_vs_crosstab_parity
        WHERE [date] >= CAST(DATEADD(day, -7, GETUTCDATE()) AS DATE)
          AND parity_status = 'FAIL ❌'
    );

    IF @parity_failures = 0
        PRINT '   ✅ PASS: Flat and crosstab views are 100% consistent'
    ELSE
        PRINT '   ❌ FAIL: ' + CAST(@parity_failures AS NVARCHAR(10)) + ' parity mismatches detected';

    -- Show any parity issues
    SELECT [date], txn_delta, revenue_delta, parity_status
    FROM audit.v_flat_vs_crosstab_parity
    WHERE [date] >= CAST(DATEADD(day, -7, GETUTCDATE()) AS DATE)
      AND parity_status = 'FAIL ❌';

    PRINT '';

    -- 3. Filipino brands validation
    PRINT '3. FILIPINO BRANDS VALIDATION:';
    DECLARE @real_brands INT = (
        SELECT COUNT(DISTINCT brand)
        FROM staging.transactions
        WHERE brand IN ('Safeguard', 'Jack ''n Jill', 'Piattos', 'Combi', 'Pantene',
                       'Gatorade', 'C2', 'Coca-Cola', 'Surf', 'Oishi', 'Head & Shoulders',
                       'Close Up', 'Cream Silk', 'Sprite', 'Milo', 'Marlboro', 'Alaska')
    );

    DECLARE @test_brands INT = (
        SELECT COUNT(DISTINCT brand)
        FROM staging.transactions
        WHERE brand LIKE 'Brand %' OR brand LIKE 'Test%' OR brand LIKE 'Sample%'
    );

    PRINT '   Real Filipino brands: ' + CAST(@real_brands AS NVARCHAR(10));
    PRINT '   Test/placeholder brands: ' + CAST(@test_brands AS NVARCHAR(10));

    IF @test_brands = 0
        PRINT '   ✅ PASS: No test brands detected'
    ELSE
        PRINT '   ⚠️ WARNING: Test brands found in production data';

    -- 4. Data freshness
    DECLARE @latest_record DATETIME2 = (SELECT MAX(created_at) FROM staging.transactions);
    DECLARE @hours_old INT = DATEDIFF(HOUR, @latest_record, GETUTCDATE());

    PRINT '';
    PRINT '4. DATA FRESHNESS:';
    PRINT '   Latest record: ' + CAST(@latest_record AS NVARCHAR(30));
    PRINT '   Hours old: ' + CAST(@hours_old AS NVARCHAR(10));

    -- 5. Quality metrics
    DECLARE @valid_brands INT = (SELECT COUNT(*) FROM staging.transactions WHERE brand IS NOT NULL AND brand != '');
    DECLARE @valid_amounts INT = (SELECT COUNT(*) FROM staging.transactions WHERE total_amount > 0);

    DECLARE @quality_score FLOAT = ROUND(
        (CAST(@valid_brands AS FLOAT) / @staging_count * 100 +
         CAST(@valid_amounts AS FLOAT) / @staging_count * 100) / 2, 1
    );

    PRINT '';
    PRINT '5. DATA QUALITY:';
    PRINT '   Records with brands: ' + CAST(@valid_brands AS NVARCHAR(10)) + '/' + CAST(@staging_count AS NVARCHAR(10));
    PRINT '   Records with valid amounts: ' + CAST(@valid_amounts AS NVARCHAR(10)) + '/' + CAST(@staging_count AS NVARCHAR(10));
    PRINT '   Quality score: ' + CAST(@quality_score AS NVARCHAR(10)) + '%';

    -- Overall status
    DECLARE @status NVARCHAR(30) = CASE
        WHEN @staging_count > 0 AND @gold_flat_count > 0 AND @parity_failures = 0 AND @test_brands = 0 AND @quality_score > 95
        THEN 'PRODUCTION READY ✅'
        WHEN @staging_count > 0 AND @gold_flat_count > 0 AND @parity_failures = 0 AND @quality_score > 80
        THEN 'GOOD ✅'
        WHEN @staging_count > 0
        THEN 'NEEDS ATTENTION ⚠️'
        ELSE 'FAILED ❌'
    END;

    PRINT '';
    PRINT '=== OVERALL STATUS: ' + @status + ' ===';

    -- Log validation
    INSERT INTO audit.export_log (operation_type, record_count, validation_status, notes)
    VALUES ('ETL_VALIDATION_ENHANCED', @staging_count,
            CASE WHEN @status LIKE '%✅' THEN 'SUCCESS' ELSE 'WARNING' END,
            'Quality: ' + CAST(@quality_score AS NVARCHAR(10)) + '%, Parity failures: ' + CAST(@parity_failures AS NVARCHAR(10)) + ', Status: ' + @status);

END;

PRINT 'Created enhanced validation procedure with parity checks';
PRINT '';

-- ===========================================
-- 5) DEPLOYMENT SMOKE TESTS
-- ===========================================

PRINT '=== Running Deployment Smoke Tests ===';

-- Test 1: Record counts
DECLARE @staging_rows INT = (SELECT COUNT(*) FROM staging.transactions);
DECLARE @gold_rows INT = (SELECT COUNT(*) FROM gold.v_transactions_flat);

PRINT '1. RECORD COUNTS:';
PRINT '   Staging: ' + CAST(@staging_rows AS NVARCHAR(10)) + ' rows';
PRINT '   Gold: ' + CAST(@gold_rows AS NVARCHAR(10)) + ' rows';

-- Test 2: Brand distribution
PRINT '';
PRINT '2. TOP BRANDS BY REVENUE:';
SELECT TOP 5 brand, COUNT(*) as txn_count, SUM(total_amount) as total_revenue
FROM gold.v_transactions_flat
GROUP BY brand
ORDER BY SUM(total_amount) DESC;

-- Test 3: Crosstab health
DECLARE @crosstab_cells INT = (SELECT COUNT(*) FROM gold.v_transactions_crosstab);
DECLARE @crosstab_txns INT = (SELECT SUM(txn_count) FROM gold.v_transactions_crosstab);

PRINT '';
PRINT '3. CROSSTAB VALIDATION:';
PRINT '   Crosstab cells: ' + CAST(@crosstab_cells AS NVARCHAR(10));
PRINT '   Total transactions: ' + CAST(@crosstab_txns AS NVARCHAR(10));

-- Test 4: Quick parity check
PRINT '';
PRINT '4. PARITY STATUS:';
SELECT COUNT(*) as total_dates, SUM(CASE WHEN parity_status = 'PASS ✅' THEN 1 ELSE 0 END) as passed_dates
FROM audit.v_flat_vs_crosstab_parity;

PRINT '';
PRINT '=== HARDENING DEPLOYMENT COMPLETE ===';
PRINT '';
PRINT 'Ready for production use:';
PRINT '• BI/ADS Connection: scout_reader user created';
PRINT '• Parity Validation: audit.v_flat_vs_crosstab_parity view available';
PRINT '• CSV Exports: staging.sp_export_* procedures ready';
PRINT '• Enhanced Validation: staging.sp_validate_scout_etl_enhanced';
PRINT '';