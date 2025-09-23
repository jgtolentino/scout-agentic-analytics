#!/bin/bash
# Azure Flat CSV Export Runner
# Wrapper script for automated exports

set -e

# Load environment variables if .env file exists
if [ -f config/azure_export.env ]; then
    export $(cat config/azure_export.env | grep -v ^# | xargs)
fi

# Run the export
echo "🚀 Starting Azure Flat CSV Export..."
python3 scripts/azure_flat_csv_export.py "$@"

# Check exit code
if [ $? -eq 0 ]; then
    echo "✅ Export completed successfully"
else
    echo "❌ Export failed"
    exit 1
fi