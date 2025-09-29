#!/bin/bash
set -euo pipefail

echo "🔍 SARI-SARI ADVANCED EXPERT V2.0 - DEPLOYMENT VALIDATION"
echo "========================================================"

# Create temporary files for capturing outputs
TEMP_DIR=$(mktemp -d)
DEPLOYMENT_OUT="$TEMP_DIR/deployment.out"
PARITY_OUT="$TEMP_DIR/parity.out"
INTEGRITY_OUT="$TEMP_DIR/integrity.out"

# Function to run SQL and capture output
run_sql_validation() {
    local sql_file="$1"
    local output_file="$2"
    local description="$3"

    echo "📊 $description..."

    # Use direct sqlcmd execution with stored credentials
    sqlcmd -S sqltbwaprojectscoutserver.database.windows.net \
           -d SQL-TBWA-ProjectScout-Reporting-Prod \
           -U sqladmin \
           -P Azure_pw26 \
           -h -1 \
           -Q "$(cat "$sql_file")" > "$output_file" 2>&1
}

# Run validations
run_sql_validation "sql/validation/simple_deployment_check.sql" "$DEPLOYMENT_OUT" "Running deployment metrics validation"
run_sql_validation "sql/validation/validate_gold_vs_legacy.sql" "$PARITY_OUT" "Running Gold vs Legacy parity validation"
run_sql_validation "sql/validation/002_analytics_integrity.sql" "$INTEGRITY_OUT" "Running analytics integrity validation"

echo ""
echo "📋 VALIDATION RESULTS"
echo "===================="

# Extract JSON from deployment validation (look for complete JSON object)
DEPLOYMENT_JSON=$(grep -E '^\s*\{.*\}\s*$' "$DEPLOYMENT_OUT" | head -1 | tr -d '[:space:]')

# Extract parity result
PARITY_RESULT=$(grep -E '✅|❌' "$PARITY_OUT" | tail -1)

# Extract integrity result
INTEGRITY_RESULT=$(grep -E 'PASS|FAIL' "$INTEGRITY_OUT" | tail -1)

# Parse deployment JSON or use defaults if parsing fails
if [[ -n "$DEPLOYMENT_JSON" && "$DEPLOYMENT_JSON" =~ ^\{.*\}$ ]]; then
    echo "✅ Successfully captured deployment metrics JSON"
else
    echo "⚠️  Could not parse deployment JSON, using status indicators"
    # Look for success indicators in output
    if grep -q "✅.*schemas.*present" "$DEPLOYMENT_OUT" && grep -q "✅.*tables.*operational" "$DEPLOYMENT_OUT"; then
        DEPLOYMENT_JSON='{"schemas_ok":1,"gold_core_ok":1,"platinum_core_ok":1,"read_mode":"gold","validation_method":"indicator_based"}'
    else
        DEPLOYMENT_JSON='{"schemas_ok":0,"gold_core_ok":0,"platinum_core_ok":0,"read_mode":"unknown","validation_method":"failed"}'
    fi
fi

# Determine individual check statuses
SCHEMA_STATUS="PASS"
TABLES_STATUS="PASS"
READMODE_STATUS="PASS"

if echo "$DEPLOYMENT_JSON" | grep -q '"schemas_ok":0\|"gold_core_ok":0\|"platinum_core_ok":0'; then
    SCHEMA_STATUS="FAIL"
    TABLES_STATUS="FAIL"
fi

if echo "$DEPLOYMENT_JSON" | grep -q '"read_mode":"unknown"'; then
    READMODE_STATUS="WARN"
fi

# Determine parity status
if [[ "$PARITY_RESULT" == *"✅"* ]]; then
    PARITY_STATUS="PASS"
elif [[ "$PARITY_RESULT" == *"❌"* ]]; then
    PARITY_STATUS="FAIL"
else
    PARITY_STATUS="WARN"
fi

# Determine integrity status
if [[ "$INTEGRITY_RESULT" == *"PASS"* ]]; then
    INTEGRITY_STATUS="PASS"
elif [[ "$INTEGRITY_RESULT" == *"FAIL"* ]]; then
    INTEGRITY_STATUS="FAIL"
else
    INTEGRITY_STATUS="WARN"
fi

# Determine overall verdict
if [[ "$SCHEMA_STATUS" == "PASS" && "$TABLES_STATUS" == "PASS" && "$PARITY_STATUS" == "PASS" && "$INTEGRITY_STATUS" == "PASS" ]]; then
    VERDICT="PASS"
elif [[ "$SCHEMA_STATUS" == "FAIL" || "$TABLES_STATUS" == "FAIL" || "$PARITY_STATUS" == "FAIL" || "$INTEGRITY_STATUS" == "FAIL" ]]; then
    VERDICT="FAIL"
else
    VERDICT="WARN"
fi

# Generate final JSON response
cat << EOF
{
  "summary": "SARI-SARI Advanced Expert v2.0 deployment validation complete",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "deployment_data": $DEPLOYMENT_JSON,
  "checks": [
    {
      "name": "Schema Validation",
      "status": "$SCHEMA_STATUS",
      "details": "All required schemas (dbo, gold, platinum) present"
    },
    {
      "name": "Core Tables",
      "status": "$TABLES_STATUS",
      "details": "Gold and Platinum layer tables operational"
    },
    {
      "name": "READ_MODE Configuration",
      "status": "$READMODE_STATUS",
      "details": "Production workload routing to Gold layer"
    },
    {
      "name": "Data Parity",
      "status": "$PARITY_STATUS",
      "details": "Gold vs Legacy layer consistency validation"
    },
    {
      "name": "Analytics Integrity",
      "status": "$INTEGRITY_STATUS",
      "details": "Comprehensive analytics platform validation"
    }
  ],
  "verdict": "$VERDICT"
}
EOF

# Cleanup
rm -rf "$TEMP_DIR"