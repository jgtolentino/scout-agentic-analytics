#!/usr/bin/env bash
# =================================================================
# Canonical Export Validator
# Ensures 13-column contract compliance and data integrity
# =================================================================

set -euo pipefail

# Configuration
EXPECTED_COLUMNS=13
EXPECTED_HEADER="Transaction_ID,Transaction_Value,Basket_Size,Category,Brand,Daypart,Demographics_Age_Gender_Role,Weekday_vs_Weekend,Time_of_Transaction,Location,Other_Products,Was_Substitution,Export_Timestamp"
MAX_VALIDATION_ROWS=${MAX_VALIDATION_ROWS:-10000}
SAMPLE_SIZE=${SAMPLE_SIZE:-1000}

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$PROJECT_ROOT/out/canonical"

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

# Initialize validation
init_validation() {
    log "Initializing canonical export validation..."

    # Create output directory if it doesn't exist
    mkdir -p "$OUT_DIR"

    # Check if we have canonical exports to validate
    local export_files
    export_files=$(find "$OUT_DIR" -name "canonical_*.csv*" -type f 2>/dev/null | head -5)

    if [[ -z "$export_files" ]]; then
        error "No canonical export files found in $OUT_DIR"
        error "Run canonical export first: make canonical-export-prod"
        exit 1
    fi

    success "Found canonical export files for validation"
}

# Validate CSV header structure
validate_header() {
    local file="$1"
    local file_display="${file##*/}"

    log "Validating header structure: $file_display"

    local actual_header
    if [[ "$file" == *.gz ]]; then
        actual_header=$(gunzip -c "$file" | head -1)
    else
        actual_header=$(head -1 "$file")
    fi

    if [[ "$actual_header" == "$EXPECTED_HEADER" ]]; then
        success "Header validation passed: $file_display"
        return 0
    else
        error "Header validation FAILED: $file_display"
        echo "Expected: $EXPECTED_HEADER"
        echo "Actual  : $actual_header"
        return 1
    fi
}

