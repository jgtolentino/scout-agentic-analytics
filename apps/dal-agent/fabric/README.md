# Scout v7 Microsoft Fabric Migration Bundle

Complete Microsoft Fabric implementation with Medallion Architecture for Scout Analytics Platform.

## 🚀 Quick Start

1. **Replace Configuration Tokens**
   ```bash
   # Find and replace in all files:
   <LAKEHOUSE_SQL_NAME> → your-lakehouse-sql-endpoint-name
   <WAREHOUSE_NAME> → your-fabric-warehouse-name
   <WORKSPACE_NAME> → your-fabric-workspace-name
   ```

2. **Deploy Warehouse Schema**
   ```sql
   -- Execute in your Fabric Warehouse
   warehouse/01_warehouse_ddl.sql
   warehouse/02_warehouse_views.sql
   ```

3. **Run ETL Notebooks**
   ```
   notebooks/01_bronze_ingestion.ipynb    (Data ingestion from Azure SQL)
   notebooks/02_silver_transformation.ipynb  (Data cleansing & modeling)
   notebooks/03_gold_aggregations.ipynb   (Analytics & ML features)
   ```

4. **Deploy Power BI Model**
   ```
   powerbi/semantic_model.json  (Import to Power BI)
   powerbi/measures.dax         (Copy DAX measures)
   ```

5. **Validate Deployment**
   ```sql
   -- Execute in Warehouse to validate data quality
   validation/data_quality_checks.sql
   ```

## 📋 Architecture Overview

### Medallion Architecture Implementation

```
Azure SQL Database → Fabric Lakehouse → Fabric Warehouse → Power BI
    (Source)           (Bronze/Silver)     (Gold/Platinum)    (Analytics)
```

| Layer | Location | Purpose | Technology |
|-------|----------|---------|------------|
| **Bronze** | Lakehouse | Raw data ingestion | Delta Tables |
| **Silver** | Lakehouse | Cleansed & transformed | Delta Tables |
| **Gold** | Warehouse | Analytics-ready views | SQL Views |
| **Platinum** | Warehouse | ML models & predictions | SQL Tables |

### Key Design Principles

- **Single Date Authority**: `canonical.SalesInteractionFact.transaction_date` is the ONLY authoritative date source
- **JSON Explosion**: `PayloadTransactions.payload_json` items array exploded to SKU level
- **Dimensional Modeling**: Star schema with proper fact/dimension relationships
- **Nielsen Integration**: L1/L2/L3 category mappings for standardized product classification

## 📁 File Structure

```
fabric/
├── warehouse/                 # Warehouse DDL and Views
│   ├── 01_warehouse_ddl.sql   # Gold/Platinum schema creation
│   └── 02_warehouse_views.sql # Cross-database views from Warehouse to Lakehouse
├── notebooks/                 # PySpark ETL Notebooks
│   ├── 01_bronze_ingestion.ipynb     # Raw data ingestion
│   ├── 02_silver_transformation.ipynb # Data cleansing & modeling
│   └── 03_gold_aggregations.ipynb    # Analytics & ML features
├── powerbi/                   # Power BI Assets
│   ├── semantic_model.json    # Power BI semantic model definition
│   └── measures.dax          # 60+ DAX measures for analytics
├── validation/                # Quality Assurance
│   └── data_quality_checks.sql # Comprehensive validation script
├── config.json               # Configuration and deployment guide
└── README.md                 # This file
```

## 🔧 Configuration

### Prerequisites

1. **Microsoft Fabric Workspace** with:
   - Lakehouse for Bronze/Silver data
   - Warehouse for Gold/Platinum serving
   - Proper permissions configured

2. **Azure SQL Database Access**:
   - Server: `sqltbwaprojectscoutserver.database.windows.net`
   - Database: `SQL-TBWA-ProjectScout-Reporting-Prod`
   - Authentication: Managed Identity (recommended)

