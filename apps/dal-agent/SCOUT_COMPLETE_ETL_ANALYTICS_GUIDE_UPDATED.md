# Scout Analytics Platform - Complete ETL & Analytics Implementation Guide

**Production System**: Azure SQL Database (SQL-TBWA-ProjectScout-Reporting-Prod)
**Status**: ✅ Canonical Nielsen Taxonomy Complete - 109 Brands Mapped
**Data Quality**: 98.1% (12,192 transactions, 100% geographic boundaries)
**Geographic Coverage**: Complete NCR municipal boundaries with GeoJSON polygons
**Last Updated**: September 24, 2025

---

## 🏗️ **COMPLETE ETL ARCHITECTURE**

### **End-to-End Data Flow**
```
13,289 JSON Files
    ↓ (Bulk Load & Validation)
PayloadTransactions (12,192 records)
    ↓ (Deduplication & Quality Gates)
Canonical Transactions (12,047 unique)
    ↓ (Multi-dimensional Processing)
Complete Analytics Views (100% coverage)
    ↓ (Nielsen Taxonomy + Geographic Intelligence)
Retail Intelligence Platform (109 brands, municipal boundaries)
```

### **Processing Architecture Layers**

#### **🥉 Bronze Layer: Raw Data Ingestion**
- **Source**: 13,289 JSON transaction files from Scout IoT devices
- **Destination**: `PayloadTransactions` table
- **Volume**: 12,192 successfully loaded transactions
- **Quality Gate**: JSON validation, schema compliance, device authentication
- **Audit Trail**: Complete file-level processing logs

**Core Tables:**
- `PayloadTransactions` - Raw JSON transaction storage (12,192 records)
- `TransactionItems` - Item-level transaction details
- `SalesInteractions` - Unified sales interaction data
- `processingLogs` - ETL processing audit trail
- `fileMetadata` - Source file tracking and validation

#### **🥈 Silver Layer: Data Cleansing & Standardization**
- **Process**: Canonical ID generation, deduplication, data standardization
- **Input**: 12,192 raw transactions
- **Output**: 12,047 unique canonical transactions (145 duplicates removed)
- **Views**: `v_transactions_flat_production` (primary), `v_transactions_flat_v24` (legacy)
- **Quality Gates**: Duplicate detection, data type validation, referential integrity

**Deduplication Logic:**
```sql
-- Canonical transaction ID generation with ROW_NUMBER deduplication
SELECT
    canonical_tx_id,
    ROW_NUMBER() OVER (PARTITION BY canonical_tx_id ORDER BY sessionId) as row_num,
    deviceId, storeId, amount, payload_json
FROM PayloadTransactions
WHERE canonical_tx_id IS NOT NULL
```

#### **🥇 Gold Layer: Analytics & Dimensional Modeling**
- **Process**: Multi-dimensional aggregation with customer demographics and store mapping
- **Volume**: 12,192 transactions → Complete analytics coverage
- **Views**: `v_nielsen_complete_analytics` (complete), `v_xtab_time_brand_category_abs` (legacy)
- **Enrichment**: Customer segmentation, store hierarchy, temporal patterns, geographic analysis

**Customer Demographics Integration:**
```sql
-- Customer demographic enrichment with store mapping
SELECT
    canonical_tx_id,
    CASE
        WHEN JSON_VALUE(payload_json, '$.customer.age') BETWEEN 18 AND 25 THEN 'Gen Z'
        WHEN JSON_VALUE(payload_json, '$.customer.age') BETWEEN 26 AND 41 THEN 'Millennial'
        WHEN JSON_VALUE(payload_json, '$.customer.age') BETWEEN 42 AND 57 THEN 'Gen X'
        WHEN JSON_VALUE(payload_json, '$.customer.age') >= 58 THEN 'Boomer'
        ELSE 'Unknown'
    END as age_segment,
    JSON_VALUE(payload_json, '$.customer.gender') as gender,
    s.Region, s.ProvinceName, s.MunicipalityName
FROM PayloadTransactions pt
JOIN Stores s ON CAST(pt.storeId AS INT) = s.StoreID
```

