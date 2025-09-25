#!/usr/bin/env bash
set -euo pipefail

# ========================================================================
# Scout Analytics - Database Connection Doctor
# Script: conn_doctor.sh
# Purpose: Diagnose Azure SQL connectivity issues and provide solutions
# ========================================================================

DB="${DB:-SQL-TBWA-ProjectScout-Reporting-Prod}"
SERVER="${SERVER:-sqltbwaprojectscoutserver.database.windows.net}"
USER="${DB_USER:-sqladmin}"

echo "🔎 Probing connectivity to $SERVER (DB=$DB, USER=$USER)"
echo "================================================"

# Create temporary error file
errfile=$(mktemp)

# Test basic connectivity
echo "📡 Testing basic SQL connectivity..."
if ./scripts/sql.sh -S "$SERVER" -d "$DB" -U "$USER" -Q "SELECT TOP 1 name FROM sys.databases;" >/dev/null 2>"$errfile"; then
    echo "✅ SQL connectivity OK - Database is accessible"
    echo "🎯 Ready to run: make persona-ci DB=\"$DB\" MIN_PCT=30"
    rm -f "$errfile"
    exit 0
fi

echo "❌ Connectivity failed. Analyzing error patterns..."
echo ""

# Read and clean error output
err=$(tr -d '\r' <"$errfile" | head -20)  # Limit output size
rm -f "$errfile"

echo "📋 Error Analysis:"
echo "=================="

# Pattern matching for common Azure SQL issues
case "$err" in
    *"Login failed for user"*)
        echo "🔐 Issue: Authentication Failed"
        echo "   Cause: Invalid credentials or expired token"
        echo "   Action: Check keychain credentials"
        echo "   Fix: security add-generic-password -s 'SQL-TBWA-ProjectScout-Reporting-Prod' -a 'scout-analytics' -w 'your-connection-string'"
        echo "   Alternative: Verify Azure AD token if using managed identity"
        exit 2
        ;;
    *"Cannot open server"*"requested by the login"*)
        echo "🌐 Issue: Server Not Reachable"
        echo "   Cause: DNS resolution failure or server name incorrect"
        echo "   Action: Verify SERVER environment variable"
        echo "   Fix: Check server name: $SERVER"
        echo "   Alternative: Try ping $SERVER"
        exit 3
        ;;
    *"Client with IP address"*"is not allowed to access the server"*)
        echo "🔥 Issue: Firewall Blocked"
        echo "   Cause: Your IP address is not in Azure SQL firewall rules"
        echo "   Action: Add your IP to Azure SQL firewall"
        echo "   Fix: az sql server firewall-rule create \\"
        echo "          --resource-group <resource-group> \\"
        echo "          --server sqltbwaprojectscoutserver \\"
        echo "          -n allow-current-ip \\"
        echo "          --start-ip-address \$(curl -s ifconfig.me) \\"
        echo "          --end-ip-address \$(curl -s ifconfig.me)"
        echo "   Quick: Current IP: $(curl -s ifconfig.me 2>/dev/null || echo 'unable to detect')"
        exit 4
        ;;
    *"The server is currently too busy"*)
        echo "⏳ Issue: Server Overloaded"
        echo "   Cause: Azure SQL is throttling connections"
        echo "   Action: Retry with exponential backoff"
        echo "   Fix: ./scripts/retry_persona_ci.sh"
        echo "   Note: This is temporary - database will recover"
        exit 5
        ;;
    *"Transport-level error"*)
        echo "🌍 Issue: Network Connectivity"
        echo "   Cause: Network interruption or proxy issues"
        echo "   Action: Check VPN/proxy configuration"
        echo "   Fix: Verify network connectivity and retry"
        echo "   Alternative: Try from different network location"
        exit 6
        ;;
    *"not currently available"*)
        echo "🔄 Issue: Database Temporarily Unavailable"
        echo "   Cause: Azure SQL maintenance or scaling operation"
        echo "   Action: Wait and retry with backoff"
        echo "   Fix: ./scripts/retry_persona_ci.sh"
        echo "   Note: Usually resolves within 5-15 minutes"
        exit 7
        ;;
    *"timeout"*)
        echo "⏱️ Issue: Connection Timeout"
        echo "   Cause: Slow network or overloaded database"
        echo "   Action: Retry with increased timeout"
        echo "   Fix: Try again in a few minutes"
        exit 8
        ;;
    *)
        echo "❓ Issue: Unknown Error"
        echo "   Raw error output:"
        echo "   =================="
        echo "$err"
        echo "   =================="
        echo "   Action: Contact database administrator"
        echo "   Debug: Save error output for troubleshooting"
        exit 9
        ;;
esac