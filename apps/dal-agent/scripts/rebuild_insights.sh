#!/usr/bin/env bash
# =================================================================
# Conversational Insights Rebuild - Path B
# Generates persona inference and signals from existing transcripts
# =================================================================

set -euo pipefail

# Configuration
MAX=${MAX:-5000}
VERSION=${VERSION:-"v2.1"}
MIN_CONFIDENCE=${MIN_CONFIDENCE:-0.6}
BATCH_SIZE=${BATCH_SIZE:-100}

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
    log "Checking insights rebuild dependencies..."

    # Check database connectivity
    if ! "$SCRIPT_DIR/sql.sh" -Q "SELECT 1 as test" > /dev/null 2>&1; then
        error "Database connection failed. Check credentials and connectivity."
        exit 1
    fi

    # Check intelligence schema
    if ! "$SCRIPT_DIR/sql.sh" -Q "SELECT COUNT(*) FROM intel.transcripts" > /dev/null 2>&1; then
        error "Intelligence schema not found. Run migration 030_suqi_intelligence_tables.sql first."
        exit 1
    fi

    # Check if we have transcripts to process
    local transcript_count
    transcript_count=$("$SCRIPT_DIR/sql.sh" -Q "SELECT COUNT(*) FROM intel.transcripts WHERE text_clean IS NOT NULL" | tail -1)

    if [[ "$transcript_count" -eq 0 ]]; then
        warning "No transcripts found with text content. Run STT processing first."
        exit 1
    fi

    success "Found $transcript_count transcripts ready for analysis"
}

