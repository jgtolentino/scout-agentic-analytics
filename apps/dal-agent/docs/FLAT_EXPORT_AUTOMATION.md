# Flat Export Automation Guide

## ✅ Complete 45-Column Export System

Successfully implemented complete flat CSV export with all 45 columns and 12,192 transactions.

### Quick Start

```bash
# Run complete export now (with cleaning and compression)
make flat-nightly

# Or step-by-step
make flat-materialize        # Refresh data
make flat-sqlcmd             # Export CSV
make flat-clean              # Clean and validate
make flat-clean-compressed   # Clean, validate, and compress
```

## 📊 Export Details

- **Files**:
  - `out/flat/flat_dataframe_complete_45col.csv` (raw export)
  - `out/flat/flat_dataframe_complete_45col.cleaned.csv` (validated & cleaned)
  - `out/flat/flat_dataframe_complete_45col.csv.gz` (raw compressed)
  - `out/flat/flat_dataframe_complete_45col.cleaned.csv.gz` (production-ready)
- **Rows**: 12,192 transactions (ALL PayloadTransactions, deduplicated)
- **Columns**: 45 comprehensive columns with full schema validation
- **Format**: CSV with proper escaping, data cleaning, and gzip compression

### Column Groups (45 total)

1. **Identity (3)**: canonical_tx_id, canonical_tx_id_norm, canonical_tx_id_payload
2. **Temporal (8)**: transaction_date, year, month, month_name, quarter, day_name, weekday_vs_weekend, iso_week
3. **Transaction Facts (4)**: amount, transaction_value, basket_size, was_substitution
4. **Location (3)**: store_id, product_id, barangay
5. **Demographics (5)**: age, gender, emotional_state, facial_id, role_id
6. **Persona (4)**: persona_id, persona_confidence, persona_alternative_roles, persona_rule_source
7. **Brand Analytics (7)**: primary_brand, secondary_brand, primary_brand_confidence, all_brands_mentioned, brand_switching_indicator, transcription_text, co_purchase_patterns
8. **Technical Metadata (8)**: device_id, session_id, interaction_id, data_source_type, payload_data_status, payload_json_truncated, transaction_date_original, created_date
9. **Derived Analytics (3)**: transaction_type, time_of_day_category, customer_segment

## 🔧 Technical Architecture

### Surrogate Key Solution
- **Problem**: PRIMARY KEY constraint on canonical_tx_id caused row loss (145 missing rows)
- **Solution**: Surrogate key (`export_row_id BIGINT IDENTITY(1,1)`) as PRIMARY KEY
- **Benefit**: Preserves ALL 12,192 PayloadTransactions without deduplication

### LEFT JOIN Strategy
- **Previous**: INNER JOINs lost rows without matching fact records
- **Current**: LEFT JOINs preserve all PayloadTransactions (12,192 rows)
- **Result**: Complete coverage with enhanced analytics for available records

### CSV-Safe Design
- **All VARCHAR columns**: Prevents type conversion errors
- **Wide column support**: sqlcmd flags `-w 32767 -y 8000 -Y 8000`
- **Proper escaping**: Handles JSON content and special characters

## 🔄 Automation Setup

### macOS/Linux Cron Job

```bash
# Edit crontab
crontab -e

# Add this line for nightly 2:05 AM export
5 2 * * * cd /Users/tbwa/scout-v7/apps/dal-agent && make flat-nightly >> out/flat/nightly.log 2>&1
```

### Windows Task Scheduler

```powershell
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-NoProfile -ExecutionPolicy Bypass -Command "cd C:\path\to\dal-agent; make flat-nightly"'
$Trigger = New-ScheduledTaskTrigger -Daily -At 2:05am
Register-ScheduledTask -TaskName "ScoutV7FlatExportNightly" -Action $Action -Trigger $Trigger -RunLevel Highest
```

## 🔧 Makefile Targets

| Target | Purpose | Dependencies |
|--------|---------|--------------|
| `flat-materialize` | Refresh source data | Database connection |
| `flat-sqlcmd` | Export via sqlcmd | flat-materialize |
| `flat-clean` | Clean and validate CSV | flat-sqlcmd |
| `flat-clean-compressed` | Clean, validate, and compress | flat-clean |
| `flat-sqlcmd-compressed` | Export and compress raw CSV | flat-sqlcmd |
| `flat-chunked` | Fallback chunked export | flat-materialize |
| `flat-nightly` | Complete nightly process (cleaned & compressed) | flat-materialize, flat-clean-compressed |

## 🧹 Data Cleaning & Validation

### Full 45-Column Schema Validation + Auto-Fixes

The enhanced cleaning pipeline validates all columns and applies intelligent auto-fixes:

**Validation Categories:**
- **Type Validation**: Numeric, integer, datetime, string types
- **Enumeration Checking**: Valid values for categorical fields
- **Business Rules**: Amount ≥ 0, confidence bounds [0,1], date ranges
- **Consistency Checks**: JSON status alignment, brand switching logic
- **Key Constraints**: Required canonical_tx_id fields
- **Deduplication**: Based on canonical_tx_id + session_id + interaction_id

**Auto-Fix Capabilities:**
- **Data Enrichment**: Fill transaction_value from amount when missing
- **Normalization**: Standardize gender (m/f → Male/Female), day names
- **Recomputation**: Derive year/month/quarter from transaction_date
- **Bounds Clamping**: Confidence values into [0,1] range
- **Logic Repair**: Brand switching indicators based on evidence
- **Quality Improvement**: Trim whitespace, enforce basket_size ≥ 1

