-- ================================================================
-- 002_analytics_integrity.sql
-- Analytics Integrity Validation Suite
-- Validates: coverage, freshness, foreign keys, null-safety
-- ================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

SET NOCOUNT ON;

PRINT '🔍 ANALYTICS INTEGRITY VALIDATION SUITE';
PRINT '=========================================';
PRINT CONCAT('Validation Time: ', CONVERT(VARCHAR, SYSUTCDATETIME(), 120), ' UTC');
PRINT '';

DECLARE @ValidationErrors INT = 0;
DECLARE @WarningCount INT = 0;
DECLARE @ValidationStart DATETIME2(3) = SYSUTCDATETIME();

-- ================================================================
-- A. SCHEMA AND OBJECT VALIDATION
-- ================================================================

PRINT '📋 A. Schema and Object Validation';
PRINT '-----------------------------------';

-- A1. Verify Platinum schema exists
IF SCHEMA_ID('platinum') IS NULL
BEGIN
    PRINT '❌ CRITICAL: Platinum schema does not exist';
    SET @ValidationErrors = @ValidationErrors + 1;
END
ELSE
    PRINT '✅ Platinum schema exists';

-- A2. Verify required tables exist
DECLARE @RequiredTables TABLE (table_name SYSNAME);
INSERT INTO @RequiredTables VALUES
    ('model_registry'), ('model_version'), ('model_metric'),
    ('features'), ('predictions'), ('insights');

DECLARE @MissingTables INT = (
    SELECT COUNT(*)
    FROM @RequiredTables rt
    WHERE NOT EXISTS (
        SELECT 1 FROM sys.tables t
        JOIN sys.schemas s ON t.schema_id = s.schema_id
        WHERE s.name = 'platinum' AND t.name = rt.table_name
    )
);

IF @MissingTables > 0
BEGIN
    PRINT CONCAT('❌ CRITICAL: ', @MissingTables, ' required Platinum tables missing');
    SET @ValidationErrors = @ValidationErrors + 1;
END
ELSE
    PRINT CONCAT('✅ All ', (SELECT COUNT(*) FROM @RequiredTables), ' required tables exist');

-- ================================================================
-- B. FOREIGN KEY AND REFERENTIAL INTEGRITY
-- ================================================================

PRINT '';
PRINT '🔗 B. Foreign Key and Referential Integrity';
PRINT '--------------------------------------------';

-- B1. Predictions → model_version references
DECLARE @OrphanedPredictions INT = (
    SELECT COUNT(*)
    FROM platinum.predictions p
    LEFT JOIN platinum.model_version mv ON mv.model_version_id = p.model_version_id
    WHERE mv.model_version_id IS NULL
);

IF @OrphanedPredictions > 0
BEGIN
    PRINT CONCAT('❌ CRITICAL: ', @OrphanedPredictions, ' predictions reference non-existent model versions');
    SET @ValidationErrors = @ValidationErrors + 1;
END
ELSE
    PRINT '✅ All predictions have valid model version references';

-- B2. Predictions → subject key coverage in Gold layer
-- Check transaction predictions reference existing transactions
DECLARE @InvalidTxPredictions INT = (
    SELECT COUNT(*)
    FROM platinum.predictions p
    LEFT JOIN gold.mart_transactions mt ON p.subject_key = mt.canonical_tx_id
    WHERE p.subject_type = 'tx' AND mt.canonical_tx_id IS NULL
);

IF @InvalidTxPredictions > 0
BEGIN
    PRINT CONCAT('❌ CRITICAL: ', @InvalidTxPredictions, ' transaction predictions reference missing transactions in Gold layer');
    SET @ValidationErrors = @ValidationErrors + 1;
END
ELSE
    PRINT '✅ All transaction predictions reference valid Gold layer transactions';

