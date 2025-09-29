#!/usr/bin/env bash
# =================================================================
# STT Reprocessing Pipeline - Path A
# Processes audio files through Whisper STT with intelligence extraction
# =================================================================

set -euo pipefail

# Configuration
LIMIT=${LIMIT:-100}
LANG=${LANG:-"fil"}
STORE_ID=${STORE_ID:-}
MAX_PARALLEL=${MAX_PARALLEL:-4}

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUQI_DIR="$PROJECT_ROOT/../suqi-analytics"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $*"
}

success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅${NC} $*"
}

warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠️${NC} $*"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ❌${NC} $*" >&2
}

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."

    # Check Python and required packages
    if ! command -v python3 &> /dev/null; then
        error "Python 3 is required but not installed"
        exit 1
    fi

    # Check if Whisper is available
    if ! python3 -c "import whisper" 2>/dev/null; then
        warning "OpenAI Whisper not found. Installing..."
        pip3 install openai-whisper
    fi

    # Check database connectivity
    if ! "$SCRIPT_DIR/sql.sh" -Q "SELECT 1 as test" > /dev/null 2>&1; then
        error "Database connection failed. Check credentials and connectivity."
        exit 1
    fi

    # Check intelligence schema exists
    if ! "$SCRIPT_DIR/sql.sh" -Q "SELECT COUNT(*) FROM intel.stt_jobs" > /dev/null 2>&1; then
        error "Intelligence schema not found. Run migration 030_suqi_intelligence_tables.sql first."
        exit 1
    fi

    success "All dependencies verified"
}