### Validation Rules

```python
# Sample schema validation rules
"weekday_vs_weekend": {"enum": {"Weekday", "Weekend", "Unknown"}}
"gender": {"enum": {"Male", "Female", "Unknown"}}
"brand_switching_indicator": {"enum": {"Single-Brand", "Brand-Switch-Considered", "No-Analytics-Data"}}
"data_source_type": {"enum": {"Enhanced-Analytics", "Payload-Only"}}
"time_of_day_category": {"enum": {"Morning", "Afternoon", "Evening", "Night", "Unknown"}}
```

### Error Reporting & Statistics

- **Hard Errors**: Missing keys, type coercion failures, date parsing errors → rows dropped
- **Soft Errors**: Enum violations, business rule violations → logged but kept
- **Auto-Fixes**: Intelligent corrections with full audit trail → prefixed `autofix::`
- **Error Log**: `out/flat/flat_dataframe_complete_45col.errors.csv`
- **Statistics**: `out/flat/cleaning_stats.json`

**Example Statistics Output:**
```json
{
  "input_rows": 12192,
  "clean_rows": 12185,
  "dropped_rows": 7,
  "errors_logged": 245,
  "autofixes_applied": 189,
  "validation_errors": 56,
  "data_quality_score": 99.54
}
```

## 🛡️ Quality Assurance

### Sanity Checks

```bash
# Run validation
./scripts/sql.sh -i sql/validation/flat_export_sanity_checks.sql
```

### Expected Results

- **Row Count**: Exactly 12,192 unique transactions
- **Data Quality**: <1% null values in core fields
- **File Size**: ~2-3 MB uncompressed
- **Processing Time**: <5 minutes end-to-end

## 📈 File Compression

Compression is now built-in and used by default for nightly exports:

```bash
# Export with compression
make flat-sqlcmd-compressed

# Nightly exports are compressed by default
make flat-nightly
```

**Benefits**:
- ~70-80% size reduction (typical CSV compression ratio)
- Faster network transfers
- Reduced storage costs
- Maintains full data integrity

## 🔍 Troubleshooting

### Common Issues

1. **Row Count Mismatch**: Check for duplicates in source views
2. **JSON Parsing Error**: Use chunked export fallback
3. **Permission Issues**: Verify database connection credentials
4. **File Size Issues**: Check disk space in `out/flat/` directory

### Validation Commands

```bash
# Check row count (uncompressed)
wc -l out/flat/flat_dataframe_complete_45col.csv

# Check row count (compressed)
zcat out/flat/flat_dataframe_complete_45col.csv.gz | wc -l

# Check column count
head -1 out/flat/flat_dataframe_complete_45col.csv | awk -F',' '{print NF}'

# Check compressed file integrity
gzip -t out/flat/flat_dataframe_complete_45col.csv.gz

# Check for errors
grep -i "error\|msg" out/flat/nightly.log
```

## 📝 Monitoring

### Log Files

- **Nightly Exports**: `out/flat/nightly.log`
- **Manual Exports**: Console output
- **Database Logs**: Azure SQL Database query logs

### Success Indicators

- CSV file exists and has 12,193 lines (12,192 + header)
- Compressed file exists and passes integrity test (`gzip -t`)
- No SQL error messages in logs
- Fresh timestamp on output files
- Consistent column count (45)
- Compression ratio ~70-80% (typical for CSV data)

## 🏗️ Infrastructure Components

### Database Objects

```sql
-- Materialized table with surrogate key
CREATE TABLE dbo.FlatExport_CSVSafe (
    export_row_id BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    canonical_tx_id VARCHAR(64) NULL,
    -- ... 45 columns total, all VARCHAR
);

-- Population procedure with LEFT JOINs
CREATE OR ALTER PROCEDURE dbo.sp_populate_flat_export_full
-- Uses LEFT JOINs to preserve ALL PayloadTransactions
```

### File Structure

```
/Users/tbwa/scout-v7/apps/dal-agent/
├── sql/
│   ├── schema/materialized_flat_export_complete.sql
│   ├── procedures/populate_flat_export_complete.sql
│   └── validation/flat_export_sanity_checks.sql
├── scripts/
│   └── export_flat_chunked.sh
├── out/flat/
│   ├── flat_dataframe_complete_45col.csv
│   ├── flat_dataframe_complete_45col.cleaned.csv
│   ├── flat_dataframe_complete_45col.csv.gz
│   ├── flat_dataframe_complete_45col.cleaned.csv.gz
│   ├── flat_dataframe_complete_45col.errors.csv
│   ├── cleaning_stats.json
│   └── nightly.log
├── scripts/
│   └── clean_validate_scout45.py
└── Makefile (flat-* targets)
```

---

## 🎯 Summary

The complete 45-column flat export system is now operational and ready for automated nightly runs. All 12,192 transactions are exported with comprehensive analytics columns for downstream processing.

**Key Achievements**:
- Fixed the 145 missing rows issue by implementing surrogate key strategy and LEFT JOIN preservation
- Added comprehensive data cleaning and validation with full 45-column schema
- Integrated compression and error reporting for production-ready pipeline

Use `make flat-nightly` for complete exports with cleaning and compression, and set up cron/scheduler for automation.