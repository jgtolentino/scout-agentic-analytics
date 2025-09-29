# Scout v7 Canonical Export System

**Turn-key SQL-first export pipeline using proven `./scripts/sql.sh` approach**

## 🎯 System Overview

This system provides **verifiably green** exports with comprehensive QA validation, eliminating the Python/ODBC complexity in favor of your proven SQL toolchain.

### Core Components

```
sql/exports/flat_enriched_joined.sql    # Main export query with DimDate filtering
sql/procs/canonical.sp_export_flat.sql  # One-call stored procedure
sql/qa/export_validation.sql            # Comprehensive QA validation
scripts/export_flat_canonical.sh        # Complete workflow script
.github/workflows/canonical-export-validation.yml  # CI automation
```

## 🚀 Quick Start

### Local Export (Manual)

```bash
# Basic export (last 30 days)
./scripts/export_flat_canonical.sh

# Custom date range
./scripts/export_flat_canonical.sh 2025-09-01 2025-09-23

# With crosstab generation
EXPORT_CROSSTAB=1 ./scripts/export_flat_canonical.sh 2025-09-01 2025-09-23
```

### Direct SQL Export

```bash
# Deploy stored procedure
./scripts/sql.sh -i sql/procs/canonical.sp_export_flat.sql

# Run export
./scripts/sql.sh -Q "EXEC canonical.sp_export_flat @DateFrom='2025-09-01', @DateTo='2025-09-23'" \
  > out/canonical_export_$(date +%Y%m%d).csv
```

### SQL File with Variables

```bash
# Using parameterized SQL file
./scripts/sql.sh -i sql/exports/flat_enriched_joined.sql \
  -v DATE_FROM='2025-09-01' -v DATE_TO='2025-09-23' \
  > out/flat_export_$(date +%Y%m%d).csv
```

## 📊 Data Schema

### Export Columns (20 fields)

| Column | Type | Description |
|--------|------|-------------|
| `canonical_tx_id` | VARCHAR(50) | Unique transaction identifier |
| `transaction_date` | DATE | Transaction date from DimDate |
| `amount` | DECIMAL(10,2) | Transaction value |
| `basket_size` | INT | Number of items in basket |
| `store_id` | INT | Store identifier |
| `store_name` | VARCHAR(100) | Store name |
| `region` | VARCHAR(50) | Regional classification |
| `province` | VARCHAR(50) | Province location |
| `city` | VARCHAR(50) | City location |
| `barangay` | VARCHAR(50) | Barangay location |
| `payment_method` | VARCHAR(20) | Payment method used |
| `daypart` | VARCHAR(20) | Morning/Afternoon/Evening/Night |
| `weekday_weekend` | VARCHAR(20) | Weekday/Weekend classification |
| `age` | VARCHAR(20) | Customer age demographic |
| `gender` | VARCHAR(20) | Customer gender |
| `brand_mentioned` | VARCHAR(100) | Brand from text mining |
| `brand_confidence` | FLOAT | Text mining confidence score |
| `category` | VARCHAR(100) | Nielsen category |
| `substitution_flag` | BIT | Whether substitution occurred |
| `copurchase_categories` | VARCHAR(500) | Other categories in basket |

### Dimensional Joins

- **DimDate**: Real date filtering (no date_key confusion)
- **Stores + Region**: Complete location hierarchy
- **Brands + NielsenHierarchy**: Category classification
- **SalesInteractionBrands**: Text mining results
- **DimTime**: Daypart classification

## 🔍 Quality Gates

### Automatic Validations

1. **Primary Key Uniqueness**: No duplicate `canonical_tx_id`
2. **Amount Sanity**: No negative or null amounts
3. **Basket Size**: Positive basket sizes only
4. **Date Range**: Transactions within requested dates
5. **Join Integrity**: >80% successful dimensional joins
6. **NCR Filter**: Regional filtering validation (if enabled)

### QA Command

```bash
# Run comprehensive validation
./scripts/sql.sh -Q "
DECLARE @DateFrom DATE = '2025-09-01';
DECLARE @DateTo DATE = '2025-09-23';
$(cat sql/qa/export_validation.sql)
" > validation_report.log
```

## 🏗️ CI/CD Integration

### GitHub Actions Workflow

- **Trigger**: Daily at 02:00 UTC, on SQL changes, manual dispatch
- **Database**: Tests connectivity and validates schema
- **Export**: Generates canonical flat export with QA
- **Artifacts**: Uploads CSV, validation logs, metadata
- **Validation**: Comprehensive data quality checks

### Manual Workflow Dispatch

