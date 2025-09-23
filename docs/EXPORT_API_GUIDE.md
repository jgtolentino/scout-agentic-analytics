# 🚀 Scout Analytics Export API - Complete Guide

**Zero-credential CSV export system with Bruno integration and privacy controls**

## 🎯 **Architecture Overview**

The Scout Export API provides secure, credential-free data exports with two operational modes:

### **Resolve Mode** (Recommended)
- Dashboard calls API → receives SQL + filename → Bruno executes with vault credentials
- No database credentials exposed to application
- Copy-paste Bruno commands for immediate execution

### **Delegate Mode** (Advanced)
- Dashboard calls API → API triggers Bruno webhook → automatic execution
- Requires webhook setup and HMAC signature validation
- Fully automated export pipeline

## 📡 **API Endpoints**

### **1. List Available Exports**
```http
GET /api/export/list
```

**Response:**
```json
{
  "ok": true,
  "available_exports": [
    {
      "type": "crosstab_14d",
      "redact": false,
      "description": "14-day crosstab analysis with time period breakdown"
    },
    {
      "type": "flat_today_no_transcripts",
      "redact": true,
      "description": "Today's transactions without audio transcripts (privacy-safe)"
    }
  ]
}
```

### **2. Execute Predefined Export**
```http
POST /api/export/{type}
```

**Available Types:**
- `crosstab_14d` - 14-day dimensional analysis
- `brands_summary` - Brand performance metrics
- `flat_latest` - Latest 1000 transactions (with transcripts)
- `flat_today_no_transcripts` - Privacy-safe today's data
- `flat_today_full` - Complete today's data with transcripts
- `pbi_transactions_summary` - Power BI optimized export

**Response:**
```json
{
  "ok": true,
  "type": "crosstab_14d",
  "sql": "SELECT [date], store_name, Morning_Transactions...",
  "filename": "scout_crosstab_14d_2025-09-22.csv",
  "mode": "resolve",
  "runner_command": "./scripts/bcp_export_runner.sh custom \"SELECT...\" \"filename.csv\""
}
```

### **3. Execute Custom SQL Export**
```http
POST /api/export/custom
```

**Request Body:**
```json
{
  "sql": "SELECT TOP (100) brand, COUNT(*) as transactions FROM gold.v_transactions_flat WHERE transaction_date >= CONVERT(date, DATEADD(day, -7, SYSUTCDATETIME())) GROUP BY brand ORDER BY transactions DESC",
  "filename": "brand_analysis_last_7days.csv",
  "description": "Brand transaction analysis for last 7 days"
}
```

**Response (Success):**
```json
{
  "ok": true,
  "type": "custom",
  "sql": "SELECT TOP (100) brand, COUNT(*) as transactions...",
  "filename": "brand_analysis_last_7days.csv",
  "mode": "resolve",
  "runner_command": "./scripts/bcp_export_runner.sh custom \"SELECT...\" \"filename.csv\"",
  "validation": {
    "passed": true,
    "checks": ["length_check", "keyword_check", "table_validation", "select_only"]
  }
}
```

**Response (Validation Error):**
```json
{
  "ok": false,
  "error": "table_not_allowed: Must reference one of: gold.v_transactions_flat, gold.v_transactions_crosstab...",
  "validation": {
    "passed": false,
    "error": "table_not_allowed"
  },
  "help": {
    "allowed_tables": ["gold.v_transactions_flat", "gold.v_transactions_crosstab"],
    "max_length": 5000,
    "max_top": 10000,
    "example": "SELECT TOP (100) brand, COUNT(*) as transactions FROM gold.v_transactions_flat..."
  }
}
```

## 🛡️ **Security Features**

### **SQL Validation (Custom Exports)**
- **Maximum Length**: 5,000 characters
- **Required Start**: Must begin with `SELECT`
- **Prohibited Keywords**: `DROP`, `ALTER`, `INSERT`, `UPDATE`, `DELETE`, `MERGE`, `EXEC`, `CREATE`, `TRUNCATE`
- **Allowed Tables**: Only whitelisted `gold.*` and `audit.*` views
- **TOP Limit**: Maximum 10,000 records per query
- **No File Operations**: Blocks `LOADFILE`, `OUTFILE`, `DUMPFILE`

### **Access Control**
- **No Database Credentials**: Application never sees database passwords
- **Bruno Vault Integration**: Credentials injected at execution time
- **Read-Only Access**: Uses `scout_reader` with minimal permissions
- **Audit Logging**: All exports logged in `audit.export_log`

### **Privacy Protection**
- **Transcript Redaction**: `*_no_transcripts` variants exclude audio data
- **Selective Exports**: Choose privacy level per export
- **Data Classification**: Clear labeling of sensitive vs. safe exports

## 🔧 **Bruno Integration**

### **Environment Setup**
```bash
# .env.bruno
AZSQL_HOST=sqltbwaprojectscoutserver.database.windows.net
AZSQL_DB=flat_scratch
AZSQL_USER=scout_reader
AZSQL_PASS={{vault.scout_analytics.sql_reader_password}}
EXPORT_DIR=./exports
EXPORT_DELEGATION_MODE=resolve
```

