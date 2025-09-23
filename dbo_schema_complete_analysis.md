# Complete DBO Schema Analysis - Scout v7 Database

## Database Overview
- **Server**: sqltbwaprojectscoutserver.database.windows.net
- **Database**: SQL-TBWA-ProjectScout-Reporting-Prod
- **Schema**: dbo
- **Total Objects**: 153 (100 tables + 44 views + 9 procedures)

## 📊 Tables (100)

### Core Transaction Tables
- **PayloadTransactions** - Raw JSON transaction payloads (12,192 records)
- **SalesInteractions** - Processed interactions (165,480 records)
- **TransactionItems** - Individual transaction items
- **SalesInteractionBrands** - Brand associations
- **SalesInteractionTranscripts** - Audio transcription data

### Medallion Architecture Tables

#### Bronze Layer (Raw Data)
- **bronze_device_logs** - Raw device logs
- **bronze_transcriptions** - Raw audio transcriptions
- **bronze_vision_detections** - Raw vision detection data

#### Silver Layer (Cleaned Data)
- **silver_location_verified** - Verified location data
- **silver_transcripts** - Cleaned transcriptions
- **silver_txn_items** - Cleaned transaction items
- **silver_vision_detections** - Cleaned vision detections

#### Gold Layer (Business Ready)
- **gold_interaction_summary** - Aggregated interactions
- **gold_reconstructed_transcripts** - Reconstructed audio
- **gold_store_performance** - Store performance metrics

### Master Data Tables
- **Brands** - Brand master data
- **BrandUpdates** - Brand update tracking
- **BrandVersions** - Brand version control
- **Products** - Product catalog
- **UnbrandedCommodities** - Unbranded product mapping
- **Customers** - Customer information

### Location & Geography
- **Stores** - Store master data
- **DeviceStoreMap** - Device-to-store mapping
- **DeviceData** - Device information
- **StoreLocationStaging** - Location staging data
- **Region**, **Province**, **Municipality**, **Barangay** - Geographic hierarchy

### Cross-Tab Analysis Tables (16)
- **ct_ageXbrand** - Age vs Brand analysis
- **ct_ageXcategory** - Age vs Category analysis
- **ct_ageXpack** - Age vs Package analysis
- **ct_basketXcategory** - Basket vs Category analysis
- **ct_basketXcusttype** - Basket vs Customer type analysis
- **ct_basketXemotions** - Basket vs Emotions analysis
- **ct_basketXpay** - Basket vs Payment analysis
- **ct_genderXdaypart** - Gender vs Daypart analysis
- **ct_payXdemo** - Payment vs Demographics analysis
- **ct_substEventXcategory** - Substitution vs Category analysis
- **ct_substEventXreason** - Substitution vs Reason analysis
- **ct_suggestionAcceptedXbrand** - Suggestion acceptance vs Brand
- **ct_timeXbrand** - Time vs Brand analysis
- **ct_timeXcategory** - Time vs Category analysis
- **ct_timeXdemo** - Time vs Demographics analysis
- **ct_timeXemotions** - Time vs Emotions analysis

### Campaign & Analytics Tables
- **campaign_performance** - Campaign metrics
- **campaignInsights** - Campaign insights
- **consumer_profile** - Consumer profiles
- **creative_asset** - Creative asset management

### System & Audit Tables
- **audit_log** - System audit trail
- **IntegrationAuditLogs** - Integration audit logs
- **TranscriptChunkAudit** - Transcript processing audit
- **processingLogs** - ETL processing logs
- **qualityMetrics** - Data quality metrics
- **migrations** - Database migrations
- **systranschemas** - System schemas

### Staging & Processing Tables
- **PayloadTransactionsStaging_csv** - CSV staging
- **TranscriptionDataTable** - Transcription processing
- **fileMetadata** - File processing metadata
- **pageIndex** - Page indexing
- **semanticIndex** - Semantic search index
- **SessionMatches** - Session matching results

### Validation & Monitoring
- **adsbot_validation_result** - Bot validation results
- **data_subject_request** - GDPR compliance
- **RequestMethods** - API request tracking
- **txn_timestamp_overrides** - Timestamp corrections