-- B3. Model versions → model registry references
DECLARE @OrphanedVersions INT = (
    SELECT COUNT(*)
    FROM platinum.model_version mv
    LEFT JOIN platinum.model_registry mr ON mr.model_id = mv.model_id
    WHERE mr.model_id IS NULL
);

IF @OrphanedVersions > 0
BEGIN
    PRINT CONCAT('❌ CRITICAL: ', @OrphanedVersions, ' model versions reference non-existent models');
    SET @ValidationErrors = @ValidationErrors + 1;
END
ELSE
    PRINT '✅ All model versions have valid registry references';

-- ================================================================
-- C. NULL-SAFETY ON CRITICAL FIELDS
-- ================================================================

PRINT '';
PRINT '🛡️ C. Null-Safety Validation';
PRINT '-----------------------------';

-- C1. Critical fields in predictions
DECLARE @PredictionsNullErrors INT = 0;

SELECT @PredictionsNullErrors = SUM(CASE
    WHEN subject_key IS NULL THEN 1
    WHEN subject_type IS NULL THEN 1
    WHEN label IS NULL THEN 1
    WHEN model_version_id IS NULL THEN 1
    ELSE 0
END)
FROM platinum.predictions;

IF @PredictionsNullErrors > 0
BEGIN
    PRINT CONCAT('❌ CRITICAL: ', @PredictionsNullErrors, ' predictions have null critical fields');
    SET @ValidationErrors = @ValidationErrors + 1;
END
ELSE
    PRINT '✅ All predictions have non-null critical fields';

-- C2. Critical fields in insights
DECLARE @InsightsNullErrors INT = 0;

SELECT @InsightsNullErrors = SUM(CASE
    WHEN source IS NULL THEN 1
    WHEN entity_type IS NULL THEN 1
    WHEN entity_key IS NULL THEN 1
    WHEN title IS NULL THEN 1
    WHEN summary IS NULL THEN 1
    ELSE 0
END)
FROM platinum.insights;

IF @InsightsNullErrors > 0
BEGIN
    PRINT CONCAT('❌ CRITICAL: ', @InsightsNullErrors, ' insights have null critical fields');
    SET @ValidationErrors = @ValidationErrors + 1;
END
ELSE
    PRINT '✅ All insights have non-null critical fields';

-- ================================================================
-- D. FRESHNESS VALIDATION
-- ================================================================

PRINT '';
PRINT '⏰ D. Data Freshness Validation';
PRINT '--------------------------------';

DECLARE @FreshnessThreshold DATETIME2(3) = DATEADD(HOUR, -30, SYSUTCDATETIME()); -- 30-hour window

-- D1. Predictions freshness
DECLARE @FreshPredictions INT = (
    SELECT COUNT(*)
    FROM platinum.predictions
    WHERE pred_date >= CAST(DATEADD(HOUR, -30, SYSUTCDATETIME()) AS DATE)
);

IF @FreshPredictions = 0
BEGIN
    PRINT '⚠️  WARNING: No predictions generated in last 30 hours';
    SET @WarningCount = @WarningCount + 1;
END
ELSE
    PRINT CONCAT('✅ ', @FreshPredictions, ' fresh predictions (last 30 hours)');

-- D2. Insights freshness
DECLARE @FreshInsights INT = (
    SELECT COUNT(*)
    FROM platinum.insights
    WHERE insight_date >= CAST(DATEADD(DAY, -2, GETDATE()) AS DATE)
);

IF @FreshInsights = 0
BEGIN
    PRINT '⚠️  WARNING: No insights generated in last 2 days';
    SET @WarningCount = @WarningCount + 1;
END
ELSE
    PRINT CONCAT('✅ ', @FreshInsights, ' fresh insights (last 2 days)');

-- ================================================================
-- E. COVERAGE VALIDATION (95% threshold)
-- ================================================================

PRINT '';
PRINT '📊 E. Coverage Validation';
PRINT '-------------------------';

