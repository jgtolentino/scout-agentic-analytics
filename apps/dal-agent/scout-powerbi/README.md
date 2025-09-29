# Scout Power BI Analytics - PBIP/TMDL Implementation

A Mac-native, Fabric-first Power BI solution using text-based PBIP/TMDL format for version control and Git integration.

## 🏗️ Architecture Overview

```
scout-powerbi/
├── pbip-model-core/           # Shared semantic model (60+ DAX measures)
│   ├── .pbip/definition.pbir  # Dataset artifact definition
│   └── model/                 # TMDL model components
│       ├── Model.tmdl         # Main model with time intelligence
│       ├── datasources.tmdl   # Fabric Warehouse connection
│       ├── tables/            # Dimension and fact tables
│       ├── relationships.tmdl # Star schema relationships
│       ├── measures.tmdl      # 60+ DAX measures
│       ├── roles.tmdl         # Row-Level Security roles
│       └── refresh-policy.tmdl # Incremental refresh policies
├── executive-dashboard/       # C-Suite strategic overview
├── sales-analysis/           # Sales performance deep-dive
├── store-performance/        # Individual store metrics
├── category-insights/        # Category and brand analysis
├── predictive-analytics/     # ML predictions and forecasting
├── scout-theme.json          # Custom Power BI theme
└── validate-pbip.sh         # Validation script
```

## ✨ Key Features

### 🎯 Shared Dataset Pattern
- **Single Source of Truth**: One semantic model, multiple thin reports
- **60+ DAX Measures**: Comprehensive analytics covering sales, profitability, predictions
- **Time Intelligence**: Proper Date dimension with YoY, QTD, MTD calculations
- **Philippine Context**: ₱ currency formatting, Nielsen categories, regional hierarchy

### 🔒 Security & Performance
- **Row-Level Security (RLS)**: 12 predefined roles (Regional, Store, Category managers)
- **Incremental Refresh**: 2-year rolling window for transactions, 1-year for predictions
- **Optimized Queries**: Fabric Warehouse gold layer with parameterized connections

### 🎨 Professional Design
- **Scout Theme**: TBWA brand colors with accessibility compliance
- **Philippine Localization**: Regional hierarchy (NCR → Luzon → Visayas → Mindanao)
- **Mobile-Responsive**: Designed for desktop and mobile consumption

## 🚀 Quick Start

### Prerequisites
- **Microsoft Fabric workspace** with Git integration enabled
- **Power BI Desktop** (latest version with PBIP support)
- **Git repository** connected to Fabric workspace
- **Fabric Warehouse** with Scout gold layer tables

### 1. Repository Setup
```bash
# Clone to Fabric-connected repository
git clone <your-fabric-repo> scout-powerbi
cd scout-powerbi

# Validate structure
./validate-pbip.sh
```

### 2. Mock Users Setup (Testing)
```sql
-- Run in your Fabric Warehouse
-- This creates the security table and mock users
\i setup-security-table.sql
```

Mock users will be available for testing:
- `alice@mock.local` - Regional Manager (NCR)
- `bob@mock.local` - Store Manager (Store 1001)
- `carol@mock.local` - Category Manager (Tobacco)
- `dave@mock.local` - Data Analyst (All data)

### 3. Environment Configuration
Update connection tokens in `datasources.tmdl`:
```tmdl
connectionString: "Provider=MSOLEDBSQL;Data Source=<FAB_SQL_SERVER>;Initial Catalog=<FAB_SQL_DB>"
```

Replace with your Fabric Warehouse details:
- `<FAB_SQL_SERVER>`: Your Fabric Warehouse SQL endpoint
- `<FAB_SQL_DB>`: Your Fabric Warehouse database name

### 4. Fabric Deployment
```bash
# Commit changes
git add .
git commit -m "Initial Scout Power BI setup"
git push origin main

# Fabric will auto-deploy:
# 1. Shared dataset from pbip-model-core
# 2. 5 report templates
# 3. Theme and security policies
```

## 📊 Report Templates

### 1. Executive Dashboard
**Audience**: C-Suite, Senior Management
**Content**: Strategic KPIs, trends, regional performance
- Key metrics cards (Sales, Growth, Margin, Store count)
- Sales trend with moving averages
- Regional performance donut chart
- Category mix and premium analysis

