#!/bin/bash
set -euo pipefail

# =====================================================
# Scout v7 Local Testing Script
# =====================================================
# Purpose: Local development testing for Azure pipeline
# Usage: ./test_local.sh

echo "🧪 Scout v7 Local Testing"
echo "========================="

# Check if .env file exists for local development
if [[ -f ".env" ]]; then
    echo "Loading environment from .env file..."
    set -a
    source .env
    set +a
else
    echo "No .env file found - using system environment variables"
fi

# Check required variables
required_vars=(
    "AZ_SQL_SERVER"
    "AZ_SQL_DB"
)

echo "🔍 Checking environment variables..."
missing_vars=()
for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        missing_vars+=("$var")
    else
        echo "  ✅ $var is set"
    fi
done

if [[ ${#missing_vars[@]} -gt 0 ]]; then
    echo "❌ Missing required variables: ${missing_vars[*]}"
    echo ""
    echo "Create a .env file with:"
    echo "export AZ_SQL_SERVER=yourserver.database.windows.net"
    echo "export AZ_SQL_DB=SQL-TBWA-ProjectScout-Reporting-Prod"
    echo "export AZ_SQL_UID=your_username"
    echo "export AZ_SQL_PWD=your_password"
    echo "export DATE_FROM=2025-09-01"
    echo "export DATE_TO=2025-09-23"
    echo "export NCR_ONLY=1"
    echo "export AMOUNT_TOLERANCE_PCT=1.0"
    echo "# Optional:"
    echo "export AZURE_STORAGE_CONNECTION_STRING=DefaultEndpointsProtocol=https;..."
    echo "export BLOB_CONTAINER=exports"
    exit 1
fi

# Check authentication
if [[ -n "${AZ_SQL_UID:-}" ]] && [[ -n "${AZ_SQL_PWD:-}" ]]; then
    echo "  ✅ SQL Authentication configured"
else
    echo "  ⚠️  No SQL credentials - will attempt Azure AD authentication"
fi

# Set defaults
export DATE_FROM="${DATE_FROM:-2025-09-01}"
export DATE_TO="${DATE_TO:-2025-09-23}"
export NCR_ONLY="${NCR_ONLY:-1}"
export AMOUNT_TOLERANCE_PCT="${AMOUNT_TOLERANCE_PCT:-1.0}"
export OUT_DIR="${OUT_DIR:-./out}"

echo ""
echo "📋 Configuration:"
echo "  Server: $AZ_SQL_SERVER"
echo "  Database: $AZ_SQL_DB"
echo "  Date range: $DATE_FROM to $DATE_TO"
echo "  NCR only: $NCR_ONLY"
echo "  Tolerance: $AMOUNT_TOLERANCE_PCT%"
echo "  Output: $OUT_DIR"

# Check Python environment
echo ""
echo "🐍 Python Environment:"
python_cmd="python3"
if ! command -v "$python_cmd" &> /dev/null; then
    python_cmd="python"
    if ! command -v "$python_cmd" &> /dev/null; then
        echo "❌ Python not found"
        exit 1
    fi
fi

echo "  Python: $($python_cmd --version)"

# Check if virtual environment exists
if [[ ! -d ".venv" ]]; then
    echo "  Creating virtual environment..."
    $python_cmd -m venv .venv
fi

# Activate virtual environment
echo "  Activating virtual environment..."
source .venv/bin/activate

# Install/upgrade dependencies
echo "  Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Check if pyodbc can import (basic connectivity test)
echo ""
echo "🔌 Testing connectivity..."
if $python_cmd -c "import pyodbc; print('✅ pyodbc available'); drivers = [d for d in pyodbc.drivers() if 'SQL Server' in d]; print('✅ SQL Server drivers:', drivers if drivers else 'None')" 2>/dev/null; then
    echo "  Database connectivity looks good"
else
    echo "  ⚠️  pyodbc or SQL Server drivers may have issues"
    echo "  Install ODBC drivers: https://docs.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server"
fi

# Run pipeline
echo ""
echo "🚀 Running Pipeline..."
echo "================================="

if $python_cmd pipeline.py; then
    echo ""
    echo "✅ Pipeline completed successfully!"

    # Show results
    echo ""
    echo "📁 Generated files:"
    ls -la "$OUT_DIR"/ || true

    if ls "$OUT_DIR"/flat_enriched_*.csv 1> /dev/null 2>&1; then
        flat_file=$(ls -t "$OUT_DIR"/flat_enriched_*.csv | head -1)
        echo ""
        echo "📊 Export summary:"
        echo "  File: $(basename "$flat_file")"
        echo "  Rows: $(($(wc -l < "$flat_file") - 1))"
        echo "  Columns: $(head -1 "$flat_file" | tr ',' '\n' | wc -l)"
        echo ""
        echo "🔍 Header preview:"
        head -1 "$flat_file"
        echo ""
        echo "📋 Sample data:"
        head -3 "$flat_file" | tail -2
    fi

else
    echo ""
    echo "❌ Pipeline failed!"
    echo "Check the logs above for error details"
    exit 1
fi

echo ""
echo "================================="
echo "🎉 Local testing complete!"
echo "✅ Pipeline executed successfully"
echo "✅ Exports generated in $OUT_DIR"
echo ""
echo "Next steps:"
echo "  • Commit changes: git add . && git commit -m 'Pipeline ready'"
echo "  • Set GitHub secrets for CI/CD"
echo "  • Run manual dispatch in GitHub Actions"