-- ================================================================
-- validate_actual_deployment.sql
-- Comprehensive deployment validation for SARI-SARI Expert v2.0
-- Returns JSON metrics for programmatic parsing
-- ================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];

SET NOCOUNT ON;

DECLARE @schemas_ok BIT = 0;
DECLARE @gold_core_ok BIT = 0;
DECLARE @platinum_core_ok BIT = 0;
DECLARE @read_mode NVARCHAR(50) = 'unknown';
DECLARE @total_transactions INT = 0;
DECLARE @personas_covered INT = 0;
DECLARE @market_basket_items INT = 0;
DECLARE @insights_count INT = 0;
DECLARE @predictions_fresh BIT = 0;
DECLARE @integrity_score INT = 0;

-- Check schemas exist
IF SCHEMA_ID('dbo') IS NOT NULL AND SCHEMA_ID('gold') IS NOT NULL AND SCHEMA_ID('platinum') IS NOT NULL
    SET @schemas_ok = 1;

-- Check Gold core tables
IF OBJECT_ID('gold.mart_transactions','U') IS NOT NULL
   AND OBJECT_ID('gold.v_customer_segments','V') IS NOT NULL
    SET @gold_core_ok = 1;

-- Check Platinum core tables
IF OBJECT_ID('platinum.model_registry','U') IS NOT NULL
   AND OBJECT_ID('platinum.predictions','U') IS NOT NULL
   AND OBJECT_ID('platinum.insights','U') IS NOT NULL
    SET @platinum_core_ok = 1;

-- Get READ_MODE setting
SELECT @read_mode = ISNULL([value], 'unknown')
FROM dbo.AppConfig
WHERE [key] = 'READ_MODE';

-- Get transaction counts (if Gold layer available)
IF @gold_core_ok = 1
BEGIN
    SELECT @total_transactions = COUNT(*)
    FROM gold.mart_transactions
    WHERE transaction_date >= DATEADD(DAY, -7, GETDATE());
END;

-- Get persona coverage (if Platinum available)
IF @platinum_core_ok = 1
BEGIN
    SELECT @personas_covered = COUNT(DISTINCT p.subject_key)
    FROM platinum.predictions p
    JOIN platinum.model_version mv ON mv.model_version_id = p.model_version_id
    JOIN platinum.model_registry mr ON mr.model_id = mv.model_id
    WHERE mr.model_name = 'persona_inference'
    AND p.pred_date >= DATEADD(DAY, -7, GETDATE());

    -- Market basket analysis count
    SELECT @market_basket_items = COUNT(*)
    FROM platinum.insights
    WHERE source = 'market_basket'
    AND insight_date >= DATEADD(DAY, -7, GETDATE());

    -- Total insights count
    SELECT @insights_count = COUNT(*)
    FROM platinum.insights
    WHERE insight_date >= DATEADD(DAY, -2, GETDATE());

    -- Check for fresh predictions
    IF EXISTS (
        SELECT 1 FROM platinum.predictions
        WHERE pred_date >= CAST(DATEADD(HOUR, -24, GETDATE()) AS DATE)
    )
        SET @predictions_fresh = 1;
END;

-- Calculate integrity score
SET @integrity_score = (
    (@schemas_ok * 20) +
    (@gold_core_ok * 25) +
    (@platinum_core_ok * 25) +
    (CASE WHEN @read_mode = 'gold' THEN 15 ELSE 0 END) +
    (@predictions_fresh * 15)
);

-- Output JSON result
SELECT
    @schemas_ok AS schemas_ok,
    @gold_core_ok AS gold_core_ok,
    @platinum_core_ok AS platinum_core_ok,
    @read_mode AS read_mode,
    @total_transactions AS total_transactions,
    @personas_covered AS personas_covered,
    @market_basket_items AS market_basket_items,
    @insights_count AS insights_count,
    @predictions_fresh AS predictions_fresh,
    @integrity_score AS integrity_score
FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;