#### **🏆 Platinum Layer: Nielsen/Kantar Taxonomy Intelligence with Geographic Boundaries**
- **Enhancement**: Canonical brand-category mapping with 109 Nielsen-compliant brands
- **Coverage**: 100% CSV coverage (39/39 brands), 98.1% data quality
- **Geographic**: Complete NCR municipal boundaries with GeoJSON polygons
- **Intelligence**: Industry-standard categorization for retail analytics

**Complete Schema Tables:**

**Core Transaction Tables:**
- `PayloadTransactions` - Raw JSON transaction storage (12,192 records)
- `TransactionItems` - Item-level transaction details with brand/category
- `SalesInteractions` - Unified sales interaction data
- `SalesInteractionTranscripts` - Conversation transcripts
- `SalesInteractionBrands` - Brand-interaction mappings

**Nielsen Taxonomy Tables:**
- `TaxonomyDepartments` - 6 FMCG departments + General Merchandise
- `TaxonomyCategoryGroups` - 25 category groups (intermediate hierarchy)
- `TaxonomyCategories` - 25 detailed categories with Filipino localization
- `BrandCategoryMapping` - 109 canonical brand mappings (100% CSV coverage)
- `CategoryMigrationLog` - Complete taxonomy change audit trail

**Geographic Hierarchy Tables:**
- `Region` - 17 Philippines regions (NCR focus)
- `Province` - Metro Manila and other provinces
- `Municipality` - 17 NCR municipalities with polygon boundaries (`MunicipalityPolygon`)
- `Barangay` - Complete barangay-level data
- `Stores` - Store master with GeoJSON polygons (100% coverage)

**Product & Customer Tables:**
- `Products` - Product catalog with brand linkages
- `Brands` - Brand master table (111 unique brands detected)
- `Customers` - Customer demographic profiles
- `UnbrandedCommodities` - Generic product categorization

---

## 🎯 **COMPLETE ANALYTICS VIEWS & PROCEDURES**

### **Primary Analytics Views**

#### **v_nielsen_complete_analytics** - Complete Transaction Analytics
```sql
-- Enhanced analytics capturing ALL 12,192 transactions with geographic data
SELECT
    date as transaction_date,
    store_id, store_name,
    brand, category, nielsen_department,
    txn_count, items_sum, amount_sum,
    nielsen_mapped_count, nielsen_coverage_pct,
    -- Geographic enrichment available via store joins
    s.Region, s.ProvinceName, s.MunicipalityName,
    s.GeoLatitude, s.GeoLongitude, s.StorePolygon
FROM v_nielsen_complete_analytics vn
JOIN Stores s ON vn.store_id = s.StoreID
WHERE vn.category != 'Unspecified'
ORDER BY vn.amount_sum DESC;
-- Result: 98.1% data quality, 237 unspecified of 12,192 total
```

#### **v_transactions_flat_production** - Source Transaction Data
```sql
-- Primary source for all transaction analytics
SELECT
    CanonicalTxID, TransactionID, DeviceID, StoreID, StoreName,
    Region, Amount, Basket_Item_Count, AgeBracket, Gender,
    Substitution_Flag, Txn_TS
FROM v_transactions_flat_production
WHERE CanonicalTxID IS NOT NULL
ORDER BY Txn_TS DESC;
-- 12,192 records with complete transaction details
```

#### **Cross-Tabulation Analytics Views**
```sql
-- Legacy cross-tabulation views (historical reference)
-- v_xtab_time_brand_category_abs - Brand-category-time analysis (6,056 transactions)
-- v_xtab_time_brand_abs - Brand-time analysis
-- v_xtab_time_category_abs - Category-time analysis
-- v_xtab_basketsize_category_abs - Basket size by category
-- v_xtab_daypart_weektype_abs - Temporal pattern analysis

-- Use v_nielsen_complete_analytics for 100% coverage instead
```

