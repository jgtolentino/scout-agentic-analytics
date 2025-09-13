#!/usr/bin/env bash
set -euo pipefail

# MindsDB MCP Server Health Check
# Usage: ./mindsdb-health.sh [mysql|postgres]

PROTOCOL="${1:-mysql}"
HOST="${MINDSDB_HOST:-127.0.0.1}"
PORT="${MINDSDB_PORT:-47335}"
USER="${MINDSDB_USER:-mindsdb}"
PASSWORD="${MINDSDB_PASSWORD:-}"

if [ -z "$PASSWORD" ]; then
    echo "❌ MINDSDB_PASSWORD not set"
    exit 1
fi

echo "🔍 Testing MindsDB connectivity..."
echo "   Protocol: $PROTOCOL"
echo "   Host: $HOST:$PORT"
echo "   User: $USER"

# Test connection based on protocol
if [ "$PROTOCOL" = "postgres" ]; then
    # PostgreSQL test
    PGPASSWORD="$PASSWORD" psql -h "$HOST" -p "$PORT" -U "$USER" -d mindsdb -c "SELECT 1;" 2>/dev/null && {
        echo "✅ MindsDB PostgreSQL gateway: OK"
    } || {
        echo "❌ MindsDB PostgreSQL gateway: FAILED"
        exit 1
    }
else
    # MySQL test
    mysql -h "$HOST" -P "$PORT" -u "$USER" -p"$PASSWORD" -e "SELECT 1;" 2>/dev/null && {
        echo "✅ MindsDB MySQL gateway: OK"
    } || {
        echo "❌ MindsDB MySQL gateway: FAILED"
        exit 1
    }
fi

# Test MCP server
if [ -f "servers/mindsdb-mcp/server.mjs" ]; then
    MINDSDB_PROTOCOL="$PROTOCOL" \
    MINDSDB_HOST="$HOST" \
    MINDSDB_PORT="$PORT" \
    MINDSDB_USER="$USER" \
    MINDSDB_PASSWORD="$PASSWORD" \
    node servers/mindsdb-mcp/server.mjs --self-test 2>/dev/null && {
        echo "✅ MindsDB MCP server: OK"
    } || {
        echo "❌ MindsDB MCP server: FAILED"
        exit 1
    }
else
    echo "⚠️ MindsDB MCP server not found (run setup first)"
fi

echo "🎯 MindsDB health check complete"