# Queue audio files for STT processing
queue_audio_files() {
    log "Queueing $LIMIT audio files for STT processing..."

    local store_condition=""
    if [[ -n "$STORE_ID" ]]; then
        store_condition="AND store_id = '$STORE_ID'"
    fi

    # Queue new STT jobs from audio file sources
    local queued_count
    queued_count=$("$SCRIPT_DIR/sql.sh" -Q "
        WITH audio_sources AS (
            SELECT TOP ($LIMIT)
                audio_file_path as source_uri,
                store_location as store_id,
                recorded_timestamp as txn_ts_hint,
                '$LANG' as lang
            FROM staging.audio_files af
            WHERE processed = 0
              AND audio_file_path IS NOT NULL
              AND DATALENGTH(audio_file_path) > 0
              $store_condition
              AND NOT EXISTS (
                  SELECT 1 FROM intel.stt_jobs sj
                  WHERE sj.source_uri = af.audio_file_path
                    AND sj.status NOT IN ('error')
              )
            ORDER BY recorded_timestamp DESC
        )
        INSERT INTO intel.stt_jobs (source_uri, store_id, txn_ts_hint, lang, status)
        SELECT source_uri, store_id, txn_ts_hint, lang, 'queued'
        FROM audio_sources;

        SELECT @@ROWCOUNT as queued;
    " | tail -1)

    if [[ "$queued_count" -eq 0 ]]; then
        warning "No new audio files to process"
        return 0
    fi

    success "Queued $queued_count audio files for STT processing"
    return "$queued_count"
}

# Process STT jobs using Whisper
process_stt_jobs() {
    local queued_jobs="$1"

    if [[ "$queued_jobs" -eq 0 ]]; then
        log "No STT jobs to process, skipping..."
        return 0
    fi

    log "Processing $queued_jobs STT jobs with Whisper..."

    # Create temporary processing script
    local processing_script=$(mktemp)
    cat > "$processing_script" << 'EOF'
#!/usr/bin/env python3
import sys
import os
import pyodbc
import tempfile
from datetime import datetime
import json

# Add services to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..', 'suqi-analytics', 'src'))

try:
    from services.stt_service import WhisperSTTService
    from services.transaction_matcher import DatabaseConnector
except ImportError as e:
    print(f"Error importing services: {e}")
    print("Make sure the Suqi Analytics services are available")
    sys.exit(1)

def get_db_connection():
    """Get database connection using Scout's method"""
    try:
        import subprocess
        result = subprocess.run([
            'security', 'find-generic-password',
            '-s', 'SQL-TBWA-ProjectScout-Reporting-Prod',
            '-a', 'scout-analytics',
            '-w'
        ], capture_output=True, text=True, timeout=10)

        if result.returncode == 0 and result.stdout.strip():
            return pyodbc.connect(result.stdout.strip(), timeout=30)
    except Exception:
        pass

    # Fallback to environment variable
    conn_str = os.getenv('AZURE_SQL_CONN_STR')
    if conn_str:
        return pyodbc.connect(conn_str, timeout=30)

    raise Exception("No database connection available")

def process_stt_job(job_id, source_uri, store_id, lang):
    """Process a single STT job"""
    stt_service = WhisperSTTService(model_size="base")

    try:
        # Update job status to running
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "UPDATE intel.stt_jobs SET status = 'running', started_utc = SYSUTCDATETIME() WHERE job_id = ?",
                [job_id]
            )
            conn.commit()

        print(f"Processing STT job {job_id}: {source_uri}")

        # Check if file exists
        if not os.path.exists(source_uri):
            raise Exception(f"Audio file not found: {source_uri}")

        # Process with STT service
        start_time = datetime.now()
        result = stt_service.transcribe_audio_file(source_uri, enable_diarization=True)
        processing_time = (datetime.now() - start_time).total_seconds() * 1000

        # Save results to database
        transcript_id = None
        with get_db_connection() as conn:
            cursor = conn.cursor()

            # Insert transcript
            cursor.execute("""
                INSERT INTO intel.transcripts (job_id, store_id, duration_ms, text_clean, text_raw, lang, confidence)
                OUTPUT INSERTED.transcript_id
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, [
                job_id,
                store_id,
                int(result.duration * 1000),
                result.full_text,
                result.full_text,  # For now, same as clean
                result.language,
                0.85  # Default confidence
            ])

            transcript_result = cursor.fetchone()
            if transcript_result:
                transcript_id = transcript_result[0]

            # Insert conversation segments
            for i, segment in enumerate(result.segments):
                cursor.execute("""
                    INSERT INTO intel.conversation_segments (
                        transcript_id, speaker_role, start_ms, end_ms, text,
                        confidence, brand_mentions, brand_count
                    )
                    OUTPUT INSERTED.segment_id
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """, [
                    transcript_id,
                    segment.speaker_id if hasattr(segment, 'speaker_id') else 'unknown',
                    int(segment.start_time * 1000),
                    int(segment.end_time * 1000),
                    segment.text,
                    segment.confidence,
                    ','.join(segment.brands_mentioned) if hasattr(segment, 'brands_mentioned') and segment.brands_mentioned else None,
                    len(segment.brands_mentioned) if hasattr(segment, 'brands_mentioned') and segment.brands_mentioned else 0
                ])

                segment_result = cursor.fetchone()
                if segment_result and hasattr(segment, 'brands_mentioned') and segment.brands_mentioned:
                    segment_id = segment_result[0]

                    # Insert individual brand mentions
                    for brand in segment.brands_mentioned:
                        cursor.execute("""
                            INSERT INTO intel.segment_brands (segment_id, brand, confidence)
                            VALUES (?, ?, ?)
                        """, [segment_id, brand, 0.8])  # Default brand confidence

            # Update job status to completed
            cursor.execute("""
                UPDATE intel.stt_jobs
                SET status = 'done',
                    finished_utc = SYSUTCDATETIME(),
                    processing_time_ms = ?,
                    audio_duration_ms = ?
                WHERE job_id = ?
            """, [int(processing_time), int(result.duration * 1000), job_id])

            conn.commit()

        print(f"Completed STT job {job_id}: {len(result.segments)} segments, {len(result.brands_detected)} brands")
        return True

    except Exception as e:
        print(f"Error processing STT job {job_id}: {e}")

        # Update job status to error
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(
                    "UPDATE intel.stt_jobs SET status = 'error', error_message = ?, finished_utc = SYSUTCDATETIME() WHERE job_id = ?",
                    [str(e), job_id]
                )
                conn.commit()
        except Exception as db_error:
            print(f"Error updating job status: {db_error}")

        return False

def main():
    max_jobs = int(sys.argv[1]) if len(sys.argv) > 1 else 100

    # Get queued jobs
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT TOP (?) job_id, source_uri, store_id, lang
            FROM intel.stt_jobs
            WHERE status = 'queued'
            ORDER BY created_utc
        """, [max_jobs])

        jobs = cursor.fetchall()

    if not jobs:
        print("No queued STT jobs found")
        return 0

    print(f"Processing {len(jobs)} STT jobs...")

    successful = 0
    failed = 0

    for job in jobs:
        job_id, source_uri, store_id, lang = job

        try:
            if process_stt_job(job_id, source_uri, store_id, lang):
                successful += 1
            else:
                failed += 1
        except KeyboardInterrupt:
            print("\nProcessing interrupted by user")
            break
        except Exception as e:
            print(f"Unexpected error processing job {job_id}: {e}")
            failed += 1

    print(f"\nSTT Processing complete:")
    print(f"  Successful: {successful}")
    print(f"  Failed: {failed}")
    print(f"  Total: {successful + failed}")

    return 0 if failed == 0 else 1

if __name__ == "__main__":
    sys.exit(main())
EOF

    # Make script executable and run it
    chmod +x "$processing_script"
    python3 "$processing_script" "$queued_jobs"
    local exit_code=$?

    # Clean up
    rm -f "$processing_script"

    if [[ $exit_code -eq 0 ]]; then
        success "STT processing completed successfully"
    else
        error "STT processing completed with errors"
    fi

    return $exit_code
}

