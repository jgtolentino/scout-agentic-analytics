# Scout v7 Export Validator

Drop-in validator that scans export trees recursively, checks CSV(.gz) headers against locked schemas, verifies Parquet column order, flags missing CSV↔Parquet pairs, and confirms canonical 13-column file presence.

## Quick Start

```bash
# Basic scan (prints summary + writes 2 JSON files in export folder)
python3 scripts/validate_exports.py out/inquiries_filtered

# Via Makefile
make validate-exports

# Fail CI on ANY issue (non-zero exit)
make validate-exports-strict
python3 scripts/validate_exports.py out/inquiries_filtered --strict
```

## What It Checks

### 1. Canonical 13-Column File Presence
Exact header required:
```
Transaction_ID,Transaction_Value,Basket_Size,Category,Brand,Daypart,
Demographics_Age_Gender_Role,Weekday_vs_Weekend,Time_of_Transaction,
Location,Other_Products,Was_Substitution,Export_Timestamp
```

### 2. Locked Schemas (Column Order)
All pinned exports must match exact column order:

#### Overall Analytics
- **`overall/store_profiles`**: `store_id,store_name,region,transactions,total_items,total_amount`
- **`overall/sales_by_week`**: `iso_week,week_start,transactions,total_amount`
- **`overall/daypart_by_category`**: `daypart,category,transactions,share_pct`
- **`overall/purchase_profile_pdp`**: `dom_bucket,transactions,share_pct`

#### Tobacco Analytics
- **`tobacco/demo_gender_age_brand`**: `gender,age_band,brand,transactions,share_pct`
- **`tobacco/purchase_profile_pdp`**: `dom_bucket,transactions,share_pct`
- **`tobacco/sales_by_day_daypart`**: `date,daypart,transactions,share_pct`
- **`tobacco/sticks_per_visit`**: `transaction_id,brand,items,sticks_per_pack,estimated_sticks`
- **`tobacco/copurchase_categories`**: `category,transactions,share_pct`

#### Laundry Analytics
- **`laundry/detergent_type`**: `detergent_type,with_fabcon,transactions,share_pct`

### 3. File Format Support
- **CSV(.gz) header read** (handles gzip correctly)
- **Parquet schema** (requires `pyarrow`; degrades gracefully if not installed)
- **CSV↔Parquet pairing** per stem (e.g., `store_profiles.{csv.gz,parquet}`)

### 4. Manifest Generation
Writes manifests alongside exports:
- **`_SCAN_MANIFEST.json`** — files, sizes, MD5 hashes
- **`_SCAN_ISSUES.json`** — exact schema drifts/missing pairs

## Output Examples

### ✅ PASS (Quiet)
```
✅ Validation Status: PASS
✅ Canonical 13-col CSV present: YES
📁 Files scanned: 45
🔍 Issues found: 0 (0 errors, 0 warnings)
```

### ❌ DRIFT Detection
```
❌ Validation Status: FAIL
✅ Canonical 13-col CSV present: YES
📁 Files scanned: 45
🔍 Issues found: 3 (2 errors, 1 warnings)

First 10 issues:
  🚨 SCHEMA_DRIFT: tobacco/demo_gender_age_brand.csv
    Missing: share_pct
    Extra: percentage
  🚨 SCHEMA_DRIFT: overall/store_profiles.parquet
    Column order mismatch
  ⚠️ MISSING_PARQUET_PAIR: laundry/detergent_type
```

### CI Integration
In CI environments, use `--strict` to fail the job:
```bash
# Returns exit code 1 if any errors found
python3 scripts/validate_exports.py out/inquiries_filtered --strict
```

## Makefile Integration

Add to your build process:

```make
# Basic validation
validate-exports:
	python3 scripts/validate_exports.py out/inquiries_filtered

# Strict mode for CI
validate-exports-strict:
	python3 scripts/validate_exports.py out/inquiries_filtered --strict

# Complete system validation
system-complete: schema-complete validate-complete analytics-comprehensive
```

## File Pattern Matching

The validator automatically maps file patterns to schema keys:

| File Pattern | Schema Key |
|--------------|------------|
| `*store_profiles*` | `overall/store_profiles` |
| `*sales_by_week*` | `overall/sales_by_week` |
| `*daypart_by_category*` | `overall/daypart_by_category` |
| `*demo_gender_age_brand*` | `tobacco/demo_gender_age_brand` |
| `*sticks_per_visit*` | `tobacco/sticks_per_visit` |
| `*detergent_type*` | `laundry/detergent_type` |

## Dependencies

### Required
- Python 3.7+
- Standard library only (csv, gzip, json, pathlib, etc.)

### Optional
- **`pyarrow`** for Parquet validation
  ```bash
  pip install pyarrow
  ```
  If not installed, validator still works but skips Parquet files

## Error Types

### SCHEMA_DRIFT
Column header doesn't match locked schema exactly:
- Missing columns
- Extra columns
- Wrong column order
- Different column names

### MISSING_DIRECTORY
Export directory doesn't exist

### CSV_READ_ERROR / PARQUET_READ_ERROR
File corruption or encoding issues

### MISSING_CSV_PAIR / MISSING_PARQUET_PAIR
Files exist in one format but not the other

## Integration with Scout v7 System

This validator is part of the complete Scout v7 validation suite:

1. **Schema Compliance** - `make validate` (database structure)
2. **Export Compliance** - `make validate-exports` (file formats)
3. **Analytics Coverage** - `make analytics-comprehensive` (business logic)
4. **Complete System** - `make system-complete` (everything)

The validator ensures your export pipeline produces consistent, contract-compliant files that downstream systems can rely on.

## Advanced Usage

### Custom Export Directory
```bash
python3 scripts/validate_exports.py /path/to/custom/exports
```

### Quiet Mode
```bash
python3 scripts/validate_exports.py out/inquiries_filtered --quiet
```

### Programmatic Usage
```python
from validate_exports import ExportValidator

validator = ExportValidator("out/inquiries_filtered")
report = validator.scan_exports()

if report["validation_status"] == "PASS":
    print("All exports valid!")
else:
    print(f"Found {report['error_count']} errors")
```

## Troubleshooting

### No Canonical File Found
Ensure your canonical export file:
- Contains "canonical", "13col", "flat_export", or similar in filename
- Has exactly 13 columns matching the locked schema

### Schema Drift Issues
Check the `_SCAN_ISSUES.json` file for exact details:
- Which columns are missing/extra
- Expected vs actual column order
- File-specific error details

### Parquet Validation Disabled
Install pyarrow for full validation:
```bash
pip install pyarrow
```

This validator provides comprehensive export quality assurance for the Scout v7 retail intelligence platform.