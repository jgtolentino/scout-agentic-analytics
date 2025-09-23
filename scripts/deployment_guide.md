# Scout RAG-CAG Analytics Deployment Guide

## Overview
Complete deployment guide for Scout's RAG-CAG analytics platform with Azure Data Studio, Power BI, and intelligent query processing.

## 🚀 Quick Start (5-Minute Setup)

### 1. Database Security
```bash
# Execute in Bruno
azure/scout_reader_security.sql
```

### 2. Install Dependencies
```bash
cd /Users/tbwa/scout-v7
pip install -r requirements_rag_cag.txt
```

### 3. Create Knowledge Corpus
```bash
python scripts/knowledge_indexer.py --create
```

### 4. Test RAG-CAG System
```bash
python scripts/rag_cag_tools.py --query "time analysis last 14 days"
```

## 📊 Dashboard Setup

### Azure Data Studio
1. Copy settings to ADS:
   ```bash
   cp config/azure_data_studio_settings.json ~/.azuredatastudio/User/settings.json
   ```

2. Create query directory:
   ```bash
   mkdir -p ~/.azuredatastudio/queries/scout_v7_queries
   cp azure_data_studio_queries/*.sql ~/.azuredatastudio/queries/scout_v7_queries/
   ```

3. Connect to database and refresh dashboard

### Power BI Desktop
1. Install Power BI Desktop
2. Import template: `powerbi/scout_analytics_template.json`
3. Configure data sources (PostgreSQL primary, Azure SQL fallback)
4. Publish to Power BI Service

## 🔧 Complete Implementation

### Phase 1: Infrastructure

#### 1.1 Database Setup
```sql
-- Execute via Bruno
exec azure/scout_reader_security.sql

-- Verify access
SELECT COUNT(*) FROM public.scout_gold_transactions_flat;
SELECT COUNT(*) FROM dbo.Stores WHERE StoreID IN (102,103,104,109,110,112);
```

#### 1.2 Python Environment
```bash
# Install core dependencies
pip install psycopg2-binary pyodbc sentence-transformers
pip install scikit-learn pandas pyyaml numpy

# Install optional components
pip install chromadb  # For vector database (production)
pip install streamlit  # For web interface (optional)
```

### Phase 2: Knowledge Base

#### 2.1 Create Knowledge Corpus
```bash
# Index all components
python scripts/knowledge_indexer.py --create --source all

# Verify indexing
python scripts/knowledge_indexer.py --stats
```

#### 2.2 Test Knowledge Search
```bash
# Test template search
python scripts/knowledge_indexer.py --search "brand preferences by age"

# Test KPI search
python scripts/knowledge_indexer.py --search "transaction volume metrics"
```

### Phase 3: RAG-CAG Engine

#### 3.1 Test Core Functionality
```bash
# Test natural language queries
python scripts/rag_cag_tools.py --query "Which categories peak in the evening?"
python scripts/rag_cag_tools.py --query "Payment method preferences by basket size"
python scripts/rag_cag_tools.py --query "Gender shopping patterns last 30 days"
```

#### 3.2 Validate Templates
```bash
# Test specific template
python scripts/rag_cag_tools.py --template time_of_day_category --params '{"date_from": "2025-09-01"}'

# Validate template syntax
python scripts/rag_cag_tools.py --template age_bracket_brand --validate-only
```

### Phase 4: Quality Framework

#### 4.1 Run Validation Suite
```bash
# Comprehensive validation
python scripts/validation_framework.py --comprehensive

# Specific validations
python scripts/validation_framework.py --quality-check
python scripts/validation_framework.py --parity-check
```

#### 4.2 Monitor System Health
```bash
# System monitoring
python scripts/validation_framework.py --monitor

# Continuous monitoring (background)
nohup python scripts/validation_framework.py --monitor --continuous > monitor.log 2>&1 &
```

## 🎯 Usage Examples