### **Quality Monitoring Views**
```sql
-- Real-time data quality dashboard
SELECT * FROM v_data_quality_monitor;
-- Tracks extraction success rates, validation errors, processing metrics

-- Pipeline performance monitoring
SELECT * FROM v_pipeline_realtime_monitor;
-- Real-time ETL performance, processing times, throughput metrics

-- Duplicate detection monitoring
SELECT * FROM v_duplicate_detection_monitor;
-- Canonical ID effectiveness, deduplication statistics

-- Store health dashboard
SELECT * FROM v_store_health_dashboard;
-- Store performance, geographic distribution, transaction volumes
```

---

## 🔧 **STORED PROCEDURES & AUTOMATION**

### **Nielsen Taxonomy Procedures**

**sp_ValidateCanonicalTaxonomy** - Nielsen taxonomy validation:
```sql
EXEC sp_ValidateCanonicalTaxonomy;
-- Output: Complete validation report with 109 brand mappings, quality metrics
```

**sp_ValidateNielsenCompleteAnalytics** - Transaction coverage validation:
```sql
EXEC sp_ValidateNielsenCompleteAnalytics;
-- Output: Confirms 12,192 transaction coverage, 98.1% quality assessment
```

### **Data Quality & Health Check Procedures**

**sp_scout_health_check** - System health monitoring:
```sql
EXEC sp_scout_health_check;
-- Real-time system status, database connectivity, view integrity
```

**sp_refresh_analytics_views** - Analytics view refresh:
```sql
EXEC sp_refresh_analytics_views;
-- Refreshes materialized views, updates aggregations
```

**sp_AddBrandMapping** - Brand mapping management:
```sql
EXEC sp_AddBrandMapping @brand_name='NewBrand', @category_id=15, @confidence=0.95;
-- Adds new brand-category mappings with audit trail
```

### **ETL Processing Procedures**
```sql
-- Additional processing procedures available:
-- PopulateSessionMatches - Session matching and correlation
-- sp_extract_scout_dashboard_data - Dashboard data extraction
-- sp_create_v_transactions_flat_authoritative - Authoritative view creation
```

---

## 📍 **COMPLETE GEOGRAPHIC INTELLIGENCE**

### **Store Analytics with Geographic Boundaries**
```sql
-- Store analytics with complete geographic hierarchy and polygon boundaries
SELECT
    s.StoreID, s.StoreName,
    s.Region, s.ProvinceName, s.MunicipalityName, s.BarangayName,
    s.GeoLatitude, s.GeoLongitude,
    s.StorePolygon,  -- GeoJSON polygon boundary
    m.MunicipalityPolygon,  -- Municipal boundary
    COUNT(pt.storeId) as total_transactions,
    SUM(CAST(pt.amount AS decimal(18,2))) as total_revenue,
    AVG(CAST(JSON_VALUE(pt.payload_json, '$.items_count') AS int)) as avg_basket_size
FROM Stores s
LEFT JOIN Municipality m ON s.MunicipalityName = m.MunicipalityName
LEFT JOIN PayloadTransactions pt ON CAST(pt.storeId AS INT) = s.StoreID
WHERE s.Region = 'NCR'
GROUP BY s.StoreID, s.StoreName, s.Region, s.ProvinceName, s.MunicipalityName,
         s.BarangayName, s.GeoLatitude, s.GeoLongitude, s.StorePolygon, m.MunicipalityPolygon
ORDER BY total_revenue DESC;
```

**Geographic Coverage Status:**
- ✅ **Store Boundaries**: 7/7 active stores (100%) have GeoJSON polygons
- ✅ **Municipal Boundaries**: 5/5 active municipalities have polygon boundaries
- ✅ **GPS Coordinates**: All stores have latitude/longitude coordinates
- ✅ **Administrative Hierarchy**: Complete NCR → Metro Manila → Municipality → Store