DECLARE @TestPeriodDays INT = 7;
DECLARE @SinceDate DATE = DATEADD(DAY, -@TestPeriodDays, CAST(GETDATE() AS DATE));

-- E1. Persona prediction coverage
DECLARE @TotalTransactions INT = (
    SELECT COUNT(DISTINCT canonical_tx_id)
    FROM gold.mart_transactions
    WHERE transaction_date >= @SinceDate
);

DECLARE @PersonaPredictions INT = (
    SELECT COUNT(DISTINCT p.subject_key)
    FROM platinum.predictions p
    JOIN platinum.model_version mv ON mv.model_version_id = p.model_version_id
    JOIN platinum.model_registry mr ON mr.model_id = mv.model_id
    WHERE mr.model_name = 'persona_inference'
    AND p.subject_type = 'tx'
    AND p.pred_date >= @SinceDate
);

DECLARE @PersonaCoverage DECIMAL(9,2) = CASE
    WHEN @TotalTransactions > 0 THEN (100.0 * @PersonaPredictions / @TotalTransactions)
    ELSE 0
END;

IF @PersonaCoverage < 95.0
BEGIN
    PRINT CONCAT('❌ CRITICAL: Persona prediction coverage is ', @PersonaCoverage, '% (required: ≥95%)');
    PRINT CONCAT('   Transactions: ', @TotalTransactions, ', Predictions: ', @PersonaPredictions);
    SET @ValidationErrors = @ValidationErrors + 1;
END
ELSE
    PRINT CONCAT('✅ Persona prediction coverage: ', @PersonaCoverage, '% (', @PersonaPredictions, '/', @TotalTransactions, ')');

-- E2. Market basket coverage (for stores with sufficient volume)
DECLARE @ActiveStores INT = (
    SELECT COUNT(DISTINCT store_key)
    FROM gold.mart_transactions
    WHERE transaction_date >= @SinceDate
    GROUP BY store_key
    HAVING COUNT(*) >= 10
);

DECLARE @StoresWithBasketAnalysis INT = (
    SELECT COUNT(DISTINCT i.entity_key)
    FROM platinum.insights i
    WHERE i.source = 'market_basket'
    AND i.entity_type = 'brand'
    AND i.insight_date >= @SinceDate
);

IF @ActiveStores > 0
BEGIN
    DECLARE @BasketCoverage DECIMAL(9,2) = (100.0 * @StoresWithBasketAnalysis / @ActiveStores);

    IF @BasketCoverage < 80.0
    BEGIN
        PRINT CONCAT('⚠️  WARNING: Market basket coverage is ', @BasketCoverage, '% (target: ≥80%)');
        SET @WarningCount = @WarningCount + 1;
    END
    ELSE
        PRINT CONCAT('✅ Market basket coverage: ', @BasketCoverage, '%');
END;

-- ================================================================
-- F. MODEL PERFORMANCE VALIDATION
-- ================================================================

PRINT '';
PRINT '🎯 F. Model Performance Validation';
PRINT '-----------------------------------';

-- F1. Verify deployed models have performance metrics
DECLARE @DeployedModelsWithoutMetrics INT = (
    SELECT COUNT(*)
    FROM platinum.model_version mv
    LEFT JOIN platinum.model_metric mm ON mm.model_version_id = mv.model_version_id
    WHERE mv.deployment_status = 'production'
    AND mm.model_version_id IS NULL
);

IF @DeployedModelsWithoutMetrics > 0
BEGIN
    PRINT CONCAT('⚠️  WARNING: ', @DeployedModelsWithoutMetrics, ' deployed models lack performance metrics');
    SET @WarningCount = @WarningCount + 1;
END
ELSE
    PRINT '✅ All deployed models have performance metrics';

-- F2. Check for reasonable performance scores
DECLARE @PoorPerformingModels INT = (
    SELECT COUNT(DISTINCT mv.model_version_id)
    FROM platinum.model_version mv
    JOIN platinum.model_metric mm ON mm.model_version_id = mv.model_version_id
    WHERE mv.deployment_status = 'production'
    AND mm.metric_name IN ('accuracy', 'f1_score', 'auc')
    AND mm.metric_value < 0.6  -- Below 60% is concerning
);

