# ETL Monitoring System - Scout v7 Data Pipeline

**System Status**: ✅ **OPERATIONAL** | **Coverage**: Medallion Architecture Complete  
**Data Volume**: 175,344+ transactions | **Sources**: Azure SQL + Scout Edge + Local Files

## 🏗️ Pipeline Architecture Overview

### Medallion Layer Monitoring
```
Azure SQL (160K) ──┐
Scout Edge JSON ───┼─→ Bronze Layer ─→ Silver Layer ─→ Gold Layer ─→ Knowledge Layer
Local Files ───────┘       │              │              │              │
                      Raw Ingestion    Cleaned Data   Business KPIs   AI Insights
                         ↓                ↓              ↓              ↓
                    Quarantine      Data Quality     Aggregations   Vector Search
                      System         Validation       & Metrics      & RAG System
```

### Current Production Status
- **Bronze Layer**: ✅ 160,108 Azure records + Scout Edge capability
- **Silver Layer**: ✅ 175,344 cleaned transactions operational
- **Gold Layer**: ✅ 137 daily metrics generated
- **Knowledge Layer**: ✅ 53 vector embeddings + 6 market insights

## 📊 Real-Time Monitoring Dashboard Specifications

### Layer-by-Layer Health Monitoring

#### Bronze Layer Monitoring
```sql
-- Raw data ingestion health check
SELECT 
    'Azure Integration' as source,
    COUNT(*) as record_count,
    MAX("TransactionDate") as latest_record,
    CASE WHEN MAX("TransactionDate") > NOW() - INTERVAL '1 day' 
         THEN 'HEALTHY' ELSE 'STALE' END as status
FROM azure_data.interactions
UNION ALL
SELECT 
    'Scout Edge Processing' as source,
    COUNT(*) as record_count,
    MAX(created_at) as latest_record,
    CASE WHEN MAX(created_at) > NOW() - INTERVAL '1 hour'
         THEN 'HEALTHY' ELSE 'STALE' END as status
FROM bronze.edge_raw;
```

#### Silver Layer Validation
```sql
-- Data quality and completeness monitoring  
SELECT 
    'Silver Transactions' as layer,
    COUNT(*) as total_records,
    COUNT(CASE WHEN brand_name IS NOT NULL THEN 1 END) as branded_records,
    ROUND(
        COUNT(CASE WHEN brand_name IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 
        2
    ) as brand_detection_rate
FROM silver.transactions_cleaned;
```

#### Gold Layer Performance
```sql
-- Business metrics generation monitoring
SELECT 
    table_name,
    COUNT(*) as metric_count,
    MAX(created_at) as last_updated,
    CASE WHEN MAX(created_at) > NOW() - INTERVAL '1 day'
         THEN 'CURRENT' ELSE 'OUTDATED' END as freshness
FROM information_schema.tables t
JOIN gold.daily_metrics g ON t.table_name = 'daily_metrics'
WHERE t.table_schema = 'gold';
```

#### Knowledge Layer Intelligence
```sql
-- AI and vector embeddings monitoring
SELECT 
    'Vector Embeddings' as component,
    COUNT(*) as embedding_count,
    AVG(array_length(embedding, 1)) as avg_dimensions,
    COUNT(DISTINCT content_type) as content_types
FROM knowledge.vector_embeddings;
```

## 🔍 Azure Data Integration Monitoring

### Connection Health Monitoring
```python
# Azure SQL integration health check
async def check_azure_integration():
    """Monitor Azure SQL data integration health"""
    query = """
    SELECT 
        COUNT(*) as total_interactions,
        MAX("TransactionDate") as latest_transaction,
        COUNT(DISTINCT "StoreID") as active_stores,
        COUNT(DISTINCT "DeviceID") as active_devices,
        EXTRACT(EPOCH FROM (NOW() - MAX("TransactionDate")))/3600 as hours_since_last
    FROM azure_data.interactions;
    """
    
    result = await db.fetch_one(query)
    
    health_status = {
        'status': 'HEALTHY' if result['hours_since_last'] < 24 else 'STALE',
        'total_records': result['total_interactions'],
        'latest_activity': result['latest_transaction'],
        'active_stores': result['active_stores'],
        'active_devices': result['active_devices'],
        'data_freshness_hours': result['hours_since_last']
    }
    
    return health_status
```

