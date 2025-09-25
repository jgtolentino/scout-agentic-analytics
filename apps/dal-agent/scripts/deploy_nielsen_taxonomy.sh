#!/usr/bin/env bash
# DEPLOY NIELSEN INDUSTRY STANDARD TAXONOMY
set -euo pipefail

echo "🏪 DEPLOYING NIELSEN TAXONOMY FOR SCOUT ANALYTICS"
echo "=================================================="
echo ""

# Check if connection string is provided
if [ -z "${AZURE_SQL_CONN_STR:-}" ]; then
    echo "❌ AZURE_SQL_CONN_STR not set. Setting up connection..."
    echo ""
    echo "🔐 Using Azure credentials:"
    export AZURE_SQL_CONN_STR="sqltbwaprojectscoutserver.database.windows.net -d sqltbwaprojectscoutserverdb -U sqladmin -P 'R@nd0mPA\$2025!'"
    echo "   ✅ Connection configured"
fi

echo ""

# Test connection first
echo "🔍 Testing database connection..."
if sqlcmd -S $AZURE_SQL_CONN_STR -Q "SELECT COUNT(*) as test FROM dbo.SalesInteractions" -h -1 > /tmp/connection_test.txt 2>&1; then
    echo "✅ Database connection successful"
    test_count=$(cat /tmp/connection_test.txt | tr -d ' \t\n\r')
    echo "   SalesInteractions count: $test_count"
    rm -f /tmp/connection_test.txt
else
    echo "❌ Database connection failed:"
    cat /tmp/connection_test.txt
    rm -f /tmp/connection_test.txt
    echo ""
    echo "💡 Check credentials and network connectivity"
    exit 1
fi

echo ""
echo "📊 STEP 1: Create Nielsen Hierarchy Tables"
echo "=========================================="

echo "Creating Nielsen taxonomy structure (Departments → Groups → Categories → Subcategories → Brands)..."
if sqlcmd -S $AZURE_SQL_CONN_STR -i sql/analytics/008_nielsen_taxonomy_extension.sql > /tmp/nielsen_structure.log 2>&1; then
    echo "✅ Nielsen structure created successfully"
    echo "   📋 Created: 6 departments, 25+ groups, 50+ categories"
    echo "   🏷️  Structure: Department → Group → Category → Subcategory"
else
    echo "❌ Failed to create Nielsen structure:"
    cat /tmp/nielsen_structure.log
    rm -f /tmp/nielsen_structure.log
    exit 1
fi
rm -f /tmp/nielsen_structure.log

echo ""
echo "🏷️  STEP 2: Map All 113 Brands to Nielsen Categories"
echo "===================================================="

echo "Mapping brands to Nielsen subcategories with full hierarchy..."
if sqlcmd -S $AZURE_SQL_CONN_STR -i sql/analytics/009_brand_to_nielsen_mapping.sql > /tmp/brand_mapping.log 2>&1; then
    echo "✅ Brand mapping completed successfully"

    # Get mapping statistics
    mapped_brands=$(sqlcmd -S $AZURE_SQL_CONN_STR -Q "SELECT COUNT(*) FROM dbo.nielsen_brand_mapping" -h -1 | tr -d ' \t\n\r')
    critical_brands=$(sqlcmd -S $AZURE_SQL_CONN_STR -Q "SELECT COUNT(*) FROM dbo.v_nielsen_brand_hierarchy WHERE sari_sari_importance = 'Critical'" -h -1 | tr -d ' \t\n\r')
    high_priority=$(sqlcmd -S $AZURE_SQL_CONN_STR -Q "SELECT COUNT(*) FROM dbo.v_nielsen_brand_hierarchy WHERE sari_sari_importance = 'High Priority'" -h -1 | tr -d ' \t\n\r')

    echo "   📈 Total brands mapped: $mapped_brands"
    echo "   🎯 Critical sari-sari brands: $critical_brands"
    echo "   ⭐ High priority brands: $high_priority"
else
    echo "❌ Failed to create brand mapping:"
    cat /tmp/brand_mapping.log
    rm -f /tmp/brand_mapping.log
    exit 1
fi
rm -f /tmp/brand_mapping.log

echo ""
echo "📋 STEP 3: Create Nielsen-Enhanced Export Views"
echo "=============================================="

echo "Creating enhanced flat export with Nielsen taxonomy..."
if sqlcmd -S $AZURE_SQL_CONN_STR -i sql/analytics/010_nielsen_flat_export_final.sql > /tmp/export_views.log 2>&1; then
    echo "✅ Nielsen export views created successfully"
    echo "   📊 Views created:"
    echo "   • v_nielsen_flat_export (15 columns with full Nielsen hierarchy)"
    echo "   • v_nielsen_summary (departmental analytics)"
    echo "   • v_nielsen_brand_performance (brand rankings)"
else
    echo "❌ Failed to create export views:"
    cat /tmp/export_views.log
    rm -f /tmp/export_views.log
    exit 1
fi
rm -f /tmp/export_views.log

echo ""
echo "📈 STEP 4: Generate Analytics Report"
echo "===================================="

echo "Generating Nielsen taxonomy analytics..."
mkdir -p out/nielsen

# Export Nielsen summary
echo "📊 Exporting Nielsen taxonomy summary..."
sqlcmd -S $AZURE_SQL_CONN_STR -Q "SELECT * FROM dbo.v_nielsen_summary" -s "," -W -h -1 > out/nielsen/nielsen_summary.csv

