#!/usr/bin/env bash
set -euo pipefail

# ========================================================================
# Scout Analytics - SQL Mock Router for Dry-Run Testing
# Script: sql_mock_router.sh
# Purpose: Simulate SQL responses when MOCK=1 for local testing
# ========================================================================

# Only activate in mock mode
if [[ "${MOCK:-}" != "1" ]]; then
    echo "Error: sql_mock_router.sh should only be called with MOCK=1"
    exit 1
fi

# Parse command line arguments
query=""
output_file=""
separator=","
while [[ $# -gt 0 ]]; do
    case "$1" in
        -Q) query="$2"; shift 2;;
        -o) output_file="$2"; shift 2;;
        -s) separator="$2"; shift 2;;
        -W|-h|-1) shift;;  # Ignore formatting flags
        *) shift;;
    esac
done

# Default output file if not specified
if [[ -z "$output_file" ]]; then
    output_file="out/mock_output.csv"
fi

# Create output directory
mkdir -p "$(dirname "$output_file")"

echo "🔬 MOCK MODE: Simulating SQL query response"
echo "Query pattern: ${query:0:80}..."
echo "Output file: $output_file"

# Generate mock responses based on query patterns
if [[ "$query" == *"gold.v_persona_coverage_summary"* ]]; then
    cat > "$output_file" <<EOF
total_tx,assigned_tx,coverage_pct,avg_confidence,unique_personas,high_confidence,med_confidence,low_confidence
12192,4200,34.45,0.78,8,3100,900,200
EOF
    echo "📊 Mock: Generated persona coverage summary (34.45% coverage)"

elif [[ "$query" == *"gold.v_persona_examples"* ]]; then
    cat > "$output_file" <<EOF
inferred_role,canonical_tx_id,confidence_score,rule_source,transcript_snippet,category,brand,daypart,hour_of_day,basket_size
Parent,tx_001,0.95,rule_1_prio_1,"gatas para sa bata bear brand isa",Milk,Bear Brand,Afternoon,14,3
Office Worker,tx_002,0.87,rule_2_prio_2,"kape kopiko dalawa nescafe isa",Beverages,Kopiko,Morning,8,2
Teen Gamer,tx_003,0.85,rule_7_prio_2,"pepsi malamig sprite dalawa",Soft Drinks,Pepsi,Evening,18,4
Health-Conscious,tx_004,0.82,rule_9_prio_3,"safeguard sabon tide isa",Personal Care,Safeguard,Morning,9,2
Blue-Collar Worker,tx_005,0.89,rule_5_prio_2,"lucky me canton tatlo marlboro isa",Instant Noodles,Lucky Me,Evening,19,4
EOF
    echo "👥 Mock: Generated persona examples (5 high-confidence samples)"

elif [[ "$query" == *"gold.v_persona_role_distribution"* ]]; then
    cat > "$output_file" <<EOF
inferred_role,transaction_count,percentage,avg_confidence,min_confidence,max_confidence,unique_rules_used
Health-Conscious,1450,34.52,0.76,0.75,0.82,3
Teen Gamer,980,23.33,0.86,0.85,0.89,2
Office Worker,720,17.14,0.85,0.82,0.89,4
Blue-Collar Worker,510,12.14,0.87,0.85,0.91,2
Parent,340,8.10,0.94,0.90,0.96,2
Smoker,200,4.76,0.78,0.75,0.83,2
Unassigned,7992,65.55,0.00,0.00,0.00,0
EOF
    echo "📈 Mock: Generated persona role distribution"

elif [[ "$query" == *"gold.v_conversation_quality"* ]]; then
    cat > "$output_file" <<EOF
total_transactions,with_transcripts,with_segments,avg_segments_per_tx,customer_segments,owner_segments,unattributed_segments,speaker_attribution_pct,signal_facts_generated
12192,9942,8756,3.2,15420,12340,2890,91.2,36864
EOF
    echo "🎤 Mock: Generated conversation quality metrics (91.2% speaker attribution)"

elif [[ "$query" == *"gold.v_persona_signals"* ]]; then
    cat > "$output_file" <<EOF
signal_type,signal_value,occurrence_count,percentage_within_type,personas_using_signal,avg_weight
hour,morning,3456,28.35,6,1.00
hour,afternoon,4123,33.82,7,1.00
hour,evening,3211,26.34,8,1.00
hour,night,1402,11.50,4,1.00
nielsen_group,Beverages,2890,34.78,5,1.00
nielsen_group,Personal Care,1654,19.90,3,1.00
nielsen_group,Instant Noodles,1234,14.85,4,1.00
nielsen_group,Tobacco Products,987,11.88,2,1.00
nielsen_group,Mixed,1546,18.60,6,1.00
basket_size,small,6789,55.67,8,1.00
basket_size,medium,4321,35.43,7,1.00
basket_size,bulk,1082,8.87,3,1.00
EOF
    echo "📊 Mock: Generated persona signal distribution"

elif [[ "$query" == *"gold.v_unassigned_analysis"* ]]; then
    cat > "$output_file" <<EOF
canonical_tx_id,transcript_snippet,category,brand,daypart,hour_of_day,basket_size,hour_bucket,nielsen_group,basket_category
tx_unassigned_001,"yung ano po yung malaking size","Beverages","Coca-Cola","Afternoon","14","2","afternoon","Beverages","small"
tx_unassigned_002,"pabili ng tatlong piraso","Snacks","Pringles","Evening","17","3","evening","Snacks","small"
tx_unassigned_003,"meron bang stock niyan","Personal Care","Colgate","Morning","10","1","morning","Personal Care","small"
tx_unassigned_004,"magkano yung bundle","Mixed","Various","Night","21","5","night","Mixed","medium"
tx_unassigned_005,"pwede bang credit","Tobacco Products","Marlboro","Evening","18","2","evening","Tobacco Products","small"
EOF
    echo "🔍 Mock: Generated unassigned transaction samples for improvement"

elif [[ "$query" == *"EXEC etl.sp_parse_transcripts_basic"* ]]; then
    cat > "$output_file" <<EOF
status,message
success,"Parsed 9942 transcripts into 28456 conversation segments with 91% speaker attribution"
EOF
    echo "🎤 Mock: Simulated transcript parsing execution"

elif [[ "$query" == *"EXEC etl.sp_update_persona_roles_v21"* ]]; then
    cat > "$output_file" <<EOF
status,coverage_pct,assigned_tx,total_tx
success,34.45,4200,12192
EOF
    echo "🧠 Mock: Simulated enhanced persona inference execution (34.45% coverage)"

elif [[ "$query" == *"SELECT TOP 1 name FROM sys.databases"* ]]; then
    cat > "$output_file" <<EOF
name
SQL-TBWA-ProjectScout-Reporting-Prod
EOF
    echo "✅ Mock: Simulated database connectivity check"

else
    # Generic success response
    cat > "$output_file" <<EOF
status,message
success,"Mock SQL execution completed"
EOF
    echo "✨ Mock: Generated generic success response"
fi

echo "📁 Mock response written to: $output_file"
echo "🔬 MOCK MODE: Local testing completed successfully"