### Awards & Analysis (PH Awards)
- **ph_awards_analysis_batches** - Analysis batch processing
- **ph_awards_assets** - Award asset management
- **ph_awards_campaigns** - Award campaign tracking
- **ph_awards_pages** - Award page content

## 📈 Views (44)

### Cross-Tab Views (16)
All ct_* tables are also available as views for dynamic querying.

### Gold Layer Views
- **gold_interaction_summary** - Interaction summary view
- **gold_reconstructed_transcripts** - Reconstructed transcript view

### Silver Layer Views
- **silver_transcripts** - Cleaned transcript view
- **silver_vision_detections** - Vision detection view

### Analytics Views
- **v_transactions_crosstab_production** - Production crosstab
- **v_transactions_flat_production** - Production flat view
- **v_transactions_flat_v24** - Version 24 flat view
- **v_xtab_*_abs** - Cross-tab absolute views (6 variations)

### Monitoring Views
- **v_azure_norm** - Azure normalization view
- **v_data_quality_monitor** - Data quality monitoring
- **v_duplicate_detection_monitor** - Duplicate detection
- **v_insight_base** - Base insights view
- **v_payload_norm** - Payload normalization
- **v_performance_metrics_dashboard** - Performance dashboard
- **v_pipeline_realtime_monitor** - Real-time pipeline monitor
- **v_SalesInteractionsComplete** - Complete sales interactions
- **v_store_facial_age_101_120** - Store facial age analysis
- **v_store_health_dashboard** - Store health dashboard

### Mock/Demo Views
- **vw_campaign_effectiveness** - Campaign effectiveness
- **vw_tbwa_brand_performance_mock** - TBWA brand performance mock
- **vw_tbwa_latest_mock_transactions** - Latest mock transactions
- **vw_tbwa_location_analytics_mock** - Location analytics mock
- **vw_transaction_analytics** - Transaction analytics

## ⚙️ Stored Procedures (9)

### Core Procedures
1. **PopulateSessionMatches** - Session matching logic
2. **sp_adsbot_validation_summary** - Bot validation summary
3. **sp_create_v_transactions_flat_authoritative** - Authoritative flat view creation
4. **sp_create_v_transactions_flat_min** - Minimal flat view creation
5. **sp_refresh_analytics_views** - Analytics view refresh
6. **sp_scout_health_check** - System health check
7. **sp_upsert_device_store** - Device-store mapping upsert
8. **sp_validate_v24** - Version 24 validation
9. **VerifyScoutMigration** - Migration verification

## 🔍 JSON Schema Analysis

### PayloadTransactions JSON Structure

Based on analysis of valid JSON payloads (12,101 out of 12,192 records):

