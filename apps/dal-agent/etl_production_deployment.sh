#!/bin/bash
set -euo pipefail

DB="${DB:-SQL-TBWA-ProjectScout-Reporting-Prod}"
ROOT="${REPO_ROOT:-.}"

echo "🚀 Production ETL Deployment: Corrected Medallion Architecture"
echo "Database: ${DB}"
echo "================================================"

run_sql() {
    local file="$1"
    local desc="$2"
    echo "📋 ${desc}..."
    
    if [ -x "./scripts/sql.sh" ]; then
        ./scripts/sql.sh -i "$file"
    else
        # Fallback: direct sqlcmd (expects env vars)
        sqlcmd -S "${AZ_SQL_SERVER:?}" -d "${AZ_SQL_DB:-$DB}" -U "${AZ_SQL_USER:?}" -P "${AZ_SQL_PASS:?}" -b -i "$file"
    fi
    echo "✅ ${desc} completed"
}

# 1) Apply hardened medallion ETL
run_sql "sql/migrations/031_corrected_medallion_etl_hardened.sql" "Deploying corrected medallion architecture"

# 2) Apply Nielsen integration
run_sql "sql/migrations/032_nielsen_integration_silver.sql" "Integrating Nielsen taxonomy"

# 3) Add JSON performance optimizations
echo "📋 Adding JSON performance optimizations..."
cat > /tmp/json_perf_optimizations.sql << 'SQL'
SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRAN;

-- Add computed columns for hot JSON paths (idempotent)
IF COL_LENGTH('dbo.PayloadTransactions','cc_total_amount') IS NULL
    ALTER TABLE dbo.PayloadTransactions
    ADD cc_total_amount AS TRY_CONVERT(DECIMAL(18,2), JSON_VALUE(payload_json, '$.totalAmount')) PERSISTED;

IF COL_LENGTH('dbo.PayloadTransactions','cc_item_count') IS NULL
    ALTER TABLE dbo.PayloadTransactions
    ADD cc_item_count AS TRY_CONVERT(INT, JSON_VALUE(payload_json, '$.items.length()')) PERSISTED;

IF COL_LENGTH('dbo.PayloadTransactions','cc_store_key') IS NULL
    ALTER TABLE dbo.PayloadTransactions
    ADD cc_store_key AS TRY_CONVERT(VARCHAR(64), JSON_VALUE(payload_json, '$.store.key')) PERSISTED;

-- Create indexes on computed columns
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_pt_cc_total_amount' AND object_id=OBJECT_ID('dbo.PayloadTransactions'))
    CREATE INDEX IX_pt_cc_total_amount ON dbo.PayloadTransactions(cc_total_amount) WHERE cc_total_amount IS NOT NULL;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_pt_cc_item_count' AND object_id=OBJECT_ID('dbo.PayloadTransactions'))
    CREATE INDEX IX_pt_cc_item_count ON dbo.PayloadTransactions(cc_item_count) WHERE cc_item_count IS NOT NULL;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_pt_cc_store_key' AND object_id=OBJECT_ID('dbo.PayloadTransactions'))
    CREATE INDEX IX_pt_cc_store_key ON dbo.PayloadTransactions(cc_store_key) WHERE cc_store_key IS NOT NULL;

-- Index on canonical_tx_id for performance
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_pt_canonical_tx_id' AND object_id=OBJECT_ID('dbo.PayloadTransactions'))
    CREATE INDEX IX_pt_canonical_tx_id ON dbo.PayloadTransactions(canonical_tx_id);

PRINT '✅ JSON performance optimizations applied';
COMMIT;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK;
    PRINT '❌ JSON optimization failed: ' + ERROR_MESSAGE();
    THROW;
END CATCH
SQL

run_sql "/tmp/json_perf_optimizations.sql" "Applying JSON performance optimizations"

# 4) Execute migration from legacy to medallion
echo "📋 Executing legacy to medallion migration..."
cat > /tmp/execute_migration.sql << 'SQL'
-- Execute the migration with error handling
DECLARE @start_time DATETIME2 = SYSUTCDATETIME();
PRINT 'Starting legacy to medallion migration...';

