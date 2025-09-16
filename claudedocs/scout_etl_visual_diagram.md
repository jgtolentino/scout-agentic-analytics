# Scout ETL Visual Flow Diagram

## 📊 Complete Data Processing Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           SCOUT DATA PROCESSING PIPELINE                             │
└─────────────────────────────────────────────────────────────────────────────────────┘

┌─── DATA SOURCES ────────────────────────────────────────────────────────────────────┐
│                                                                                     │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                │
│  │   Scout Edge    │    │  Google Drive   │    │  Azure Legacy   │                │
│  │   IoT Devices   │    │   Documents     │    │   Database      │                │
│  │                 │    │                 │    │                 │                │
│  │ • SCOUTPI-0002  │    │ • PDFs          │    │ • 176,879 txns  │                │
│  │ • SCOUTPI-0003  │    │ • Spreadsheets  │    │ • Demographics  │                │
│  │ • SCOUTPI-0004  │    │ • Presentations │    │ • Campaigns     │                │
│  │ • SCOUTPI-0006  │    │ • Reports       │    │ • Survey data   │                │
│  │ • SCOUTPI-0009  │    │                 │    │                 │                │
│  │ • SCOUTPI-0010  │    │                 │    │                 │                │
│  │ • SCOUTPI-0012  │    │                 │    │                 │                │
│  │                 │    │                 │    │                 │                │
│  │ 13,289 JSON     │    │ Document        │    │ Structured      │                │
│  │ transactions    │    │ Intelligence    │    │ SQL Data        │                │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘                │
│           │                       │                       │                       │
└───────────│───────────────────────│───────────────────────│───────────────────────┘
            │                       │                       │
            ▼                       ▼                       ▼
┌─── INGESTION LAYER ─────────────────────────────────────────────────────────────────┐
│                                                                                     │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                │
│  │ Audio → STT →   │    │ OCR → Text →    │    │ SQL Extract →   │                │
│  │ JSON Generation │    │ Entity Extract  │    │ Schema Mapping  │                │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘                │
│           │                       │                       │                       │
│           ▼                       ▼                       ▼                       │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                │
│  │ Google Drive    │    │ Document        │    │ Direct DB       │                │
│  │ Auto-Upload     │    │ Processing      │    │ Connection      │                │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘                │
│           │                       │                       │                       │
└───────────│───────────────────────│───────────────────────│───────────────────────┘
            │                       │                       │
            ▼                       ▼                       ▼
┌─── TEMPORAL WORKFLOWS ──────────────────────────────────────────────────────────────┐
│                                                                                     │
│           ┌─────────────────────────────────────────────────────────────┐          │
│           │              SUPABASE ORCHESTRATION                         │          │
│           │                                                             │          │
│           │  ┌─────────────────┐    ┌─────────────────┐                │          │
│           │  │ drive_to_bucket │    │ bucket_to_bronze│                │          │
│           │  │    workflow     │    │    workflow     │                │          │
│           │  └─────────────────┘    └─────────────────┘                │          │
│           │           │                       │                        │          │
│           │           ▼                       ▼                        │          │
│           │  ┌─────────────────┐    ┌─────────────────┐                │          │
│           │  │ Bucket Storage  │    │ Enhanced Brand  │                │          │
│           │  │ scout-ingest    │    │   Detection     │                │          │
│           │  └─────────────────┘    └─────────────────┘                │          │
│           └─────────────────────────────────────────────────────────────┘          │
│                                      │                                             │
└──────────────────────────────────────│─────────────────────────────────────────────┘
                                       │
                                       ▼
┌─── BRONZE LAYER (Raw Data) ─────────────────────────────────────────────────────────┐
│                                                                                     │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                │
│  │bronze_scout_edge│    │ bronze_drive_   │    │ bronze_azure_   │                │
│  │  _transactions  │    │  intelligence   │    │    legacy       │                │
│  │                 │    │                 │    │                 │                │
│  │ • JSON parsing  │    │ • Text extract  │    │ • SQL import    │                │
│  │ • Schema valid  │    │ • OCR process   │    │ • Quality filter│                │
│  │ • Quality score │    │ • Entity recog  │    │ • Schema map    │                │
│  │ • Brand detect  │    │ • Doc classify  │    │ • Demo enrich   │                │
│  │ • Audio clean   │    │ • Meta enrich   │    │ • Campaign link │                │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘                │
│           │                       │                       │                       │
└───────────│───────────────────────│───────────────────────│───────────────────────┘
            │                       │                       │
            ▼                       ▼                       ▼
