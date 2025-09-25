# SCOUT ANALYTICS PLATFORM - DATABASE ARCHITECTURE REPORT

## 🏗️ EXECUTIVE SUMMARY

The Scout Analytics Platform implements a **medallion architecture** (Bronze → Silver → Gold → Platinum) with real-time change data capture (CDC) for a comprehensive retail analytics solution. The platform processes **165,485+ production records** from 13 active stores with 91.7% facial recognition coverage and 44.2% audio transcription capabilities.

---

## 📂 DATABASE SCHEMAS OVERVIEW

### Core Business Schemas
- **`bronze`** - Raw data ingestion layer (3 tables, 9 records)
- **`silver`** - Cleaned and validated data (4 objects)
- **`gold`** - Business-ready analytics data (3 objects, 12,101+ records)
- **`dbo`** - Main operational schema (60+ tables, 165K+ records)

### Technical & System Schemas
- **`cdc`** - Change data capture (35+ stored procedures, real-time sync)
- **`staging`** - Data loading interim tables
- **`poc`** - Proof of concept tables (9 tables)
- **`scout`** - Scout-specific business objects (9 tables)
- **`ces`** - Campaign effectiveness scoring (5 tables)
- **`ops`** - Operational metadata (1 table)

---

## 🔄 ETL FLOW ARCHITECTURE

### 1. DATA SOURCES → STAGING
```
Retail Stores (POS) ──┐
IoT Devices (Sensors) ─┤
Vision AI (Cameras) ───┼── → staging.StoreLocationImport
Audio AI (Microphones) ┤      dbo.PayloadTransactionsStaging_csv
External APIs ─────────┘
```

### 2. STAGING → BRONZE LAYER (Raw Data)
```
bronze.transactions (3 records)
bronze.bronze_transactions (3 records)
bronze.dim_stores_ncr
dbo.PayloadTransactions (12,192 records) ← PRIMARY TRANSACTION TABLE
dbo.SalesInteractions (165,485 records)  ← PRIMARY INTERACTION TABLE
dbo.bronze_device_logs
dbo.bronze_transcriptions
```

### 3. BRONZE → SILVER LAYER (Cleaned & Validated)
```
dbo.silver_location_verified
dbo.silver_txn_items
dbo.silver_transcripts (VIEW)
dbo.silver_vision_detections (VIEW)
```

### 4. SILVER → GOLD LAYER (Business Ready)
```
gold.scout_dashboard_transactions (12,101 records) ← DASHBOARD DATA
gold.tbwa_client_brands
gold.v_transactions_crosstab (VIEW)
gold.v_transactions_flat (VIEW)
gold.v_transactions_flat_v24 (VIEW)
```

### 5. ANALYTICAL VIEWS & PROCEDURES
```
PRODUCTION VIEWS:
• dbo.v_transactions_flat_production (12,192 records)
• dbo.v_transactions_flat_v24 (12,192 records)
• dbo.v_SalesInteractionsComplete
• dbo.v_store_health_dashboard

KEY STORED PROCEDURES:
• gold.sp_extract_scout_dashboard_data
• dbo.sp_refresh_analytics_views
• dbo.sp_scout_health_check
```

### 6. API LAYER
```
Scout DAL Agent (/api/dash)
Single Endpoint Bundle API
├── KPIs
├── Brands
├── Transactions
├── Store Geo
└── Comparisons

Deployed: scout-dashboard-xi.vercel.app
```

---

## 🗃️ KEY TABLE SPECIFICATIONS

### Primary Transaction Tables

#### `dbo.SalesInteractions` (165,485 records) - MAIN INTERACTION TABLE
```sql
InteractionID         varchar(60) NOT NULL    -- Primary key
StoreID              int NULL                 -- Store reference
ProductID            int NULL                 -- Product reference
TransactionDate      datetime NULL            -- Transaction timestamp
DeviceID             nvarchar(100) NULL       -- Device identifier
FacialID             nvarchar(255) NULL       -- Face recognition ID
Gender               nvarchar(50) NULL        -- Customer gender
Age                  int NULL                 -- Customer age
EmotionalState       nvarchar(100) NULL       -- Detected emotion
TranscriptionText    nvarchar(MAX) NULL       -- Audio transcript
canonical_tx_id      varchar(32) NULL         -- Transaction linkage
```

#### `dbo.PayloadTransactions` (12,192 records) - PAYLOAD DATA
```sql
sessionId            varchar(128) NOT NULL    -- Session identifier
deviceId             varchar(128) NULL        -- Device reference
storeId              varchar(64) NULL         -- Store reference
amount               decimal NULL             -- Transaction amount
payload_json         nvarchar(MAX) NOT NULL   -- Raw JSON payload
canonical_tx_id      nvarchar(4000) NULL      -- Transaction ID
```

#### `gold.scout_dashboard_transactions` (12,101 records) - DASHBOARD READY
```sql
id                   nvarchar(50) NOT NULL    -- Record ID
store_id             nvarchar(20) NOT NULL    -- Store identifier
timestamp            nvarchar(30) NOT NULL    -- Transaction time
location_city        nvarchar(100) NOT NULL   -- Geographic data
brand_name           nvarchar(100) NOT NULL   -- Product brand
peso_value           decimal NOT NULL         -- Transaction value
basket_size          int NOT NULL             -- Items in basket
gender               nvarchar(20) NOT NULL    -- Customer demographics
age_bracket          nvarchar(20) NOT NULL    -- Age classification
is_tbwa_client       bit NOT NULL             -- Client classification
```

---

## 🔗 FOREIGN KEY RELATIONSHIPS

