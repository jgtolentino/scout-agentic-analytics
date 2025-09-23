#!/usr/bin/env bash
# Setup Bruno vault entry for scout_reader password
# This ensures zero-credential architecture while enabling exports

set -euo pipefail

echo "🔐 Setting up Bruno vault for scout_reader credentials"
echo "=================================================="

# Bruno vault path for Scout analytics
VAULT_PATH="vault.scout_analytics.sql_reader_password"

echo "📋 Instructions for Bruno vault setup:"
echo ""
echo "1. Open Bruno and navigate to your Scout project"
echo "2. Go to Settings → Environment Variables"
echo "3. Add the following vault entry:"
echo ""
echo "   Key: ${VAULT_PATH}"
echo "   Value: [SECURE_PASSWORD_FOR_SCOUT_READER]"
echo ""
echo "4. Test the connection with:"
echo "   export AZSQL_PASS=\"\${${VAULT_PATH}}\""
echo "   sqlcmd -S sqltbwaprojectscoutserver.database.windows.net \\"
echo "     -d flat_scratch -U scout_reader -P \"\$AZSQL_PASS\" \\"
echo "     -C -Q \"SELECT TOP (1) 1 AS connectivity_test;\""
echo ""

# Create test script to validate vault integration
cat > scripts/test_vault_connection.sh << 'EOF'
#!/usr/bin/env bash
# Test script for Bruno vault integration

if [[ -z "${AZSQL_PASS:-}" ]]; then
    echo "❌ AZSQL_PASS not set. Bruno should inject from vault."
    echo "   Ensure vault.scout_analytics.sql_reader_password is configured"
    exit 1
fi

echo "🔍 Testing scout_reader connection..."
if sqlcmd -S sqltbwaprojectscoutserver.database.windows.net \
    -d flat_scratch -U scout_reader -P "$AZSQL_PASS" \
    -C -l 15 -Q "SELECT TOP (1) 1 AS connectivity_test;" > /dev/null 2>&1; then
    echo "✅ Connection successful - Bruno vault integration working"
    exit 0
else
    echo "❌ Connection failed - check credentials or firewall"
    exit 1
fi
EOF

chmod +x scripts/test_vault_connection.sh

echo "✅ Setup complete!"
echo ""
echo "📝 Next steps:"
echo "1. Configure Bruno vault with scout_reader password"
echo "2. Run: ./scripts/test_vault_connection.sh"
echo "3. Execute exports: ./scripts/export_complete_data.sh"
echo ""
echo "🔗 Export commands ready:"
echo "   - scout_flat_complete_all_12075_records.csv (24 columns)"
echo "   - scout_crosstab_complete_all_data.csv (10 columns)"