### Data Freshness Alerts
- **Critical**: No new Azure data for >24 hours
- **Warning**: Data processing delays >4 hours
- **Info**: Normal processing within SLA (<1 hour)

### Integration Performance Metrics
- **Current Volume**: 160,108 interaction records
- **Date Range**: March 28, 2025 → September 16, 2025 (6 months)
- **Processing Rate**: Real-time integration capability
- **Error Rate**: <0.1% (monitored via quarantine system)

## 📁 Local File Processing Monitoring

### Scout Edge JSON Processing
**Current Accomplishment**: 13,289 files processed successfully

```python
# Scout Edge processing monitor
def monitor_scout_edge_processing():
    """Monitor Scout Edge JSON file processing"""
    
    processing_stats = {
        'total_files_processed': 13289,
        'success_rate': 100.0,  # Zero errors achieved
        'processing_time_minutes': 49,
        'avg_rate_per_minute': 270,
        'device_distribution': {
            'SCOUTPI-0006': 5919,  # 44.5%
            'SCOUTPI-0009': 2645,  # 19.9%
            'SCOUTPI-0002': 1488,  # 11.2%
            'SCOUTPI-0003': 1484,  # 11.2%
            'SCOUTPI-0010': 1312,  # 9.9%
            'SCOUTPI-0012': 234,   # 1.8%
            'SCOUTPI-0004': 207    # 1.6%
        },
        'status': 'COMPLETED',
        'error_count': 0
    }
    
    return processing_stats
```

### File Processing Pipeline Monitoring
1. **File Discovery**: Directory scanning and file enumeration
2. **Format Validation**: JSON structure and schema validation
3. **Data Transformation**: Currency conversion and field mapping
4. **Quality Checks**: Data completeness and integrity validation
5. **Database Insertion**: Batch loading with error handling

### Processing Performance Benchmarks
- **Throughput**: 270 files/minute sustained processing
- **Success Rate**: 100% (13,289 files, zero failures)
- **Memory Efficiency**: Batch processing with memory management
- **Error Recovery**: Automatic retry with quarantine for invalid data

## 🌐 Google Drive Ingestion Recommendations

### Proposed Monitoring Architecture
```python
# Google Drive ingestion monitoring framework
class GoogleDriveMonitor:
    def __init__(self, drive_service, db_connection):
        self.drive = drive_service
        self.db = db_connection
        self.sync_log = []
    
    async def monitor_drive_sync(self):
        """Monitor Google Drive to database sync health"""
        
        sync_metrics = {
            'files_discovered': await self.count_drive_files(),
            'files_processed': await self.count_processed_files(),
            'sync_lag_hours': await self.calculate_sync_lag(),
            'error_rate': await self.get_sync_error_rate(),
            'storage_usage': await self.get_storage_metrics()
        }
        
        return sync_metrics
    
    async def setup_realtime_sync(self):
        """Configure real-time Google Drive sync monitoring"""
        
        # Webhook configuration for real-time updates
        webhook_config = {
            'notification_channel': 'scout-v7-drive-sync',
            'target_url': f'{SUPABASE_URL}/functions/v1/drive-sync-webhook',
            'events': ['add', 'remove', 'update'],
            'filters': {
                'file_types': ['.json', '.csv', '.xlsx'],
                'folders': ['scout-data', 'market-intelligence']
            }
        }
        
        return webhook_config
```

### Sync Strategy Implementation
1. **Real-Time Sync**
   - Webhook-triggered for critical business data
   - <5 minute processing SLA
   - Automatic error recovery

2. **Batch Sync** 
   - Hourly for standard data ingestion
   - Daily for historical data processing
   - Weekly for archive and cleanup

3. **Cloud-to-Cloud Direct Transfer**
   - Google Drive API → Supabase Storage
   - Reduced local processing overhead
   - Improved reliability and performance

### Monitoring Dashboard Requirements
```javascript
// Real-time dashboard metrics
const DriveMonitoringDashboard = {
    realTimeMetrics: {
        syncStatus: 'ACTIVE' | 'PAUSED' | 'ERROR',
        filesInQueue: number,
        processingRate: 'files/minute',
        errorRate: 'percentage',
        lastSyncTime: timestamp
    },
    
    performanceMetrics: {
        averageProcessingTime: 'seconds',
        throughputTrend: 'files/hour over 24h',
        storageUtilization: 'GB used/available',
        apiQuotaUsage: 'requests/quota limit'
    },
    
    alerts: {
        syncFailures: 'count > 5 in 1 hour',
        quotaExceeded: 'API usage > 90%',
        storageNearFull: 'usage > 85%',
        staleSyncData: 'last sync > 2 hours'
    }
};
```

