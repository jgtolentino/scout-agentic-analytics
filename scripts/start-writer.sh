#!/usr/bin/env bash

# 🔧 Local Writer MCP Server for Development & CI
# Starts the Supabase MCP server with write permissions on port 8893

set -e

echo "🚀 Starting local writer MCP server on port 8893..."

# Check for required environment variable
if [ -z "$SUPABASE_SERVICE_KEY" ]; then
    echo "❌ Error: SUPABASE_SERVICE_KEY environment variable is required"
    echo "   This should be the service role key from Supabase Dashboard → API"
    exit 1
fi

# Default values
PROJECT_REF=${SUPABASE_PROJECT_REF:-"cxzllzyxwpyptfretryc"}
PORT=${WRITER_MCP_PORT:-8893}
SEARCH_PATH=${SEARCH_PATH:-"public,scout,ces,qa_class"}

echo "📝 Configuration:"
echo "   Project: $PROJECT_REF"
echo "   Port: $PORT" 
echo "   Search Path: $SEARCH_PATH"
echo "   Service Key: ${SUPABASE_SERVICE_KEY:0:20}..."

# Start the MCP server with write permissions
npx -y @supabase/mcp-server-supabase@latest \
  --project-ref "$PROJECT_REF" \
  --port "$PORT" \
  --allow "select,insert,update,delete,ddl" \
  --access-token "$SUPABASE_SERVICE_KEY" \
  --search-path "$SEARCH_PATH" \
  --no-llm &

# Store PID for cleanup
MCP_PID=$!
echo "✅ Writer MCP server started with PID: $MCP_PID"

# Wait a moment for startup
sleep 3

# Test connectivity
if curl -sf "http://localhost:$PORT/health" > /dev/null 2>&1; then
    echo "✅ Health check passed - writer MCP is ready"
else
    echo "⚠️  Health check failed - server may still be starting"
fi

echo ""
echo "🔧 Usage examples:"
echo "   curl -X POST http://localhost:$PORT/mcp/ddl -d '{\"sql\":\"CREATE TABLE test(id int)\"}'"
echo "   :lw ddl sql=\"CREATE TABLE test (id UUID PRIMARY KEY)\" schema=\"qa_class\""
echo ""
echo "🛑 To stop: kill $MCP_PID"

# Keep running in foreground if called directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "⏳ Keeping server running... Press Ctrl+C to stop"
    wait $MCP_PID
fi