### Natural Language Queries
```bash
# Time-based analysis
python scripts/rag_cag_tools.py --query "peak shopping hours last week"
python scripts/rag_cag_tools.py --query "weekend vs weekday patterns store 102"

# Customer demographics
python scripts/rag_cag_tools.py --query "age groups prefer which brands"
python scripts/rag_cag_tools.py --query "male vs female shopping times"

# Business intelligence
python scripts/rag_cag_tools.py --query "substitution reasons by category"
python scripts/rag_cag_tools.py --query "payment method correlations with basket size"

# Store performance
python scripts/rag_cag_tools.py --query "top performing stores last month"
python scripts/rag_cag_tools.py --query "store comparison Quezon City vs Manila"
```

### Direct Template Execution
```bash
# Time analysis
python scripts/rag_cag_tools.py --template time_of_day_category \
  --params '{"date_from": "2025-09-01", "date_to": "2025-09-15", "category": "Snacks"}'

# Demographics analysis
python scripts/rag_cag_tools.py --template age_bracket_brand \
  --params '{"date_from": "2025-09-01", "brand": "Coca-Cola"}'

# Payment analysis
python scripts/rag_cag_tools.py --template basket_size_payment \
  --params '{"date_from": "2025-09-01", "store_id": 102}'
```

## 📈 Dashboard Operations

### Azure Data Studio
- **Access**: Connect to PostgreSQL/Azure SQL
- **Dashboards**: Database overview with live tiles
- **Export**: Click tiles → View Data → Save as CSV
- **Refresh**: Automatic every 15 minutes

### Power BI
- **Reports**: 4 pre-built pages (Transactions, Cross-tab, Demographics, Stores)
- **Filters**: Date range, store selection, category filtering
- **Export**: Click "..." on visuals → Export data
- **Refresh**: Daily at 6:00 AM Asia/Manila

## 🔍 Troubleshooting

### Connection Issues

#### PostgreSQL Connection Failed
```bash
# Test connection
python -c "
import psycopg2
conn = psycopg2.connect(
    host='aws-0-ap-southeast-1.pooler.supabase.com',
    port=6543,
    database='postgres',
    user='postgres.cxzllzyxwpyptfretryc',
    password='Postgres_26'
)
print('PostgreSQL connection successful')
"
```

#### Azure SQL Connection Failed
```bash
# Test Azure SQL
python -c "
import pyodbc
conn = pyodbc.connect(
    'DRIVER={ODBC Driver 18 for SQL Server};'
    'SERVER=sql-tbwa-projectscout-reporting-prod.database.windows.net;'
    'DATABASE=SQL-TBWA-ProjectScout-Reporting-Prod;'
    'UID=scout_reader;'
    'PWD=Scout_Analytics_2025!;'
    'TrustServerCertificate=yes;'
)
print('Azure SQL connection successful')
"
```

### Data Issues

#### No Query Results
1. Check date filters: `--params '{"date_from": "2025-09-01"}'`
2. Verify NCR location filter in data
3. Confirm store IDs exist: 102, 103, 104, 109, 110, 112
4. Test with broader parameters

#### Validation Failures
```bash
# Debug data quality
python scripts/validation_framework.py --quality-check --engine postgresql

# Check system health
python scripts/validation_framework.py --monitor --engine postgresql

# Validate parity
python scripts/validation_framework.py --parity-check --engine postgresql
```

### Performance Issues

#### Slow Query Execution
1. **Reduce date range**: Use smaller time windows for testing
2. **Add filters**: Specify store_id or category to reduce data volume
3. **Check engine**: Try both postgresql and azuresql engines
4. **Monitor resources**: Check database CPU/memory usage

#### Memory Issues
```bash
# Monitor memory usage
python scripts/rag_cag_tools.py --query "simple query" --engine postgresql
```

### Template Issues

#### Template Not Found
```bash
# List available templates
python scripts/rag_cag_tools.py

# Rebuild knowledge corpus
python scripts/knowledge_indexer.py --update --source templates
```

#### Invalid Parameters
```bash
# Validate template parameters
python scripts/rag_cag_tools.py --template time_of_day_category --validate-only
```

## 🔧 Configuration