# Post-process: enrich transcripts with additional analysis
enrich_transcripts() {
    log "Post-processing: enriching transcripts with additional analysis..."

    # Update transcript analysis flags
    "$SCRIPT_DIR/sql.sh" -Q "
        DECLARE @updated INT = 0;
        DECLARE @transcript_cursor CURSOR;
        DECLARE @transcript_id UNIQUEIDENTIFIER;

        SET @transcript_cursor = CURSOR FOR
            SELECT transcript_id FROM intel.transcripts
            WHERE analyzed_utc IS NULL OR analyzed_utc < DATEADD(HOUR, -1, SYSUTCDATETIME());

        OPEN @transcript_cursor;
        FETCH NEXT FROM @transcript_cursor INTO @transcript_id;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC intel.sp_update_transcript_flags @transcript_id;
            SET @updated = @updated + 1;
            FETCH NEXT FROM @transcript_cursor INTO @transcript_id;
        END;

        CLOSE @transcript_cursor;
        DEALLOCATE @transcript_cursor;

        SELECT @updated as transcripts_updated;
    "

    # Generate summary statistics
    local stats
    stats=$("$SCRIPT_DIR/sql.sh" -Q "
        SELECT
            COUNT(*) as total_transcripts,
            COUNT(CASE WHEN has_segments = 1 THEN 1 END) as with_segments,
            COUNT(CASE WHEN has_brands = 1 THEN 1 END) as with_brands,
            AVG(CAST(duration_ms AS FLOAT) / 1000.0) as avg_duration_seconds,
            COUNT(DISTINCT store_id) as store_count
        FROM intel.transcripts
        WHERE created_utc >= DATEADD(HOUR, -1, SYSUTCDATETIME());
    ")

    echo "$stats" | while IFS=$'\t' read -r total segments brands avg_duration stores; do
        success "Transcript analysis complete:"
        echo "  Total transcripts: $total"
        echo "  With segments: $segments"
        echo "  With brand mentions: $brands"
        echo "  Average duration: ${avg_duration}s"
        echo "  Stores covered: $stores"
    done
}

# Generate processing report
generate_report() {
    log "Generating STT processing report..."

    local report_file="$PROJECT_ROOT/out/stt_processing_report_$(date '+%Y%m%d_%H%M%S').txt"
    mkdir -p "$(dirname "$report_file")"

    {
        echo "STT Processing Report"
        echo "===================="
        echo "Generated: $(date)"
        echo "Limit: $LIMIT"
        echo "Language: $LANG"
        echo "Store ID filter: ${STORE_ID:-"(none)"}"
        echo ""

        echo "Job Status Summary:"
        echo "==================="
        "$SCRIPT_DIR/sql.sh" -Q "
            SELECT
                status,
                COUNT(*) as job_count,
                AVG(CASE WHEN processing_time_ms IS NOT NULL THEN CAST(processing_time_ms AS FLOAT) / 1000.0 END) as avg_processing_seconds,
                MIN(created_utc) as earliest_job,
                MAX(finished_utc) as latest_completion
            FROM intel.stt_jobs
            WHERE created_utc >= DATEADD(HOUR, -2, SYSUTCDATETIME())
            GROUP BY status
            ORDER BY status;
        "

        echo ""
        echo "Brand Mention Analysis:"
        echo "======================="
        "$SCRIPT_DIR/sql.sh" -Q "
            SELECT TOP 20
                sb.brand,
                COUNT(*) as mention_count,
                COUNT(DISTINCT cs.transcript_id) as transcript_count
            FROM intel.segment_brands sb
            JOIN intel.conversation_segments cs ON cs.segment_id = sb.segment_id
            JOIN intel.transcripts t ON t.transcript_id = cs.transcript_id
            WHERE t.created_utc >= DATEADD(HOUR, -2, SYSUTCDATETIME())
            GROUP BY sb.brand
            ORDER BY mention_count DESC;
        "

        echo ""
        echo "Store Coverage:"
        echo "==============="
        "$SCRIPT_DIR/sql.sh" -Q "
            SELECT
                store_id,
                COUNT(*) as transcript_count,
                AVG(CAST(duration_ms AS FLOAT) / 1000.0) as avg_duration_seconds
            FROM intel.transcripts
            WHERE created_utc >= DATEADD(HOUR, -2, SYSUTCDATETIME())
              AND store_id IS NOT NULL
            GROUP BY store_id
            ORDER BY transcript_count DESC;
        "
    } > "$report_file"

    success "Report generated: $report_file"
}

# Main execution
main() {
    log "Starting STT Reprocessing Pipeline (Path A)"
    log "Limit: $LIMIT, Language: $LANG, Store: ${STORE_ID:-"all"}"

    # Check dependencies
    check_dependencies

    # Queue audio files
    local queued_count
    if ! queued_count=$(queue_audio_files); then
        error "Failed to queue audio files"
        exit 1
    fi

    # Process STT jobs
    if ! process_stt_jobs "$queued_count"; then
        warning "STT processing completed with some errors"
    fi

    # Enrich transcripts
    enrich_transcripts

    # Generate report
    generate_report

    success "STT reprocessing pipeline completed"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [options]"
        echo ""
        echo "Environment variables:"
        echo "  LIMIT         Number of audio files to process (default: 100)"
        echo "  LANG          Language code for processing (default: fil)"
        echo "  STORE_ID      Filter by specific store ID (optional)"
        echo "  MAX_PARALLEL  Maximum parallel processes (default: 4)"
        echo ""
        echo "Examples:"
        echo "  $0                          # Process 100 files in Filipino"
        echo "  LIMIT=50 $0                 # Process 50 files"
        echo "  LANG=en STORE_ID=store_001 $0  # English, specific store"
        exit 0
        ;;
    --check-deps)
        check_dependencies
        exit $?
        ;;
    *)
        main "$@"
        ;;
esac