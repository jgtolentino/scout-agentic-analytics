-- =====================================================
-- Scout Lakehouse Fabric Validation Script
-- Single-query validation for Claude Code CLI execution
-- =====================================================

-- Returns a single row with validation results for automated checking
DECLARE @schemas_ok BIT = IIF(SCHEMA_ID('gold') IS NOT NULL AND SCHEMA_ID('platinum') IS NOT NULL, 1, 0);

DECLARE @gold_views_ok BIT = IIF(
    OBJECT_ID('gold.dim_store','V') IS NOT NULL AND
    OBJECT_ID('gold.dim_brand','V') IS NOT NULL AND
    OBJECT_ID('gold.dim_category','V') IS NOT NULL AND
    OBJECT_ID('gold.fact_transactions','V') IS NOT NULL AND
    OBJECT_ID('gold.mart_transactions','V') IS NOT NULL, 1, 0);

DECLARE @platinum_ok BIT = IIF(
    OBJECT_ID('platinum.model_registry','U') IS NOT NULL AND
    OBJECT_ID('platinum.model_version','U') IS NOT NULL AND
    OBJECT_ID('platinum.model_metric','U') IS NOT NULL AND
    OBJECT_ID('platinum.features','U') IS NOT NULL AND
    OBJECT_ID('platinum.predictions','U') IS NOT NULL AND
    OBJECT_ID('platinum.insights','U') IS NOT NULL, 1, 0);

DECLARE @fresh_7d BIGINT = 0;
DECLARE @persona_coverage DECIMAL(9,3) = NULL;
DECLARE @single_date_ok BIT = 1;
DECLARE @indexes_ok BIT = 1;

-- Check data freshness (7 days)
BEGIN TRY
    SET @fresh_7d = (
        SELECT COUNT(*)
        FROM gold.mart_transactions
        WHERE transaction_date >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE))
    );
END TRY
BEGIN CATCH
    SET @fresh_7d = 0;
END CATCH;

-- Check persona coverage (if predictions exist)
BEGIN TRY
    DECLARE @total_tx_7d BIGINT = (
        SELECT COUNT(DISTINCT canonical_tx_id)
        FROM gold.mart_transactions
        WHERE transaction_date >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE))
    );

    DECLARE @persona_tx_7d BIGINT = (
        SELECT COUNT(DISTINCT p.subject_key)
        FROM platinum.predictions p
        INNER JOIN gold.mart_transactions t ON p.subject_key = t.canonical_tx_id
        WHERE p.label LIKE 'persona:%'
          AND p.pred_date >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE))
          AND t.transaction_date >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE))
    );

    IF @total_tx_7d > 0
        SET @persona_coverage = CAST(@persona_tx_7d AS DECIMAL(9,3)) / @total_tx_7d * 100;
END TRY
BEGIN CATCH
    SET @persona_coverage = NULL;
END CATCH;

-- Check single date authority (no NULL transaction_dates)
BEGIN TRY
    IF EXISTS (SELECT 1 FROM gold.mart_transactions WHERE transaction_date IS NULL)
        SET @single_date_ok = 0;
END TRY
BEGIN CATCH
    SET @single_date_ok = 0;
END CATCH;

-- Check critical indexes
BEGIN TRY
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE name = 'IX_pred_subject'
        AND object_id = OBJECT_ID('platinum.predictions')
    )
        SET @indexes_ok = 0;

    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE name = 'IX_insight_entity'
        AND object_id = OBJECT_ID('platinum.insights')
    )
        SET @indexes_ok = 0;
END TRY
BEGIN CATCH
    SET @indexes_ok = 0;
END CATCH;

-- Return validation results as JSON-compatible single row
SELECT
    @schemas_ok AS schemas_ok,
    CASE
        WHEN @gold_views_ok = 1 THEN 'true'
        ELSE 'false'
    END AS gold_views_ok,
    @platinum_ok AS platinum_ok,
    @fresh_7d AS freshness_7d_rows,
    @persona_coverage AS persona_coverage_pct_7d,
    @indexes_ok AS indexes_ok,
    @single_date_ok AS single_date_enforced,
    CASE
        WHEN @schemas_ok = 1 AND @gold_views_ok = 1 AND @platinum_ok = 1
             AND @fresh_7d > 0 AND @single_date_ok = 1 AND @indexes_ok = 1
        THEN 'pass'
        WHEN @schemas_ok = 1 AND @gold_views_ok = 1 AND @fresh_7d > 0 AND @single_date_ok = 1
        THEN 'warn'
        ELSE 'fail'
    END AS verdict,
    CONCAT(
        CASE WHEN @schemas_ok = 0 THEN 'Missing schemas; ' ELSE '' END,
        CASE WHEN @gold_views_ok = 0 THEN 'Gold views missing; ' ELSE '' END,
        CASE WHEN @platinum_ok = 0 THEN 'Platinum tables missing; ' ELSE '' END,
        CASE WHEN @fresh_7d = 0 THEN 'No recent data; ' ELSE '' END,
        CASE WHEN @single_date_ok = 0 THEN 'Date authority violated; ' ELSE '' END,
        CASE WHEN @indexes_ok = 0 THEN 'Missing indexes; ' ELSE '' END,
        CASE WHEN @persona_coverage IS NOT NULL AND @persona_coverage < 95
             THEN CONCAT('Low persona coverage: ', FORMAT(@persona_coverage, '0.0'), '%; ')
             ELSE '' END,
        'Validation complete'
    ) AS notes;