IF @PoorPerformingModels > 0
BEGIN
    PRINT CONCAT('⚠️  WARNING: ', @PoorPerformingModels, ' deployed models have performance scores <60%');
    SET @WarningCount = @WarningCount + 1;
END
ELSE
    PRINT '✅ All deployed models have acceptable performance scores (≥60%)';

-- ================================================================
-- G. DATA QUALITY CHECKS
-- ================================================================

PRINT '';
PRINT '🔍 G. Data Quality Checks';
PRINT '-------------------------';

-- G1. Check for duplicate predictions
DECLARE @DuplicatePredictions INT = (
    SELECT COUNT(*) - COUNT(DISTINCT CONCAT(model_version_id, '|', subject_type, '|', subject_key, '|', label, '|', pred_date))
    FROM platinum.predictions
);

IF @DuplicatePredictions > 0
BEGIN
    PRINT CONCAT('❌ CRITICAL: ', @DuplicatePredictions, ' duplicate predictions detected');
    SET @ValidationErrors = @ValidationErrors + 1;
END
ELSE
    PRINT '✅ No duplicate predictions detected';

-- G2. Check for suspicious score ranges
DECLARE @InvalidScores INT = (
    SELECT COUNT(*)
    FROM platinum.predictions
    WHERE score IS NOT NULL
    AND (score < -100 OR score > 100) -- Scores outside reasonable range
);

IF @InvalidScores > 0
BEGIN
    PRINT CONCAT('⚠️  WARNING: ', @InvalidScores, ' predictions have scores outside reasonable range (-100 to 100)');
    SET @WarningCount = @WarningCount + 1;
END
ELSE
    PRINT '✅ All prediction scores within reasonable range';

-- G3. Check confidence values are between 0 and 1
DECLARE @InvalidConfidence INT = (
    SELECT COUNT(*)
    FROM platinum.predictions
    WHERE confidence IS NOT NULL
    AND (confidence < 0 OR confidence > 1)
);

IF @InvalidConfidence > 0
BEGIN
    PRINT CONCAT('❌ CRITICAL: ', @InvalidConfidence, ' predictions have invalid confidence values (must be 0-1)');
    SET @ValidationErrors = @ValidationErrors + 1;
END
ELSE
    PRINT '✅ All confidence values within valid range (0-1)';

-- ================================================================
-- H. PERFORMANCE AND INDEX VALIDATION
-- ================================================================

PRINT '';
PRINT '⚡ H. Performance and Index Validation';
PRINT '--------------------------------------';

-- H1. Check for required indexes
DECLARE @RequiredIndexes TABLE (table_name SYSNAME, index_name SYSNAME);
INSERT INTO @RequiredIndexes VALUES
    ('predictions', 'IX_pred_subject_latest'),
    ('predictions', 'IX_pred_model_date'),
    ('insights', 'IX_insight_entity_date'),
    ('features', 'IX_feat_subject_date');

DECLARE @MissingIndexes INT = (
    SELECT COUNT(*)
    FROM @RequiredIndexes ri
    WHERE NOT EXISTS (
        SELECT 1 FROM sys.indexes i
        JOIN sys.tables t ON t.object_id = i.object_id
        JOIN sys.schemas s ON s.schema_id = t.schema_id
        WHERE s.name = 'platinum'
        AND t.name = ri.table_name
        AND i.name = ri.index_name
    )
);

IF @MissingIndexes > 0
BEGIN
    PRINT CONCAT('⚠️  WARNING: ', @MissingIndexes, ' required indexes missing (may impact performance)');
    SET @WarningCount = @WarningCount + 1;
END
ELSE
    PRINT '✅ All required performance indexes present';