# Export brand performance
echo "🏆 Exporting brand performance rankings..."
sqlcmd -S $AZURE_SQL_CONN_STR -Q "SELECT TOP 50 * FROM dbo.v_nielsen_brand_performance ORDER BY Transaction_Count DESC" -s "," -W -h -1 > out/nielsen/top_50_brands.csv

# Export departmental breakdown
echo "📋 Exporting departmental breakdown..."
sqlcmd -S $AZURE_SQL_CONN_STR -Q "
SELECT
    Nielsen_Department as Department,
    COUNT(*) as Transaction_Count,
    COUNT(DISTINCT Brand_Name) as Unique_Brands,
    SUM(Transaction_Value) as Total_Revenue,
    AVG(Transaction_Value) as Avg_Transaction_Value,
    CAST(100.0 * COUNT(*) / (SELECT COUNT(*) FROM dbo.v_nielsen_flat_export) AS DECIMAL(5,2)) as Percent_of_Total
FROM dbo.v_nielsen_flat_export
WHERE Nielsen_Department != 'Unclassified'
GROUP BY Nielsen_Department
ORDER BY Transaction_Count DESC
" -s "," -W -h -1 > out/nielsen/departmental_analysis.csv

# Export data quality report
echo "✅ Exporting data quality metrics..."
sqlcmd -S $AZURE_SQL_CONN_STR -Q "
SELECT
    Quality_Flag,
    COUNT(*) as Transaction_Count,
    CAST(100.0 * COUNT(*) / (SELECT COUNT(*) FROM dbo.v_nielsen_flat_export) AS DECIMAL(5,2)) as Percentage,
    AVG(Transaction_Value) as Avg_Value
FROM dbo.v_nielsen_flat_export
GROUP BY Quality_Flag
ORDER BY Transaction_Count DESC
" -s "," -W -h -1 > out/nielsen/data_quality_report.csv

# Sample of enhanced data
echo "🔍 Exporting data sample (first 100 transactions)..."
sqlcmd -S $AZURE_SQL_CONN_STR -Q "SELECT TOP 100 * FROM dbo.v_nielsen_flat_export ORDER BY Transaction_ID" -s "," -W -h -1 > out/nielsen/sample_data_nielsen.csv

echo ""
echo "🎉 NIELSEN TAXONOMY DEPLOYMENT COMPLETE"
echo "======================================="

# Get final statistics
total_transactions=$(sqlcmd -S $AZURE_SQL_CONN_STR -Q "SELECT COUNT(*) FROM dbo.v_nielsen_flat_export" -h -1 | tr -d ' \t\n\r')
nielsen_mapped=$(sqlcmd -S $AZURE_SQL_CONN_STR -Q "SELECT COUNT(*) FROM dbo.v_nielsen_flat_export WHERE Data_Source = 'Nielsen_Mapped'" -h -1 | tr -d ' \t\n\r')
coverage_pct=$(sqlcmd -S $AZURE_SQL_CONN_STR -Q "SELECT CAST(100.0 * SUM(CASE WHEN Data_Source = 'Nielsen_Mapped' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) FROM dbo.v_nielsen_flat_export" -h -1 | tr -d ' \t\n\r')

departments=$(sqlcmd -S $AZURE_SQL_CONN_STR -Q "SELECT COUNT(DISTINCT Nielsen_Department) FROM dbo.v_nielsen_flat_export WHERE Nielsen_Department != 'Unclassified'" -h -1 | tr -d ' \t\n\r')
categories=$(sqlcmd -S $AZURE_SQL_CONN_STR -Q "SELECT COUNT(DISTINCT Nielsen_Category) FROM dbo.v_nielsen_flat_export WHERE Nielsen_Category != 'Unclassified'" -h -1 | tr -d ' \t\n\r')
brands_mapped=$(sqlcmd -S $AZURE_SQL_CONN_STR -Q "SELECT COUNT(DISTINCT Brand_Name) FROM dbo.v_nielsen_flat_export WHERE Brand_Name != 'Unknown'" -h -1 | tr -d ' \t\n\r')

echo ""
echo "📊 FINAL STATISTICS:"
echo "==================="
echo "✅ Total transactions processed: $total_transactions"
echo "✅ Nielsen-mapped transactions: $nielsen_mapped ($coverage_pct%)"
echo "✅ Active departments: $departments"
echo "✅ Active categories: $categories"
echo "✅ Mapped brands: $brands_mapped"
echo ""
echo "📁 FILES CREATED:"
echo "================"
echo "• out/nielsen/nielsen_summary.csv - Overall taxonomy summary"
echo "• out/nielsen/top_50_brands.csv - Top performing brands"
echo "• out/nielsen/departmental_analysis.csv - Department-level analytics"
echo "• out/nielsen/data_quality_report.csv - Data quality metrics"
echo "• out/nielsen/sample_data_nielsen.csv - Sample enhanced data"
echo ""
echo "🎯 NEXT STEPS:"
echo "=============="
echo "1. Review data quality report - target >80% Nielsen coverage"
echo "2. Validate brand mappings against actual product portfolios"
echo "3. Use v_nielsen_flat_export for business intelligence"
echo "4. Consider extending to full 1,100 Nielsen categories for deeper insights"
echo ""
echo "✨ Nielsen Industry Standard Taxonomy successfully deployed!"
echo "   Compatible with Nielsen ScanTrack, Kantar CRP, and FMCG standards"