### Core Business Relationships
```
dbo.SalesInteractions.StoreID → dbo.Stores.StoreID
dbo.SalesInteractions.ProductID → dbo.Products.ProductID
dbo.SalesInteractionBrands.InteractionID → dbo.SalesInteractions.InteractionID
dbo.Products.BrandID → dbo.Brands.BrandID
```

### Geographic Hierarchies
```
dbo.Barangay.MunicipalityID → dbo.Municipality.MunicipalityID
dbo.Municipality.ProvinceID → dbo.Province.ProvinceID
dbo.Province.RegionID → dbo.Region.RegionID
```

### Scout Schema Relationships
```
scout.transactions.store_id → scout.stores.store_id
scout.transactions.customer_id → scout.customers.customer_id
scout.transaction_items.transaction_id → scout.transactions.transaction_id
scout.products.brand_id → scout.brands.brand_id
```

---

## ⚙️ STORED PROCEDURES & FUNCTIONS

### Gold Layer ETL Procedures
- **`gold.sp_extract_scout_dashboard_data`** - Main dashboard data extraction
- **`dbo.sp_refresh_analytics_views`** - Refresh analytical views
- **`dbo.sp_scout_health_check`** - System health monitoring

### CDC (Change Data Capture) Procedures
- **35+ CDC stored procedures** for real-time change tracking
- **`sp_batchinsert_*`** procedures for bulk data operations
- **`fn_cdc_get_all_changes_*`** functions for change retrieval

### Utility & Maintenance
- **`dbo.PopulateSessionMatches`** - Session matching logic
- **`dbo.sp_upsert_device_store`** - Device-store mapping
- **`dbo.VerifyScoutMigration`** - Data migration validation

---

## 👁️ ANALYTICAL VIEWS

### Production Views (12,192 records each)
- **`dbo.v_transactions_flat_production`** - Flattened transaction view
- **`dbo.v_transactions_flat_v24`** - Version 24 transaction view
- **`dbo.v_SalesInteractionsComplete`** - Complete interaction data

### Cross-Tabulation Views
- **`dbo.ct_timeXbrand`** - Time vs Brand analysis
- **`dbo.ct_basketXcategory`** - Basket vs Category analysis
- **`dbo.ct_genderXdaypart`** - Gender vs Time analysis

### Health & Monitoring Views
- **`dbo.v_store_health_dashboard`** - Store performance monitoring
- **`dbo.v_performance_metrics_dashboard`** - System metrics
- **`dbo.v_data_quality_monitor`** - Data quality tracking

---

## 📊 PRODUCTION DATA VOLUMES

### Record Counts (As of September 2024)
```
Primary Tables:
├── dbo.SalesInteractions: 165,485 records (6 months)
├── dbo.PayloadTransactions: 12,192 records
├── gold.scout_dashboard_transactions: 12,101 records
├── dbo.v_transactions_flat_production: 12,192 records
├── dbo.Stores: 21 records
└── dbo.Products: 1 record

Operational Scale:
├── Active Stores: 13 locations
├── IoT Devices: 15 active devices
├── Date Range: April 2025 - September 2025 (6 months)
├── Coverage: 90% of operational days
└── Data Quality: 91.7% facial recognition, 44.2% transcription
```

---

## 🏗️ TECHNICAL ARCHITECTURE

### Database Platform
- **Azure SQL Database** (Production)
- **Server**: sqltbwaprojectscoutserver.database.windows.net
- **Database**: SQL-TBWA-ProjectScout-Reporting-Prod

### ETL Architecture
- **Medallion Pattern**: Bronze → Silver → Gold → Platinum
- **Change Data Capture**: Real-time sync with CDC schema
- **Stored Procedures**: ETL orchestration and health checks
- **Views**: Analytical abstractions and cross-tabulations

### API Architecture
- **Next.js 14** App Router with TypeScript
- **Vercel Serverless** deployment
- **Single Endpoint Bundle**: `/api/dash` aggregating multiple data sources
- **Error Isolation**: HTTP 207 Multi-Status for partial failures

---

## 🎯 KEY INSIGHTS

### Data Architecture Strengths
1. **Medallion Pattern Implementation** - Clean separation of raw, cleaned, and business-ready data
2. **Real-time CDC** - Change data capture enables near real-time analytics
3. **Comprehensive Analytics** - 40+ views for cross-tabulation and analysis
4. **Production Scale** - 165K+ interaction records with high data quality

### Data Quality Metrics
- **Completeness**: 100% for core identifiers (InteractionID, canonical_tx_id)
- **Facial Recognition**: 91.7% coverage across interactions
- **Audio Transcription**: 44.2% coverage for voice interactions
- **Temporal Coverage**: 90% of operational days have transaction data

### API Performance
- **Single Endpoint Design** - Reduces API complexity and latency
- **Error Isolation** - Partial failures don't break entire dashboard
- **Serverless Deployment** - Auto-scaling with Vercel Edge Functions
- **Production Ready** - Deployed at scout-dashboard-xi.vercel.app

---

## 📈 OPERATIONAL INSIGHTS

### Business Intelligence Capabilities
- **Customer Demographics** - Age, gender, emotional state tracking
- **Product Analytics** - Brand performance, category analysis
- **Store Performance** - Geographic distribution, store-level metrics
- **Temporal Patterns** - Time-of-day, day-of-week analysis
- **Campaign Effectiveness** - TBWA client brand performance tracking

### Technology Integration
- **IoT Integration** - 15 devices across 13 stores
- **AI/ML Capabilities** - Vision AI (facial recognition), Audio AI (transcription)
- **Real-time Processing** - CDC for immediate data availability
- **API-First Design** - RESTful API with comprehensive error handling

This architecture supports a comprehensive retail analytics platform with real-time customer behavior insights, operational intelligence, and campaign effectiveness measurement for the Scout Analytics ecosystem.