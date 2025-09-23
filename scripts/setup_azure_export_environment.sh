#!/bin/bash
# Setup Azure Flat CSV Export Environment
# Install dependencies and configure environment for flat export system

set -e

echo "🚀 Setting up Azure Flat CSV Export Environment"
echo "================================================"

# Check if we're in the right directory
if [ ! -f "CLAUDE.md" ]; then
    echo "❌ Error: Please run from scout-v7 root directory"
    exit 1
fi

# Create necessary directories
echo "📁 Creating export directories..."
mkdir -p data/exports
mkdir -p logs
mkdir -p config

# Check Python version
echo "🐍 Checking Python environment..."
python3 --version

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip3 install --upgrade pip

# Core dependencies for Azure SQL export
pip3 install pyodbc pandas

# Optional dependencies for enhanced functionality
pip3 install hashlib-compat  # For file integrity
pip3 install python-dotenv   # For environment variable management

# Check ODBC driver availability
echo "🔍 Checking ODBC Driver for SQL Server..."
if command -v odbcinst &> /dev/null; then
    echo "Available ODBC drivers:"
    odbcinst -q -d
else
    echo "⚠️  odbcinst not found. You may need to install ODBC Driver for SQL Server"
    echo "   macOS: brew install microsoft/mssql-release/mssql-tools"
    echo "   Linux: https://docs.microsoft.com/en-us/sql/connect/odbc/linux-mac/installing-the-microsoft-odbc-driver-for-sql-server"
fi

# Create environment configuration template
echo "📝 Creating environment configuration template..."
cat > config/azure_export.env.template << 'EOF'
# Azure SQL Configuration
AZSQL_HOST=your-server.database.windows.net
AZSQL_DB=your-database
AZSQL_USER=your-username
AZSQL_PASS=your-password

# Export Configuration
EXPORT_PATH=/Users/tbwa/scout-v7/data/exports
LOG_LEVEL=INFO

# Optional: Bruno integration
BRUNO_VAULT_MODE=true
EOF

# Create logging configuration
echo "📝 Creating logging configuration..."
cat > config/logging.conf << 'EOF'
[loggers]
keys=root,azure_export

[handlers]
keys=consoleHandler,fileHandler

[formatters]
keys=simpleFormatter

[logger_root]
level=INFO
handlers=consoleHandler

[logger_azure_export]
level=INFO
handlers=consoleHandler,fileHandler
qualname=azure_export
propagate=0

[handler_consoleHandler]
class=StreamHandler
level=INFO
formatter=simpleFormatter
args=(sys.stdout,)

[handler_fileHandler]
class=FileHandler
level=INFO
formatter=simpleFormatter
args=('logs/azure_export.log',)

[formatter_simpleFormatter]
format=%(asctime)s - %(name)s - %(levelname)s - %(message)s
datefmt=%Y-%m-%d %H:%M:%S
EOF

# Create export runner script
echo "📝 Creating export runner script..."
cat > scripts/run_flat_export.sh << 'EOF'
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
EOF

# Make runner script executable
chmod +x scripts/run_flat_export.sh

# Create validation runner script
echo "📝 Creating validation runner script..."
cat > scripts/run_export_validation.sh << 'EOF'
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
EOF

# Make validation runner script executable
chmod +x scripts/run_export_validation.sh

# Create daily export cron job template
echo "📝 Creating cron job template..."
cat > config/crontab.template << 'EOF'
# Scout Analytics Daily Flat Export
# Run at 6 AM daily (adjust timezone as needed)
0 6 * * * cd /Users/tbwa/scout-v7 && ./scripts/run_flat_export.sh >> logs/daily_export.log 2>&1

# Weekly validation of latest export
0 7 * * 1 cd /Users/tbwa/scout-v7 && find data/exports -name "scout_flat_export_*.csv" -mtime -7 | head -1 | xargs -I {} ./scripts/run_export_validation.sh {} >> logs/weekly_validation.log 2>&1
EOF

# Create maintenance script
echo "📝 Creating maintenance script..."
cat > scripts/maintenance.sh << 'EOF'
#!/bin/bash
# Azure Export System Maintenance
# Cleanup old files and logs

set -e

echo "🧹 Starting Azure Export System Maintenance..."

# Define retention periods (days)
EXPORT_RETENTION_DAYS=30
LOG_RETENTION_DAYS=90

# Clean old export files
echo "🗂️  Cleaning export files older than $EXPORT_RETENTION_DAYS days..."
find data/exports -name "scout_flat_export_*.csv" -mtime +$EXPORT_RETENTION_DAYS -delete 2>/dev/null || true
find data/exports -name "scout_flat_export_*.xlsx" -mtime +$EXPORT_RETENTION_DAYS -delete 2>/dev/null || true

