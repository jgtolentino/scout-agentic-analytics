#!/bin/bash

# Scout Power BI PBIP Validation Script (Mac/Linux)
# Validates PBIP/TMDL structure and syntax

set -e

PROJECT_PATH="${1:-.}"
VERBOSE="${2:-false}"

echo "🔍 Scout Power BI Validation Script"
echo "==================================="

ERROR_COUNT=0
WARNING_COUNT=0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

function log_result() {
    local message="$1"
    local type="${2:-info}"
    local details="$3"

    case $type in
        "error")
            echo -e "${RED}❌ $message${NC}"
            if [[ -n "$details" ]]; then
                echo -e "   ${RED}$details${NC}"
            fi
            ((ERROR_COUNT++))
            ;;
        "warning")
            echo -e "${YELLOW}⚠️  $message${NC}"
            if [[ -n "$details" ]]; then
                echo -e "   ${YELLOW}$details${NC}"
            fi
            ((WARNING_COUNT++))
            ;;
        "success")
            echo -e "${GREEN}✅ $message${NC}"
            if [[ "$VERBOSE" == "true" && -n "$details" ]]; then
                echo -e "   ${GREEN}$details${NC}"
            fi
            ;;
        *)
            echo -e "${BLUE}ℹ️  $message${NC}"
            if [[ -n "$details" ]]; then
                echo -e "   ${BLUE}$details${NC}"
            fi
            ;;
    esac
}

# 1. Validate Directory Structure
echo -e "\n${CYAN}1. Validating Directory Structure...${NC}"

required_dirs=(
    "pbip-model-core"
    "pbip-model-core/.pbip"
    "pbip-model-core/model"
    "pbip-model-core/model/tables"
    "executive-dashboard"
    "sales-analysis"
    "store-performance"
    "category-insights"
    "predictive-analytics"
)

for dir in "${required_dirs[@]}"; do
    if [[ -d "$PROJECT_PATH/$dir" ]]; then
        log_result "Directory exists: $dir" "success"
    else
        log_result "Missing directory: $dir" "error"
    fi
done

# 2. Validate Core Model Files
echo -e "\n${CYAN}2. Validating Core Model Files...${NC}"

core_files=(
    "pbip-model-core/.pbip/definition.pbir"
    "pbip-model-core/model/Model.tmdl"
    "pbip-model-core/model/datasources.tmdl"
    "pbip-model-core/model/relationships.tmdl"
    "pbip-model-core/model/measures.tmdl"
    "pbip-model-core/model/roles.tmdl"
    "pbip-model-core/model/refresh-policy.tmdl"
)

for file in "${core_files[@]}"; do
    if [[ -f "$PROJECT_PATH/$file" ]]; then
        log_result "Core file exists: $file" "success"

        # Basic syntax validation
        if [[ "$file" == *.pbir ]]; then
            if jq empty "$PROJECT_PATH/$file" 2>/dev/null; then
                log_result "Valid JSON syntax: $file" "success"
            else
                log_result "Invalid JSON syntax: $file" "error"
            fi
        elif [[ "$file" == *.tmdl ]]; then
            if grep -q -E "(table |model |dataSource |relationship |measure |role |refreshPolicy )" "$PROJECT_PATH/$file"; then
                log_result "Valid TMDL syntax: $file" "success"
            else
                log_result "Invalid TMDL syntax: $file" "warning" "Missing expected TMDL keywords"
            fi
        fi
    else
        log_result "Missing core file: $file" "error"
    fi
done

# 3. Validate Table Definitions
echo -e "\n${CYAN}3. Validating Table Definitions...${NC}"

table_files=(
    "pbip-model-core/model/tables/dim_date.tmdl"
    "pbip-model-core/model/tables/dim_store.tmdl"
    "pbip-model-core/model/tables/dim_brand.tmdl"
    "pbip-model-core/model/tables/dim_category.tmdl"
    "pbip-model-core/model/tables/mart_tx.tmdl"
    "pbip-model-core/model/tables/platinum_predictions.tmdl"
)

for file in "${table_files[@]}"; do
    if [[ -f "$PROJECT_PATH/$file" ]]; then
        table_name=$(basename "$file" .tmdl)

        if grep -q "table \"$table_name\"" "$PROJECT_PATH/$file"; then
            log_result "Valid table definition: $table_name" "success"
        else
            log_result "Table name mismatch: $table_name" "warning" "Table definition doesn't match filename"
        fi

        if grep -q "partition " "$PROJECT_PATH/$file" && grep -q "column " "$PROJECT_PATH/$file"; then
            log_result "Complete table structure: $table_name" "success"
        else
            log_result "Incomplete table structure: $table_name" "warning" "Missing partition or columns"
        fi
    else
        log_result "Missing table file: $file" "error"
    fi