┌─── ENHANCED BRAND DETECTION ────────────────────────────────────────────────────────┐
│                                                                                     │
│                    ┌─────────────────────────────────────────┐                     │
│                    │     match_brands_enhanced()             │                     │
│                    │                                         │                     │
│                    │  ┌─────────────┐  ┌─────────────┐      │                     │
│                    │  │Exact Match  │  │Alias Match  │      │                     │
│                    │  │Confidence:  │  │Confidence:  │      │                     │
│                    │  │ 0.8 - 1.0   │  │ 0.6 - 0.8   │      │                     │
│                    │  └─────────────┘  └─────────────┘      │                     │
│                    │         │               │              │                     │
│                    │         ▼               ▼              │                     │
│                    │  ┌─────────────┐  ┌─────────────┐      │                     │
│                    │  │Fuzzy Match  │  │Context Boost│      │                     │
│                    │  │Confidence:  │  │ +0.02-0.05  │      │                     │
│                    │  │ 0.4 - 0.7   │  │   boost     │      │                     │
│                    │  └─────────────┘  └─────────────┘      │                     │
│                    └─────────────────────────────────────────┘                     │
│                                         │                                          │
│     Enhanced Brands: Hello, TM, Tang, Voice, Roller Coaster, etc.                │
│     Recovery Rate: 85% | Additional Detections: ~213 brands                       │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
┌─── SILVER LAYER (Unified Analytics) ────────────────────────────────────────────────┐
│                                                                                     │
│               ┌─────────────────────────────────────────────────────────┐          │
│               │              UNIFIED TRANSACTIONS                        │          │
│               │                                                         │          │
│               │  Scout Edge (13,289) + Azure Legacy (176,879)          │          │
│               │  = 190,168 Total Unified Transactions                   │          │
│               │                                                         │          │
│               │  ┌─────────────────┐    ┌─────────────────┐            │          │
│               │  │ Field Mapping   │    │ Quality Gates   │            │          │
│               │  │ • transaction_id│    │ • ≥80% quality  │            │          │
│               │  │ • store_id      │    │ • Schema valid  │            │          │
│               │  │ • brand_name    │    │ • Business rules│            │          │
│               │  │ • peso_value    │    │ • Cross validate│            │          │
│               │  │ • device_id     │    │ • Outlier detect│            │          │
│               │  └─────────────────┘    └─────────────────┘            │          │
│               └─────────────────────────────────────────────────────────┘          │
│                                         │                                          │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐               │
│  │silver_unified_  │    │silver_drive_    │    │silver_          │               │
│  │  transactions   │    │  intelligence   │    │ interactions    │               │
│  │                 │    │                 │    │                 │               │
│  │ • Cross-source  │    │ • Doc analytics │    │ • Journey       │               │
│  │ • Demographics  │    │ • Entity link   │    │ • Behavior      │               │
│  │ • Brand unified │    │ • Campaign map  │    │ • Patterns      │               │
│  │ • Quality norm  │    │ • Content index │    │ • Attribution   │               │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘               │
│           │                       │                       │                      │
└───────────│───────────────────────│───────────────────────│──────────────────────┘
            │                       │                       │
            ▼                       ▼                       ▼
┌─── GOLD LAYER (Business Intelligence) ──────────────────────────────────────────────┐
│                                                                                     │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                │
│  │gold_unified_    │    │gold_drive_      │    │gold_executive_  │                │
│  │retail_intel     │    │business_intel   │    │    kpis         │                │
│  │                 │    │                 │    │                 │                │
│  │ • Brand perform │    │ • Campaign ROI  │    │ • Revenue KPIs  │                │
│  │ • Store metrics │    │ • Content value │    │ • Growth rates  │                │
│  │ • Customer seg  │    │ • Document rank │    │ • Market share  │                │
│  │ • Market trends │    │ • Entity network│    │ • Efficiency    │                │
│  │ • Competitive   │    │ • Knowledge map │    │ • Quality score │                │
│  │ • Cross-channel │    │ • Usage patterns│    │ • Device health │                │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘                │
│           │                       │                       │                      │
└───────────│───────────────────────│───────────────────────│──────────────────────┘
            │                       │                       │
            ▼                       ▼                       ▼
