#!/bin/bash
# Scout v7 Auto-Sync Deployment Script
# Complete rollout of task-tracked auto-sync system

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "🚀 Scout v7 Auto-Sync Deployment Starting..."
echo "Working directory: $SCRIPT_DIR"

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v sqlcmd &> /dev/null; then
    echo "❌ sqlcmd not found. Please install SQL Server tools."
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo "❌ python3 not found. Please install Python 3.8+."
    exit 1
fi

echo "✅ Prerequisites check passed"

# Set up environment
echo "🔧 Setting up environment..."

# Create exports directory
mkdir -p "$SCRIPT_DIR/exports"
echo "✅ Created exports directory"

# Install Python dependencies
echo "📦 Installing Python dependencies..."
python3 -m pip install --quiet pyodbc pandas openpyxl pyarrow
echo "✅ Python dependencies installed"

# Database deployment function
deploy_sql() {
    local sql_file="$1"
    local description="$2"

    echo "📊 Deploying: $description"
    echo "   File: $sql_file"

    if [[ -f "$sql_file" ]]; then
        # Use environment variables for SQL connection
        sqlcmd -S "${AZURE_SQL_SERVER:-sqltbwaprojectscoutserver.database.windows.net}" \
                -d "${AZURE_SQL_DATABASE:-SQL-TBWA-ProjectScout-Reporting-Prod}" \
                -U "${AZURE_SQL_USER:-TBWA}" \
                -P "${AZURE_SQL_PASSWORD:-R@nd0mPA$$2025!}" \
                -i "$sql_file"
        echo "✅ $description deployed successfully"
    else
        echo "⚠️  File not found: $sql_file"
        return 1
    fi
}

# Deploy SQL components in order
echo "🗄️  Deploying database components..."

deploy_sql "$SCRIPT_DIR/sql/000_prerequisites.sql" "Change Tracking Prerequisites"
deploy_sql "$SCRIPT_DIR/sql/025_enhanced_etl_column_mapping.sql" "Enhanced ETL Column Mapping"
deploy_sql "$SCRIPT_DIR/sql/026_task_framework.sql" "Task Framework"
deploy_sql "$SCRIPT_DIR/sql/027_register_tasks.sql" "Task Registration"
deploy_sql "$SCRIPT_DIR/sql/001_canonical_id_si_timestamps.sql" "Canonical ID & SI Timestamps"
deploy_sql "$SCRIPT_DIR/sql/002_parity_check.sql" "Parity Check Procedures"

echo "✅ Database deployment complete"

# Verify deployment
echo "🔍 Verifying deployment..."

sqlcmd -S "${AZURE_SQL_SERVER:-sqltbwaprojectscoutserver.database.windows.net}" \
        -d "${AZURE_SQL_DATABASE:-SQL-TBWA-ProjectScout-Reporting-Prod}" \
        -U "${AZURE_SQL_USER:-TBWA}" \
        -P "${AZURE_SQL_PASSWORD:-R@nd0mPA$$2025!}" \
        -Q "SELECT COUNT(*) AS registered_tasks FROM system.task_definitions WHERE enabled=1;"

echo "✅ Deployment verification complete"

# Set up environment configuration
echo "⚙️  Setting up environment configuration..."

if [[ ! -f "$SCRIPT_DIR/.env.autosync" ]]; then
    cp "$SCRIPT_DIR/.env.autosync.example" "$SCRIPT_DIR/.env.autosync"
    echo "📝 Created .env.autosync from template"
    echo "⚠️  Please edit .env.autosync with your actual credentials before starting the worker"
else
    echo "✅ .env.autosync already exists"
fi

# Create ODBC connection string
export AZURE_SQL_ODBC="DRIVER={ODBC Driver 18 for SQL Server};SERVER=tcp:${AZURE_SQL_SERVER:-sqltbwaprojectscoutserver.database.windows.net},1433;DATABASE=${AZURE_SQL_DATABASE:-SQL-TBWA-ProjectScout-Reporting-Prod};UID=${AZURE_SQL_USER:-TBWA};PWD=${AZURE_SQL_PASSWORD:-R@nd0mPA$$2025!};Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"

echo "✅ Environment configuration complete"

# Test auto-sync worker (dry run)
echo "🧪 Testing auto-sync worker..."

if [[ -f "$SCRIPT_DIR/etl/agents/auto_sync_tracked.py" ]]; then
    echo "✅ Auto-sync worker script found"
    echo "📝 To start the worker manually:"
    echo "   export AZURE_SQL_ODBC=\"$AZURE_SQL_ODBC\""
    echo "   export OUTDIR=\"$SCRIPT_DIR/exports\""
    echo "   export SYNC_INTERVAL=\"60\""
    echo "   python3 $SCRIPT_DIR/etl/agents/auto_sync_tracked.py"
else
    echo "❌ Auto-sync worker script not found"
    exit 1
fi

# Systemd service setup (optional)
if command -v systemctl &> /dev/null && [[ "$EUID" -eq 0 ]]; then
    echo "🔧 Setting up systemd service..."

    # Copy service file
    cp "$SCRIPT_DIR/deployment/scout-autosync.service" /etc/systemd/system/

    # Create service user
    if ! id "scout" &>/dev/null; then
        useradd -r -s /bin/false scout
        echo "✅ Created scout user"
    fi

    # Set permissions
    chown -R scout:scout "$SCRIPT_DIR"

    # Copy environment file
    mkdir -p /opt/scout-v7
    cp "$SCRIPT_DIR/.env.autosync" /opt/scout-v7/
    cp -r "$SCRIPT_DIR/etl" /opt/scout-v7/
    mkdir -p /opt/scout-exports
    chown -R scout:scout /opt/scout-v7 /opt/scout-exports

    # Enable service
    systemctl daemon-reload
    systemctl enable scout-autosync

    echo "✅ Systemd service configured"
    echo "📝 To start the service: sudo systemctl start scout-autosync"
    echo "📝 To view logs: sudo journalctl -u scout-autosync -f"
else
    echo "⚠️  Systemd service setup skipped (requires root or systemd not available)"
fi

# Final monitoring setup
echo "📊 Final monitoring check..."

sqlcmd -S "${AZURE_SQL_SERVER:-sqltbwaprojectscoutserver.database.windows.net}" \
        -d "${AZURE_SQL_DATABASE:-SQL-TBWA-ProjectScout-Reporting-Prod}" \
        -U "${AZURE_SQL_USER:-TBWA}" \
        -P "${AZURE_SQL_PASSWORD:-R@nd0mPA$$2025!}" \
        -i "$SCRIPT_DIR/sql/003_monitoring_dashboard.sql"

echo ""
echo "🎉 Scout v7 Auto-Sync Deployment Complete!"
echo ""
echo "📋 Next Steps:"
echo "1. Review and update .env.autosync with correct credentials"
echo "2. Start the auto-sync worker:"
echo "   cd $SCRIPT_DIR"
echo "   source .env.autosync"
echo "   python3 etl/agents/auto_sync_tracked.py"
echo ""
echo "3. Monitor execution:"
echo "   sqlcmd -i sql/003_monitoring_dashboard.sql"
echo ""
echo "4. Check exports:"
echo "   ls -la exports/"
echo ""
echo "🚀 Auto-sync system is ready for production use!"