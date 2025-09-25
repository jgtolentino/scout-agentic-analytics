#!/usr/bin/env bash
# EXECUTE IMMEDIATE FIX - Category Correction + SKU Backfill
set -euo pipefail

echo "🚀 EXECUTING IMMEDIATE FIX FOR SCOUT ANALYTICS"
echo "============================================="
echo ""

# Check if connection string is provided
if [ -z "${AZURE_SQL_CONN_STR:-}" ]; then
    echo "❌ AZURE_SQL_CONN_STR not set. Please set it first:"
    echo ""
    echo "Option 1: sqladmin + Azure_pw26"
    echo "export AZURE_SQL_CONN_STR=\"sqltbwaprojectscoutserver.database.windows.net -d sqltbwaprojectscoutserverdb -U sqladmin -P Azure_pw26\""
    echo ""
    echo "Option 2: sqladmin + R@nd0mPA\$2025!"
    echo "export AZURE_SQL_CONN_STR=\"sqltbwaprojectscoutserver.database.windows.net -d sqltbwaprojectscoutserverdb -U sqladmin -P 'R@nd0mPA\$2025!'\""
    echo ""
    echo "Then run: ./scripts/execute_fix_now.sh"
    exit 1
fi

echo "✅ Connection string configured"
echo ""

# Test connection first
echo "🔍 Testing database connection..."
if sqlcmd -S $AZURE_SQL_CONN_STR -Q "SELECT COUNT(*) as test FROM dbo.TransactionItems" -h -1 > /tmp/connection_test.txt 2>&1; then
    echo "✅ Database connection successful"
    test_count=$(cat /tmp/connection_test.txt | tr -d ' \t\n\r')
    echo "   TransactionItems count: $test_count"
    rm -f /tmp/connection_test.txt
else
    echo "❌ Database connection failed:"
    cat /tmp/connection_test.txt
    rm -f /tmp/connection_test.txt
    echo ""
    echo "💡 Try different credentials or check network connectivity"
    exit 1
fi

echo ""
echo "🔧 STEP 1: Category Fix + SKU Backfill"
echo "======================================"

# Execute the main fix script
echo "Executing sql/analytics/004_fix_categories_and_backfill_skus.sql..."

# First run in validation mode (with ROLLBACK)
sqlcmd -S $AZURE_SQL_CONN_STR -i sql/analytics/004_fix_categories_and_backfill_skus.sql

echo ""
echo "📊 STEP 2: Manual Commit Decision"
echo "================================="
echo ""
echo "❗ IMPORTANT: The script ran in VALIDATION MODE (with ROLLBACK)"
echo "   Review the output above to confirm:"
echo "   ✅ 'CATEGORIES TO BE FIXED' shows correct mappings"
echo "   ✅ 'categories_fixed' shows reasonable count"
echo "   ✅ 'skus_backfilled' shows progress (if payload data available)"
echo ""
echo "🎯 TO ACTUALLY APPLY THE FIXES:"
echo "   1. Edit sql/analytics/004_fix_categories_and_backfill_skus.sql"
echo "   2. Change 'ROLLBACK;' to 'COMMIT;' at the end"
echo "   3. Run this script again"
echo ""

# Check if it was actually committed or rolled back
echo "🔍 Checking if changes were applied..."
unspec_count=$(sqlcmd -S $AZURE_SQL_CONN_STR -Q "SELECT COUNT(*) FROM dbo.TransactionItems WHERE brand_name = 'Alaska' AND category = 'unspecified'" -h -1 | tr -d ' \t\n\r')

if [ "$unspec_count" = "0" ]; then
    echo "✅ CHANGES APPLIED! Alaska no longer has unspecified category"

    echo ""
    echo "📈 STEP 3: Verification and Export"
    echo "=================================="

    # Run verification script
    sqlcmd -S $AZURE_SQL_CONN_STR -i sql/analytics/005_verify_and_export_fixed.sql

    echo ""
    echo "📦 STEP 4: Export Clean Data"
    echo "============================"

    # Export clean brand mapping
    echo "Exporting fixed brand mapping..."
    mkdir -p out/fixed

    sqlcmd -S $AZURE_SQL_CONN_STR -Q "
    WITH brand_summary AS (
        SELECT
            ti.brand_name,
            ti.category,
            COUNT(*) as transactions,
            SUM(TRY_CAST(si.TransactionValue AS DECIMAL(10,2))) as total_sales,
            COUNT(DISTINCT ti.sku_id) as unique_skus,
            ROW_NUMBER() OVER (PARTITION BY ti.brand_name ORDER BY COUNT(*) DESC) as rn
        FROM dbo.TransactionItems ti
        LEFT JOIN dbo.SalesInteractions si ON si.canonical_tx_id = ti.canonical_tx_id
        GROUP BY ti.brand_name, ti.category
    )
    SELECT
        brand_name,
        category,
        transactions,
        ISNULL(total_sales, 0) as total_sales,
        unique_skus
    FROM brand_summary
    WHERE rn = 1
    ORDER BY transactions DESC
    " -s "," -W -h -1 > out/fixed/clean_brand_mapping.csv

    echo "✅ Clean data exported to: out/fixed/clean_brand_mapping.csv"

    # Show summary
    total_brands=$(sqlcmd -S $AZURE_SQL_CONN_STR -Q "SELECT COUNT(DISTINCT brand_name) FROM dbo.TransactionItems" -h -1 | tr -d ' \t\n\r')
    total_unspec=$(sqlcmd -S $AZURE_SQL_CONN_STR -Q "SELECT COUNT(*) FROM dbo.TransactionItems WHERE category = 'unspecified'" -h -1 | tr -d ' \t\n\r')
    total_with_sku=$(sqlcmd -S $AZURE_SQL_CONN_STR -Q "SELECT COUNT(*) FROM dbo.TransactionItems WHERE sku_id IS NOT NULL" -h -1 | tr -d ' \t\n\r')

    echo ""
    echo "🎉 SUCCESS SUMMARY"
    echo "=================="
    echo "✅ Total brands: $total_brands"
    echo "✅ Unspecified categories remaining: $total_unspec"
    echo "✅ Items with SKU IDs: $total_with_sku"
    echo ""
    echo "📁 Files created:"
    echo "   • out/fixed/clean_brand_mapping.csv"
    echo ""
    echo "🎯 NEXT: Use the clean data for analytics and reporting!"

else
    echo "⚠️  CHANGES NOT YET APPLIED (still $unspec_count Alaska unspecified entries)"
    echo "   Script ran in validation mode only"
    echo ""
    echo "🔧 TO APPLY FIXES:"
    echo "   1. Review the validation output above"
    echo "   2. Edit sql/analytics/004_fix_categories_and_backfill_skus.sql"
    echo "   3. Change 'ROLLBACK;' to 'COMMIT;' at the end"
    echo "   4. Run this script again"
fi

echo ""
echo "🏁 Script completed."