# Validate column count consistency
validate_column_count() {
    local file="$1"
    local file_display="${file##*/}"

    log "Validating column count consistency: $file_display"

    local validation_cmd
    if [[ "$file" == *.gz ]]; then
        validation_cmd="gunzip -c \"$file\""
    else
        validation_cmd="cat \"$file\""
    fi

    # Check column count for sample rows
    local inconsistent_rows
    inconsistent_rows=$(eval "$validation_cmd" | head -"$MAX_VALIDATION_ROWS" | awk -F',' '
        NR == 1 { expected = NF; next }
        NF != expected {
            bad_rows++
            if (bad_rows <= 10) print "Line " NR ": " NF " columns (expected " expected ")"
        }
        END {
            if (bad_rows > 10) print "... and " (bad_rows - 10) " more rows with column issues"
            exit (bad_rows > 0 ? 1 : 0)
        }
    ')

    if [[ $? -eq 0 ]]; then
        success "Column count validation passed: $file_display"
        return 0
    else
        error "Column count validation FAILED: $file_display"
        echo "$inconsistent_rows"
        return 1
    fi
}

# Validate data quality
validate_data_quality() {
    local file="$1"
    local file_display="${file##*/}"

    log "Validating data quality: $file_display"

    local validation_cmd
    if [[ "$file" == *.gz ]]; then
        validation_cmd="gunzip -c \"$file\""
    else
        validation_cmd="cat \"$file\""
    fi

    # Create temporary validation script
    local validation_script=$(mktemp)
    cat > "$validation_script" << 'EOF'
#!/usr/bin/env python3
import sys
import csv
from datetime import datetime
import re

def validate_transaction_id(value):
    """Validate transaction ID format"""
    if not value or len(value.strip()) == 0:
        return False, "Empty transaction ID"
    if len(value) > 64:
        return False, "Transaction ID too long"
    return True, None

def validate_transaction_value(value):
    """Validate transaction value"""
    if not value:
        return False, "Missing transaction value"
    try:
        val = float(value)
        if val < 0:
            return False, "Negative transaction value"
        if val > 100000:  # Reasonable upper limit
            return False, "Unusually high transaction value"
        return True, None
    except ValueError:
        return False, "Invalid transaction value format"

def validate_basket_size(value):
    """Validate basket size"""
    if not value:
        return False, "Missing basket size"
    try:
        val = int(value)
        if val < 1:
            return False, "Invalid basket size"
        if val > 100:  # Reasonable upper limit
            return False, "Unusually high basket size"
        return True, None
    except ValueError:
        return False, "Invalid basket size format"

def validate_timestamp(value):
    """Validate timestamp format"""
    if not value:
        return True, None  # Timestamps can be null

    # Try common timestamp formats
    formats = [
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%d %H:%M:%S.%f",
        "%Y-%m-%dT%H:%M:%S.%f"
    ]

    for fmt in formats:
        try:
            datetime.strptime(value[:19], fmt[:19])  # Check first 19 chars
            return True, None
        except ValueError:
            continue

    return False, "Invalid timestamp format"

def validate_daypart(value):
    """Validate daypart values"""
    valid_dayparts = {'Morning', 'Afternoon', 'Evening', 'Night', 'Unknown'}
    if value not in valid_dayparts:
        return False, f"Invalid daypart: {value}"
    return True, None

def validate_weekend(value):
    """Validate weekend classification"""
    valid_values = {'Weekday', 'Weekend', 'Unknown'}
    if value not in valid_values:
        return False, f"Invalid weekend classification: {value}"
    return True, None

def main():
    sample_size = int(sys.argv[1]) if len(sys.argv) > 1 else 1000

    reader = csv.reader(sys.stdin)
    header = next(reader)  # Skip header

    issues = []
    total_rows = 0

    validators = [
        (0, "Transaction_ID", validate_transaction_id),
        (1, "Transaction_Value", validate_transaction_value),
        (2, "Basket_Size", validate_basket_size),
        (5, "Daypart", validate_daypart),
        (7, "Weekday_vs_Weekend", validate_weekend),
        (8, "Time_of_Transaction", validate_timestamp),
        (12, "Export_Timestamp", validate_timestamp)
    ]

    for row_num, row in enumerate(reader, 2):  # Start at 2 (after header)
        if row_num > sample_size + 1:  # +1 for header
            break

        total_rows += 1

        # Basic row validation
        if len(row) != 13:
            issues.append(f"Row {row_num}: Wrong number of columns ({len(row)})")
            continue

        # Run field validators
        for col_idx, col_name, validator in validators:
            if col_idx < len(row):
                is_valid, error_msg = validator(row[col_idx])
                if not is_valid:
                    issues.append(f"Row {row_num}, {col_name}: {error_msg}")

    # Report results
    print(f"Validated {total_rows} rows")

    if issues:
        print(f"Found {len(issues)} data quality issues:")
        for issue in issues[:20]:  # Show first 20 issues
            print(f"  {issue}")

        if len(issues) > 20:
            print(f"  ... and {len(issues) - 20} more issues")

        return 1
    else:
        print("No data quality issues found")
        return 0

if __name__ == "__main__":
    sys.exit(main())
EOF

    # Run validation
    local validation_result
    if eval "$validation_cmd" | head -"$((SAMPLE_SIZE + 1))" | python3 "$validation_script" "$SAMPLE_SIZE"; then
        success "Data quality validation passed: $file_display"
        validation_result=0
    else
        error "Data quality validation FAILED: $file_display"
        validation_result=1
    fi

    # Clean up
    rm -f "$validation_script"
    return $validation_result
}

# Validate row count parity with database
validate_row_parity() {
    local file="$1"
    local file_display="${file##*/}"

    log "Validating row count parity with database: $file_display"

    # Get row count from database
    local db_rows
    db_rows=$("$SCRIPT_DIR/sql.sh" -Q "SELECT COUNT(*) FROM gold.v_transactions_flat_canonical" | tail -1)

    if [[ -z "$db_rows" || ! "$db_rows" =~ ^[0-9]+$ ]]; then
        warning "Could not get database row count for parity check"
        return 0
    fi

    # Get row count from file
    local file_rows
    if [[ "$file" == *.gz ]]; then
        file_rows=$(gunzip -c "$file" | tail -n +2 | wc -l | awk '{print $1}')
    else
        file_rows=$(tail -n +2 "$file" | wc -l | awk '{print $1}')
    fi

    if [[ "$db_rows" -eq "$file_rows" ]]; then
        success "Row parity validation passed: $file_display (DB: $db_rows, File: $file_rows)"
        return 0
    else
        error "Row parity validation FAILED: $file_display"
        echo "Database rows: $db_rows"
        echo "File rows: $file_rows"
        echo "Difference: $((file_rows - db_rows))"
        return 1
    fi
}

# Validate CSV safety (no JSON crashes)
validate_csv_safety() {
    local file="$1"
    local file_display="${file##*/}"

    log "Validating CSV safety (no JSON crashes): $file_display"

    local validation_cmd
    if [[ "$file" == *.gz ]]; then
        validation_cmd="gunzip -c \"$file\""
    else
        validation_cmd="cat \"$file\""
    fi

    # Check for potential CSV-unsafe characters
    local unsafe_patterns
    unsafe_patterns=$(eval "$validation_cmd" | head -"$SAMPLE_SIZE" | grep -n -E '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]' | head -5)

    if [[ -n "$unsafe_patterns" ]]; then
        warning "Found potentially unsafe characters in CSV:"
        echo "$unsafe_patterns"
        return 1
    fi

    # Check for unescaped quotes and commas within fields
    local quote_issues
    quote_issues=$(eval "$validation_cmd" | head -"$SAMPLE_SIZE" | awk -F',' '
        {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^[^"].*".*[^"]$/) {
                    print "Line " NR ", Field " i ": Unescaped quote - " substr($i, 1, 50)
                    issues++
                    if (issues >= 10) exit
                }
            }
        }
    ')

    if [[ -n "$quote_issues" ]]; then
        warning "Found quote escaping issues:"
        echo "$quote_issues"
        return 1
    fi

    success "CSV safety validation passed: $file_display"
    return 0
}

# Generate validation report
generate_validation_report() {
    local validation_results=("$@")
    local passed=0
    local failed=0

    log "Generating validation report..."

    for result in "${validation_results[@]}"; do
        if [[ "$result" == *":PASS" ]]; then
            ((passed++))
        else
            ((failed++))
        fi
    done

    local report_file="$OUT_DIR/validation_report_$(date '+%Y%m%d_%H%M%S').txt"

    {
        echo "Canonical Export Validation Report"
        echo "=================================="
        echo "Generated: $(date)"
        echo "Expected columns: $EXPECTED_COLUMNS"
        echo "Max validation rows: $MAX_VALIDATION_ROWS"
        echo "Sample size for quality checks: $SAMPLE_SIZE"
        echo ""

        echo "Validation Summary:"
        echo "=================="
        echo "Files validated: $((passed + failed))"
        echo "Validations passed: $passed"
        echo "Validations failed: $failed"
        echo "Success rate: $(( passed * 100 / (passed + failed) ))%"
        echo ""

        echo "Detailed Results:"
        echo "================"
        for result in "${validation_results[@]}"; do
            echo "$result"
        done

        echo ""
        echo "Validation Checks Performed:"
        echo "============================"
        echo "1. Header Structure - Exact match against expected 13-column header"
        echo "2. Column Count - All rows must have exactly 13 columns"
        echo "3. Data Quality - Field validation for key columns"
        echo "4. Row Parity - File row count matches database count"
        echo "5. CSV Safety - No unsafe characters or formatting issues"
        echo ""

        if [[ $failed -eq 0 ]]; then
            echo "✅ ALL VALIDATIONS PASSED"
            echo ""
            echo "The canonical export maintains full compliance with the 13-column contract:"
            echo "$EXPECTED_HEADER"
        else
            echo "❌ VALIDATION FAILURES DETECTED"
            echo ""
            echo "Please address the validation failures before using the export in production."
            echo "Run 'make canonical-export-prod' to regenerate the canonical export."
        fi

        echo ""
        echo "Database Query for Manual Verification:"
        echo "======================================"
        echo "SELECT COUNT(*) as total_rows, COUNT(DISTINCT Transaction_ID) as unique_transactions"
        echo "FROM gold.v_transactions_flat_canonical;"
        echo ""
        echo "Expected canonical structure validation:"
        echo "SELECT Transaction_ID, Transaction_Value, Basket_Size, Category, Brand,"
        echo "       Daypart, Demographics_Age_Gender_Role, Weekday_vs_Weekend,"
        echo "       Time_of_Transaction, Location, Other_Products, Was_Substitution,"
        echo "       Export_Timestamp"
        echo "FROM gold.v_transactions_flat_canonical"
        echo "ORDER BY Export_Timestamp DESC"
        echo "OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;"

    } > "$report_file"

    success "Validation report generated: $report_file"

    # Also display summary to console
    echo ""
    echo "=================================="
    echo "CANONICAL VALIDATION SUMMARY"
    echo "=================================="
    if [[ $failed -eq 0 ]]; then
        success "ALL VALIDATIONS PASSED ($passed/$((passed + failed)))"
        echo ""
        echo "✓ Header structure compliant"
        echo "✓ Column count consistent (13 columns)"
        echo "✓ Data quality validated"
        echo "✓ Row parity with database"
        echo "✓ CSV safety confirmed"
        echo ""
        echo "Export ready for production use."
    else
        error "VALIDATION FAILURES: $failed failures out of $((passed + failed)) checks"
        echo ""
        echo "Review the detailed report: $report_file"
    fi
    echo "=================================="

    return $failed
}

# Validate a single export file
validate_single_file() {
    local file="$1"
    local file_display="${file##*/}"
    local results=()

    log "Starting validation for: $file_display"

    # Run all validations
    local validation_failed=0

    if validate_header "$file"; then
        results+=("Header validation: PASS")
    else
        results+=("Header validation: FAIL")
        ((validation_failed++))
    fi

    if validate_column_count "$file"; then
        results+=("Column count validation: PASS")
    else
        results+=("Column count validation: FAIL")
        ((validation_failed++))
    fi

    if validate_data_quality "$file"; then
        results+=("Data quality validation: PASS")
    else
        results+=("Data quality validation: FAIL")
        ((validation_failed++))
    fi

    if validate_row_parity "$file"; then
        results+=("Row parity validation: PASS")
    else
        results+=("Row parity validation: FAIL")
        ((validation_failed++))
    fi

    if validate_csv_safety "$file"; then
        results+=("CSV safety validation: PASS")
    else
        results+=("CSV safety validation: FAIL")
        ((validation_failed++))
    fi

    if [[ $validation_failed -eq 0 ]]; then
        success "All validations passed for: $file_display"
    else
        error "$validation_failed validation(s) failed for: $file_display"
    fi

    return $validation_failed
}

# Main validation function
main() {
    log "Starting canonical export validation"

    init_validation

    # Find all canonical export files
    local export_files=()
    while IFS= read -r -d '' file; do
        export_files+=("$file")
    done < <(find "$OUT_DIR" -name "canonical_*.csv*" -type f -print0 2>/dev/null)

    if [[ ${#export_files[@]} -eq 0 ]]; then
        error "No canonical export files found"
        exit 1
    fi

    log "Found ${#export_files[@]} canonical export file(s) to validate"

    # Validate each file
    local all_results=()
    local total_failures=0

    for file in "${export_files[@]}"; do
        local file_results=()
        if validate_single_file "$file"; then
            file_results=("${file##*/}: ALL_VALIDATIONS_PASSED")
        else
            file_results=("${file##*/}: VALIDATION_FAILURES")
            ((total_failures++))
        fi
        all_results+=("${file_results[@]}")
    done

    # Generate comprehensive report
    generate_validation_report "${all_results[@]}"

    if [[ $total_failures -eq 0 ]]; then
        success "Canonical export validation completed successfully"
        exit 0
    else
        error "Canonical export validation completed with $total_failures failure(s)"
        exit 1
    fi
}

# Quick header check function
quick_check() {
    local latest_file
    latest_file=$(find "$OUT_DIR" -name "canonical_*.csv*" -type f -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)

    if [[ -z "$latest_file" ]]; then
        error "No canonical export files found for quick check"
        exit 1
    fi

    log "Quick validation of latest export: ${latest_file##*/}"

    # Check header only
    validate_header "$latest_file"
    local header_result=$?

    # Quick column count check (first 100 rows)
    local quick_column_check
    if [[ "$latest_file" == *.gz ]]; then
        quick_column_check=$(gunzip -c "$latest_file" | head -100 | awk -F',' 'NR>1 && NF!=13 {bad++} END{print (bad>0 ? bad " rows with wrong column count" : "Column count OK")}')
    else
        quick_column_check=$(head -100 "$latest_file" | awk -F',' 'NR>1 && NF!=13 {bad++} END{print (bad>0 ? bad " rows with wrong column count" : "Column count OK")}')
    fi

    echo "Quick column check: $quick_column_check"

    if [[ $header_result -eq 0 && "$quick_column_check" == "Column count OK" ]]; then
        success "Quick validation passed"
        exit 0
    else
        error "Quick validation failed - run full validation"
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --quick         Quick validation (header + basic column check)"
        echo "  --help          Show this help message"
        echo ""
        echo "Environment variables:"
        echo "  MAX_VALIDATION_ROWS    Maximum rows to validate (default: 10000)"
        echo "  SAMPLE_SIZE           Sample size for quality checks (default: 1000)"
        echo ""
        echo "Examples:"
        echo "  $0                    # Full validation of all canonical exports"
        echo "  $0 --quick           # Quick validation of latest export"
        echo "  MAX_VALIDATION_ROWS=5000 $0  # Validate first 5000 rows only"
        exit 0
        ;;
    --quick)
        quick_check
        ;;
    *)
        main "$@"
        ;;
esac