### **Resolve Mode Execution**
```bash
# 1. Call API to get command
curl -X POST http://localhost:3000/api/export/crosstab_14d

# 2. Execute returned command in Bruno
./scripts/bcp_export_runner.sh custom "SELECT [date], store_name..." "scout_crosstab_14d_2025-09-22.csv"
```

### **Delegate Mode Setup** (Optional)
```bash
# Additional environment for webhook delegation
BRUNO_WEBHOOK_URL=https://bruno.local/export
BRUNO_WEBHOOK_SECRET={{vault.scout_analytics.webhook_secret}}

# Webhook handler
./scripts/bruno_webhook_export.sh
```

## 📱 **Dashboard Integration**

### **ScoutExportButton Component**
```tsx
import ScoutExportButton from '@/components/ScoutExportButton';

// Basic usage
<ScoutExportButton exportType="crosstab_14d" />

// With custom SQL
<ScoutExportButton
  exportType="custom"
  customSql="SELECT brand, COUNT(*) FROM gold.v_transactions_flat GROUP BY brand"
/>

// Privacy-safe export
<ScoutExportButton exportType="flat_today_no_transcripts" />
```

### **API Utilities**
```typescript
import { executePreDefinedExport, executeCustomExport } from '@/lib/utils/exportApi';

// Predefined export
const result = await executePreDefinedExport('brands_summary');

// Custom export with validation
const customResult = await executeCustomExport({
  sql: "SELECT TOP (50) * FROM gold.v_transactions_flat ORDER BY txn_ts DESC",
  filename: "recent_transactions.csv"
});
```

## 🎨 **Export Types Reference**

### **Dimensional Analysis**
```sql
-- crosstab_14d
SELECT [date], store_name, Morning_Transactions, Midday_Transactions,
       Afternoon_Transactions, Evening_Transactions, txn_count, total_amount
FROM gold.v_transactions_crosstab
WHERE [date] >= CONVERT(date, DATEADD(day,-14, SYSUTCDATETIME()))
ORDER BY [date], store_name;
```

### **Brand Performance**
```sql
-- brands_summary
SELECT brand, category, COUNT(*) as total_transactions,
       SUM(total_amount) as total_revenue, AVG(total_amount) as avg_transaction_value,
       MIN(txn_ts) as first_transaction, MAX(txn_ts) as latest_transaction
FROM gold.v_transactions_flat
WHERE transaction_date >= CONVERT(date, DATEADD(day,-7, SYSUTCDATETIME()))
GROUP BY brand, category ORDER BY total_revenue DESC;
```

### **Privacy-Safe Export**
```sql
-- flat_today_no_transcripts
SELECT canonical_tx_id, device_id, store_id, brand, product_name, category,
       total_amount, total_items, payment_method, daypart, weekday_weekend,
       txn_ts, store_name, transaction_date
FROM gold.v_transactions_flat
WHERE transaction_date = CONVERT(date, SYSUTCDATETIME())
ORDER BY txn_ts DESC;
```

## 🧪 **Testing & Validation**

### **API Tests**
```bash
# List available exports
curl -s http://localhost:3000/api/export/list | jq

# Test predefined export
curl -s -X POST http://localhost:3000/api/export/crosstab_14d | jq

# Test custom export validation
curl -s -X POST http://localhost:3000/api/export/custom \
  -H 'content-type: application/json' \
  -d '{"sql":"SELECT TOP (50) * FROM gold.v_transactions_flat ORDER BY txn_ts DESC"}' | jq

# Test validation error
curl -s -X POST http://localhost:3000/api/export/custom \
  -H 'content-type: application/json' \
  -d '{"sql":"DROP TABLE users"}' | jq
```

### **Export Execution Tests**
```bash
# Test with actual Bruno environment
./scripts/bcp_export_runner.sh crosstab_14d
./scripts/bcp_export_runner.sh brands_summary

# Verify exports directory
ls -la exports/scout_*.csv
```

## 📋 **Troubleshooting**

### **Common Issues**

**1. "unknown_export_type" Error**
```bash
# Check available types
curl -s http://localhost:3000/api/export/list | jq '.available_exports[].type'
```

**2. "table_not_allowed" Error**
```bash
# Use only whitelisted tables
gold.v_transactions_flat
gold.v_transactions_crosstab
gold.v_pbi_transactions_summary
audit.v_flat_vs_crosstab_parity
```

**3. "missing_webhook" Error**
```bash
# Set delegation mode environment
export EXPORT_DELEGATION_MODE=resolve  # Use resolve mode instead
```

**4. Bruno Command Execution Issues**
```bash
# Verify environment
echo $AZSQL_PASS  # Should be injected by Bruno
./scripts/bcp_export_runner.sh --help
```

## 🎉 **Ready for Production**

The Export API provides:
- ✅ **Zero-credential architecture** with vault-managed secrets
- ✅ **Strict validation** with comprehensive security controls
- ✅ **Privacy protection** with transcript redaction options
- ✅ **Bruno integration** for seamless execution
- ✅ **Dashboard ready** with React components
- ✅ **Production monitoring** with audit trails

**Example Production Workflow:**
1. User clicks export in dashboard
2. API validates request and returns Bruno command
3. Command copied to clipboard automatically
4. Bruno executes with vault credentials
5. CSV file delivered to exports directory
6. Operation logged in audit trail

**The system is fully operational and production-ready! 🚀**