### 2. Sales Analysis
**Audience**: Sales Managers, Regional Managers
**Content**: Detailed sales performance and trends
- Monthly/daily/hourly sales patterns
- Brand and category performance
- Premium vs standard analysis
- Product velocity analysis

### 3. Store Performance
**Audience**: Store Managers, Regional Managers
**Content**: Individual store metrics and comparisons
- Store ranking and performance matrix
- Geographic performance analysis
- Store efficiency metrics

### 4. Category Insights
**Audience**: Category Managers, Brand Managers
**Content**: Deep dive into category and brand performance
- Nielsen category hierarchy analysis
- Brand loyalty and penetration metrics
- Cross-category effects

### 5. Predictive Analytics
**Audience**: Data Scientists, Business Analysts
**Content**: ML predictions and forecasting insights
- Model accuracy and confidence scores
- Demand forecasting and volatility
- Market trends and seasonal factors

## 🔐 Security Model

### Row-Level Security Roles

| Role | Access Scope | Filter Logic |
|------|-------------|-------------|
| **Regional Manager - NCR** | NCR region only | `[RegionName] = "NCR"` |
| **Regional Manager - Luzon** | Luzon provinces | `[RegionName] IN {...}` |
| **Regional Manager - Visayas** | Visayas provinces | `[RegionName] IN {...}` |
| **Regional Manager - Mindanao** | Mindanao provinces | `[RegionName] IN {...}` |
| **Store Manager** | Single store | `[StoreID] = VALUE(RIGHT(USERNAME(), 4))` |
| **Category Manager - Tobacco** | Tobacco products | `[IsTobacco] = TRUE` |
| **Category Manager - Laundry** | Laundry products | `[IsLaundry] = TRUE` |
| **Premium Brand Manager** | Premium brands | `[IsPremium] = TRUE` |
| **Data Analyst** | Read-only all data | No filter |
| **Business Intelligence** | Read + refresh | No filter |
| **Finance Team** | Financial metrics | No filter |
| **Executive Dashboard** | High-level summary | Recent data only |

### Dynamic RLS with Security Table
Users are mapped via the `security.assignments` table in Fabric Warehouse:

| Email | Role | Access Scope |
|-------|------|-------------|
| `maria.santos@scout.com` | region_manager | NCR region |
| `store.manager.1001@scout.com` | store_manager | Store 1001 only |
| `tobacco.manager@scout.com` | category_manager | Tobacco products |

### Mock Users for Testing
Pre-configured test users (use with "View as" feature):

| Type | Email | Role | Expected Access |
|------|-------|------|----------------|
| **Regional** | `alice@mock.local` | Dynamic Regional Manager | NCR only |
| **Store** | `bob@mock.local` | Dynamic Store Manager | Store 1001 only |
| **Category** | `carol@mock.local` | Dynamic Category Manager | Tobacco only |
| **Analyst** | `dave@mock.local` | Data Analyst | All data |

## ⚡ Performance Optimization

### Incremental Refresh Policies

| Table | Incremental Period | Rolling Window | Schedule |
|-------|-------------------|----------------|----------|
| **mart_tx** | Last 30 days | 2 years | Daily 6:00 AM |
| **platinum_predictions** | Last 7 days | 1 year | Daily 7:00 AM |
| **Dimensions** | Full refresh | N/A | Weekly Sunday 5:00 AM |

### Query Optimization
- **Star Schema**: Optimized relationships with fact table at center
- **Gold Layer**: Pre-aggregated data from Fabric Warehouse
- **Partitioning**: Date-based partitioning for large fact tables
- **Indexes**: Fabric Warehouse indexes on join keys

## 🛠️ Development Workflow

### Local Development
```bash
# 1. Make changes to TMDL files
vi pbip-model-core/model/measures.tmdl

# 2. Validate changes
./validate-pbip.sh

# 3. Test in Power BI Desktop
# Open pbip-model-core/.pbip/definition.pbir

# 4. Commit and deploy
git add .
git commit -m "feat: add new sales measures"
git push origin main
```

### Environment Promotion
```bash
# Development → Staging
git checkout staging
git merge main
git push origin staging

# Staging → Production
git checkout production
git merge staging
git push origin production
```

### CI/CD Pipeline
```yaml
# .github/workflows/powerbi-validation.yml
name: Power BI Validation
on: [push, pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Validate PBIP Structure
        run: ./validate-pbip.sh
      - name: Check Theme Syntax
        run: jq empty scout-theme.json
```