```json
{
  "storeId": "108",
  "deviceId": "SCOUTPI-0006",
  "timestamp": "",
  "transactionId": "0003eea1-082e-497b-a7c4-c855d264ada6",
  "brandDetection": {
    "detectedBrands": {
      "Marlboro": 0.83,
      "Coca-Cola": 0.23,
      "Camel": 0.83
    },
    "explicitMentions": [
      {
        "brand": "Marlboro",
        "category": "Tobacco Products",
        "subcategory": "unspecified",
        "confidence": 0.83,
        "productName": "Marlboro Gold Round Corner 20's"
      }
    ]
  },
  "totals": {
    "totalAmount": 352.00,
    "totalItems": 2,
    "currency": "PHP"
  },
  "items": [
    {
      "itemId": 1,
      "brandName": "Marlboro",
      "productName": "Marlboro Gold Round Corner 20's",
      "category": "Tobacco Products",
      "subcategory": "unspecified",
      "unitPrice": 176.00,
      "quantity": 2,
      "totalPrice": 352.00,
      "confidence": 0.83
    }
  ],
  "demographics": {
    "ageBracket": "Adult",
    "gender": "Female",
    "role": "Primary Shopper",
    "emotion": "Neutral",
    "confidence": 0.75
  },
  "transactionContext": {
    "paymentMethod": "cash",
    "daypart": "Morning",
    "weekdayWeekend": "Weekday",
    "isHoliday": false,
    "weather": "Clear",
    "otherProductsBought": ["Coca-Cola"],
    "substitutionEvent": false,
    "substitutionDetails": {
      "originalBrand": null,
      "substituteBrand": null,
      "reason": null
    },
    "suggestionAccepted": false,
    "crossSelling": true
  },
  "audioContext": {
    "transcript": "marlboro coke isa camel, kulang",
    "transcriptConfidence": 0.85,
    "language": "tl-PH",
    "audioQuality": "good"
  },
  "visionContext": {
    "facialAnalysis": {
      "ageDetected": "25-35",
      "genderDetected": "Female",
      "emotionDetected": "Neutral",
      "confidence": 0.78
    },
    "productDetection": {
      "productsVisible": ["Marlboro", "Coca-Cola"],
      "brandLogosDetected": 2,
      "confidence": 0.82
    }
  },
  "metadata": {
    "processingVersion": "v2.4",
    "createdAt": "2025-09-05T09:44:28.000Z",
    "updatedAt": "2025-09-05T09:44:28.000Z",
    "processingDuration": "1.2s",
    "dataSource": "real-time",
    "qualityScore": 0.85
  }
}
```

### Key JSON Paths for Extraction

#### Basic Transaction Data
- `$.storeId` - Store identifier
- `$.deviceId` - Device identifier
- `$.transactionId` - Transaction ID
- `$.timestamp` - Transaction timestamp

#### Financial Data
- `$.totals.totalAmount` - Total transaction amount
- `$.totals.totalItems` - Total item count
- `$.totals.currency` - Currency (PHP)

#### Product Data
- `$.items[].brandName` - Product brand
- `$.items[].productName` - Product name
- `$.items[].category` - Product category
- `$.items[].unitPrice` - Unit price
- `$.items[].quantity` - Quantity purchased

#### Demographics & Context
- `$.demographics.ageBracket` - Customer age bracket
- `$.demographics.gender` - Customer gender
- `$.demographics.emotion` - Customer emotion
- `$.transactionContext.paymentMethod` - Payment method
- `$.transactionContext.daypart` - Time of day
- `$.transactionContext.weekdayWeekend` - Day type

#### Behavioral Data
- `$.transactionContext.otherProductsBought` - Cross-sell items
- `$.transactionContext.substitutionEvent` - Substitution occurred
- `$.transactionContext.substitutionDetails` - Substitution details
- `$.transactionContext.suggestionAccepted` - Staff suggestion accepted

#### Audio & Vision Data
- `$.audioContext.transcript` - Audio transcript
- `$.audioContext.language` - Language detected
- `$.visionContext.facialAnalysis` - Facial detection data
- `$.visionContext.productDetection` - Product detection data

## 📋 Data Quality Assessment

### JSON Completeness
- **Valid JSON**: 12,101 (99.25%)
- **Malformed JSON**: 91 (0.75%)
- **Empty/Null**: 0 (0%)

### Critical Tables with Canonical IDs
- **PayloadTransactions**: 12,192 records, 100% have canonical_tx_id_norm
- **SalesInteractions**: 165,480 records, 100% have canonical_tx_id_norm
- **gold.v_transactions_flat**: 12,192 records (flattened view)

### Schema Completeness
- **Tables**: ✅ Complete (100 objects)
- **Views**: ✅ Complete (44 objects)
- **Procedures**: ✅ Complete (9 objects)
- **JSON Schema**: ✅ Comprehensive structure mapped

## 🚀 Recommendations

1. **JSON Analysis**: 99.25% valid JSON payloads ready for extraction
2. **Schema Utilization**: Rich set of cross-tab views for analytics
3. **Data Pipeline**: Well-structured medallion architecture
4. **Monitoring**: Comprehensive health check and audit capabilities
5. **Quality**: Robust validation and duplicate detection systems

The database schema is enterprise-ready with comprehensive transaction tracking, advanced analytics capabilities, and strong data governance frameworks.