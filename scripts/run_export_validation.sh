#!/bin/bash
# Flat Export Validation Runner
# Validate exported CSV files

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <csv_file_path> [connection_string]"
    echo "Example: $0 data/exports/scout_flat_export_20250922_150000.csv"
    exit 1
fi

CSV_FILE="$1"
CONNECTION_STRING="${2:-}"

# Load environment variables if .env file exists
if [ -f config/azure_export.env ]; then
    export $(cat config/azure_export.env | grep -v ^# | xargs)
    if [ -z "$CONNECTION_STRING" ] && [ -n "$AZSQL_HOST" ]; then
        CONNECTION_STRING="DRIVER={ODBC Driver 17 for SQL Server};SERVER=$AZSQL_HOST;DATABASE=$AZSQL_DB;UID=$AZSQL_USER;PWD=$AZSQL_PASS;Encrypt=yes;TrustServerCertificate=no;"
    fi
fi

echo "🔍 Validating CSV export: $CSV_FILE"

# Run validation
if [ -n "$CONNECTION_STRING" ]; then
    python3 scripts/validate_flat_export.py "$CSV_FILE" --connection-string "$CONNECTION_STRING" --report-file "logs/validation_$(date +%Y%m%d_%H%M%S).json"
else
    python3 scripts/validate_flat_export.py "$CSV_FILE" --report-file "logs/validation_$(date +%Y%m%d_%H%M%S).json"
fi

echo "✅ Validation completed"