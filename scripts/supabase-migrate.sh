#!/bin/bash
# Supabase migration script using local writer MCP
# This script spins up a temporary writer MCP for migrations only

set -euo pipefail

# Check for required environment variables
if [ -z "${SERVICE_ROLE:-}" ]; then
    echo "Error: SERVICE_ROLE environment variable is required"
    exit 1
fi

PROJECT_REF="cxzllzyxwpyptfretryc"
WRITER_PORT="8889"

echo "Starting local writer MCP for migrations..."

# Start the writer MCP in background
npx @supabase/mcp-server-supabase \
    --project-ref "$PROJECT_REF" \
    --access-token "$SERVICE_ROLE" \
    --allow "ddl,insert,update,copy" \
    --no-llm \
    --port "$WRITER_PORT" &

MCP_PID=$!

# Wait for MCP to be ready
sleep 2

# Function to cleanup on exit
cleanup() {
    echo "Shutting down writer MCP..."
    kill $MCP_PID 2>/dev/null || true
}
trap cleanup EXIT

echo "Writer MCP ready on port $WRITER_PORT"
echo "Run your migrations now. Press Ctrl+C when done."

# Keep script running until interrupted
wait $MCP_PID