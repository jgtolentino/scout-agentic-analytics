# Scout Lakehouse - Single-Run Fabric Bundle

**Ready-to-deploy Microsoft Fabric implementation with locked `scout-lakehouse` name**

## 🚀 Claude Code CLI Execution

Since **Claude Code IS the CLI**, execute this bundle directly:

### 1. Deploy Complete Bundle
```bash
# Navigate to bundle
cd fabric/scout-lakehouse

# Deploy with Claude Code (you are the CLI!)
# This executes the workspace.manifest.yaml
```

### 2. Manual Steps (if needed)
```sql
-- 1. Execute in Fabric Warehouse "scout-warehouse"
warehouse/01_warehouse_ddl.sql
warehouse/02_warehouse_views.sql

-- 2. Run in Lakehouse "scout-lakehouse"
notebooks/02_silver_transformation.py

-- 3. Validate deployment
validation/validate_fabric.sql
```

### 3. Power BI Connection
```json
// Import to Power BI Desktop
powerbi/semantic_model.json
powerbi/measures.dax  // 60+ DAX measures
```

## 📋 Architecture

```
Azure SQL → scout-lakehouse (Bronze/Silver) → scout-warehouse (Gold/Platinum) → Power BI
  Source      Fabric Lakehouse Delta            Fabric Warehouse Views       Analytics
```

### Medallion Layers
- **Bronze**: Raw Azure SQL ingestion (`bronze.*_raw`)
- **Silver**: Cleansed with JSON explosion (`silver.transactions`, `silver.transaction_items`)
- **Gold**: Analytics views (`gold.mart_transactions`, `gold.dim_*`)
- **Platinum**: ML registry (`platinum.model_registry`, `platinum.predictions`)

### Key Design
- ✅ **Single Date Authority**: `transaction_date` from `canonical.SalesInteractionFact`
- ✅ **JSON Explosion**: `PayloadTransactions.payload_json.items[]` → SKU level
- ✅ **Nielsen Integration**: L1/L2/L3 category mappings
- ✅ **Locked Names**: All references use `scout-lakehouse` (no tokens)

## 📁 Bundle Contents

```
scout-lakehouse/
├── warehouse/
│   ├── 01_warehouse_ddl.sql      # Gold/Platinum schemas + ML registry
│   └── 02_warehouse_views.sql    # Cross-database views (locked to scout-lakehouse)
├── notebooks/
│   └── 02_silver_transformation.py  # Bronze→Silver ETL with JSON explosion
├── powerbi/
│   ├── semantic_model.json       # Power BI model definition
│   └── measures.dax             # 60+ business metrics
├── validation/
│   └── validate_fabric.sql      # Single-query validation for Claude
├── config/
│   └── workspace.manifest.yaml  # Complete deployment manifest
└── README.md                    # This file
```

## 🔧 Configuration (Pre-locked)

All files use **locked `scout-lakehouse`** name:
- **Lakehouse**: `scout-lakehouse`
- **Warehouse**: `scout-warehouse`
- **Workspace**: `scout-lakehouse`
- **Views**: `FROM [scout-lakehouse].dbo.silver_*`

No token replacement needed!

## ✅ Validation

**Claude Code validation prompt** (drop-in):

```
You are an auditor. Connect to Fabric Warehouse "scout-warehouse" and Lakehouse SQL endpoint "scout-lakehouse". Execute validation/validate_fabric.sql and verify:

1) Schemas: gold, platinum exist
2) Lakehouse Silver: silver.transactions, silver.transaction_items, silver_dim_* tables
3) Gold views: dim_store, dim_brand, fact_transactions, mart_transactions (>=1 rows)
4) Platinum: model_registry, predictions, insights tables
5) Freshness: mart_transactions rows where transaction_date >= today-7d
6) Persona coverage: predictions with label LIKE 'persona:%' covering >=95% of 7d transactions
7) Indexes: IX_pred_subject, IX_insight_entity
8) Single date rule: transaction_date NOT NULL in mart_transactions

Return JSON:
{
  "schemas_ok": bool,
  "gold_views_ok": bool,
  "platinum_ok": bool,
  "freshness_7d_rows": number,
  "persona_coverage_pct_7d": number|null,
  "indexes_ok": bool,
  "single_date_enforced": bool,
  "verdict": "pass"|"warn"|"fail",
  "notes": ["validation details"]
}
```

## 📊 Business Intelligence

### 60+ DAX Measures Include:
- **Revenue**: Total, MTD, YTD, Growth %, Forecasting
- **Customers**: Count, Retention, Segmentation, Lifecycle Value
- **Stores**: Performance, Rankings, Efficiency, Regional
- **Products**: Nielsen categories, Premium share, Market basket
- **Time**: Hourly patterns, Peak vs Off-peak, Seasonal
- **Operational**: Revenue velocity, Store efficiency, Health scores

### Key Reports:
- Executive Dashboard
- Store Performance Analysis
- Customer Segmentation
- Nielsen Category Intelligence
- Operational Metrics

## 🚨 Troubleshooting

### Common Issues:
1. **Cross-database views fail** → Ensure same workspace
2. **Authentication errors** → Check Managed Identity setup
3. **No recent data** → Verify Azure SQL connectivity
4. **Power BI connection** → Check warehouse connection string

### Success Indicators:
- ✅ `validation/validate_fabric.sql` returns `verdict: "pass"`
- ✅ Gold views return data: `SELECT COUNT(*) FROM gold.mart_transactions`
- ✅ Power BI connects: 60+ measures available
- ✅ Data freshness: Last 7 days have transactions

## 🎯 Expected Results

**After deployment:**
- **Lakehouse**: 7 Silver tables with dimensional model
- **Warehouse**: 15+ Gold views + 7 Platinum ML tables
- **Power BI**: 60+ measures, 5 tables, star schema
- **Validation**: Single-query health check returns "pass"

**Data Volume:**
- Transactions: ~12K from canonical.SalesInteractionFact
- Items: Variable based on JSON explosion
- Dimensions: Stores, Brands, Categories from Azure SQL

---

**Deployment Time**: ~2 hours end-to-end
**Single Date Authority**: ✅ Enforced via `canonical.SalesInteractionFact.transaction_date`
**Ready for**: Production analytics, ML workflows, business intelligence