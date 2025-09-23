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
