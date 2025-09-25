#!/usr/bin/env bash
set -euo pipefail

# ========================================================================
# Scout Analytics - Persona Coverage CI Gate
# Script: persona_ci_gate.sh
# Purpose: Validate persona coverage meets minimum thresholds
# ========================================================================

# Configuration
MIN_PCT="${MIN_PCT:-30}"   # Minimum coverage percentage (start conservative)
MIN_CONFIDENCE="${MIN_CONFIDENCE:-0.70}"  # Minimum average confidence
MIN_PERSONAS="${MIN_PERSONAS:-5}"  # Minimum unique personas detected

echo "🔍 Persona Coverage Quality Gate"
echo "================================================"
echo "Minimum coverage required: ${MIN_PCT}%"
echo "Minimum average confidence: ${MIN_CONFIDENCE}"
echo "Minimum unique personas: ${MIN_PERSONAS}"
echo ""

# Get coverage metrics
echo "📊 Fetching persona coverage metrics..."
coverage_row=$(./scripts/sql.sh -Q "SELECT CAST(coverage_pct AS varchar(10)), CAST(avg_confidence AS varchar(10)), unique_personas FROM gold.v_persona_coverage_summary;" -s "," -W -h -1)

if [[ -z "$coverage_row" ]]; then
    echo "❌ Failed to retrieve coverage metrics"
    exit 1
fi

# Parse metrics
IFS=',' read -r coverage_pct avg_confidence unique_personas <<< "$coverage_row"

# Clean up values (remove any whitespace)
coverage_pct=$(echo "$coverage_pct" | xargs)
avg_confidence=$(echo "$avg_confidence" | xargs)
unique_personas=$(echo "$unique_personas" | xargs)

echo "Current Results:"
echo "  Coverage: ${coverage_pct}%"
echo "  Avg Confidence: ${avg_confidence}"
echo "  Unique Personas: ${unique_personas}"
echo ""

# Validate coverage percentage
coverage_int=$(awk -v x="$coverage_pct" 'BEGIN{printf "%.0f", x*100}')
min_int=$(($MIN_PCT*100))

if [[ $coverage_int -lt $min_int ]]; then
    echo "❌ Coverage gate failed: ${coverage_pct}% < ${MIN_PCT}%"
    echo ""
    echo "📋 Top unassigned patterns for improvement:"
    ./scripts/sql.sh -Q "
        SELECT TOP 10
            SUBSTRING(transcript_snippet, 1, 80) + '...' AS sample_transcript,
            hour_bucket, nielsen_group, basket_category
        FROM gold.v_unassigned_analysis
        WHERE transcript_snippet IS NOT NULL
        ORDER BY canonical_tx_id;" -s "," -W -h -1 | head -10
    exit 2
fi

# Validate average confidence
confidence_check=$(awk -v c="$avg_confidence" -v m="$MIN_CONFIDENCE" 'BEGIN{print (c >= m) ? "pass" : "fail"}')
if [[ "$confidence_check" == "fail" ]]; then
    echo "❌ Confidence gate failed: ${avg_confidence} < ${MIN_CONFIDENCE}"
    exit 3
fi

# Validate unique personas
if [[ $unique_personas -lt $MIN_PERSONAS ]]; then
    echo "❌ Persona variety gate failed: ${unique_personas} < ${MIN_PERSONAS}"
    exit 4
fi

echo "✅ All persona coverage gates passed!"
echo ""
echo "📈 Persona Distribution:"
./scripts/sql.sh -Q "
    SELECT
        inferred_role,
        transaction_count,
        CAST(percentage AS varchar(10)) + '%' AS percentage,
        CAST(avg_confidence AS varchar(10)) AS avg_confidence
    FROM gold.v_persona_role_distribution
    WHERE inferred_role <> 'Unassigned'
    ORDER BY transaction_count DESC;" -s "," -W -h -1

echo ""
echo "🎯 Quality Metrics:"
./scripts/sql.sh -Q "
    SELECT
        'Speaker Attribution' AS metric,
        CAST(speaker_attribution_pct AS varchar(10)) + '%' AS value
    FROM gold.v_conversation_quality
    UNION ALL
    SELECT
        'Avg Segments/TX' AS metric,
        CAST(avg_segments_per_tx AS varchar(10)) AS value
    FROM gold.v_conversation_quality;" -s "," -W -h -1

echo ""
echo "✅ Persona coverage gate validation completed successfully"
echo "🚀 Ready for production deployment"