3. **Source Tables**:
   - `canonical.SalesInteractionFact` (12,192 transactions)
   - `dbo.PayloadTransactions` (JSON with items array)
   - `dbo.Stores`, `dbo.Brands`, `dbo.Categories`

### Token Replacement

Before deployment, replace these tokens in all files:

| Token | Description | Example |
|-------|-------------|---------|
| `<LAKEHOUSE_SQL_NAME>` | Lakehouse SQL endpoint name | `scout-lakehouse-sql` |
| `<WAREHOUSE_NAME>` | Fabric Warehouse name | `scout-warehouse` |
| `<WORKSPACE_NAME>` | Fabric Workspace name | `scout-analytics` |

## 🏗️ Implementation Guide

### Phase 1: Infrastructure Setup (Day 1-3)

1. **Create Fabric Workspace**
2. **Create Lakehouse** and configure permissions
3. **Create Warehouse** and configure access
4. **Configure Azure SQL connectivity** with Managed Identity

### Phase 2: Data Engineering (Day 4-8)

1. **Deploy Warehouse DDL**
   ```sql
   -- Execute in Fabric Warehouse SQL endpoint
   warehouse/01_warehouse_ddl.sql
   warehouse/02_warehouse_views.sql
   ```

2. **Test Bronze Ingestion**
   - Import `notebooks/01_bronze_ingestion.ipynb` to Fabric
   - Configure Azure SQL connection parameters
   - Execute and validate Bronze tables

3. **Test Silver Transformation**
   - Import `notebooks/02_silver_transformation.ipynb`
   - Execute JSON parsing and dimensional modeling
   - Validate Silver tables and data quality

4. **Test Gold Aggregations**
   - Import `notebooks/03_gold_aggregations.ipynb`
   - Execute advanced analytics and ML features
   - Validate Gold analytics tables

### Phase 3: Analytics Development (Day 9-11)

1. **Deploy Power BI Semantic Model**
   - Import `powerbi/semantic_model.json`
   - Configure data source connections
   - Test table relationships

2. **Import DAX Measures**
   - Copy content from `powerbi/measures.dax`
   - Paste into Power BI Desktop
   - Validate measure calculations

3. **Create Reports and Dashboards**
   - Executive Summary dashboard
   - Store Performance analytics
   - Customer segmentation analysis
   - Product intelligence reports

### Phase 4: Testing & Deployment (Day 12)

1. **Execute Data Quality Validation**
   ```sql
   validation/data_quality_checks.sql
   ```

2. **User Acceptance Testing**
3. **Production Go-Live**

## 📊 Data Model

### Fact Tables

- **fact_transactions**: Core transaction data with single date authority
- **fact_transaction_items**: SKU-level transaction items from JSON explosion

### Dimension Tables

- **dim_date**: Complete date dimension with business calendars
- **dim_time**: Time dimension with business hour categorization
- **dim_store**: Store master with geographical hierarchy
- **dim_brand**: Brand master with Nielsen category mappings
- **dim_category**: Product category hierarchy

### Key Metrics Available

- Revenue analytics (Total, MTD, YTD, Growth)
- Customer analytics (Unique, Retention, Segmentation)
- Store performance (Rankings, Efficiency, Regional)
- Product intelligence (Nielsen categories, Market basket)
- Operational metrics (Peak hours, Conversion rates)

## 🔍 Data Quality & Validation

### Automated Validation Checks

The `validation/data_quality_checks.sql` script validates:

- **Data Freshness**: Latest transaction dates
- **Cross-Layer Consistency**: Bronze → Silver → Gold consistency
- **Business Rules**: Transaction amounts, basket sizes, customer data
- **Data Lineage**: canonical_tx_id consistency across layers
- **Nielsen Categories**: Product classification coverage
- **Performance Indicators**: Recent activity and system health

### Quality Thresholds

