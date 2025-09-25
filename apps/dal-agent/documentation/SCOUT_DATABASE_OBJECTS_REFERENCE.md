# Scout Analytics Platform - Complete Database Objects Reference

**Database**: SQL-TBWA-ProjectScout-Reporting-Prod
**Version**: 3.0
**Updated**: September 2025

## Table of Contents

1. [Schema Overview](#schema-overview)
2. [Tables by Schema](#tables-by-schema)
3. [Views Reference](#views-reference)
4. [Stored Procedures](#stored-procedures)
5. [Functions](#functions)
6. [Indexes & Performance](#indexes--performance)
7. [Relationships & Dependencies](#relationships--dependencies)

## Schema Overview

### Schema Structure

| Schema | Purpose | Object Count | Primary Use |
|--------|---------|-------------|-------------|
| `dbo` | Main data objects | 25+ tables, 12+ views | Core business data, ETL processing |
| `ref` | Reference data | 8 tables | Taxonomies, lookup tables, standards |
| `gold` | Analytics layer | 15+ views | Business intelligence, aggregations |
| `audit` | Monitoring | 5 tables | Process logs, quality metrics |

### Data Architecture Layers

```
┌─────────────────────────────────────────────────────┐
│                PLATINUM LAYER                        │
│  Advanced Analytics & Machine Learning              │
│  • v_nielsen_complete_analytics                     │
│  • v_xtab_time_brand_category_abs                   │
│  • Market basket analysis aggregations             │
└─────────────────────────────────────────────────────┘
                            ↑
┌─────────────────────────────────────────────────────┐
│                 GOLD LAYER                          │
│  Business Intelligence Views                        │
│  • v_transactions_flat_production                   │
│  • v_insight_base                                   │
│  • v_data_quality_monitor                          │
└─────────────────────────────────────────────────────┘
                            ↑
┌─────────────────────────────────────────────────────┐
│                SILVER LAYER                         │
│  Cleaned & Structured Data                         │
│  • Transactions                                    │
│  • TransactionItems                                │
│  • BrandSubstitutions                              │
└─────────────────────────────────────────────────────┘
                            ↑
┌─────────────────────────────────────────────────────┐
│                BRONZE LAYER                         │
│  Raw Data Ingestion                                │
│  • PayloadTransactions                             │
│  • SalesInteractions                               │
└─────────────────────────────────────────────────────┘
```

## Tables by Schema

### dbo Schema - Core Business Tables

#### Transaction Processing Tables

**`dbo.PayloadTransactions`** - Bronze Layer Raw Data
```sql
-- Primary raw data ingestion table
CREATE TABLE dbo.PayloadTransactions (
    transaction_id varchar(50) PRIMARY KEY,
    interaction_id varchar(50),
    canonical_tx_id varchar(64) UNIQUE,
    payload_json nvarchar(max),           -- Complete JSON payload
    payload_hash varchar(64),             -- SHA-256 for deduplication
    txn_ts datetime2,
    total_amount decimal(12,2),
    total_items int,
    payment_method varchar(50),
    store_id varchar(50),
    source_system varchar(100),
    ingestion_timestamp datetime2 DEFAULT GETDATE(),
    processing_status varchar(20) DEFAULT 'pending',
    etl_batch_id varchar(100),
    is_duplicate bit DEFAULT 0,
    validation_errors nvarchar(1000),
    quality_score decimal(3,2)
);
```

**Key Indexes:**
- `IX_PayloadTransactions_Processing` on `(processing_status, etl_batch_id)`
- `IX_PayloadTransactions_Hash` on `payload_hash`
- `IX_PayloadTransactions_Canonical` on `canonical_tx_id`

---

**`dbo.Transactions`** - Silver Layer Clean Transactions
```sql
-- Cleaned transaction records
CREATE TABLE dbo.Transactions (
    transaction_id varchar(50) PRIMARY KEY,
    canonical_tx_id varchar(64) UNIQUE,
    interaction_id varchar(50),
    txn_ts datetime2,
    store_id varchar(50),
    total_amount decimal(12,2),
    total_items int,
    payment_method varchar(50),
    daypart varchar(20),                  -- Morning, Afternoon, Evening
    weekday_weekend varchar(20),          -- Weekday, Weekend
    processing_status varchar(20) DEFAULT 'active',
    created_timestamp datetime2 DEFAULT GETDATE()
);
```

**Relationships:**
- Foreign Key: `store_id` → `dbo.Stores.StoreID`
- Referenced by: `dbo.TransactionItems`, `dbo.BrandSubstitutions`

---

**`dbo.TransactionItems`** - Individual Product Items
```sql
-- Detailed product-level transaction data
CREATE TABLE dbo.TransactionItems (
    item_id bigint IDENTITY(1,1) PRIMARY KEY,
    transaction_id varchar(50),
    canonical_tx_id varchar(64),
    product_name varchar(200),
    sku_name varchar(200),
    barcode varchar(50),
    brand_detected varchar(100),          -- ML-enhanced brand detection
    brand_confidence decimal(3,2),
    category_detected varchar(100),       -- Auto-detected category
    nielsen_category varchar(100),        -- Nielsen FMCG taxonomy
    nielsen_department varchar(100),
    pack_size varchar(50),
    unit_price decimal(10,2),
    quantity int DEFAULT 1,
    total_price decimal(10,2),
    extraction_confidence decimal(3,2),
    data_quality_score decimal(3,2),
    extracted_timestamp datetime2 DEFAULT GETDATE(),
    processing_batch_id varchar(100)
);
```

**Key Indexes:**
- `IX_TransactionItems_Brand_Category` on `(brand_detected, category_detected)`
- `IX_TransactionItems_Nielsen` on `(nielsen_category, nielsen_department)`
- `IX_TransactionItems_Canonical` on `canonical_tx_id`

---

**`dbo.SalesInteractions`** - Customer Demographic Data
```sql
-- Customer interaction and demographic information
CREATE TABLE dbo.SalesInteractions (
    interaction_id varchar(50) PRIMARY KEY,
    canonical_tx_id varchar(64),
    session_id varchar(100),
    age_bracket varchar(20),              -- 18-24, 25-34, 35-44, etc.
    gender varchar(10),                   -- Male, Female, Other
    customer_type varchar(50),            -- Regular, First-time, Loyal, VIP
    interaction_type varchar(50),         -- purchase, inquiry, substitution
    channel varchar(30),                  -- in-store, online, mobile
    emotions varchar(100),                -- Happy, Neutral, Satisfied
    session_duration_minutes int,
    interaction_timestamp datetime2,
    store_id varchar(50),
    staff_id varchar(50),
    substitution_event varchar(10),       -- true, false, or empty
    substitution_reason varchar(100),
    suggestion_accepted varchar(10)       -- Yes, No, or empty
);
```

#### Business Intelligence Tables

**`dbo.BrandSubstitutions`** - Substitution Pattern Analysis
```sql
-- Brand substitution tracking and analysis
CREATE TABLE dbo.BrandSubstitutions (
    substitution_id bigint IDENTITY(1,1) PRIMARY KEY,
    interaction_id varchar(50),
    transaction_id varchar(50),
    canonical_tx_id varchar(64),
    original_brand varchar(100),
    original_product varchar(200),
    original_sku varchar(100),
    substituted_brand varchar(100),
    substituted_product varchar(200),
    substituted_sku varchar(100),
    substitution_reason varchar(100),     -- out_of_stock, price, preference
    suggestion_accepted bit DEFAULT 0,
    customer_requested bit DEFAULT 0,    -- vs store suggested
    original_price decimal(10,2),
    substituted_price decimal(10,2),
    price_difference decimal(10,2),      -- Computed column
    confidence_score decimal(3,2),
    detection_timestamp datetime2 DEFAULT GETDATE()
);
```

**Business Value:**
- Track brand switching patterns
- Identify out-of-stock situations
- Measure substitution acceptance rates
- Calculate revenue impact of substitutions

---

**`dbo.TransactionBaskets`** - Market Basket Analysis
```sql
-- Transaction-level basket composition analysis
CREATE TABLE dbo.TransactionBaskets (
    basket_id bigint IDENTITY(1,1) PRIMARY KEY,
    transaction_id varchar(50) UNIQUE,
    canonical_tx_id varchar(64),
    interaction_id varchar(50),
    total_items int,
    unique_products int,
    unique_brands int,
    unique_categories int,
    total_basket_value decimal(12,2),
    avg_item_price decimal(10,2),
    max_item_price decimal(10,2),
    product_list nvarchar(max),           -- JSON array
    brand_list nvarchar(max),             -- JSON array
    category_list nvarchar(max),          -- JSON array
    has_tobacco bit DEFAULT 0,           -- Category flags
    has_laundry bit DEFAULT 0,
    has_beverages bit DEFAULT 0,
    has_snacks bit DEFAULT 0,
    basket_timestamp datetime2
);
```

**JSON Structure Examples:**
```json
// product_list
[
  {"name": "Marlboro Red", "quantity": 2, "price": 88.00},
  {"name": "Coca Cola 1.5L", "quantity": 1, "price": 45.00}
]

// brand_list
["Marlboro", "Coca Cola", "Ariel"]

// category_list
["Cigarettes", "Soft Drinks", "Detergent"]
```

---

**`dbo.ProductAssociations`** - Market Basket Rules
```sql
-- Product association rules from market basket analysis
CREATE TABLE dbo.ProductAssociations (
    association_id bigint IDENTITY(1,1) PRIMARY KEY,
    product_a varchar(200),
    product_b varchar(200),
    brand_a varchar(100),
    brand_b varchar(100),
    category_a varchar(100),
    category_b varchar(100),
    support_count int,                    -- Co-occurrence count
    support_percentage decimal(5,2),      -- % of total transactions
    confidence decimal(5,2),              -- P(B|A)
    lift decimal(5,2),                    -- Lift = confidence / P(B)
    conviction decimal(5,2),              -- Conviction measure
    co_occurrence_frequency int,
    avg_basket_value decimal(10,2),
    total_revenue_impact decimal(12,2),
    analysis_date datetime2 DEFAULT GETDATE(),
    min_support_threshold decimal(3,2),
    min_confidence_threshold decimal(3,2)
);
```

**Business Applications:**
- Cross-selling recommendations
- Store layout optimization
- Promotional bundling strategies
- Inventory management

#### Geographic Hierarchy Tables

**`dbo.Region`** - Top-level Geographic Division
```sql
CREATE TABLE dbo.Region (
    RegionID int PRIMARY KEY,
    RegionName varchar(100),
    RegionCode varchar(10) UNIQUE,
    Country varchar(50) DEFAULT 'Philippines'
);
```

**`dbo.Province`** - Provincial Level
```sql
CREATE TABLE dbo.Province (
    ProvinceID int PRIMARY KEY,
    ProvinceName varchar(100),
    ProvinceCode varchar(10) UNIQUE,
    RegionID int FOREIGN KEY REFERENCES dbo.Region(RegionID)
);
```

**`dbo.Municipality`** - City/Municipality Level
```sql
CREATE TABLE dbo.Municipality (
    MunicipalityID int PRIMARY KEY,
    MunicipalityName varchar(100),
    MunicipalityCode varchar(10) UNIQUE,
    ProvinceID int FOREIGN KEY REFERENCES dbo.Province(ProvinceID)
);
```

**`dbo.Barangay`** - Smallest Administrative Unit
```sql
CREATE TABLE dbo.Barangay (
    BarangayID int PRIMARY KEY,
    BarangayName varchar(100),
    BarangayCode varchar(15) UNIQUE,
    MunicipalityID int FOREIGN KEY REFERENCES dbo.Municipality(MunicipalityID)
);
```

**`dbo.Stores`** - Store Master Data
```sql
-- Complete store information with geographic hierarchy
CREATE TABLE dbo.Stores (
    StoreID varchar(50) PRIMARY KEY,
    StoreName varchar(200),
    StoreType varchar(50),               -- Supermarket, Convenience, etc.
    RegionID int FOREIGN KEY REFERENCES dbo.Region(RegionID),
    ProvinceID int FOREIGN KEY REFERENCES dbo.Province(ProvinceID),
    MunicipalityID int FOREIGN KEY REFERENCES dbo.Municipality(MunicipalityID),
    BarangayID int FOREIGN KEY REFERENCES dbo.Barangay(BarangayID),
    Address varchar(500),
    PostalCode varchar(10),
    Latitude decimal(10,8),
    Longitude decimal(11,8),
    IsActive bit DEFAULT 1,
    OpeningDate datetime2,
    StoreSize varchar(20)                -- Small, Medium, Large, XL
);
```

#### Nielsen/Kantar Taxonomy Tables

**`dbo.BrandCategoryMapping`** - Brand-Category Alignment
```sql
-- Nielsen FMCG taxonomy brand mapping
CREATE TABLE dbo.BrandCategoryMapping (
    mapping_id bigint IDENTITY(1,1) PRIMARY KEY,
    brand_name varchar(100),
    nielsen_category varchar(100),
    nielsen_department varchar(100),
    nielsen_sub_category varchar(100),
    kantar_category varchar(100),        -- Optional Kantar alignment
    kantar_segment varchar(100),
    confidence_score decimal(3,2) DEFAULT 1.0,
    mapping_source varchar(50),          -- manual, automated, ml_predicted
    created_date datetime2 DEFAULT GETDATE(),
    updated_date datetime2,
    is_active bit DEFAULT 1,
    validated_by varchar(100),
    validation_date datetime2,
    validation_notes nvarchar(500)
);
```

### ref Schema - Reference Data Tables

**`ref.nielsen_departments`** - Nielsen Department Hierarchy
```sql
CREATE TABLE ref.nielsen_departments (
    department_id int IDENTITY(1,1) PRIMARY KEY,
    department_name varchar(100) UNIQUE,
    department_code varchar(20),
    parent_department_id int REFERENCES ref.nielsen_departments(department_id),
    hierarchy_level int DEFAULT 1,
    description nvarchar(500),
    is_active bit DEFAULT 1,
    sort_order int
);
```

**Sample Data:**
```sql
INSERT INTO ref.nielsen_departments VALUES
('Food & Beverages', 'F&B', NULL, 1, 'All food and beverage products', 1, 1),
('Household Care', 'HH', NULL, 1, 'Cleaning and household products', 1, 2),
('Personal Care', 'PC', NULL, 1, 'Health and beauty products', 1, 3),
('Tobacco & Vaping', 'TOB', NULL, 1, 'Tobacco and vaping products', 1, 4);
```

**`ref.nielsen_categories`** - Detailed Category Classification
```sql
CREATE TABLE ref.nielsen_categories (
    category_id int IDENTITY(1,1) PRIMARY KEY,
    category_name varchar(100) UNIQUE,
    category_code varchar(20),
    department_id int REFERENCES ref.nielsen_departments(department_id),
    sub_category varchar(100),
    category_type varchar(50),           -- FMCG, Non-FMCG, Service
    description nvarchar(500),
    is_active bit DEFAULT 1,
    sort_order int
);
```

**`ref.nielsen_brand_map`** - Standardized Brand Mapping
```sql
-- Comprehensive brand name standardization
CREATE TABLE ref.nielsen_brand_map (
    brand_mapping_id bigint IDENTITY(1,1) PRIMARY KEY,
    original_brand_name varchar(100),
    standardized_brand_name varchar(100),
    nielsen_category varchar(100),
    nielsen_department varchar(100),
    category_id int REFERENCES ref.nielsen_categories(category_id),
    department_id int REFERENCES ref.nielsen_departments(department_id),
    confidence_score decimal(3,2) DEFAULT 1.0,
    mapping_method varchar(50),          -- exact_match, fuzzy_match, manual
    created_by varchar(100),
    created_date datetime2 DEFAULT GETDATE(),
    last_updated datetime2,
    is_verified bit DEFAULT 0
);
```

### audit Schema - Monitoring & Audit Tables

**`audit.ETLProcessingLog`** - Process Execution Tracking
```sql
-- Complete ETL process monitoring
CREATE TABLE audit.ETLProcessingLog (
    log_id bigint IDENTITY(1,1) PRIMARY KEY,
    process_name varchar(200),
    batch_id varchar(100),
    start_time datetime2 DEFAULT GETDATE(),
    end_time datetime2,
    status varchar(20),                  -- running, completed, failed
    records_processed int,
    records_successful int,
    records_failed int,
    processing_duration_seconds int,
    error_message nvarchar(max),
    error_details nvarchar(max),
    retry_count int DEFAULT 0,
    cpu_time_seconds decimal(10,3),
    memory_used_mb decimal(10,2)
);
```

## Views Reference

### Gold Layer - Business Intelligence Views

**`dbo.v_transactions_flat_production`** - Primary Transaction View
- **Purpose**: Main view for transaction analytics with enhanced product data
- **Update Frequency**: Near real-time (updated as transactions are processed)
- **Key Features**:
  - Combines transaction, product, and store data
  - Includes Nielsen taxonomy alignment
  - Data quality scoring
  - Geographic hierarchy integration

```sql
-- Core structure (simplified)
SELECT
    canonical_tx_id,
    transaction_id,
    txn_ts,
    store_name,
    total_amount,
    brand,                        -- Primary brand (highest value item)
    category,                     -- Primary category
    nielsen_category,             -- Nielsen taxonomy
    nielsen_department,
    data_quality_score,
    extraction_confidence
FROM [complex_joins_and_calculations]
```

**`dbo.v_nielsen_complete_analytics`** - Nielsen Taxonomy Aligned View
- **Purpose**: Complete transaction data aligned with Nielsen FMCG taxonomy
- **Business Use**: Category management, brand analysis, market share
- **Key Features**:
  - 100% Nielsen taxonomy compliance
  - Customer demographics integration
  - Geographic analysis ready
  - Pack size standardization

**`dbo.v_insight_base`** - Customer Insights Foundation
- **Purpose**: Customer behavior and interaction analysis
- **Key Features**:
  - Demographics aggregation
  - Substitution pattern analysis
  - Customer journey tracking
  - Session-level insights

### Platinum Layer - Advanced Analytics Views

**`dbo.v_xtab_time_brand_category_abs`** - Cross-tabulation Analytics
- **Purpose**: Time-series cross-tabulation for brand/category performance
- **Features**:
  - Multiple time dimensions (hourly, daily, weekly, monthly)
  - Market share calculations
  - Performance ranking
  - Seasonal trend analysis

**`dbo.v_data_quality_monitor`** - Data Quality Dashboard
- **Purpose**: Real-time data quality monitoring and alerting
- **Metrics**:
  - Completeness rates
  - Accuracy scores
  - Freshness indicators
  - Processing success rates

**`dbo.v_pipeline_realtime_monitor`** - ETL Pipeline Monitoring
- **Purpose**: Real-time ETL process health monitoring
- **Features**:
  - Process execution status
  - Performance metrics
  - Error tracking
  - Resource utilization

**`dbo.v_flat_export_sheet`** - Analytics Export View
- **Purpose**: Flat format for external analytics tools
- **Features**:
  - All 12 required columns for cross-tab analysis
  - Co-purchase detection
  - Substitution flagging
  - Time formatting for readability

## Stored Procedures

### ETL Processing Procedures

**`dbo.sp_IngestRawTransactionData`** - Bronze Layer Ingestion
```sql
-- Parameters: @BatchId, @DataSource, @ProcessingMode
-- Purpose: Ingest raw JSON payloads into PayloadTransactions
-- Features: Deduplication, validation, error handling
```

**`dbo.sp_ExtractTransactionItems`** - Item Extraction
```sql
-- Parameters: @BatchId
-- Purpose: Extract individual items from JSON payloads
-- Features: Brand detection, category classification, confidence scoring
```

**`dbo.sp_DeduplicateTransactions`** - Deduplication Process
```sql
-- Parameters: @BatchId
-- Purpose: Identify and mark duplicate transactions
-- Methods: Hash comparison, business logic comparison
```

**`dbo.sp_ProcessBrandSubstitutions`** - Substitution Analysis
```sql
-- Parameters: @BatchId, @AnalysisThreshold
-- Purpose: Detect and analyze brand substitution patterns
-- Features: ML-based pattern detection, confidence scoring
```

### Nielsen Taxonomy Procedures

**`dbo.sp_ValidateCanonicalTaxonomy`** - Taxonomy Validation
```sql
-- Purpose: Validate brand-category mappings against Nielsen standards
-- Output: Compliance report, mapping suggestions
```

**`dbo.sp_AddBrandMapping`** - Add New Brand Mapping
```sql
-- Parameters: @BrandName, @NielsenCategory, @NielsenDepartment
-- Purpose: Add validated brand-category mapping
```

**`dbo.sp_RefreshAnalyticsViews`** - View Refresh
```sql
-- Purpose: Refresh materialized analytics views
-- Frequency: Scheduled (every 30 minutes)
```

### Monitoring & Maintenance Procedures

**`dbo.sp_scout_health_check`** - System Health Check
```sql
-- Purpose: Comprehensive system health validation
-- Checks: Data freshness, quality scores, process status
-- Output: Health report with actionable recommendations
```

**`dbo.sp_GenerateQualityReport`** - Data Quality Reporting
```sql
-- Parameters: @StartDate, @EndDate, @ReportType
-- Purpose: Generate comprehensive data quality reports
-- Formats: Summary, detailed, executive dashboard
```

## Functions

### Data Processing Functions

**`dbo.fn_DetectBrandName(@ProductName)`** - Brand Detection
```sql
-- Returns: VARCHAR(100) - Detected brand name
-- Method: Exact match → Fuzzy match → ML prediction
-- Confidence: Stored separately in processing tables
```

**`dbo.fn_ClassifyCategory(@ProductName)`** - Category Classification
```sql
-- Returns: VARCHAR(100) - Detected category
-- Method: Keyword matching → Pattern recognition → Default classification
```

**`dbo.fn_FuzzyMatch(@String1, @String2)`** - Fuzzy String Matching
```sql
-- Returns: DECIMAL(3,2) - Similarity score (0.0 to 1.0)
-- Algorithm: Levenshtein distance with optimizations
-- Use: Brand name standardization, deduplication
```

### Utility Functions

**`dbo.fn_CalculateConfidence(@Factors)`** - Confidence Scoring
```sql
-- Returns: DECIMAL(3,2) - Confidence score
-- Factors: Data completeness, validation results, ML scores
```

**`dbo.fn_GetStoreHierarchy(@StoreID)`** - Geographic Hierarchy
```sql
-- Returns: TABLE - Complete geographic path
-- Columns: Region, Province, Municipality, Barangay
```

## Indexes & Performance

### Primary Performance Indexes

**Transaction Processing Indexes:**
```sql
-- PayloadTransactions
CREATE NONCLUSTERED INDEX IX_PayloadTransactions_Processing
ON dbo.PayloadTransactions (processing_status, etl_batch_id, ingestion_timestamp)
INCLUDE (canonical_tx_id, payload_hash);

-- TransactionItems
CREATE NONCLUSTERED INDEX IX_TransactionItems_Brand_Category_Date
ON dbo.TransactionItems (brand_detected, category_detected, extracted_timestamp)
INCLUDE (canonical_tx_id, product_name, total_price);

-- SalesInteractions
CREATE NONCLUSTERED INDEX IX_SalesInteractions_Demographics_Date
ON dbo.SalesInteractions (age_bracket, gender, interaction_timestamp)
INCLUDE (canonical_tx_id, customer_type, emotions);
```

**Analytics Indexes:**
```sql
-- BrandSubstitutions
CREATE NONCLUSTERED INDEX IX_BrandSub_Analysis
ON dbo.BrandSubstitutions (original_brand, substituted_brand, suggestion_accepted)
INCLUDE (substitution_reason, price_difference);

-- ProductAssociations
CREATE NONCLUSTERED INDEX IX_ProductAssoc_Metrics
ON dbo.ProductAssociations (support_percentage, confidence, lift)
INCLUDE (product_a, product_b, brand_a, brand_b);
```

**Geographic Indexes:**
```sql
-- Stores
CREATE NONCLUSTERED INDEX IX_Stores_Geography
ON dbo.Stores (RegionID, ProvinceID, MunicipalityID, IsActive)
INCLUDE (StoreID, StoreName, StoreType);
```

### Columnstore Indexes for Analytics

```sql
-- Analytics workload optimization
CREATE NONCLUSTERED COLUMNSTORE INDEX IX_TransactionItems_Analytics
ON dbo.TransactionItems (
    canonical_tx_id, brand_detected, category_detected,
    nielsen_category, unit_price, total_price, extracted_timestamp
);

CREATE NONCLUSTERED COLUMNSTORE INDEX IX_PayloadTransactions_Analytics
ON dbo.PayloadTransactions (
    canonical_tx_id, txn_ts, total_amount, total_items,
    store_id, processing_status
);
```

## Relationships & Dependencies

### Core Entity Relationships

```
PayloadTransactions (1) ──→ (1) Transactions
                                      │
                                      ├──→ (M) TransactionItems
                                      ├──→ (1) SalesInteractions
                                      ├──→ (1) TransactionBaskets
                                      └──→ (M) BrandSubstitutions

Stores (1) ──→ (M) Transactions
       │
       ├──→ Region (M:1)
       ├──→ Province (M:1)
       ├──→ Municipality (M:1)
       └──→ Barangay (M:1)

BrandCategoryMapping (1) ──→ (M) TransactionItems
                                        │
                                        └──→ nielsen_brand_map
```

### View Dependencies

```
v_transactions_flat_production
├── Depends on: Transactions, TransactionItems, Stores
└── Used by: v_nielsen_complete_analytics, v_xtab_analytics

v_nielsen_complete_analytics
├── Depends on: v_transactions_flat_production, BrandCategoryMapping, SalesInteractions
└── Used by: v_xtab_time_brand_category_abs, external BI tools

v_insight_base
├── Depends on: SalesInteractions, BrandSubstitutions
└── Used by: v_flat_export_sheet, customer analytics
```

### Processing Dependencies

```
ETL Process Flow:
1. sp_IngestRawTransactionData → PayloadTransactions
2. sp_ExtractTransactionItems → TransactionItems
3. sp_DeduplicateTransactions → Updates PayloadTransactions
4. sp_ProcessBrandSubstitutions → BrandSubstitutions
5. sp_RefreshAnalyticsViews → All analytics views
```

This comprehensive database objects reference provides complete documentation of the Scout Analytics Platform's data architecture, enabling efficient development, maintenance, and optimization of the system.