-- =====================================================
-- GOLD vs LEGACY PARITY VALIDATION
-- Proves medallion architecture maintains semantic correctness
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

PRINT 'Starting Gold vs Legacy parity validation...';

-- =====================================================
-- 1. Row Count Parity Check
-- =====================================================
PRINT '1. Checking row count parity...';

DECLARE @legacy_rows INT, @gold_rows INT;

SELECT @legacy_rows = COUNT(*)
FROM dbo.SalesInteractions si
INNER JOIN dbo.PayloadTransactions pt ON si.canonical_tx_id = pt.canonical_tx_id
WHERE si.TransactionDate >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE))
AND pt.payload_json IS NOT NULL
AND ISJSON(pt.payload_json) = 1;

SELECT @gold_rows = COUNT(*)
FROM gold.mart_transactions
WHERE transaction_date >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE));

SELECT
    @legacy_rows AS legacy_rows,
    @gold_rows AS gold_rows,
    (@gold_rows - @legacy_rows) AS row_delta,
    CASE
        WHEN ABS(@gold_rows - @legacy_rows) <= 5 THEN 'PASS'
        ELSE 'FAIL'
    END AS row_count_status;

IF ABS(@gold_rows - @legacy_rows) > 5
BEGIN
    PRINT 'ERROR: Row count mismatch exceeds tolerance (±5 rows)';
    THROW 50001, 'Row count parity check failed', 1;
END

-- =====================================================
-- 2. Canonical Key Coverage Check
-- =====================================================
PRINT '2. Checking canonical key coverage...';

-- Find legacy keys missing in Gold
SELECT
    'Missing in Gold' AS issue_type,
    si.canonical_tx_id,
    si.TransactionDate,
    si.StoreID
FROM dbo.SalesInteractions si
INNER JOIN dbo.PayloadTransactions pt ON si.canonical_tx_id = pt.canonical_tx_id
LEFT JOIN gold.mart_transactions gmt ON gmt.canonical_tx_id = si.canonical_tx_id
WHERE si.TransactionDate >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE))
AND pt.payload_json IS NOT NULL
AND ISJSON(pt.payload_json) = 1
AND gmt.canonical_tx_id IS NULL;

-- Find Gold keys missing in legacy (should be none)
SELECT
    'Missing in Legacy' AS issue_type,
    gmt.canonical_tx_id,
    gmt.transaction_date,
    gmt.store_id
FROM gold.mart_transactions gmt
LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = gmt.canonical_tx_id
WHERE gmt.transaction_date >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE))
AND si.canonical_tx_id IS NULL;

-- =====================================================
-- 3. Metric Parity Smoke Test
-- =====================================================
PRINT '3. Checking metric parity...';

DECLARE @test_date_from DATE = DATEADD(DAY, -7, CAST(GETDATE() AS DATE));
DECLARE @test_date_to DATE = CAST(GETDATE() AS DATE);

