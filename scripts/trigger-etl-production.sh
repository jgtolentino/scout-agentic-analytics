#!/bin/bash

# Scout Analytics ETL Production Trigger System
# Implements data-driven watcher + Temporal cron backup + health checks

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ETL_DIR="$PROJECT_ROOT/etl"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Environment validation
validate_environment() {
    log "Validating environment..."
    
    # Required environment variables
    required_vars=(
        "SUPABASE_DB_URL"
        "POSTGRES_PASSWORD"
        "TEMPORAL_HOST"
        "TEMPORAL_TASK_QUEUE"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            error "Required environment variable $var is not set"
            exit 1
        fi
    done
    
    # Test database connectivity
    if ! psql "$SUPABASE_DB_URL" -c "SELECT 1" >/dev/null 2>&1; then
        error "Database connection failed"
        exit 1
    fi
    
    # Test Temporal connectivity
    if ! curl -f "http://${TEMPORAL_HOST}/api/v1/namespaces" >/dev/null 2>&1; then
        error "Temporal server not accessible at $TEMPORAL_HOST"
        exit 1
    fi
    
    success "Environment validated"
}

# Setup Temporal cron schedules
setup_temporal_schedules() {
    log "Setting up Temporal cron schedules..."
    
    cd "$ETL_DIR"
    
    python3 - <<'PY'
import os, asyncio, datetime
from temporalio.client import Client, Schedule, ScheduleActionStartWorkflow, ScheduleSpec

TARGET = f"{os.getenv('TEMPORAL_HOST', 'localhost:7233')}"
QUEUE = os.getenv('TEMPORAL_TASK_QUEUE', 'scout-etl-queue')

async def upsert_schedule(name, cron, workflow_type, args):
    client = await Client.connect(TARGET)
    spec = ScheduleSpec(cron_expressions=[cron], timezone='Asia/Manila')
    action = ScheduleActionStartWorkflow(
        workflow_type, *args,
        id=f'{name}-{datetime.datetime.now().strftime("%Y%m%d-%H%M%S")}',
        task_queue=QUEUE,
    )
    schedule = Schedule(action=action, spec=spec)
    
    try:
        handle = client.get_schedule_handle(name)
        await handle.update(lambda _: schedule)
        print(f'✅ Updated schedule: {name}')
    except Exception:
        await client.create_schedule(name, schedule)
        print(f'✅ Created schedule: {name}')

async def main():
    # Bronze ingestion every 15 minutes
    await upsert_schedule(
        'scout-bronze-ingestion-q15m', 
        '*/15 * * * *',
        'BronzeIngestionWorkflow',
        ['azure_data.interactions', 'scout.bronze_transactions']
    )
    
    # Full pipeline daily at 2 AM PHT
    await upsert_schedule(
        'scout-full-pipeline-daily-2am',
        '0 2 * * *', 
        'FullPipelineWorkflow',
        ['full-pipeline']
    )
    
    # Quality validation every 4 hours
    await upsert_schedule(
        'scout-quality-validation-q4h',
        '0 */4 * * *',
        'QualityValidationWorkflow', 
        ['all-layers']
    )

asyncio.run(main())
PY
    
    success "Temporal schedules configured"
}

# Create data-driven watcher
create_watcher() {
    log "Creating data-driven watcher..."
    
    mkdir -p "$PROJECT_ROOT/daemon"
    
    cat > "$PROJECT_ROOT/daemon/scout_watcher.py" <<'PY'
import os
import asyncio
import datetime
import logging
import psycopg
from temporalio.client import Client
from typing import Set, Optional

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('scout_watcher')

# Configuration
PGURI = os.environ['SUPABASE_DB_URL']
TEMPORAL_HOST = os.getenv('TEMPORAL_HOST', 'localhost:7233')
TEMPORAL_QUEUE = os.getenv('TEMPORAL_TASK_QUEUE', 'scout-etl-queue')
WATCH_INTERVAL = int(os.getenv('WATCH_INTERVAL', '300'))  # 5 minutes

class ScoutDataWatcher:
    def __init__(self):
        self.seen_partitions: Set[str] = set()
        self.client: Optional[Client] = None
    
    async def init_temporal_client(self):
        """Initialize Temporal client"""
        self.client = await Client.connect(TEMPORAL_HOST)
        logger.info(f"Connected to Temporal at {TEMPORAL_HOST}")
    
    def get_latest_source_watermark(self) -> Optional[str]:
        """Get latest watermark from Azure source data"""
        try:
            with psycopg.connect(PGURI) as conn, conn.cursor() as cur:
                # Get max transaction date from Azure foreign table
                cur.execute("""
                    SELECT COALESCE(
                        MAX(DATE("TransactionDate")), 
                        CURRENT_DATE - INTERVAL '1 day'
                    )::text
                    FROM azure_data.interactions 
                    WHERE "TransactionDate" IS NOT NULL
                """)
                result = cur.fetchone()
                return result[0] if result else None
        except Exception as e:
            logger.error(f"Failed to get source watermark: {e}")
            return None
    
    def get_last_processed_watermark(self) -> Optional[str]:
        """Get last successfully processed partition"""
        try:
            with psycopg.connect(PGURI) as conn, conn.cursor() as cur:
                cur.execute("""
                    SELECT watermark_value
                    FROM metadata.watermarks 
                    WHERE source_name = 'azure_data.interactions'
                    AND table_name = 'bronze_transactions'
                    ORDER BY updated_at DESC 
                    LIMIT 1
                """)
                result = cur.fetchone()
                return result[0] if result else None
        except Exception as e:
            logger.error(f"Failed to get processed watermark: {e}")
            return None
    
    async def trigger_bronze_ingestion(self, partition_date: str):
        """Trigger Bronze layer ingestion workflow"""
        if not self.client:
            await self.init_temporal_client()
        
        workflow_id = f'bronze-ingestion-{partition_date}'
        
        try:
            await self.client.start_workflow(
                'BronzeIngestionWorkflow',
                {
                    'source_name': 'azure_data.interactions',
                    'target_table': 'scout.bronze_transactions', 
                    'batch_size': 1000,
                    'watermark_column': 'TransactionDate',
                    'contract_validation': True,
                    'pii_masking': True
                },
                partition_date,
                id=workflow_id,
                task_queue=TEMPORAL_QUEUE
            )
            logger.info(f"✅ Triggered Bronze ingestion for {partition_date}")
            return True
        except Exception as e:
            logger.error(f"❌ Failed to trigger workflow for {partition_date}: {e}")
            return False
    
    async def check_and_trigger(self):
        """Check for new data and trigger processing if needed"""
        try:
            # Get latest available data
            latest_source = self.get_latest_source_watermark()
            if not latest_source:
                logger.warning("No source watermark available")
                return
            
            # Get last processed date
            last_processed = self.get_last_processed_watermark()
            
            # Determine what partitions need processing
            partitions_to_process = []
            
            if not last_processed:
                # First run - process latest partition
                partitions_to_process.append(latest_source)
                logger.info(f"First run: processing {latest_source}")
            else:
                # Check if there's new data since last processed
                if latest_source > last_processed:
                    # Process all dates from last processed + 1 to latest
                    start_date = datetime.datetime.fromisoformat(last_processed) + datetime.timedelta(days=1)
                    end_date = datetime.datetime.fromisoformat(latest_source)
                    
                    current = start_date
                    while current <= end_date:
                        partitions_to_process.append(current.strftime('%Y-%m-%d'))
                        current += datetime.timedelta(days=1)
                    
                    logger.info(f"New data detected: processing {len(partitions_to_process)} partitions")
            
            # Trigger processing for new partitions
            for partition in partitions_to_process:
                if partition not in self.seen_partitions:
                    success = await self.trigger_bronze_ingestion(partition)
                    if success:
                        self.seen_partitions.add(partition)
                        
        except Exception as e:
            logger.error(f"Error in check_and_trigger: {e}")
    
    async def health_check(self):
        """Perform health check and log status"""
        try:
            # Check database connectivity
            with psycopg.connect(PGURI) as conn, conn.cursor() as cur:
                cur.execute("SELECT COUNT(*) FROM azure_data.interactions")
                total_interactions = cur.fetchone()[0]
                
                cur.execute("""
                    SELECT COUNT(*), MAX(created_at) 
                    FROM metadata.job_runs 
                    WHERE job_name LIKE 'bronze_ingestion_%'
                    AND status = 'success'
                    AND created_at > NOW() - INTERVAL '24 hours'
                """)
                success_jobs, last_success = cur.fetchone()
                
            logger.info(f"Health check - Total interactions: {total_interactions}, "
                       f"Successful jobs (24h): {success_jobs}, Last success: {last_success}")
                       
        except Exception as e:
            logger.error(f"Health check failed: {e}")
    
    async def run(self):
        """Main watcher loop"""
        logger.info("🚀 Starting Scout Data Watcher")
        
        await self.init_temporal_client()
        
        # Initial health check
        await self.health_check()
        
        iteration = 0
        while True:
            try:
                iteration += 1
                logger.info(f"👁️  Watcher iteration {iteration}")
                
                # Check for new data and trigger if needed
                await self.check_and_trigger()
                
                # Health check every 12 iterations (1 hour at 5min intervals)
                if iteration % 12 == 0:
                    await self.health_check()
                
                # Wait before next check
                await asyncio.sleep(WATCH_INTERVAL)
                
            except KeyboardInterrupt:
                logger.info("🛑 Watcher stopped by user")
                break
            except Exception as e:
                logger.error(f"💥 Unexpected error in watcher loop: {e}")
                await asyncio.sleep(60)  # Wait 1 minute before retry

if __name__ == '__main__':
    watcher = ScoutDataWatcher()
    asyncio.run(watcher.run())
PY
    
    success "Data watcher created"
}

# Create webhook server
create_webhook_server() {
    log "Creating webhook server..."
    
    cat > "$PROJECT_ROOT/daemon/webhook_server.py" <<'PY'
import os
import asyncio
import logging
from datetime import datetime
from fastapi import FastAPI, HTTPException, BackgroundTasks
from pydantic import BaseModel
from temporalio.client import Client
import uvicorn

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('scout_webhook')

app = FastAPI(title="Scout ETL Webhook Server", version="1.0.0")

TEMPORAL_HOST = os.getenv('TEMPORAL_HOST', 'localhost:7233')
TEMPORAL_QUEUE = os.getenv('TEMPORAL_TASK_QUEUE', 'scout-etl-queue')

class TriggerRequest(BaseModel):
    source: str = 'azure_data.interactions'
    target: str = 'scout.bronze_transactions'
    partition: str
    batch_size: int = 1000
    dry_run: bool = False

class PipelineRequest(BaseModel):
    partition_key: str = None
    dry_run: bool = False

@app.post('/trigger-bronze')
async def trigger_bronze_ingestion(req: TriggerRequest):
    """Trigger Bronze layer ingestion for specific partition"""
    try:
        client = await Client.connect(TEMPORAL_HOST)
        workflow_id = f'webhook-bronze-{req.source.replace(".", "-")}-{req.partition}'
        
        config = {
            'source_name': req.source,
            'target_table': req.target,
            'batch_size': req.batch_size,
            'watermark_column': 'TransactionDate',
            'contract_validation': True,
            'pii_masking': True
        }
        
        await client.start_workflow(
            'BronzeIngestionWorkflow',
            config,
            req.partition,
            id=workflow_id,
            task_queue=TEMPORAL_QUEUE
        )
        
        logger.info(f"✅ Triggered Bronze ingestion: {workflow_id}")
        return {
            'status': 'triggered',
            'workflow_id': workflow_id,
            'config': config,
            'partition': req.partition
        }
        
    except Exception as e:
        logger.error(f"❌ Failed to trigger Bronze ingestion: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post('/trigger-pipeline')
async def trigger_full_pipeline(req: PipelineRequest):
    """Trigger full ETL pipeline"""
    try:
        client = await Client.connect(TEMPORAL_HOST)
        workflow_id = f'webhook-pipeline-{req.partition_key or datetime.now().strftime("%Y%m%d-%H%M%S")}'
        
        await client.start_workflow(
            'FullPipelineWorkflow',
            req.partition_key,
            id=workflow_id,
            task_queue=TEMPORAL_QUEUE
        )
        
        logger.info(f"✅ Triggered full pipeline: {workflow_id}")
        return {
            'status': 'triggered',
            'workflow_id': workflow_id,
            'partition_key': req.partition_key
        }
        
    except Exception as e:
        logger.error(f"❌ Failed to trigger pipeline: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get('/health')
async def health_check():
    """Health check endpoint"""
    try:
        # Test Temporal connection
        client = await Client.connect(TEMPORAL_HOST)
        await client.list_workflows()
        
        return {
            'status': 'healthy',
            'temporal_host': TEMPORAL_HOST,
            'temporal_queue': TEMPORAL_QUEUE,
            'timestamp': datetime.now().isoformat()
        }
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Unhealthy: {e}")

if __name__ == '__main__':
    uvicorn.run(app, host='0.0.0.0', port=8080, log_level='info')
PY
    
    success "Webhook server created"
}

# Create health check script
create_health_checks() {
    log "Creating health check scripts..."
    
    cat > "$PROJECT_ROOT/scripts/health-check-etl.sh" <<'HEALTH'
#!/bin/bash

# Scout ETL Health Check Script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
        return 0
    else
        echo -e "${RED}❌ $1${NC}"
        return 1
    fi
}

echo "🏥 Scout ETL Health Check - $(date)"
echo "=================================="

# 1. Database connectivity
echo -n "Database connectivity: "
psql "$SUPABASE_DB_URL" -c "SELECT 1" >/dev/null 2>&1
check_status "Database connection"

# 2. Temporal server
echo -n "Temporal server: "
curl -f "http://${TEMPORAL_HOST}/api/v1/namespaces" >/dev/null 2>&1
check_status "Temporal server accessible"

# 3. Recent job success rate
echo -n "Recent job success rate: "
SUCCESS_RATE=$(psql "$SUPABASE_DB_URL" -t -A -c "
    SELECT ROUND(
        100.0 * COUNT(*) FILTER (WHERE status = 'success') / 
        NULLIF(COUNT(*), 0), 2
    )
    FROM metadata.job_runs 
    WHERE created_at > NOW() - INTERVAL '24 hours'
    AND job_name LIKE 'bronze_ingestion_%'
")
if (( $(echo "$SUCCESS_RATE >= 90" | bc -l) )); then
    echo -e "${GREEN}✅ $SUCCESS_RATE% (last 24h)${NC}"
else
    echo -e "${RED}❌ $SUCCESS_RATE% (last 24h) - Below 90% threshold${NC}"
fi

# 4. Data freshness
echo -n "Data freshness: "
HOURS_SINCE_LAST=$(psql "$SUPABASE_DB_URL" -t -A -c "
    SELECT EXTRACT(EPOCH FROM (NOW() - MAX(updated_at)))/3600
    FROM metadata.watermarks 
    WHERE source_name = 'azure_data.interactions'
")
if (( $(echo "$HOURS_SINCE_LAST <= 2" | bc -l) )); then
    echo -e "${GREEN}✅ ${HOURS_SINCE_LAST}h ago${NC}"
else
    echo -e "${YELLOW}⚠️  ${HOURS_SINCE_LAST}h ago - Consider investigating${NC}"
fi

# 5. Quality score
echo -n "Data quality score: "
QUALITY_SCORE=$(psql "$SUPABASE_DB_URL" -t -A -c "
    SELECT ROUND(AVG(quality_score), 3)
    FROM metadata.quality_metrics 
    WHERE created_at > NOW() - INTERVAL '24 hours'
")
if (( $(echo "$QUALITY_SCORE >= 0.95" | bc -l) )); then
    echo -e "${GREEN}✅ $QUALITY_SCORE${NC}"
else
    echo -e "${RED}❌ $QUALITY_SCORE - Below 0.95 threshold${NC}"
fi

# 6. Active workflows
echo -n "Active workflows: "
ACTIVE_WORKFLOWS=$(curl -s "http://${TEMPORAL_HOST}/api/v1/workflows" | jq -r '.workflows | length' 2>/dev/null || echo "0")
echo -e "${GREEN}✅ $ACTIVE_WORKFLOWS active${NC}"

echo "=================================="
echo "Health check completed at $(date)"
HEALTH
    
    chmod +x "$PROJECT_ROOT/scripts/health-check-etl.sh"
    
    success "Health check script created"
}

# Start services
start_services() {
    log "Starting ETL trigger services..."
    
    case "${1:-all}" in
        "schedules")
            setup_temporal_schedules
            ;;
        "watcher")
            cd "$PROJECT_ROOT/daemon"
            python3 scout_watcher.py &
            echo $! > watcher.pid
            success "Data watcher started (PID: $(cat watcher.pid))"
            ;;
        "webhook")
            cd "$PROJECT_ROOT/daemon"
            python3 webhook_server.py &
            echo $! > webhook.pid
            success "Webhook server started (PID: $(cat webhook.pid)) - http://localhost:8080"
            ;;
        "all")
            setup_temporal_schedules
            
            cd "$PROJECT_ROOT/daemon"
            python3 scout_watcher.py &
            echo $! > watcher.pid
            
            python3 webhook_server.py &
            echo $! > webhook.pid
            
            success "All services started:"
            echo "  • Temporal schedules: Configured"
            echo "  • Data watcher: PID $(cat watcher.pid)"
            echo "  • Webhook server: PID $(cat webhook.pid) - http://localhost:8080"
            echo "  • Health check: ./scripts/health-check-etl.sh"
            ;;
    esac
}

# Stop services
stop_services() {
    log "Stopping ETL trigger services..."
    
    cd "$PROJECT_ROOT/daemon" 2>/dev/null || true
    
    if [[ -f watcher.pid ]]; then
        kill $(cat watcher.pid) 2>/dev/null || true
        rm -f watcher.pid
        success "Data watcher stopped"
    fi
    
    if [[ -f webhook.pid ]]; then
        kill $(cat webhook.pid) 2>/dev/null || true
        rm -f webhook.pid
        success "Webhook server stopped"
    fi
}

# Main function
main() {
    case "${1:-deploy}" in
        "deploy")
            validate_environment
            create_watcher
            create_webhook_server
            create_health_checks
            start_services "all"
            
            echo
            success "🎉 Scout ETL trigger system deployed!"
            echo
            log "Trigger Options:"
            echo "  • Manual: curl -X POST http://localhost:8080/trigger-bronze -d '{\"partition\":\"2025-01-16\"}'"
            echo "  • Immediate: python3 daemon/scout_watcher.py (one-shot check)"
            echo "  • Health check: ./scripts/health-check-etl.sh"
            echo
            log "Monitoring:"
            echo "  • Temporal UI: http://localhost:8088"
            echo "  • Webhook API: http://localhost:8080/docs"
            echo "  • Logs: tail -f daemon/*.log"
            ;;
        "start")
            validate_environment
            start_services "${2:-all}"
            ;;
        "stop")
            stop_services
            ;;
        "status")
            "$PROJECT_ROOT/scripts/health-check-etl.sh"
            ;;
        "test")
            validate_environment
            log "Testing immediate trigger..."
            cd "$PROJECT_ROOT/daemon"
            python3 -c "
import asyncio
from scout_watcher import ScoutDataWatcher
async def test():
    watcher = ScoutDataWatcher()
    await watcher.check_and_trigger()
asyncio.run(test())
            "
            ;;
        *)
            echo "Usage: $0 {deploy|start|stop|status|test}"
            echo "  deploy - Full deployment with all services"
            echo "  start [schedules|watcher|webhook|all] - Start specific services"
            echo "  stop - Stop all services"
            echo "  status - Run health checks"
            echo "  test - Test immediate trigger"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"