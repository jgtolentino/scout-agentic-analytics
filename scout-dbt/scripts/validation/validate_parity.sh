#!/bin/bash
set -euo pipefail

echo "🔍 Validating parity between Supabase and Azure SQL..."

# Check row counts
SUPABASE_COUNT=$(PGPASSWORD="$SUPABASE_PASS" psql "$SUPABASE_URL" -tAc "
    SELECT COUNT(*) FROM gold.gold_store_performance;
")

AZURE_COUNT=$(sqlcmd -S "$AZURE_SERVER" -d "$AZURE_DATABASE" -U "$AZURE_USERNAME" -P "$AZURE_PASSWORD" -Q "
    SELECT COUNT(*) FROM gold.gold_store_performance;
" -h -1)

echo "Supabase row count: $SUPABASE_COUNT"
echo "Azure SQL row count: $AZURE_COUNT"

if [ "$SUPABASE_COUNT" -eq "$AZURE_COUNT" ]; then
    echo "✅ Row counts match"
else
    echo "❌ Row count mismatch!"
    exit 1
fi

# Check verification rates
SUPABASE_RATE=$(PGPASSWORD="$SUPABASE_PASS" psql "$SUPABASE_URL" -tAc "
    SELECT ROUND(AVG(verification_rate), 2) FROM gold.gold_store_performance;
")

AZURE_RATE=$(sqlcmd -S "$AZURE_SERVER" -d "$AZURE_DATABASE" -U "$AZURE_USERNAME" -P "$AZURE_PASSWORD" -Q "
    SELECT ROUND(AVG(verification_rate), 2) FROM gold.gold_store_performance;
" -h -1)

echo "Supabase avg verification rate: $SUPABASE_RATE%"
echo "Azure SQL avg verification rate: $AZURE_RATE%"

if [ "$SUPABASE_RATE" = "$AZURE_RATE" ]; then
    echo "✅ Verification rates match"
else
    echo "⚠️ Verification rate variance detected"
fi

echo "✅ Parity validation complete"