## 📈 Data Architecture

### Medallion Architecture Integration
```
Bronze (Raw) → Silver (Cleaned) → Gold (Enriched) → Platinum (Analytics)
                                      ↓
                              Power BI Semantic Model
                                      ↓
                              5 Specialized Reports
```

### Key Tables

| Layer | Table | Purpose | Refresh |
|-------|-------|---------|---------|
| **Gold** | `dim_date` | Calendar dimension | Weekly |
| **Gold** | `dim_store` | Store hierarchy | Weekly |
| **Gold** | `dim_brand` | Brand attributes | Weekly |
| **Gold** | `dim_category` | Nielsen categories | Weekly |
| **Gold** | `mart_tx` | Transaction facts | Daily |
| **Platinum** | `predictions` | ML predictions | Daily |

### Data Quality Gates
1. **Schema Validation**: Column presence and data types
2. **Business Rules**: Revenue > 0, dates within range
3. **Completeness**: <5% null values in key columns
4. **Consistency**: Cross-table referential integrity
5. **Freshness**: Data within 24 hours of source

## 🎨 Theming & Branding

### Color Palette
- **Primary**: #0066CC (TBWA Blue)
- **Secondary**: #FF6B35 (Accent Orange)
- **Success**: #28A745 (Green)
- **Warning**: #FFC107 (Yellow)
- **Danger**: #DC3545 (Red)

### Typography
- **Font Family**: Segoe UI (consistent with Microsoft ecosystem)
- **Sizes**: Title (20px), Subtitle (16px), Body (12px), KPI (24px)
- **Currency**: ₱ (Philippine Peso)

### Accessibility
- **Color Blind Safe**: High contrast ratios
- **Screen Reader**: Semantic markup
- **Keyboard Navigation**: Full accessibility

## 🔧 Troubleshooting

### Common Issues

#### 1. Connection Errors
```
Error: Cannot connect to Fabric Warehouse
Solution: Check datasources.tmdl connection string and credentials
```

#### 2. RLS Not Working
```
Error: Users see all data despite role assignment
Solution: Verify role filters and username mapping logic
```

#### 3. Incremental Refresh Failures
```
Error: Incremental refresh policy fails
Solution: Check date column format and policy configuration
```

#### 4. Theme Not Applied
```
Error: Reports don't use Scout theme
Solution: Ensure scout-theme.json is valid and referenced correctly
```

### Validation Commands
```bash
# Full validation
./validate-pbip.sh

# Check specific components
jq empty scout-theme.json                    # Theme syntax
grep -c "measure " */model/measures.tmdl     # Measure count
find . -name "*.tmdl" | xargs grep "table "  # Table definitions
```

### Performance Monitoring
```sql
-- Check refresh times
SELECT
    TableName,
    LastRefresh,
    RefreshDuration,
    RowCount
FROM SYSTEMRESTRICTSCHEMA('$SYSTEM.TMSCHEMA_PARTITIONS')

-- Monitor query performance
SELECT
    QUERY_HASH,
    DURATION_MS,
    CPU_TIME_MS,
    QUERY_TEXT
FROM $SYSTEM.DISCOVER_SESSIONS
WHERE SESSION_ID = SESSION_ID()
```

## 📚 Additional Resources

### Documentation
- [Power BI PBIP Documentation](https://docs.microsoft.com/power-bi/developer/projects/)
- [TMDL Language Reference](https://docs.microsoft.com/analysis-services/tmsl/)
- [Fabric Git Integration](https://docs.microsoft.com/fabric/cicd/git-integration/)

### Training Materials
- [DAX Patterns](https://www.daxpatterns.com/)
- [Power BI Best Practices](https://docs.microsoft.com/power-bi/guidance/)
- [Row-Level Security Guide](https://docs.microsoft.com/power-bi/admin/service-admin-rls/)

### Support Contacts
- **Data Team**: data-team@tbwa.com
- **IT Support**: it-support@tbwa.com
- **Business Intelligence**: bi-team@tbwa.com

---

## 🏷️ Metadata

**Created**: 2025-01-02
**Version**: 1.0
**Authors**: TBWA Data Team
**Last Updated**: 2025-01-02
**License**: Internal Use Only
**Tags**: powerbi, fabric, philippines, retail, analytics