#!/usr/bin/env bash
set -euo pipefail

echo "🔍 Scout Badge Validation Test"
echo "==============================="

# Test credentials from keychain
REF=$(security find-generic-password -s "scout-validation" -a "SUPABASE_REF" -w 2>/dev/null || echo "demo-project")
ANON=$(security find-generic-password -s "scout-validation" -a "SUPABASE_ANON_KEY" -w 2>/dev/null || echo "demo-anon-key")

echo "🎯 Target: https://${REF}.supabase.co"
echo ""

# Test badge status
echo "🏷️  Checking current badge status..."
if badge=$(curl -sf "https://${REF}.supabase.co/rest/v1/rpc/get_data_source_badge" \
    -H "apikey: ${ANON}" \
    -H "Authorization: Bearer ${ANON}" \
    -H "Content-Type: application/json" \
    -d '{}' | jq -r '.' 2>/dev/null); then

    echo "📊 Current Badge: $badge"

    case "$badge" in
        "Trusted")
            echo "🎉 SUCCESS: Badge shows 'Trusted'!"
            ;;
        "Partial Coverage")
            echo "🔄 Progress: Data present but coverage below threshold"
            ;;
        "Limited Data")
            echo "⚠️  Partial: Only some data sources available"
            ;;
        "Mock Data")
            echo "❌ Still Mock Data - data processing may have failed"
            ;;
    esac
else
    echo "❌ Badge check failed - API might not be accessible"

    # Try a simpler health check
    echo ""
    echo "🔍 Testing basic connectivity..."
    if curl -sf "https://${REF}.supabase.co/rest/v1/health" -H "apikey: ${ANON}" >/dev/null 2>&1; then
        echo "✅ Basic connectivity works"
    else
        echo "❌ Connection failed"
        echo ""
        echo "💡 Possible issues:"
        echo "   - Incorrect credentials in keychain"
        echo "   - API endpoint not available"
        echo "   - Network connectivity issues"
        echo "   - Badge function not deployed"
    fi
fi

echo ""
echo "✅ Validation test complete"