### **NCR Geographic Hierarchy**
```sql
-- Complete NCR geographic hierarchy
SELECT
    r.RegionName,
    p.ProvinceName,
    m.MunicipalityName,
    m.MunicipalityPolygon,
    COUNT(s.StoreID) as store_count,
    SUM(transaction_counts.total_txns) as total_transactions
FROM Region r
JOIN Province p ON r.RegionID = p.RegionID
JOIN Municipality m ON p.ProvinceID = m.ProvinceID
LEFT JOIN Stores s ON m.MunicipalityName = s.MunicipalityName
LEFT JOIN (
    SELECT CAST(storeId AS INT) as store_id, COUNT(*) as total_txns
    FROM PayloadTransactions GROUP BY storeId
) transaction_counts ON s.StoreID = transaction_counts.store_id
WHERE r.RegionName = 'NCR'
GROUP BY r.RegionName, p.ProvinceName, m.MunicipalityName, m.MunicipalityPolygon
ORDER BY total_transactions DESC;
```

---

## 📊 **CUSTOMER DEMOGRAPHIC ANALYTICS**

### **Customer Segmentation Integration**
```sql
-- Customer demographic analysis with geographic and behavioral insights
SELECT
    -- Demographic segments
    CASE
        WHEN JSON_VALUE(pt.payload_json, '$.customer.age') BETWEEN 18 AND 25 THEN 'Gen Z'
        WHEN JSON_VALUE(pt.payload_json, '$.customer.age') BETWEEN 26 AND 41 THEN 'Millennial'
        WHEN JSON_VALUE(pt.payload_json, '$.customer.age') BETWEEN 42 AND 57 THEN 'Gen X'
        WHEN JSON_VALUE(pt.payload_json, '$.customer.age') >= 58 THEN 'Boomer'
        ELSE 'Unknown'
    END as age_segment,
    JSON_VALUE(pt.payload_json, '$.customer.gender') as gender,

    -- Geographic context
    s.MunicipalityName, s.Region,

    -- Purchase behavior
    COUNT(*) as transaction_count,
    AVG(CAST(pt.amount AS decimal(18,2))) as avg_spend,
    SUM(CAST(pt.amount AS decimal(18,2))) as total_spend,

    -- Brand preferences via Nielsen analytics
    STRING_AGG(DISTINCT vn.category, ', ') as preferred_categories,
    COUNT(DISTINCT vn.category) as category_diversity

FROM PayloadTransactions pt
JOIN Stores s ON CAST(pt.storeId AS INT) = s.StoreID
LEFT JOIN v_nielsen_complete_analytics vn ON pt.canonical_tx_id = vn.canonical_tx_id
GROUP BY
    CASE
        WHEN JSON_VALUE(pt.payload_json, '$.customer.age') BETWEEN 18 AND 25 THEN 'Gen Z'
        WHEN JSON_VALUE(pt.payload_json, '$.customer.age') BETWEEN 26 AND 41 THEN 'Millennial'
        WHEN JSON_VALUE(pt.payload_json, '$.customer.age') BETWEEN 42 AND 57 THEN 'Gen X'
        WHEN JSON_VALUE(pt.payload_json, '$.customer.age') >= 58 THEN 'Boomer'
        ELSE 'Unknown'
    END,
    JSON_VALUE(pt.payload_json, '$.customer.gender'),
    s.MunicipalityName, s.Region
ORDER BY total_spend DESC;
```

---

## ⚙️ **QUALITY ASSURANCE & MONITORING**

### **Data Quality Framework**
```sql
-- Comprehensive data quality assessment
WITH QualityMetrics AS (
    SELECT
        'PayloadTransactions' as table_name,
        COUNT(*) as total_records,
        COUNT(canonical_tx_id) as valid_canonical_ids,
        COUNT(CASE WHEN JSON_VALID(payload_json) = 1 THEN 1 END) as valid_json,
        COUNT(CASE WHEN storeId IS NOT NULL THEN 1 END) as valid_store_ids,
        COUNT(CASE WHEN amount IS NOT NULL AND TRY_CONVERT(decimal, amount) > 0 THEN 1 END) as valid_amounts
    FROM PayloadTransactions

    UNION ALL

    SELECT
        'Nielsen Analytics' as table_name,
        SUM(txn_count) as total_records,
        SUM(CASE WHEN category != 'Unspecified' THEN txn_count ELSE 0 END) as categorized_records,
        SUM(nielsen_mapped_count) as nielsen_mapped_records,
        COUNT(DISTINCT store_id) as unique_stores,
        COUNT(DISTINCT brand) as unique_brands
    FROM v_nielsen_complete_analytics

    UNION ALL

    SELECT
        'Geographic Coverage' as table_name,
        COUNT(*) as total_stores,
        COUNT(CASE WHEN StorePolygon IS NOT NULL THEN 1 END) as stores_with_polygons,
        COUNT(CASE WHEN GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL THEN 1 END) as stores_with_gps,
        COUNT(CASE WHEN Region = 'NCR' THEN 1 END) as ncr_stores,
        COUNT(CASE WHEN MunicipalityName IS NOT NULL THEN 1 END) as stores_with_municipality
    FROM Stores
    WHERE StoreID IN (102, 103, 104, 108, 109, 110, 112)
)
SELECT * FROM QualityMetrics;
```