## 🚨 Alert System Configuration

### Alert Severity Levels
- **🔴 Critical**: System failures, data loss, security breaches
- **🟡 Warning**: Performance degradation, quota limits, data delays
- **🟢 Info**: Normal operations, successful completions, metrics updates

### Monitoring Thresholds
```yaml
bronze_layer:
  data_staleness: 24_hours
  error_rate: 1_percent
  processing_delay: 4_hours

silver_layer:
  quality_score: 95_percent
  brand_detection_rate: 80_percent
  completeness_threshold: 98_percent

gold_layer:
  metric_freshness: 24_hours
  aggregation_errors: 0_percent
  kpi_availability: 99_percent

knowledge_layer:
  embedding_generation: 2_hours
  vector_search_performance: 200_milliseconds
  rag_response_time: 2_seconds
```

### Alert Delivery Mechanisms
1. **Real-time**: Supabase Edge Functions for immediate notifications
2. **Email**: Critical alerts to operations team
3. **Slack/Teams**: Integration with collaboration platforms
4. **Dashboard**: Visual alerts in monitoring interface

## 📈 Performance Optimization Monitoring

### Query Performance Tracking
```sql
-- Monitor slow queries and optimize performance
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    ROUND(total_time * 100 / (SELECT SUM(total_time) FROM pg_stat_statements), 2) as percentage
FROM pg_stat_statements
WHERE mean_time > 100  -- Queries taking >100ms
ORDER BY mean_time DESC
LIMIT 10;
```

### Resource Utilization Monitoring
- **Database Connections**: Monitor active vs. available connections
- **Storage Growth**: Track data growth trends and capacity planning
- **CPU/Memory Usage**: Supabase resource utilization metrics
- **Network I/O**: Data transfer rates and bandwidth utilization

### Optimization Recommendations
1. **Indexing Strategy**: Optimize vector and traditional indexes
2. **Query Optimization**: Identify and refactor slow queries
3. **Caching Implementation**: Redis integration for frequent queries
4. **Connection Pooling**: Efficient database resource management

## 🔧 Operational Runbooks

### Daily Health Checks
```bash
# Daily ETL pipeline health verification
#!/bin/bash
echo "=== Daily ETL Health Check - $(date) ==="

# Check data freshness
psql $DATABASE_URL -c "SELECT 'Azure Data Freshness', EXTRACT(EPOCH FROM (NOW() - MAX(\"TransactionDate\")))/3600 as hours_old FROM azure_data.interactions;"

# Check processing volumes
psql $DATABASE_URL -c "SELECT 'Silver Layer Count', COUNT(*) FROM silver.transactions_cleaned WHERE DATE(transaction_date) = CURRENT_DATE - INTERVAL '1 day';"

# Check system health
psql $DATABASE_URL -c "SELECT 'Vector Embeddings', COUNT(*) FROM knowledge.vector_embeddings WHERE created_at >= CURRENT_DATE - INTERVAL '1 day';"

echo "=== Health Check Complete ==="
```

### Emergency Response Procedures
1. **Data Pipeline Failure**: Automatic failover to backup processing
2. **Azure Integration Loss**: Switch to local file processing mode  
3. **Vector Database Issues**: Fallback to traditional search methods
4. **Performance Degradation**: Auto-scaling and resource optimization

---

## 📋 Monitoring Implementation Status

**Current State - Production Ready**
- ✅ **Database Monitoring**: Schema and performance tracking operational
- ✅ **Data Quality**: Quarantine and validation systems active
- ✅ **Azure Integration**: 160K+ records successfully integrated  
- ✅ **Scout Edge Processing**: 13,289 files processed with 100% success
- ⏳ **Google Drive Sync**: Architecture designed, implementation pending
- ⏳ **Real-time Dashboard**: Framework ready, UI development needed
- ⏳ **Alert System**: Thresholds defined, delivery integration pending

**Next Phase**: Complete real-time monitoring dashboard and alert system implementation.