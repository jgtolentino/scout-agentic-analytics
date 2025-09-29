# Scout v7 One-Liner Export Reference

**Quick reference for canonical export using proven `./scripts/sql.sh`**

## 🚀 Essential One-Liners

### Deploy Stored Procedure (One-Time Setup)
```bash
./scripts/sql.sh -i sql/procs/canonical.sp_export_flat.sql
```

### Basic Export (Date Range)
```bash
./scripts/sql.sh -Q "EXEC canonical.sp_export_flat @DateFrom='2025-09-01', @DateTo='2025-09-23'" > export.csv
```

### Export with Timestamp
```bash
./scripts/sql.sh -Q "EXEC canonical.sp_export_flat @DateFrom='2025-09-01', @DateTo='2025-09-23'" > "export_$(date +%Y%m%d_%H%M%S).csv"
```

### Quick Row Count Validation
```bash
./scripts/sql.sh -Q "SELECT COUNT(*) AS rows FROM canonical.SalesInteractionFact f JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey WHERE dd.[Date] BETWEEN '2025-09-01' AND '2025-09-23'"
```

## 📊 Complete Workflow (4 Commands)

```bash
# 1. Deploy procedure (if needed)
./scripts/sql.sh -i sql/procs/canonical.sp_export_flat.sql

# 2. Generate export
./scripts/sql.sh -Q "EXEC canonical.sp_export_flat @DateFrom='2025-09-01', @DateTo='2025-09-23'" > canonical_export.csv

# 3. Validate row count
EXPECTED_ROWS=$(./scripts/sql.sh -Q "SELECT COUNT(*) FROM canonical.SalesInteractionFact f JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey WHERE dd.[Date] BETWEEN '2025-09-01' AND '2025-09-23'" | tail -1)

# 4. Verify export
ACTUAL_ROWS=$(wc -l < canonical_export.csv)
echo "Expected: $EXPECTED_ROWS | Actual: $ACTUAL_ROWS | Status: $([[ $EXPECTED_ROWS -eq $ACTUAL_ROWS ]] && echo "✅ PASS" || echo "❌ FAIL")"
```

## 🔧 Dynamic Date Ranges

### Last 7 Days
```bash
DATE_FROM=$(date -d '7 days ago' +%Y-%m-%d)
DATE_TO=$(date +%Y-%m-%d)
./scripts/sql.sh -Q "EXEC canonical.sp_export_flat @DateFrom='$DATE_FROM', @DateTo='$DATE_TO'" > export_last7days.csv
```

### Last 30 Days
```bash
DATE_FROM=$(date -d '30 days ago' +%Y-%m-%d)
DATE_TO=$(date +%Y-%m-%d)
./scripts/sql.sh -Q "EXEC canonical.sp_export_flat @DateFrom='$DATE_FROM', @DateTo='$DATE_TO'" > export_last30days.csv
```

### Current Month
```bash
DATE_FROM=$(date +%Y-%m-01)
DATE_TO=$(date +%Y-%m-%d)
./scripts/sql.sh -Q "EXEC canonical.sp_export_flat @DateFrom='$DATE_FROM', @DateTo='$DATE_TO'" > export_current_month.csv
```

## 🔍 Quick QA One-Liners

### Check Export Structure
```bash
head -1 canonical_export.csv | tr ',' '\n' | nl  # List all columns with numbers
```

### Validate Data Types
```bash
./scripts/sql.sh -Q "SELECT TOP 5 * FROM canonical.SalesInteractionFact f JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey WHERE dd.[Date] BETWEEN '2025-09-01' AND '2025-09-23'"
```

### Check Date Range
```bash
./scripts/sql.sh -Q "SELECT MIN(dd.[Date]) as min_date, MAX(dd.[Date]) as max_date FROM canonical.SalesInteractionFact f JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey WHERE dd.[Date] BETWEEN '2025-09-01' AND '2025-09-23'"
```

### Verify Amounts
```bash
./scripts/sql.sh -Q "SELECT COUNT(*) as total, SUM(TransactionValue) as revenue, AVG(TransactionValue) as avg_amount FROM canonical.SalesInteractionFact f JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey WHERE dd.[Date] BETWEEN '2025-09-01' AND '2025-09-23'"
```

## 📋 Output Verification

### Standard Checks
```bash
# Row count
wc -l canonical_export.csv

# File size
du -h canonical_export.csv

# Column count (should be 20)
head -1 canonical_export.csv | tr ',' '\n' | wc -l

# Sample data
head -5 canonical_export.csv
tail -5 canonical_export.csv
```

### Data Quality Checks
```bash
# Check for empty fields
grep -c ",," canonical_export.csv

# Check for duplicate transaction IDs
cut -d',' -f1 canonical_export.csv | sort | uniq -d | wc -l

# Check date format
cut -d',' -f2 canonical_export.csv | head -10
```

## 🎯 Expected Results

### Successful Export Indicators
- ✅ **File Size**: >100KB for typical date ranges
- ✅ **Row Count**: Matches database query result
- ✅ **Columns**: Exactly 20 columns
- ✅ **Headers**: First row contains column names
- ✅ **Data Types**: Numbers, dates, strings formatted correctly
- ✅ **No Errors**: No SQL error messages in output

### Typical Performance
- **1 Week**: ~5 seconds, ~500KB CSV
- **1 Month**: ~15 seconds, ~2MB CSV
- **3 Months**: ~45 seconds, ~6MB CSV

## 🔧 Troubleshooting One-Liners

### Connection Test
```bash
./scripts/sql.sh -Q "SELECT GETDATE() AS current_time, @@SERVERNAME AS server"
```

### Schema Validation
```bash
./scripts/sql.sh -Q "SELECT OBJECT_ID('canonical.sp_export_flat') AS proc_exists"
```

### Table Existence
```bash
./scripts/sql.sh -Q "SELECT COUNT(*) FROM canonical.SalesInteractionFact" | head -1
```

### Date Range Availability
```bash
./scripts/sql.sh -Q "SELECT MIN(dd.[Date]) as earliest, MAX(dd.[Date]) as latest FROM canonical.SalesInteractionFact f JOIN dbo.DimDate dd ON dd.DateKey = f.DateKey"
```

---

**💡 Pro Tip**: Bookmark these one-liners for instant canonical exports. The stored procedure approach eliminates complex joins and ensures consistent, validated output every time.