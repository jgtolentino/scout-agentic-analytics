#!/usr/bin/env bash
set -euo pipefail

# ========================================================================
# Scout Analytics - Retry Persona CI with Exponential Backoff
# Script: retry_persona_ci.sh
# Purpose: Intelligently retry persona-ci until database recovers
# ========================================================================

DB="${DB:-SQL-TBWA-ProjectScout-Reporting-Prod}"
MIN_PCT="${MIN_PCT:-30}"
MIN_CONFIDENCE="${MIN_CONFIDENCE:-0.70}"
MIN_PERSONAS="${MIN_PERSONAS:-5}"
MAX_TRIES="${MAX_TRIES:-12}"     # ~1 hour max if 5min cap
INITIAL_DELAY="${INITIAL_DELAY:-30}"
MAX_DELAY="${MAX_DELAY:-300}"    # 5 minute max delay

echo "🔄 Persona CI Retry with Exponential Backoff"
echo "============================================="
echo "Database: $DB"
echo "Coverage threshold: ${MIN_PCT}%"
echo "Max attempts: $MAX_TRIES"
echo "Initial delay: ${INITIAL_DELAY}s"
echo ""

delay=$INITIAL_DELAY
start_time=$(date +%s)

for i in $(seq 1 "$MAX_TRIES"); do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))

    echo "▶︎ Attempt $i/$MAX_TRIES (elapsed: ${elapsed}s, next delay: ${delay}s)"
    echo "  $(date '+%Y-%m-%d %H:%M:%S') - Starting attempt..."

    # First check if database is reachable
    echo "  🔍 Checking database connectivity..."
    if ./scripts/conn_doctor.sh >/dev/null 2>&1; then
        echo "  ✅ Database connection successful"

        # Database is up, try running persona-ci
        echo "  🧠 Running persona-ci pipeline..."
        if make persona-ci DB="$DB" MIN_PCT="$MIN_PCT" MIN_CONFIDENCE="$MIN_CONFIDENCE" MIN_PERSONAS="$MIN_PERSONAS"; then
            total_time=$(($(date +%s) - start_time))
            echo ""
            echo "🎉 SUCCESS: persona-ci completed on attempt $i"
            echo "⏱️  Total time: ${total_time} seconds"
            echo "📊 Pipeline executed successfully with all quality gates"
            exit 0
        else
            echo "  ⚠️  persona-ci failed (quality gate or processing error)"
            echo "  📋 This could be due to:"
            echo "      - Coverage below ${MIN_PCT}% threshold"
            echo "      - Confidence below ${MIN_CONFIDENCE} threshold"
            echo "      - Less than ${MIN_PERSONAS} unique personas"
            echo "      - Processing error in pipeline"
            echo "  🔄 Will retry in case it's a transient issue..."
        fi
    else
        # Get the specific error code for better messaging
        error_code=$?
        echo "  ❌ Database still unreachable (error code: $error_code)"
        case $error_code in
            2) echo "     → Authentication issue - check credentials" ;;
            3) echo "     → Server unreachable - check network/DNS" ;;
            4) echo "     → Firewall blocked - add IP to whitelist" ;;
            5|7) echo "     → Database busy/unavailable - will retry" ;;
            6) echo "     → Network connectivity issue" ;;
            8) echo "     → Connection timeout" ;;
            *) echo "     → Unknown connectivity issue" ;;
        esac
    fi

    # Check if this was the last attempt
    if [[ $i -eq $MAX_TRIES ]]; then
        echo ""
        echo "❌ FAILED: Exhausted all $MAX_TRIES retry attempts"
        total_time=$(($(date +%s) - start_time))
        echo "⏱️  Total time spent: ${total_time} seconds"
        echo ""
        echo "🔧 Troubleshooting suggestions:"
        echo "   1. Run 'make doctor-db DB=\"$DB\"' for detailed diagnostics"
        echo "   2. Check Azure SQL service health in portal"
        echo "   3. Verify network connectivity and firewall rules"
        echo "   4. Consider running during off-peak hours"
        echo "   5. Contact database administrator if issue persists"
        echo ""
        echo "🔄 To retry manually: make persona-ci DB=\"$DB\" MIN_PCT=\"$MIN_PCT\""
        exit 2
    fi

    # Calculate next delay with exponential backoff (capped at MAX_DELAY)
    echo "  ⏳ Waiting ${delay} seconds before next attempt..."
    sleep "$delay"

    # Exponential backoff: double delay up to maximum
    delay=$(( delay < MAX_DELAY ? delay*2 : MAX_DELAY ))
done