### Environment Variables
```bash
# PostgreSQL (Primary)
export SUPABASE_HOST=aws-0-ap-southeast-1.pooler.supabase.com
export SUPABASE_PORT=6543
export SUPABASE_DB=postgres
export SUPABASE_USER=postgres.cxzllzyxwpyptfretryc
export SUPABASE_PASS=Postgres_26

# Azure SQL (Fallback)
export AZURE_SQL_SERVER=sql-tbwa-projectscout-reporting-prod.database.windows.net
export AZURE_SQL_DB=SQL-TBWA-ProjectScout-Reporting-Prod
export AZURE_SQL_USER=scout_reader
export AZURE_SQL_PASS=Scout_Analytics_2025!
```

### Custom Templates
1. Create SQL file in `sql_templates/`
2. Add entry to `sql_templates/template_registry.yaml`
3. Rebuild knowledge corpus: `python scripts/knowledge_indexer.py --update`

### Knowledge Customization
```python
# Add custom KPI definitions
kpis = [{
    'kpi_id': 'custom_metric',
    'name': 'Custom Metric',
    'definition': 'Your definition here',
    'calculation': 'Your SQL calculation',
    'business_context': 'Business meaning'
}]
# Add to knowledge_indexer.py and rebuild
```

## 📊 Monitoring & Maintenance

### Daily Health Checks
```bash
# Automated health check
python scripts/validation_framework.py --monitor --output daily_health.json

# Review system status
cat daily_health.json | jq '.overall_status'
```

### Weekly Validation
```bash
# Comprehensive weekly validation
python scripts/validation_framework.py --comprehensive --output weekly_validation.json

# Archive results
mkdir -p validation_archive
mv weekly_validation.json "validation_archive/validation_$(date +%Y%m%d).json"
```

### Knowledge Corpus Updates
```bash
# Update templates when modified
python scripts/knowledge_indexer.py --update --source templates

# Backup corpus
python scripts/knowledge_indexer.py --export knowledge_backup.json
```

## 🎉 Success Metrics

### System Health
- ✅ **Uptime**: >99.9% availability
- ✅ **Response Time**: <2s average query execution
- ✅ **Data Freshness**: <60 minutes behind real-time
- ✅ **Query Success Rate**: >95% successful executions

### Data Quality
- ✅ **Completeness**: >95% for required fields
- ✅ **Accuracy**: >95% business rule compliance
- ✅ **Consistency**: <5% variance between flat/crosstab views
- ✅ **Coverage**: All 6 Scout stores represented

### Business Impact
- ✅ **Query Coverage**: >80% questions answered by templates
- ✅ **User Adoption**: Active usage across business teams
- ✅ **Decision Support**: Reduced ad-hoc analysis requests
- ✅ **Evidence-Based**: All insights backed by verifiable data

## 🔮 Next Steps

### Enhanced Features
1. **Real-time Streaming**: Live transaction processing
2. **Predictive Analytics**: ML-powered forecasting
3. **Mobile Dashboards**: Responsive mobile interface
4. **Voice Queries**: Natural language voice interface
5. **Automated Insights**: Proactive anomaly detection

### Integration Expansion
1. **Microsoft Teams**: Bot integration for queries
2. **Slack**: Analytics bot for team channels
3. **Email Reports**: Automated daily/weekly summaries
4. **API Gateway**: REST API for external integrations
5. **Webhook Notifications**: Alert systems for thresholds

## 📞 Support

### Documentation
- **Template Registry**: `sql_templates/template_registry.yaml`
- **API Reference**: `scripts/rag_cag_tools.py --help`
- **Validation Guide**: `scripts/validation_framework.py --help`

### Logs and Diagnostics
- **Application Logs**: Check Python script outputs
- **Database Logs**: Review Bruno execution logs
- **System Health**: Monitor validation framework outputs
- **Performance Metrics**: Track query execution times

### Escalation
1. **Level 1**: Check troubleshooting guide above
2. **Level 2**: Review system health and validation outputs
3. **Level 3**: Contact analytics team with logs and error details

---

🎯 **Ready for Production**: This RAG-CAG system is now deployed and ready to provide evidence-based analytics for Scout business intelligence!