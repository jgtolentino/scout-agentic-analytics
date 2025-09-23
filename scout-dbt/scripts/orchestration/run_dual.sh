#!/bin/bash
set -euo pipefail

echo "🎯 Running dual-target dbt orchestration..."

# Run both targets in parallel
./scripts/orchestration/run_supabase.sh &
PID1=$!

./scripts/orchestration/run_azure.sh &
PID2=$!

# Wait for both to complete
wait $PID1
SUPABASE_RESULT=$?

wait $PID2
AZURE_RESULT=$?

# Check results
if [ $SUPABASE_RESULT -eq 0 ] && [ $AZURE_RESULT -eq 0 ]; then
    echo "✅ Both targets completed successfully"
    exit 0
else
    echo "❌ One or more targets failed"
    [ $SUPABASE_RESULT -ne 0 ] && echo "  - Supabase failed with code $SUPABASE_RESULT"
    [ $AZURE_RESULT -ne 0 ] && echo "  - Azure failed with code $AZURE_RESULT"
    exit 1
fi