WITH legacy_metrics AS (
    SELECT
        CAST(si.TransactionDate AS DATE) AS metric_date,
        COUNT(*) AS transaction_count,
        COUNT(DISTINCT si.canonical_tx_id) AS unique_transactions,
        COUNT(DISTINCT si.FacialID) AS unique_customers,
        COUNT(DISTINCT si.StoreID) AS unique_stores,
        SUM(
            ISNULL(
                TRY_CONVERT(DECIMAL(12,2),
                    JSON_VALUE(pt.payload_json, '$.totalAmount')
                ), 0
            )
        ) AS total_amount,
        AVG(CAST(si.Age AS FLOAT)) AS avg_age,
        AVG(CAST(si.ConversationScore AS FLOAT)) AS avg_conversation_score
    FROM dbo.SalesInteractions si
    INNER JOIN dbo.PayloadTransactions pt ON si.canonical_tx_id = pt.canonical_tx_id
    WHERE CAST(si.TransactionDate AS DATE) BETWEEN @test_date_from AND @test_date_to
    AND pt.payload_json IS NOT NULL
    AND ISJSON(pt.payload_json) = 1
    GROUP BY CAST(si.TransactionDate AS DATE)
),
gold_metrics AS (
    SELECT
        gmt.transaction_date AS metric_date,
        COUNT(*) AS transaction_count,
        COUNT(DISTINCT gmt.canonical_tx_id) AS unique_transactions,
        COUNT(DISTINCT gmt.customer_facial_id) AS unique_customers,
        COUNT(DISTINCT gmt.store_id) AS unique_stores,
        SUM(ISNULL(gmt.total_amount, 0)) AS total_amount,
        AVG(CAST(gmt.customer_age AS FLOAT)) AS avg_age,
        AVG(CAST(gmt.conversation_score AS FLOAT)) AS avg_conversation_score
    FROM gold.mart_transactions gmt
    WHERE gmt.transaction_date BETWEEN @test_date_from AND @test_date_to
    GROUP BY gmt.transaction_date
)
SELECT
    COALESCE(l.metric_date, g.metric_date) AS metric_date,

    -- Transaction counts
    l.transaction_count AS legacy_transactions,
    g.transaction_count AS gold_transactions,
    (g.transaction_count - l.transaction_count) AS transaction_delta,

    -- Unique entities
    l.unique_customers AS legacy_customers,
    g.unique_customers AS gold_customers,
    (g.unique_customers - l.unique_customers) AS customer_delta,

    l.unique_stores AS legacy_stores,
    g.unique_stores AS gold_stores,
    (g.unique_stores - l.unique_stores) AS store_delta,

    -- Financial metrics
    l.total_amount AS legacy_amount,
    g.total_amount AS gold_amount,
    (g.total_amount - l.total_amount) AS amount_delta,

    -- Quality metrics
    l.avg_age AS legacy_avg_age,
    g.avg_age AS gold_avg_age,
    ABS(ISNULL(g.avg_age, 0) - ISNULL(l.avg_age, 0)) AS age_delta,

    l.avg_conversation_score AS legacy_conv_score,
    g.avg_conversation_score AS gold_conv_score,
    ABS(ISNULL(g.avg_conversation_score, 0) - ISNULL(l.avg_conversation_score, 0)) AS conv_score_delta,

    -- Status
    CASE
        WHEN ABS(g.transaction_count - l.transaction_count) <= 2
         AND ABS(ISNULL(g.total_amount, 0) - ISNULL(l.total_amount, 0)) <= 1.00
         AND ABS(ISNULL(g.avg_age, 0) - ISNULL(l.avg_age, 0)) <= 2.0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS daily_parity_status

FROM legacy_metrics l
FULL OUTER JOIN gold_metrics g ON g.metric_date = l.metric_date
ORDER BY COALESCE(l.metric_date, g.metric_date);

-- =====================================================
-- 4. Hard Fail Check
-- =====================================================
PRINT '4. Applying hard fail tolerance checks...';

DECLARE @allowed_transaction_delta INT = 2;
DECLARE @allowed_amount_delta DECIMAL(18,2) = 1.00;
DECLARE @allowed_age_delta DECIMAL(8,2) = 2.0;

-- Check if any day exceeds tolerance
IF EXISTS (
    WITH legacy_metrics AS (
        SELECT
            CAST(si.TransactionDate AS DATE) AS metric_date,
            COUNT(*) AS transaction_count,
            SUM(
                ISNULL(
                    TRY_CONVERT(DECIMAL(12,2),
                        JSON_VALUE(pt.payload_json, '$.totalAmount')
                    ), 0
                )
            ) AS total_amount,
            AVG(CAST(si.Age AS FLOAT)) AS avg_age
        FROM dbo.SalesInteractions si
        INNER JOIN dbo.PayloadTransactions pt ON si.canonical_tx_id = pt.canonical_tx_id
        WHERE CAST(si.TransactionDate AS DATE) BETWEEN @test_date_from AND @test_date_to
        AND pt.payload_json IS NOT NULL
        AND ISJSON(pt.payload_json) = 1
        GROUP BY CAST(si.TransactionDate AS DATE)
    ),
    gold_metrics AS (
        SELECT
            gmt.transaction_date AS metric_date,
            COUNT(*) AS transaction_count,
            SUM(ISNULL(gmt.total_amount, 0)) AS total_amount,
            AVG(CAST(gmt.customer_age AS FLOAT)) AS avg_age
        FROM gold.mart_transactions gmt
        WHERE gmt.transaction_date BETWEEN @test_date_from AND @test_date_to
        GROUP BY gmt.transaction_date
    ),
    delta_check AS (
        SELECT
            ABS(ISNULL(g.transaction_count, 0) - ISNULL(l.transaction_count, 0)) AS transaction_delta,
            ABS(ISNULL(g.total_amount, 0) - ISNULL(l.total_amount, 0)) AS amount_delta,
            ABS(ISNULL(g.avg_age, 0) - ISNULL(l.avg_age, 0)) AS age_delta
        FROM legacy_metrics l
        FULL OUTER JOIN gold_metrics g ON g.metric_date = l.metric_date
    )
    SELECT 1
    FROM delta_check
    WHERE transaction_delta > @allowed_transaction_delta
       OR amount_delta > @allowed_amount_delta
       OR age_delta > @allowed_age_delta
)
BEGIN
    PRINT 'ERROR: Metric parity check failed - deltas exceed tolerance';
    THROW 50002, 'Metric parity validation failed: Gold vs Legacy deltas exceed tolerance', 1;