- Data freshness: ≤ 1 day for fresh, ≤ 7 days acceptable
- Cross-layer consistency: ≥ 95% matching transactions
- Revenue variance: ≤ 10% between layers
- Business rules: 100% compliance for critical fields

## 🚨 Monitoring & Alerts

### Key Performance Indicators

- **Business Metrics**: Revenue, Transactions, Customers
- **Data Quality**: Completeness, Accuracy, Timeliness
- **System Health**: ETL Success Rates, Data Freshness
- **User Adoption**: Dashboard Views, Report Usage

### Alert Configuration

- **Critical**: ETL pipeline failures, data corruption
- **High**: Data quality degradation, missing data
- **Medium**: Business metric anomalies
- **Low**: Performance degradation

## 🔐 Security & Compliance

### Access Control

- **Bronze Layer**: Data Engineers only
- **Silver Layer**: Data Engineers + Analysts
- **Gold Layer**: All authorized users
- **Platinum Layer**: Data Scientists + ML Engineers

### Data Classification

- **Personal Data**: facial_id (anonymized)
- **Business Confidential**: Transaction details
- **Internal Use**: Store locations, operational data
- **General Business**: Aggregated metrics and reports

## 🎯 Success Metrics

### Technical Success

- ✅ All ETL notebooks execute successfully
- ✅ Data quality validation passes all checks
- ✅ Power BI reports load within 5 seconds
- ✅ Cross-layer data consistency > 95%

### Business Success

- 📈 Real-time visibility into store performance
- 🎯 Customer segmentation and persona insights
- 📊 Nielsen category analysis and market intelligence
- 🚀 ML-ready features for predictive analytics

## 🆘 Troubleshooting

### Common Issues

1. **Connection Failures to Azure SQL**
   - Verify Managed Identity configuration
   - Check network connectivity and firewall rules
   - Validate SQL Server authentication

2. **Cross-Database View Errors**
   - Ensure Lakehouse and Warehouse are in same workspace
   - Verify cross-item queries are enabled in tenant
   - Check permissions between Warehouse and Lakehouse

3. **Data Quality Issues**
   - Run validation script to identify specific problems
   - Check source data for changes in schema or volume
   - Validate business rules and thresholds

4. **Power BI Performance Issues**
   - Optimize DAX measures for performance
   - Consider DirectQuery vs Import mode
   - Implement aggregation tables for large datasets

### Support Contacts

- **Data Engineering**: ETL pipelines, data quality
- **Analytics Team**: Power BI reports, DAX measures
- **Infrastructure**: Fabric workspace, connectivity
- **Business Users**: Requirements, validation, testing

## 📈 Future Enhancements

### Platinum Layer Extensions

- **Predictive Models**: Customer lifetime value, churn prediction
- **Market Basket AI**: Advanced recommendation engine
- **Anomaly Detection**: Real-time fraud and outlier detection
- **Demand Forecasting**: Store-level inventory optimization

### Advanced Analytics

- **Real-time Streaming**: Event-driven analytics
- **Geospatial Analysis**: Location-based insights
- **Sentiment Analysis**: Emotional state modeling
- **A/B Testing Framework**: Campaign effectiveness measurement

---

## 📝 Deployment Checklist

- [ ] Replace all configuration tokens
- [ ] Create Fabric workspace and resources
- [ ] Execute Warehouse DDL scripts
- [ ] Test Bronze ingestion notebook
- [ ] Test Silver transformation notebook
- [ ] Test Gold aggregations notebook
- [ ] Deploy Power BI semantic model
- [ ] Import DAX measures
- [ ] Execute data quality validation
- [ ] Configure ETL scheduling
- [ ] Create monitoring dashboards
- [ ] Conduct user acceptance testing
- [ ] Production go-live

**Estimated Total Time**: 12 days (97 hours)

---

*This migration bundle provides a complete, production-ready Microsoft Fabric implementation for Scout Analytics with comprehensive data quality validation, business intelligence capabilities, and ML-ready features.*