done

# 4. Validate Report Templates
echo -e "\n${CYAN}4. Validating Report Templates...${NC}"

report_dirs=("executive-dashboard" "sales-analysis" "store-performance" "category-insights" "predictive-analytics")

for report_dir in "${report_dirs[@]}"; do
    definition_path="$PROJECT_PATH/$report_dir/.pbip/definition.pbir"

    if [[ -f "$definition_path" ]]; then
        if jq -e '.artifactKind == "report"' "$definition_path" >/dev/null 2>&1; then
            log_result "Valid report definition: $report_dir" "success"
        else
            log_result "Invalid artifact kind: $report_dir" "error" "Expected 'report'"
        fi

        if jq -e '.datasetReference.byPath == "../pbip-model-core"' "$definition_path" >/dev/null 2>&1; then
            log_result "Correct dataset reference: $report_dir" "success"
        else
            log_result "Invalid dataset reference: $report_dir" "error" "Should reference ../pbip-model-core"
        fi
    else
        log_result "Missing report definition: $report_dir" "error"
    fi
done

# 5. Validate Theme
echo -e "\n${CYAN}5. Validating Theme...${NC}"

theme_path="$PROJECT_PATH/scout-theme.json"
if [[ -f "$theme_path" ]]; then
    if jq -e '.name and .colors and .palette' "$theme_path" >/dev/null 2>&1; then
        log_result "Valid theme structure" "success"
    else
        log_result "Incomplete theme structure" "warning" "Missing required sections"
    fi

    if jq -e '.formatting.currency.symbol == "₱"' "$theme_path" >/dev/null 2>&1; then
        log_result "Correct currency symbol (₱)" "success"
    else
        log_result "Incorrect currency symbol" "warning" "Should use ₱ for Philippines"
    fi
else
    log_result "Missing theme file" "error"
fi

# 6. Validate DAX Measures
echo -e "\n${CYAN}6. Validating DAX Measures...${NC}"

measures_path="$PROJECT_PATH/pbip-model-core/model/measures.tmdl"
if [[ -f "$measures_path" ]]; then
    measure_count=$(grep -c "^measure " "$measures_path" 2>/dev/null || echo "0")

    if [[ $measure_count -ge 60 ]]; then
        log_result "Sufficient DAX measures: $measure_count" "success"
    else
        log_result "Insufficient DAX measures: $measure_count" "warning" "Target is 60+ measures"
    fi

    # Check for key measures
    key_measures=("Total Sales" "Gross Margin %" "Sales YoY Growth" "Prediction Accuracy")
    for measure in "${key_measures[@]}"; do
        if grep -q "measure \"$measure\"" "$measures_path"; then
            log_result "Key measure exists: $measure" "success"
        else
            log_result "Missing key measure: $measure" "warning"
        fi
    done
else
    log_result "Missing measures file" "error"
fi

# 7. Validate RLS Roles
echo -e "\n${CYAN}7. Validating RLS Roles...${NC}"

roles_path="$PROJECT_PATH/pbip-model-core/model/roles.tmdl"
if [[ -f "$roles_path" ]]; then
    role_count=$(grep -c "^role " "$roles_path" 2>/dev/null || echo "0")

    if [[ $role_count -ge 5 ]]; then
        log_result "Sufficient RLS roles: $role_count" "success"
    else
        log_result "Insufficient RLS roles: $role_count" "warning" "Recommend 5+ roles"
    fi

    # Check for regional roles
    regional_roles=("Regional Manager - NCR" "Store Manager" "Category Manager")
    for role in "${regional_roles[@]}"; do
        if grep -q "role \"$role\"" "$roles_path"; then
            log_result "Regional role exists: $role" "success"
        else
            log_result "Missing regional role: $role" "warning"
        fi
    done
else
    log_result "Missing roles file" "error"
fi

# Summary
echo -e "\n${GREEN}==================================================${NC}"
echo -e "${GREEN}VALIDATION SUMMARY${NC}"
echo -e "${GREEN}==================================================${NC}"

if [[ $ERROR_COUNT -eq 0 && $WARNING_COUNT -eq 0 ]]; then
    echo -e "${GREEN}🎉 All validations passed!${NC}"
elif [[ $ERROR_COUNT -eq 0 ]]; then
    echo -e "${YELLOW}✅ No errors found, but $WARNING_COUNT warning(s) to review${NC}"
else
    echo -e "${RED}❌ Found $ERROR_COUNT error(s) and $WARNING_COUNT warning(s)${NC}"
fi

echo -e "Errors: ${ERROR_COUNT}"
echo -e "Warnings: ${WARNING_COUNT}"

# Exit with appropriate code
if [[ $ERROR_COUNT -gt 0 ]]; then
    exit 1
else
    exit 0
fi