END

-- =====================================================
-- 5. JSON Extraction Quality Check
-- =====================================================
PRINT '5. Checking JSON extraction quality...';

DECLARE @total_payload_records INT;
DECLARE @successful_extractions INT;
DECLARE @json_success_rate DECIMAL(8,4);

SELECT @total_payload_records = COUNT(*)
FROM dbo.PayloadTransactions pt
INNER JOIN dbo.SalesInteractions si ON si.canonical_tx_id = pt.canonical_tx_id
WHERE CAST(si.TransactionDate AS DATE) >= @test_date_from
AND pt.payload_json IS NOT NULL;

SELECT @successful_extractions = COUNT(*)
FROM silver.transaction_items sti
INNER JOIN silver.transactions st ON st.canonical_tx_id = sti.canonical_tx_id
WHERE st.transaction_date >= @test_date_from
AND sti.sku_code IS NOT NULL
AND sti.item_total > 0;

IF @total_payload_records > 0
    SET @json_success_rate = CAST(@successful_extractions AS DECIMAL(18,2)) / @total_payload_records;
ELSE
    SET @json_success_rate = 0;

SELECT
    @total_payload_records AS total_payload_records,
    @successful_extractions AS successful_extractions,
    @json_success_rate AS json_success_rate,
    CASE
        WHEN @json_success_rate >= 0.90 THEN 'PASS'
        WHEN @json_success_rate >= 0.80 THEN 'WARNING'
        ELSE 'FAIL'
    END AS json_extraction_status;

IF @json_success_rate < 0.80
BEGIN
    PRINT 'ERROR: JSON extraction success rate below 80%';
    THROW 50003, 'JSON extraction quality check failed', 1;
END

-- =====================================================
-- 6. Single Date Source Validation
-- =====================================================
PRINT '6. Validating single date source principle...';

-- Check that all Gold transaction_date values come from SalesInteractions.TransactionDate
DECLARE @date_source_violations INT;

SELECT @date_source_violations = COUNT(*)
FROM gold.mart_transactions gmt
INNER JOIN dbo.SalesInteractions si ON si.canonical_tx_id = gmt.canonical_tx_id
WHERE CAST(si.TransactionDate AS DATE) != gmt.transaction_date;

SELECT
    @date_source_violations AS date_source_violations,
    CASE
        WHEN @date_source_violations = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS date_source_validation;

IF @date_source_violations > 0
BEGIN
    PRINT 'ERROR: Date source validation failed - transaction_date not sourced from SalesInteractions.TransactionDate';
    THROW 50004, 'Single date source principle violated', 1;
END

-- =====================================================
-- Final Summary
-- =====================================================
PRINT '✅ All parity validation checks passed!';
PRINT 'Gold layer maintains semantic correctness with legacy system.';
PRINT 'Safe to switch API to READ_MODE=gold.';

-- Log successful validation
INSERT INTO dbo.etl_execution_log (etl_name, started_at, finished_at, status, notes)
VALUES (
    'validate_gold_vs_legacy',
    SYSUTCDATETIME(),
    SYSUTCDATETIME(),
    'SUCCESS',
    CONCAT('Parity validation passed. Legacy rows: ', @legacy_rows, ', Gold rows: ', @gold_rows, ', JSON success: ', @json_success_rate * 100, '%')
);