# Generate persona signals from conversation content
generate_persona_signals() {
    log "Generating persona signals from transcripts (version $VERSION)..."

    # Create temporary signal generation script
    local signal_script=$(mktemp)
    cat > "$signal_script" << 'EOF'
#!/usr/bin/env python3
import sys
import os
import pyodbc
import re
import json
from datetime import datetime
from collections import defaultdict, Counter

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

class PersonaSignalGenerator:
    """Generate persona signals from conversation text"""

    def __init__(self, version="v2.1"):
        self.version = version

        # Define signal patterns for Filipino retail context
        self.signal_patterns = {
            # Customer signals
            'token:customer': [
                r'\b(bumili|gusto|kailangan|hinahanap|magkano|meron ba)\b',
                r'\b(buying|want|need|looking for|how much|do you have)\b'
            ],

            # Owner/staff signals
            'token:owner': [
                r'\b(tindahan|negosyo|inventory|supplier|kita|profit)\b',
                r'\b(business|store|profit|supplier|inventory)\b'
            ],

            # Brand preference signals
            'brand:preference': [
                r'\b(mas gusto|prefer|mas maganda|better|lagi|always)\b',
                r'\b(brand|tatak|kilala|sikat|popular)\b'
            ],

            # Price sensitivity signals
            'price:sensitive': [
                r'\b(mahal|expensive|mura|cheap|discount|sale|presyo)\b',
                r'\b(mas mababa|lower|mas mahal|higher|sukli|change)\b'
            ],

            # Temporal patterns
            'temporal:regular': [
                r'\b(lagi|palagi|tuwing|always|every|regular)\b',
                r'\b(minsan|sometimes|paminsan|occasionally)\b'
            ],

            # Demographic indicators
            'demo:family': [
                r'\b(pamilya|family|anak|children|asawa|wife|husband)\b',
                r'\b(para sa|for the|household|bahay)\b'
            ],

            # Purchase intent signals
            'intent:immediate': [
                r'\b(ngayon|now|kailangan|need|bilhin|buy)\b',
                r'\b(isang|one|dalawa|two|tatlo|three)\b'
            ],

            # Complaint/satisfaction signals
            'sentiment:negative': [
                r'\b(sira|broken|masama|bad|hindi ok|not good|reklamo|complaint)\b',
                r'\b(problema|problem|ayaw|dont want|bakit|why)\b'
            ],

            'sentiment:positive': [
                r'\b(maganda|good|ok|ayos|masarap|satisfied|salamat|thank)\b',
                r'\b(sulit|worth it|magaling|excellent|recommend)\b'
            ]
        }

        # Weight assignments for different signal types
        self.signal_weights = {
            'token:customer': 2.0,
            'token:owner': 3.0,
            'brand:preference': 1.5,
            'price:sensitive': 1.2,
            'temporal:regular': 1.8,
            'demo:family': 1.3,
            'intent:immediate': 2.2,
            'sentiment:negative': 1.0,
            'sentiment:positive': 1.0
        }

    def extract_signals(self, text, transcript_id, transaction_id=None):
        """Extract persona signals from conversation text"""
        signals = []
        text_lower = text.lower()

        for signal_key, patterns in self.signal_patterns.items():
            signal_strength = 0
            matches = []

            for pattern in patterns:
                pattern_matches = list(re.finditer(pattern, text_lower, re.IGNORECASE))
                matches.extend(pattern_matches)
                signal_strength += len(pattern_matches)

            if signal_strength > 0:
                # Calculate confidence based on match frequency and context
                confidence = min(0.3 + (signal_strength * 0.2), 1.0)

                # Extract context around matches
                contexts = []
                for match in matches[:3]:  # Limit to first 3 matches
                    start = max(0, match.start() - 20)
                    end = min(len(text), match.end() + 20)
                    contexts.append(text[start:end].strip())

                signal_value = '; '.join(contexts[:2])  # Store context

                signals.append({
                    'transcript_id': transcript_id,
                    'transaction_id': transaction_id,
                    'signal_key': signal_key,
                    'signal_value': signal_value[:255],  # Truncate to fit DB column
                    'signal_type': signal_key.split(':')[0],  # Extract type (token, brand, etc.)
                    'weight': self.signal_weights.get(signal_key, 1.0),
                    'confidence': confidence
                })

        return signals

    def generate_signals_batch(self, transcripts):
        """Generate signals for a batch of transcripts"""
        all_signals = []

        for transcript in transcripts:
            transcript_id, text, transaction_id = transcript
            if text and text.strip():
                signals = self.extract_signals(text, transcript_id, transaction_id)
                all_signals.extend(signals)

        return all_signals

def main():
    max_transcripts = int(sys.argv[1]) if len(sys.argv) > 1 else 5000
    version = sys.argv[2] if len(sys.argv) > 2 else "v2.1"
    batch_size = int(sys.argv[3]) if len(sys.argv) > 3 else 100

    generator = PersonaSignalGenerator(version)

    print(f"Generating persona signals for up to {max_transcripts} transcripts...")

    # Get transcripts that need signal processing
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT TOP (?)
                t.transcript_id,
                t.text_clean,
                pi.transaction_id
            FROM intel.transcripts t
            LEFT JOIN intel.persona_inference pi ON pi.transcript_id = t.transcript_id AND pi.rule_version = ?
            WHERE t.text_clean IS NOT NULL
              AND LEN(t.text_clean) > 10
              AND (pi.transcript_id IS NULL OR pi.created_utc < DATEADD(DAY, -1, SYSUTCDATETIME()))
            ORDER BY t.created_utc DESC
        """, [max_transcripts, version])

        transcripts = cursor.fetchall()

    if not transcripts:
        print("No transcripts need signal processing")
        return 0

    print(f"Processing {len(transcripts)} transcripts in batches of {batch_size}...")

    total_signals = 0
    batch_count = 0

    # Process in batches
    for i in range(0, len(transcripts), batch_size):
        batch = transcripts[i:i + batch_size]
        batch_count += 1

        print(f"Processing batch {batch_count} ({len(batch)} transcripts)...")

        # Generate signals for batch
        signals = generator.generate_signals_batch(batch)

        if signals:
            # Clear existing signals for these transcripts
            transcript_ids = [str(t[0]) for t in batch]
            placeholders = ','.join(['?' for _ in transcript_ids])

            with get_db_connection() as conn:
                cursor = conn.cursor()

                # Delete old signals for these transcripts
                cursor.execute(f"""
                    DELETE FROM intel.persona_signals
                    WHERE transcript_id IN ({placeholders})
                """, transcript_ids)

                # Insert new signals
                for signal in signals:
                    cursor.execute("""
                        INSERT INTO intel.persona_signals (
                            transcript_id, transaction_id, signal_key, signal_value,
                            signal_type, weight, confidence, extraction_method
                        )
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """, [
                        signal['transcript_id'],
                        signal['transaction_id'],
                        signal['signal_key'],
                        signal['signal_value'],
                        signal['signal_type'],
                        signal['weight'],
                        signal['confidence'],
                        f'regex_{version}'
                    ])

                conn.commit()

            total_signals += len(signals)
            print(f"  Generated {len(signals)} signals for batch {batch_count}")

    print(f"\nSignal generation complete:")
    print(f"  Transcripts processed: {len(transcripts)}")
    print(f"  Total signals generated: {total_signals}")
    print(f"  Average signals per transcript: {total_signals / len(transcripts):.1f}")

    return 0

if __name__ == "__main__":
    sys.exit(main())
EOF

    # Make script executable and run it
    chmod +x "$signal_script"
    python3 "$signal_script" "$MAX" "$VERSION" "$BATCH_SIZE"
    local exit_code=$?

    # Clean up
    rm -f "$signal_script"

    if [[ $exit_code -eq 0 ]]; then
        success "Persona signal generation completed successfully"
    else
        error "Signal generation failed"
        return $exit_code
    fi
}

# Run persona inference using generated signals
run_persona_inference() {
    log "Running persona inference (version $VERSION)..."

    # Create persona inference script
    local inference_script=$(mktemp)
    cat > "$inference_script" << 'EOF'
#!/usr/bin/env python3
import sys
import os
import pyodbc
from datetime import datetime
from collections import defaultdict
import json

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

class PersonaInferenceEngine:
    """Infer customer personas from conversation signals"""

    def __init__(self, version="v2.1", min_confidence=0.6):
        self.version = version
        self.min_confidence = min_confidence

        # Define persona inference rules
        self.persona_rules = {
            'customer_regular': {
                'required_signals': ['token:customer'],
                'positive_signals': ['temporal:regular', 'brand:preference'],
                'negative_signals': ['token:owner'],
                'min_score': 3.0,
                'description': 'Regular customer with established preferences'
            },

            'customer_new': {
                'required_signals': ['token:customer'],
                'positive_signals': ['intent:immediate', 'price:sensitive'],
                'negative_signals': ['temporal:regular', 'token:owner'],
                'min_score': 2.5,
                'description': 'New customer exploring options'
            },

            'customer_family': {
                'required_signals': ['token:customer', 'demo:family'],
                'positive_signals': ['intent:immediate'],
                'negative_signals': ['token:owner'],
                'min_score': 3.5,
                'description': 'Family-oriented customer'
            },

            'owner_operator': {
                'required_signals': ['token:owner'],
                'positive_signals': ['price:sensitive', 'brand:preference'],
                'negative_signals': ['token:customer'],
                'min_score': 4.0,
                'description': 'Store owner or operator'
            },

            'staff_employee': {
                'required_signals': [],
                'positive_signals': ['token:owner'],
                'negative_signals': ['token:customer', 'demo:family'],
                'min_score': 2.0,
                'description': 'Store staff or employee'
            },

            'price_conscious': {
                'required_signals': ['price:sensitive'],
                'positive_signals': ['token:customer'],
                'negative_signals': ['token:owner'],
                'min_score': 2.5,
                'description': 'Price-conscious customer'
            },

            'brand_loyal': {
                'required_signals': ['brand:preference'],
                'positive_signals': ['token:customer', 'temporal:regular'],
                'negative_signals': ['price:sensitive'],
                'min_score': 3.0,
                'description': 'Brand-loyal customer'
            }
        }

    def calculate_persona_score(self, signals, persona_key, persona_rule):
        """Calculate score for a specific persona"""
        signal_dict = {s['signal_key']: s for s in signals}
        score = 0.0
        signal_count = 0

        # Check required signals
        for required in persona_rule['required_signals']:
            if required not in signal_dict:
                return 0.0  # Missing required signal

        # Add positive signal scores
        for positive in persona_rule['positive_signals']:
            if positive in signal_dict:
                signal = signal_dict[positive]
                score += signal['weight'] * signal['confidence']
                signal_count += 1

        # Add required signal scores
        for required in persona_rule['required_signals']:
            if required in signal_dict:
                signal = signal_dict[required]
                score += signal['weight'] * signal['confidence'] * 1.2  # Boost required signals
                signal_count += 1

        # Subtract negative signal scores
        for negative in persona_rule['negative_signals']:
            if negative in signal_dict:
                signal = signal_dict[negative]
                score -= signal['weight'] * signal['confidence'] * 0.5

        # Normalize by signal count to prevent bias toward high signal counts
        if signal_count > 0:
            score = score / max(signal_count, 1)

        return max(score, 0.0)

    def infer_persona(self, signals):
        """Infer best persona for a set of signals"""
        persona_scores = {}

        for persona_key, persona_rule in self.persona_rules.items():
            score = self.calculate_persona_score(signals, persona_key, persona_rule)

            if score >= persona_rule['min_score']:
                persona_scores[persona_key] = {
                    'score': score,
                    'rule': persona_rule,
                    'confidence': min(score * 20, 100)  # Convert to percentage (max 100)
                }

        if not persona_scores:
            return None

        # Get best persona
        best_persona = max(persona_scores.items(), key=lambda x: x[1]['score'])

        if best_persona[1]['confidence'] < self.min_confidence * 100:
            return None

        # Generate alternative personas (top 2 alternatives)
        alternatives = []
        sorted_personas = sorted(persona_scores.items(), key=lambda x: x[1]['score'], reverse=True)

        for persona_key, persona_data in sorted_personas[1:3]:  # Skip best, take next 2
            alternatives.append({
                'persona': persona_key,
                'confidence': persona_data['confidence']
            })

        # Extract key signals used in inference
        key_signals = []
        best_rule = best_persona[1]['rule']

        signal_dict = {s['signal_key']: s for s in signals}

        for signal_type in ['required_signals', 'positive_signals']:
            for signal_key in best_rule.get(signal_type, []):
                if signal_key in signal_dict:
                    key_signals.append(signal_key)

        return {
            'persona': best_persona[0],
            'confidence': best_persona[1]['confidence'],
            'alternatives': alternatives,
            'key_signals': key_signals[:10],  # Limit to top 10
            'signal_count': len(signals)
        }

def main():
    version = sys.argv[1] if len(sys.argv) > 1 else "v2.1"
    min_confidence = float(sys.argv[2]) if len(sys.argv) > 2 else 0.6
    max_transcripts = int(sys.argv[3]) if len(sys.argv) > 3 else 5000

    engine = PersonaInferenceEngine(version, min_confidence)

    print(f"Running persona inference (version {version}, min confidence {min_confidence:.1%})...")

    # Get transcripts with signals that need inference
    with get_db_connection() as conn:
        cursor = conn.cursor()

        # Get transcripts with signals but no recent inference
        cursor.execute("""
            SELECT DISTINCT
                ps.transcript_id,
                ps.transaction_id
            FROM intel.persona_signals ps
            LEFT JOIN intel.persona_inference pi ON pi.transcript_id = ps.transcript_id AND pi.rule_version = ?
            WHERE pi.transcript_id IS NULL OR pi.created_utc < DATEADD(DAY, -1, SYSUTCDATETIME())
            ORDER BY ps.transcript_id
            OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY
        """, [version, max_transcripts])

        transcript_candidates = cursor.fetchall()

    if not transcript_candidates:
        print("No transcripts need persona inference")
        return 0

    print(f"Running inference for {len(transcript_candidates)} transcripts...")

    inferences_generated = 0
    skipped_count = 0

    for transcript_id, transaction_id in transcript_candidates:
        try:
            # Get all signals for this transcript
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    SELECT signal_key, signal_value, signal_type, weight, confidence
                    FROM intel.persona_signals
                    WHERE transcript_id = ?
                    ORDER BY weight DESC, confidence DESC
                """, [transcript_id])

                signals = []
                for row in cursor.fetchall():
                    signals.append({
                        'signal_key': row[0],
                        'signal_value': row[1],
                        'signal_type': row[2],
                        'weight': float(row[3]),
                        'confidence': float(row[4])
                    })

            if len(signals) < 2:  # Need at least 2 signals for meaningful inference
                skipped_count += 1
                continue

            # Run inference
            result = engine.infer_persona(signals)

            if result:
                # Save inference to database
                with get_db_connection() as conn:
                    cursor = conn.cursor()

                    # Delete old inference for this transcript
                    cursor.execute("""
                        DELETE FROM intel.persona_inference
                        WHERE transcript_id = ? AND rule_version = ?
                    """, [transcript_id, version])

                    # Insert new inference
                    cursor.execute("""
                        INSERT INTO intel.persona_inference (
                            transcript_id, transaction_id, inferred_role, confidence,
                            alternative_roles, signal_count, key_signals, rule_version, model_metadata
                        )
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, [
                        transcript_id,
                        transaction_id,
                        result['persona'],
                        result['confidence'],
                        json.dumps(result['alternatives']),
                        result['signal_count'],
                        ', '.join(result['key_signals']),
                        version,
                        json.dumps({'min_confidence': min_confidence, 'engine_version': version})
                    ])

                    conn.commit()

                inferences_generated += 1

                if inferences_generated % 100 == 0:
                    print(f"  Processed {inferences_generated} inferences...")

        except Exception as e:
            print(f"Error processing transcript {transcript_id}: {e}")
            continue

    print(f"\nPersona inference complete:")
    print(f"  Transcripts processed: {len(transcript_candidates)}")
    print(f"  Inferences generated: {inferences_generated}")
    print(f"  Skipped (insufficient signals): {skipped_count}")
    print(f"  Success rate: {inferences_generated / len(transcript_candidates) * 100:.1f}%")

    return 0

if __name__ == "__main__":
    sys.exit(main())
EOF

    # Make script executable and run it
    chmod +x "$inference_script"
    python3 "$inference_script" "$VERSION" "$MIN_CONFIDENCE" "$MAX"
    local exit_code=$?

    # Clean up
    rm -f "$inference_script"

    if [[ $exit_code -eq 0 ]]; then
        success "Persona inference completed successfully"
    else
        error "Persona inference failed"
        return $exit_code
    fi
}

# Update production views and caches
update_production_views() {
    log "Refreshing production views and caches..."

    # Update transcript analysis flags for all processed transcripts
    "$SCRIPT_DIR/sql.sh" -Q "
        DECLARE @updated INT = 0;
        DECLARE @transcript_cursor CURSOR;
        DECLARE @transcript_id UNIQUEIDENTIFIER;

        SET @transcript_cursor = CURSOR FOR
            SELECT DISTINCT ps.transcript_id
            FROM intel.persona_signals ps
            WHERE ps.created_utc >= DATEADD(HOUR, -2, SYSUTCDATETIME());

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

    success "Production views refreshed"
}

# Generate insights report
generate_insights_report() {
    log "Generating insights analysis report..."

    local report_file="$PROJECT_ROOT/out/insights_rebuild_report_$(date '+%Y%m%d_%H%M%S').txt"
    mkdir -p "$(dirname "$report_file")"

    {
        echo "Conversational Insights Rebuild Report"
        echo "====================================="
        echo "Generated: $(date)"
        echo "Max transcripts: $MAX"
        echo "Rule version: $VERSION"
        echo "Min confidence: $MIN_CONFIDENCE"
        echo ""

        echo "Persona Inference Summary:"
        echo "========================="
        "$SCRIPT_DIR/sql.sh" -Q "
            SELECT
                inferred_role,
                COUNT(*) as inference_count,
                AVG(confidence) as avg_confidence,
                COUNT(CASE WHEN confidence >= 70 THEN 1 END) as high_confidence_count
            FROM intel.persona_inference
            WHERE rule_version = '$VERSION'
              AND created_utc >= DATEADD(HOUR, -2, SYSUTCDATETIME())
            GROUP BY inferred_role
            ORDER BY inference_count DESC;
        "

        echo ""
        echo "Signal Type Distribution:"
        echo "========================"
        "$SCRIPT_DIR/sql.sh" -Q "
            SELECT
                signal_type,
                COUNT(*) as signal_count,
                COUNT(DISTINCT transcript_id) as transcript_count,
                AVG(weight) as avg_weight,
                AVG(confidence) as avg_confidence
            FROM intel.persona_signals
            WHERE created_utc >= DATEADD(HOUR, -2, SYSUTCDATETIME())
            GROUP BY signal_type
            ORDER BY signal_count DESC;
        "

        echo ""
        echo "Top Brand Conversations:"
        echo "======================="
        "$SCRIPT_DIR/sql.sh" -Q "
            SELECT TOP 15
                sb.brand,
                COUNT(*) as mention_count,
                COUNT(DISTINCT cs.transcript_id) as transcript_count,
                AVG(sb.confidence) as avg_confidence
            FROM intel.segment_brands sb
            JOIN intel.conversation_segments cs ON cs.segment_id = sb.segment_id
            JOIN intel.transcripts t ON t.transcript_id = cs.transcript_id
            WHERE t.created_utc >= DATEADD(HOUR, -2, SYSUTCDATETIME())
            GROUP BY sb.brand
            ORDER BY mention_count DESC;
        "

        echo ""
        echo "Store Coverage Analysis:"
        echo "======================="
        "$SCRIPT_DIR/sql.sh" -Q "
            SELECT
                t.store_id,
                COUNT(DISTINCT t.transcript_id) as transcript_count,
                COUNT(pi.inference_id) as inference_count,
                CAST(COUNT(pi.inference_id) AS FLOAT) / COUNT(DISTINCT t.transcript_id) as inference_rate
            FROM intel.transcripts t
            LEFT JOIN intel.persona_inference pi ON pi.transcript_id = t.transcript_id AND pi.rule_version = '$VERSION'
            WHERE t.created_utc >= DATEADD(HOUR, -2, SYSUTCDATETIME())
              AND t.store_id IS NOT NULL
            GROUP BY t.store_id
            ORDER BY transcript_count DESC;
        "

        echo ""
        echo "Processing Performance:"
        echo "======================"
        "$SCRIPT_DIR/sql.sh" -Q "
            SELECT
                'Total Transcripts' as metric,
                COUNT(*) as value
            FROM intel.transcripts
            WHERE created_utc >= DATEADD(HOUR, -2, SYSUTCDATETIME())

            UNION ALL

            SELECT
                'With Signals',
                COUNT(DISTINCT ps.transcript_id)
            FROM intel.persona_signals ps
            WHERE ps.created_utc >= DATEADD(HOUR, -2, SYSUTCDATETIME())

            UNION ALL

            SELECT
                'With Persona Inference',
                COUNT(*)
            FROM intel.persona_inference pi
            WHERE pi.rule_version = '$VERSION'
              AND pi.created_utc >= DATEADD(HOUR, -2, SYSUTCDATETIME())

            UNION ALL

            SELECT
                'High Confidence Inferences',
                COUNT(*)
            FROM intel.persona_inference pi
            WHERE pi.rule_version = '$VERSION'
              AND pi.confidence >= 70
              AND pi.created_utc >= DATEADD(HOUR, -2, SYSUTCDATETIME());
        "

    } > "$report_file"

    success "Report generated: $report_file"
}

# Main execution
main() {
    log "Starting Conversational Insights Rebuild (Path B)"
    log "Max: $MAX, Version: $VERSION, Min Confidence: $MIN_CONFIDENCE"

    # Check dependencies
    check_dependencies

    # Generate persona signals
    if ! generate_persona_signals; then
        error "Failed to generate persona signals"
        exit 1
    fi

    # Run persona inference
    if ! run_persona_inference; then
        error "Failed to run persona inference"
        exit 1
    fi

    # Update production views
    update_production_views

    # Generate report
    generate_insights_report

    success "Conversational insights rebuild completed"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [options]"
        echo ""
        echo "Environment variables:"
        echo "  MAX             Maximum transcripts to process (default: 5000)"
        echo "  VERSION         Rule version for inference (default: v2.1)"
        echo "  MIN_CONFIDENCE  Minimum confidence threshold (default: 0.6)"
        echo "  BATCH_SIZE      Batch size for processing (default: 100)"
        echo ""
        echo "Examples:"
        echo "  $0                                    # Process 5000 transcripts"
        echo "  MAX=1000 $0                          # Process 1000 transcripts"
        echo "  VERSION=v2.2 MIN_CONFIDENCE=0.7 $0   # Custom version and confidence"
        exit 0
        ;;
    --check-deps)
        check_dependencies
        exit $?
        ;;
    signals)
        check_dependencies
        generate_persona_signals
        exit $?
        ;;
    infer)
        check_dependencies
        run_persona_inference
        exit $?
        ;;
    *)
        main "$@"
        ;;
esac