EXEC dbo.sp_MigrateLegacyToMedallion @SinceDate = '2025-09-01';

DECLARE @end_time DATETIME2 = SYSUTCDATETIME();
DECLARE @duration_seconds INT = DATEDIFF(SECOND, @start_time, @end_time);

PRINT CONCAT('Migration completed in ', @duration_seconds, ' seconds');

-- Apply Nielsen mapping
PRINT 'Applying Nielsen taxonomy mapping...';
EXEC dbo.sp_ApplyNielsenMappingToSilver;

-- Populate initial Nielsen metrics
PRINT 'Populating Nielsen metrics...';
EXEC dbo.sp_PopulateNielsenMetrics;

PRINT '✅ Migration and Nielsen integration completed successfully';
SQL

run_sql "/tmp/execute_migration.sql" "Executing data migration"

# 5) Run comprehensive parity validation
echo "📋 Running parity validation (Gold vs Legacy)..."
run_sql "sql/validation/validate_gold_vs_legacy.sql" "Validating Gold vs Legacy parity"

# 6) Generate deployment summary
echo "📋 Generating deployment summary..."
cat > /tmp/deployment_summary.sql << 'SQL'
SELECT 'DEPLOYMENT SUMMARY' AS summary_type;

-- Schema objects created
SELECT 
    s.name AS schema_name,
    COUNT(*) AS object_count,
    STRING_AGG(o.type_desc, ', ') AS object_types
FROM sys.objects o
INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE s.name IN ('bronze', 'silver', 'gold', 'platinum')
GROUP BY s.name
ORDER BY s.name;

-- Row counts by layer
SELECT 'ROW COUNTS' AS section;

SELECT 'silver.transactions' AS table_name, COUNT(*) AS row_count FROM silver.transactions
UNION ALL
SELECT 'silver.transaction_items', COUNT(*) FROM silver.transaction_items
UNION ALL
SELECT 'silver.stores', COUNT(*) FROM silver.stores;

-- Data quality metrics
SELECT 'DATA QUALITY' AS section;

SELECT 
    metric_name,
    metric_value,
    layer,
    metric_date
FROM dbo.data_quality_metrics
WHERE metric_date = CAST(GETUTCDATE() AS DATE)
ORDER BY layer, metric_name;

-- ETL execution log (recent)
SELECT 'ETL EXECUTION LOG' AS section;

SELECT TOP 10
    etl_name,
    started_at,
    finished_at,
    status,
    DATEDIFF(SECOND, started_at, finished_at) AS duration_seconds,
    notes
FROM dbo.etl_execution_log
ORDER BY started_at DESC;

PRINT '🎯 Deployment completed successfully!';
PRINT 'Ready to switch API to READ from Gold layer.';
SQL

run_sql "/tmp/deployment_summary.sql" "Generating deployment summary"

# 7) Clean up temporary files
rm -f /tmp/json_perf_optimizations.sql /tmp/execute_migration.sql /tmp/deployment_summary.sql

echo ""
echo "🎉 PRODUCTION ETL DEPLOYMENT COMPLETED SUCCESSFULLY!"
echo "================================================"
echo "✅ Medallion architecture deployed with production guardrails"
echo "✅ canonical_tx_id linking implemented across all layers"
echo "✅ Single date source principle enforced (SalesInteractions.TransactionDate)"
echo "✅ JSON extraction optimized with computed columns and indexes"
echo "✅ Nielsen taxonomy integrated into Silver layer"
echo "✅ Comprehensive parity validation passed"
echo "✅ ETL governance and monitoring in place"
echo ""
echo "🚦 NEXT STEPS:"
echo "1. Switch API to READ from Gold layer (READ_MODE=gold)"
echo "2. Monitor Gold layer performance for 48 hours"
echo "3. Archive legacy direct table access after validation period"
echo ""
echo "📊 Gold layer views available:"
echo "   - gold.fact_transactions"
echo "   - gold.mart_transactions" 
echo "   - gold.daily_metrics"
echo "   - gold.nielsen_category_metrics"
echo "   - gold.nielsen_brand_metrics"