# Clean old log files
echo "📋 Cleaning log files older than $LOG_RETENTION_DAYS days..."
find logs -name "*.log" -mtime +$LOG_RETENTION_DAYS -delete 2>/dev/null || true
find logs -name "validation_*.json" -mtime +$LOG_RETENTION_DAYS -delete 2>/dev/null || true

# Show current disk usage
echo "💾 Current disk usage:"
du -sh data/exports
du -sh logs

echo "✅ Maintenance completed"
EOF

# Make maintenance script executable
chmod +x scripts/maintenance.sh

# Create quick test script
echo "📝 Creating test script..."
cat > scripts/test_azure_connection.py << 'EOF'
#!/usr/bin/env python3
"""
Test Azure SQL Connection
Quick test to verify Azure SQL connectivity and basic queries
"""

import os
import pyodbc
import pandas as pd
from datetime import datetime

def test_connection():
    """Test Azure SQL connection and basic queries"""

    # Load configuration
    config = {
        'server': os.getenv('AZSQL_HOST', 'your-server.database.windows.net'),
        'database': os.getenv('AZSQL_DB', 'your-database'),
        'username': os.getenv('AZSQL_USER', 'your-username'),
        'password': os.getenv('AZSQL_PASS', 'your-password'),
        'driver': '{ODBC Driver 17 for SQL Server}'
    }

    connection_string = (
        f"DRIVER={config['driver']};"
        f"SERVER={config['server']};"
        f"DATABASE={config['database']};"
        f"UID={config['username']};"
        f"PWD={config['password']};"
        f"Encrypt=yes;"
        f"TrustServerCertificate=no;"
        f"Connection Timeout=30;"
    )

    try:
        print("🔌 Testing Azure SQL connection...")
        conn = pyodbc.connect(connection_string)
        print("✅ Connection successful!")

        # Test basic query
        print("🔍 Testing basic query...")
        cursor = conn.cursor()
        cursor.execute("SELECT @@VERSION")
        version = cursor.fetchone()[0]
        print(f"📊 SQL Server Version: {version[:50]}...")

        # Test schema access
        print("🗂️  Testing schema access...")
        cursor.execute("SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'gold'")
        gold_tables = cursor.fetchone()[0]
        print(f"📋 Gold schema tables: {gold_tables}")

        # Test flat export view if it exists
        try:
            cursor.execute("SELECT COUNT(*) FROM gold.v_flat_export_ready")
            record_count = cursor.fetchone()[0]
            print(f"📊 Flat export view records: {record_count:,}")
        except Exception as e:
            print(f"⚠️  Flat export view not accessible: {str(e)}")

        cursor.close()
        conn.close()
        print("✅ All tests passed!")
        return True

    except Exception as e:
        print(f"❌ Connection test failed: {str(e)}")
        return False

if __name__ == "__main__":
    success = test_connection()
    exit(0 if success else 1)
EOF

# Make test script executable
chmod +x scripts/test_azure_connection.py

# Set up git ignore for sensitive files
echo "🔒 Updating .gitignore for sensitive files..."
cat >> .gitignore << 'EOF'

# Azure Export Environment
config/azure_export.env
logs/*.log
logs/validation_*.json
data/exports/*.csv
data/exports/*.xlsx
EOF

# Display setup summary
echo ""
echo "✅ Azure Flat CSV Export Environment Setup Complete!"
echo "===================================================="
echo ""
echo "📁 Directories created:"
echo "   - data/exports/     (CSV export files)"
echo "   - logs/            (Log files)"
echo "   - config/          (Configuration files)"
echo ""
echo "📝 Scripts created:"
echo "   - scripts/run_flat_export.sh           (Export runner)"
echo "   - scripts/run_export_validation.sh     (Validation runner)"
echo "   - scripts/maintenance.sh               (System maintenance)"
echo "   - scripts/test_azure_connection.py     (Connection test)"
echo ""
echo "⚙️  Configuration files:"
echo "   - config/azure_export.env.template     (Environment variables template)"
echo "   - config/logging.conf                  (Logging configuration)"
echo "   - config/crontab.template              (Cron job template)"
echo ""
echo "🔧 Next steps:"
echo "1. Copy config/azure_export.env.template to config/azure_export.env"
echo "2. Edit config/azure_export.env with your Azure SQL credentials"
echo "3. Test connection: python3 scripts/test_azure_connection.py"
echo "4. Run SQL setup: Execute sql/azure_flat_export_dq.sql in Azure SQL"
echo "5. Test export: ./scripts/run_flat_export.sh"
echo "6. Validate export: ./scripts/run_export_validation.sh data/exports/latest.csv"
echo ""
echo "📚 Documentation: claudedocs/FLAT_EXPORT_DQ_SPECIFICATION.md"
echo ""
echo "Ready for production Azure flat CSV exports with independent DQ & audit! 🚀"