┌─── PLATINUM LAYER (ML & Advanced Analytics) ────────────────────────────────────────┐
│                                                                                     │
│                         ┌─────────────────────────────────┐                        │
│                         │         MindsDB Integration    │                        │
│                         │                                 │                        │
│                         │  ┌─────────────────────────┐   │                        │
│                         │  │ Predictive Models       │   │                        │
│                         │  │ • Sales forecasting    │   │                        │
│                         │  │ • Customer churn       │   │                        │
│                         │  │ • Inventory optimization│   │                        │
│                         │  │ • Price elasticity     │   │                        │
│                         │  │ • Campaign response    │   │                        │
│                         │  │ • Market trends        │   │                        │
│                         │  └─────────────────────────┘   │                        │
│                         └─────────────────────────────────┘                        │
│                                         │                                          │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐               │
│  │ Feature         │    │ Real-time ML    │    │ Advanced        │               │
│  │ Engineering     │    │ Inference       │    │ Analytics       │               │
│  │                 │    │                 │    │                 │               │
│  │ • Behavior vec  │    │ • Live predict  │    │ • Cohort        │               │
│  │ • Brand affinity│    │ • Recommend     │    │ • Segmentation  │               │
│  │ • Temporal feat │    │ • Dynamic price │    │ • Attribution   │               │
│  │ • Geographic    │    │ • Inventory opt │    │ • Lifetime val  │               │
│  │ • Price elastic │    │ • Alert system │    │ • Market basket │               │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘               │
│                                         │                                          │
└─────────────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
┌─── CONSUMPTION LAYER ───────────────────────────────────────────────────────────────┐
│                                                                                     │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                │
│  │   Executive     │    │   Operational   │    │   Analytical    │                │
│  │  Dashboards     │    │   Dashboards    │    │   Dashboards    │                │
│  │                 │    │                 │    │                 │                │
│  │ • Revenue perf  │    │ • Real-time mon │    │ • Customer jour │                │
│  │ • Market share  │    │ • Device health │    │ • Brand affinity│                │
│  │ • Brand intel   │    │ • Quality assur │    │ • Market trends │                │
│  │ • Campaign ROI  │    │ • Process stats │    │ • Competitive   │                │
│  │ • Store efficiency│   │ • Inventory lev │    │ • Predictions   │                │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘                │
│           │                       │                       │                      │
│           ▼                       ▼                       ▼                      │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐                │
│  │  Next.js Web    │    │   Mobile Apps   │    │   API Endpoints │                │
│  │   Application   │    │                 │    │                 │                │
│  │                 │    │ • Store mgmt    │    │ • Data export   │                │
│  │ • Interactive   │    │ • Field ops     │    │ • Integration   │                │
│  │ • Real-time     │    │ • Monitoring    │    │ • Third-party   │                │
│  │ • Responsive    │    │ • Reporting     │    │ • Automation    │                │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘                │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## ⚡ Real-Time Processing Flow

```
Scout Device → Google Drive → Temporal Workflow → Supabase → Analytics → Dashboard
     ^              ^              ^               ^           ^          ^
   <2 min         <5 min        Real-time      Real-time   Real-time   <30 sec
```

## 📊 Data Volume & Performance

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              DATA METRICS                                            │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  Total Transactions: 190,168 (Scout Edge: 13,289 + Azure: 176,879)                │
│  Processing Speed: 5,650 files/second (parallel processing)                        │
│  Data Quality: 100% Scout Edge | ≥80% Azure (quality filtered)                    │
│  Brand Detection: 85% improvement on missed brands                                 │
│  Real-time Latency: <2 minutes from device to dashboard                           │
│  Storage: Supabase (PostgreSQL) + Bucket (file storage)                           │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

This architecture provides complete end-to-end data processing from IoT devices through advanced analytics, with real-time capabilities and comprehensive business intelligence.