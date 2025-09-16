# Scout Analytics ETL Pipeline

Production-grade ETL pipeline for TBWA Scout Analytics platform with automated data processing, quality validation, and observability.

## Architecture Overview

**Medallion Architecture**: Bronze → Silver → Gold → Platinum

- **Bronze**: Raw ingestion with PII masking and contract validation
- **Silver**: Cleansed, standardized, and deduplicated data
- **Gold**: Business-ready aggregations and KPIs
- **Platinum**: ML predictions and advanced analytics

**Core Components**:
- **Bruno Executor**: Deterministic ETL orchestration engine
- **Temporal**: Workflow orchestration with retries and state management
- **dbt**: SQL transformations with testing and documentation
- **Great Expectations**: Data quality validation framework
- **OpenTelemetry**: Observability and metrics collection

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Python 3.11+
- PostgreSQL client
- Supabase access credentials

### 1. Environment Setup
```bash
# Copy environment template
cp etl/.env.production.example etl/.env.production

# Edit with your credentials
vim etl/.env.production
```

### 2. Deploy Infrastructure
```bash
# Run deployment script
./scripts/deploy-etl.sh deploy

# Or step-by-step:
./scripts/deploy-etl.sh start    # Start infrastructure
./scripts/deploy-etl.sh test     # Run validation tests
```

### 3. Access Monitoring
- **Temporal UI**: http://localhost:8088
- **Prometheus**: http://localhost:9090  
- **Grafana**: http://localhost:3001 (admin/admin)
- **Jaeger Tracing**: http://localhost:16686

## Usage

### Bronze Data Ingestion
```bash
cd etl

# Single batch ingestion
python bruno_executor.py bronze-ingestion \
    --source azure_data.interactions \
    --target scout.bronze_transactions \
    --batch-size 1000

# Dry run for testing
python bruno_executor.py bronze-ingestion \
    --source azure_data.interactions \
    --target scout.bronze_transactions \
    --dry-run
```

### dbt Transformations
```bash
# Run all models
python bruno_executor.py dbt-run --layer all

# Run specific layer
python bruno_executor.py dbt-run --layer silver
python bruno_executor.py dbt-run --layer gold

# Run specific models
python bruno_executor.py dbt-run --models silver_interactions gold_executive_kpis
```

### Full Pipeline Execution
```bash
# End-to-end pipeline
python bruno_executor.py full-pipeline

# With specific partition
python bruno_executor.py full-pipeline --partition-key 2025-01-16
```

### Data Quality Validation
```bash
# Run quality checks
python bruno_executor.py quality-check \
    --expectation-suite azure_interactions_bronze \
    --data-asset azure_data.interactions

# Generate data docs
great_expectations docs build
```

## Data Flow

### 1. Bronze Ingestion (Azure → Supabase)
```
Azure SQL (159,897 records)
    ↓ CDC/Incremental
Contract Validation (JSON Schema)
    ↓ PII Masking
Bronze Tables (scout.bronze_*)
    ↓ OpenLineage Events
Quality Gates (Great Expectations)
```

### 2. Silver Transformations (dbt)
```
Bronze Tables
    ↓ Data Cleansing
Silver Models (scout.silver_*)
    ↓ Standardization & Deduplication
Quality Tests (dbt tests)
    ↓ Documentation Generation
```

### 3. Gold Aggregations (dbt)
```
Silver Tables
    ↓ Business Logic
Gold KPIs (scout.gold_*)
    ↓ Executive Dashboards
Platinum ML Features
    ↓ Predictive Models
```

## Monitoring & Observability

### Key Metrics
- **Pipeline Health**: Success rate, error count, processing time
- **Data Quality**: Expectation pass rate, anomaly detection
- **Performance**: Throughput, latency, resource utilization
- **Business KPIs**: Customer interactions, store performance, trends

### Alerting Rules
- **Critical**: Pipeline failure, data quality below 95%
- **Warning**: Processing delay >15min, quality 90-95%
- **Info**: Successful completion, new data detected