-- ================================================================
-- I. INTEGRATION WITH GOLD LAYER VALIDATION
-- ================================================================

PRINT '';
PRINT '🔗 I. Integration with Gold Layer';
PRINT '---------------------------------';

-- I1. Verify Gold layer views are accessible
DECLARE @GoldViews TABLE (view_name SYSNAME);
INSERT INTO @GoldViews VALUES ('mart_transactions'), ('v_customer_segments'), ('v_market_basket_analysis');

DECLARE @MissingGoldViews INT = (
    SELECT COUNT(*)
    FROM @GoldViews gv
    WHERE NOT EXISTS (
        SELECT 1 FROM sys.views v
        JOIN sys.schemas s ON s.schema_id = v.schema_id
        WHERE s.name = 'gold' AND v.name = gv.view_name
    )
);

IF @MissingGoldViews > 0
BEGIN
    PRINT CONCAT('⚠️  WARNING: ', @MissingGoldViews, ' expected Gold layer views not accessible');
    SET @WarningCount = @WarningCount + 1;
END
ELSE
    PRINT '✅ All expected Gold layer views accessible';

-- ================================================================
-- FINAL VALIDATION SUMMARY
-- ================================================================

DECLARE @ValidationDuration INT = DATEDIFF(MILLISECOND, @ValidationStart, SYSUTCDATETIME());

PRINT '';
PRINT '🏁 VALIDATION SUMMARY';
PRINT '====================';
PRINT CONCAT('Duration: ', @ValidationDuration, 'ms');
PRINT CONCAT('Validation Time: ', CONVERT(VARCHAR, SYSUTCDATETIME(), 120), ' UTC');
PRINT '';

IF @ValidationErrors = 0
BEGIN
    PRINT '✅ ALL CRITICAL VALIDATIONS PASSED';

    IF @WarningCount = 0
        PRINT '✅ NO WARNINGS - ANALYTICS PLATFORM FULLY OPERATIONAL';
    ELSE
        PRINT CONCAT('⚠️  ', @WarningCount, ' warnings detected - review recommended but not blocking');

    PRINT '';
    PRINT '🚀 ANALYTICS INTEGRITY: VALIDATED';
    PRINT '📊 READY FOR PRODUCTION WORKLOADS';
END
ELSE
BEGIN
    PRINT CONCAT('❌ ', @ValidationErrors, ' CRITICAL ERRORS DETECTED');
    PRINT CONCAT('⚠️  ', @WarningCount, ' warnings detected');
    PRINT '';
    PRINT '🚨 ANALYTICS INTEGRITY: FAILED';
    PRINT '⚠️  DO NOT PROCEED TO PRODUCTION';

    -- Fail the validation
    THROW 50021, 'Analytics integrity validation failed - critical errors detected', 1;
END;

-- Log validation results
INSERT INTO dbo.etl_execution_log (etl_name, started_at, finished_at, status, notes)
VALUES (
    'analytics_integrity_validation',
    @ValidationStart,
    SYSUTCDATETIME(),
    CASE WHEN @ValidationErrors = 0 THEN 'SUCCESS' ELSE 'FAILED' END,
    CONCAT('Errors: ', @ValidationErrors, ', Warnings: ', @WarningCount, ', Duration: ', @ValidationDuration, 'ms')
);

PRINT CONCAT('📝 Validation results logged to etl_execution_log');
PRINT '';

-- Return summary for programmatic access
SELECT
    @ValidationErrors AS critical_errors,
    @WarningCount AS warnings,
    @ValidationDuration AS duration_ms,
    CASE WHEN @ValidationErrors = 0 THEN 'PASS' ELSE 'FAIL' END AS overall_status,
    @PersonaCoverage AS persona_coverage_pct,
    @TotalTransactions AS total_transactions,
    @PersonaPredictions AS persona_predictions,
    @FreshPredictions AS fresh_predictions,
    @FreshInsights AS fresh_insights;