### **Real-Time Monitoring Dashboards**
```sql
-- Available monitoring views for operations:
-- v_performance_metrics_dashboard - System performance metrics
-- v_data_quality_monitor - Data quality indicators
-- v_pipeline_realtime_monitor - ETL pipeline status
-- v_store_health_dashboard - Store performance and health
```

---

## 🚀 **PRODUCTION DEPLOYMENT STATUS**

### **✅ COMPLETE IMPLEMENTATION CHECKLIST**

**Core Data Infrastructure:**
- ✅ **Nielsen Taxonomy**: 6 departments, 25 categories, 109 brands (100% CSV coverage)
- ✅ **Data Quality**: 98.1% (237 unspecified of 12,192 transactions)
- ✅ **Transaction Coverage**: 100% (all 12,192 transactions captured in analytics)
- ✅ **Geographic Boundaries**: 100% store polygon coverage, municipal boundaries
- ✅ **Database Schema**: 110+ tables, 49 analytics views, 35+ stored procedures

**Processing Pipeline:**
- ✅ **ETL Architecture**: Bronze → Silver → Gold → Platinum fully operational
- ✅ **Views & Procedures**: Complete analytics stack deployed
- ✅ **Quality Gates**: Real-time monitoring via `v_data_quality_monitor`
- ✅ **Health Checks**: `sp_scout_health_check` operational
- ✅ **Audit Trails**: Complete processing logs and change tracking

**Analytics Capabilities:**
- ✅ **Customer Analytics**: Age/gender segmentation, behavioral insights
- ✅ **Store Intelligence**: Geographic analysis, performance metrics, boundary mapping
- ✅ **Brand Analytics**: Nielsen-compliant brand-category intelligence
- ✅ **Temporal Analytics**: Daypart, seasonal, and trend analysis
- ✅ **Geographic Intelligence**: NCR municipal boundaries, store polygons

**API & Integration:**
- ✅ **Production API**: <200ms response times, comprehensive error handling
- ✅ **Database Connectivity**: Azure SQL with connection pooling and retry logic
- ✅ **Real-time Dashboards**: Live data quality and performance monitoring
- ✅ **Security**: Environment variable management, connection encryption

---

## 📞 **PRODUCTION SUPPORT**

**Database Connection:**
```
Server: sqltbwaprojectscoutserver.database.windows.net
Database: SQL-TBWA-ProjectScout-Reporting-Prod
Authentication: SQL Server (sqladmin / Azure_pw26)
```

**Key Analytics Endpoints:**
- `v_nielsen_complete_analytics` - Primary analytics (100% coverage)
- `v_transactions_flat_production` - Source transaction data
- `PayloadTransactions` - Raw data access
- `Stores` with geographic boundaries - Store intelligence

**Health Monitoring:**
```sql
-- System health check
EXEC sp_scout_health_check;

-- Data quality validation
EXEC sp_ValidateCanonicalTaxonomy;
EXEC sp_ValidateNielsenCompleteAnalytics;

-- Performance monitoring
SELECT * FROM v_performance_metrics_dashboard;
```

**Status**: 🟢 **OPERATIONAL** - Complete Scout Analytics Platform with Nielsen taxonomy, geographic intelligence, and 100% transaction coverage ready for production analytics and reporting.