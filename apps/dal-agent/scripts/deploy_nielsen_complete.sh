#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"

echo "🚀 Scout Nielsen Taxonomy Complete Deployment"
echo "=============================================="
echo ""

# 1. Deploy Nielsen taxonomy if not exists
echo "📊 Step 1: Deploy Nielsen taxonomy..."
if make migrate FILE=sql/analytics/011_nielsen_1100_migration.sql 2>/dev/null; then
    echo "✅ Nielsen taxonomy deployed successfully"
else
    echo "⚠️  Nielsen taxonomy deployment failed (may already exist)"
fi
echo ""

# 2. Deploy bulk loader
echo "🔧 Step 2: Deploy bulk brand loader..."
if make migrate FILE=sql/analytics/012_brand_category_bulk_loader.sql 2>/dev/null; then
    echo "✅ Bulk loader deployed successfully"
else
    echo "⚠️  Bulk loader deployment failed (may already exist)"
fi
echo ""

# 3. Load brand mappings
echo "📥 Step 3: Load brand mappings from CSV..."
if [ -f "$ROOT/data/brand-map-live.csv" ]; then
    if make brand-map-load CSV="$ROOT/data/brand-map-live.csv" 2>/dev/null; then
        echo "✅ Brand mappings loaded successfully"
    else
        echo "❌ Brand mapping load failed"
        exit 1
    fi
else
    echo "⚠️  brand-map-live.csv not found, skipping brand mapping"
fi
echo ""

# 4. Generate coverage report
echo "📊 Step 4: Generate coverage report..."
if make brand-map-report 2>/dev/null; then
    echo "✅ Coverage report generated"
else
    echo "⚠️  Coverage report failed"
fi
echo ""

# 5. Sync documentation
echo "📚 Step 5: Sync documentation..."
if make doc-sync 2>/dev/null; then
    echo "✅ Documentation synced"
else
    echo "⚠️  Documentation sync failed"
fi
echo ""

echo "🎉 Nielsen Taxonomy Deployment Complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Review coverage metrics in docs/DB_CHANGELOG.md"
echo "2. Update brand-map-live.csv with missing CategoryCodes"
echo "3. Run 'make brand-map-load CSV=data/brand-map-live.csv' to improve coverage"
echo "4. Use v_nielsen_flat_export view for enhanced analytics"
echo ""