### Log Aggregation
```bash
# View real-time logs
docker-compose -f docker-compose.etl.yml logs -f bruno-worker

# Check Temporal workflows
curl http://localhost:8088/api/v1/workflows
```

## Data Contracts

### Bronze Layer Schema
```json
{
  "type": "object",
  "required": ["InteractionID", "TransactionDate"],
  "properties": {
    "InteractionID": {"type": "string"},
    "StoreID": {"type": "integer", "minimum": 1},
    "TransactionDate": {"type": "string", "format": "date-time"},
    "FacialID": {"type": "string", "pattern": "^[A-Za-z0-9_-]+$"},
    "Age": {"type": "integer", "minimum": 0, "maximum": 120}
  }
}
```

### PII Masking Rules
- **Email**: `***@***.com`
- **Phone**: `***-***-****`
- **Credit Card**: `****-****-****-1234`
- **SSN**: `***-**-****`

## Security & Compliance

### Data Protection
- **Encryption at Rest**: AES-256 for sensitive fields
- **Encryption in Transit**: TLS 1.2+ for all connections
- **Access Control**: Role-based permissions in Supabase
- **Audit Logging**: All operations logged with user context

### PII Handling
- **Detection**: Regex-based identification of sensitive data
- **Masking**: Deterministic masking for consistency
- **Retention**: 7-year retention with automated purging
- **Compliance**: GDPR/CCPA compliant data handling

## Troubleshooting

### Common Issues

**1. Database Connection Failed**
```bash
# Test connectivity
psql "$SUPABASE_DB_URL" -c "SELECT 1"

# Check credentials
echo $POSTGRES_PASSWORD
```

**2. Temporal Worker Not Starting**
```bash
# Check Temporal server
curl http://localhost:7233/api/v1/namespaces

# Restart services
docker-compose -f docker-compose.etl.yml restart temporal
```

**3. dbt Models Failing**
```bash
# Debug dbt connection
cd dbt-scout && dbt debug

# Run with verbose logging
dbt run --debug
```

**4. Quality Validation Errors**
```bash
# Check expectation suite
great_expectations suite list

# Run specific checkpoint
great_expectations checkpoint run azure_interactions_bronze
```

### Performance Tuning

**1. Increase Batch Size**
```python
# In bruno_executor.py
BATCH_SIZE = 5000  # Default: 1000
```

**2. Parallel Processing**
```yaml
# In docker-compose.etl.yml
bruno-worker:
  environment:
    - BRUNO_MAX_WORKERS=8  # Default: 4
```

**3. Memory Optimization**
```python
# Use chunked processing for large datasets
for chunk in pd.read_sql(query, conn, chunksize=10000):
    process_chunk(chunk)
```

## Development

### Local Development Setup
```bash
# Install dependencies
cd etl && pip install -r requirements.txt

# Start development environment
docker-compose -f docker-compose.etl.yml up -d

# Run tests
pytest tests/
```

### Adding New Data Sources
1. **Create Contract**: Define JSON schema in `etl/contracts/`
2. **Add dbt Models**: Create Bronze/Silver/Gold models
3. **Update Workflows**: Extend Temporal workflows
4. **Add Quality Checks**: Create Great Expectations suite

### Code Quality
```bash
# Format code
black etl/ dbt-scout/
isort etl/

# Type checking
mypy etl/

# Security scan
bandit -r etl/
```

## Operations

### Backup & Recovery
```bash
# Database backup
pg_dump "$SUPABASE_DB_URL" > scout_backup_$(date +%Y%m%d).sql

# Config backup
tar -czf config_backup_$(date +%Y%m%d).tar.gz etl/ dbt-scout/
```

### Scaling
- **Horizontal**: Add more Bruno workers
- **Vertical**: Increase container resources
- **Database**: Use read replicas for analytics queries

### Maintenance
- **Weekly**: Review quality metrics and alerts
- **Monthly**: Update dependencies and security patches
- **Quarterly**: Performance review and optimization

## Support

**Documentation**: See `/docs` for detailed guides
**Issues**: Report via GitHub Issues
**Monitoring**: Check Grafana dashboards
**Logs**: Aggregated in Grafana and Jaeger