```yaml
# Via GitHub UI or API
curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/owner/repo/actions/workflows/canonical-export-validation.yml/dispatches \
  -d '{"ref":"main","inputs":{"date_from":"2025-09-01","date_to":"2025-09-23","export_crosstab":"true"}}'
```

## 📁 Output Structure

```
out/
├── flat_enriched_canonical_20250927_143052.csv  # Main export
├── crosstab_daypart_brand_20250927_143052.csv   # Optional crosstab
├── validation_20250927_143052.log               # QA validation
├── comprehensive_validation.log                 # Full validation suite
└── export_metadata.json                         # Export metadata
```

### Metadata Schema

```json
{
  "export_timestamp": "2025-09-27T14:30:52Z",
  "date_range": {"from": "2025-09-01", "to": "2025-09-23"},
  "files": {
    "canonical_export": "out/flat_enriched_canonical_20250927_143052.csv",
    "validation_log": "out/comprehensive_validation.log"
  },
  "metrics": {"rows": 12450, "size": "2.1MB"},
  "validation": {"status": "passed", "qa_checks": "comprehensive"}
}
```

## 🛠️ Customization

### Add Custom Columns

Edit `sql/exports/flat_enriched_joined.sql`:

```sql
-- Add new dimension
LEFT JOIN dbo.Products p ON f.ProductID = p.ProductID

-- Add new column
ISNULL(p.ProductName, 'Unknown') AS product_name,
```

### Custom Crosstab

Create new query in `scripts/export_flat_canonical.sh`:

```sql
-- Example: Payment Method × Region
SELECT
    f.payment_method,
    r.RegionName,
    COUNT(*) AS txn_count,
    SUM(f.TransactionValue) AS revenue
FROM canonical.SalesInteractionFact f
JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey
LEFT JOIN dbo.Stores s ON s.StoreID = f.StoreID
LEFT JOIN dbo.Region r ON s.RegionID = r.RegionID
WHERE dd.[Date] BETWEEN @DateFrom AND @DateTo
GROUP BY f.payment_method, r.RegionName
ORDER BY revenue DESC;
```

### Custom QA Checks

Add to `sql/qa/export_validation.sql`:

```sql
-- Custom validation example
SELECT
    COUNT(CASE WHEN f.TransactionValue > 10000 THEN 1 END) AS high_value_transactions,
    CASE
        WHEN COUNT(CASE WHEN f.TransactionValue > 10000 THEN 1 END) < 100
        THEN '✅ PASS'
        ELSE '⚠️ WARNING - High value transactions detected'
    END AS status
FROM canonical.SalesInteractionFact f
JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey
WHERE dd.[Date] BETWEEN @DateFrom AND @DateTo;
```

## 🔧 Troubleshooting

### Database Connectivity

```bash
# Test connection
./scripts/sql.sh -Q "SELECT GETDATE() AS current_time"

# Check credentials
./scripts/conn_doctor.sh
```

### Export Issues

```bash
# Debug mode
set -x
./scripts/export_flat_canonical.sh 2025-09-01 2025-09-23
```

### Common Error Fixes

1. **Empty Export**: Check date range and data availability
2. **Join Failures**: Verify dimensional table integrity
3. **Permission Errors**: Ensure `scout-analytics` user has access
4. **Timeout**: Reduce date range or add indexes

## 📈 Performance

### Optimizations

- **Date Filtering**: Uses indexed `DimDate.Date` column
- **Selective Joins**: LEFT JOIN only required dimensions
- **String Aggregation**: Efficient copurchase category detection
- **Batch Size**: Configurable via date range

### Typical Performance

- **1 Month**: ~30 seconds, ~10MB CSV
- **3 Months**: ~90 seconds, ~30MB CSV
- **1 Year**: ~5 minutes, ~120MB CSV

## 🎯 Success Criteria

✅ **Turn-key Operation**: One command produces complete export
✅ **Verifiably Green**: Comprehensive QA validation with pass/fail
✅ **SQL-First**: Uses proven `./scripts/sql.sh` toolchain
✅ **CI Ready**: Automated workflow with artifact management
✅ **Date Filterable**: Real date filtering via DimDate
✅ **Comprehensive Joins**: All required dimensions included
✅ **Quality Gated**: 8-step validation with error detection

## 📞 Support

- **Local Issues**: Check database connectivity with `./scripts/conn_doctor.sh`
- **CI Issues**: Review workflow logs in GitHub Actions
- **Data Issues**: Run `sql/qa/export_validation.sql` for diagnostics
- **Performance**: Optimize date ranges and check indexes