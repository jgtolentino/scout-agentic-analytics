# Scout v7 Comprehensive Analytics Suite

This directory contains SQL analytics queries designed to provide comprehensive insights into TBWA Project Scout's retail intelligence data.

## Analytics Files

### Core Analytics
- **`master_catalog.sql`** - Master data catalog schema with brand/SKU tracking and conversation intelligence tables
- **`store_demographics.sql`** - Store profiling, purchase demographics, and temporal sales patterns
- **`tobacco_analytics.sql`** - Tobacco category analysis with demographics, purchase patterns, and co-purchase behavior
- **`laundry_analytics.sql`** - Laundry soap analysis with detergent types and fabric conditioner patterns
- **`all_categories_analytics.sql`** - Category performance overview with cross-category affinity analysis
- **`conversation_intelligence.sql`** - Customer-store owner interaction analysis with speaker separation

## Export System

### Quick Start
```bash
# Export all analytics with default date range (last 3 months)
make analytics-comprehensive

# Export with custom date range
DATE_FROM=2025-08-01 DATE_TO=2025-09-01 ./scripts/export_comprehensive_analytics.sh

# Export specific date range via script parameters
./scripts/export_comprehensive_analytics.sh --date-from 2025-08-01 --date-to 2025-09-01
```

### Output Structure
```
out/comprehensive_analytics/
├── store_demographics/
│   ├── store_profiles_YYYYMMDD_HHMMSS.csv
│   ├── purchase_demographics_YYYYMMDD_HHMMSS.csv
│   ├── sales_by_week_YYYYMMDD_HHMMSS.csv
│   ├── sales_by_month_YYYYMMDD_HHMMSS.csv
│   └── sales_by_daypart_category_YYYYMMDD_HHMMSS.csv
├── tobacco_analytics/
│   ├── tobacco_demographics_YYYYMMDD_HHMMSS.csv
│   ├── tobacco_purchase_profiles_YYYYMMDD_HHMMSS.csv
│   ├── tobacco_sales_daypart_analysis_YYYYMMDD_HHMMSS.csv
│   ├── tobacco_sticks_per_visit_YYYYMMDD_HHMMSS.csv
│   ├── tobacco_co_purchase_analysis_YYYYMMDD_HHMMSS.csv
│   ├── tobacco_frequent_terms_YYYYMMDD_HHMMSS.csv
│   └── tobacco_conversation_intelligence_YYYYMMDD_HHMMSS.csv
├── laundry_analytics/
│   ├── laundry_demographics_YYYYMMDD_HHMMSS.csv
│   ├── laundry_purchase_profiles_YYYYMMDD_HHMMSS.csv
│   ├── detergent_type_analysis_YYYYMMDD_HHMMSS.csv
│   ├── fabric_conditioner_analysis_YYYYMMDD_HHMMSS.csv
│   ├── laundry_co_purchase_YYYYMMDD_HHMMSS.csv
│   └── laundry_frequent_terms_YYYYMMDD_HHMMSS.csv
├── all_categories/
│   ├── category_performance_overview_YYYYMMDD_HHMMSS.csv
│   ├── cross_category_affinity_YYYYMMDD_HHMMSS.csv
│   ├── customer_journey_mapping_YYYYMMDD_HHMMSS.csv
│   └── category_seasonal_trends_YYYYMMDD_HHMMSS.csv
├── conversation_intelligence/
│   ├── conversation_overview_YYYYMMDD_HHMMSS.csv
│   ├── intent_classification_YYYYMMDD_HHMMSS.csv
│   ├── brand_mention_analysis_YYYYMMDD_HHMMSS.csv
│   ├── conversation_flow_effectiveness_YYYYMMDD_HHMMSS.csv
│   └── conversation_summary_YYYYMMDD_HHMMSS.csv
└── summary/
    └── analytics_export_summary_YYYYMMDD_HHMMSS.txt
```

## Key Analytics Features

### Store Demographics
- **Store Profiles**: Transaction volume, customer demographics, conversion rates
- **Purchase Demographics**: Payment method, daypart, regional analysis
- **Temporal Patterns**: Weekly/monthly sales with "Pecha de Peligro" analysis (Filipino salary periods)
- **Daypart Analysis**: Category performance by time of day

### Category-Specific Analysis

#### Tobacco Products
- **Demographics**: Age bands, gender, region with brand preferences
- **Purchase Patterns**: Hour/day patterns, salary period impact ("Pecha de Peligro")
- **Sticks Per Visit**: Customer buying behavior segmentation
- **Co-Purchase**: What's bought with cigarettes, association strength
- **Frequent Terms**: Voice transcript analysis for Filipino market insights

#### Laundry Products
- **Detergent Types**: Bar vs powder vs liquid soap analysis
- **Fabric Conditioner**: Attachment rates and co-purchase patterns
- **Brand Affinities**: Cross-brand purchasing behavior
- **Voice Analysis**: Filipino-specific laundry terms and preferences

#### All Categories
- **Performance Rankings**: 30+ categories with growth trends
- **Cross-Category Affinity**: Market basket analysis with lift calculations
- **Customer Journey**: Category sequence analysis
- **Seasonal Trends**: Monthly performance patterns

### Conversation Intelligence
- **Speaker Separation**: Customer vs store owner dialogue analysis
- **Intent Classification**: Purchase intent, substitution patterns
- **Brand Mentions**: Brand consistency and switching behavior
- **Flow Effectiveness**: Conversation patterns that drive conversions
- **Suggestion Acceptance**: Store owner recommendation success rates

## Data Sources

### Primary Tables
- **`canonical.v_transactions_flat_enhanced`** - Main transaction data with conversation intelligence
- **`dim.stores`** - Store master data
- **`dbo.conversation_segments`** - Speaker-separated dialogue (if available)
- **`dbo.purchase_funnel_tracking`** - 5-stage customer journey (if available)

### Enhanced JSON Payload
The analytics leverage conversation intelligence from enhanced JSON payloads:
```json
{
  "conversation": {
    "duration_seconds": 45,
    "speaker_turns": {"customer": 3, "store_owner": 4},
    "brands_discussed": 2,
    "suggestion_acceptance_rate": 0.75,
    "primary_intent": "brand_request",
    "conversation_flow": "greeting_browse_request_accept_purchase",
    "brands_mentioned": ["Marlboro", "Lucky Strike"],
    "products_mentioned": ["cigarettes", "lighter"],
    "purchase_completed": true,
    "substitution_occurred": false
  }
}
```

## Filipino Market Insights

### Pecha de Peligro Analysis
- **Days 23-30**: Salary period impact on purchasing behavior
- **Start of Month (1-7)**: Post-salary spending patterns
- **Mid Month**: Budget-conscious purchasing periods

### Cultural Patterns
- **Substitution Keywords**: "kulang" (lacking), "wala" (none), "palit" (substitute)
- **Voice Transcript Analysis**: Filipino/English code-switching patterns
- **Regional Variations**: NCR vs provincial purchasing differences

## Technical Notes

### Date Parameters
- **@date_from**: Start date for analysis (default: 2025-06-28)
- **@date_to**: End date for analysis (default: 2025-09-26)
- **Date Format**: YYYY-MM-DD (ISO 8601)

### Performance Optimization
- All queries use proper indexing on `transaction_date`
- JSON extraction cached for performance
- CROSS APPLY used for efficient JSON array processing
- Windowing functions optimized for large datasets

### Security
- No hardcoded credentials - uses secure credential management
- Read-only access pattern for analytics queries
- Environment variable injection for database connections

## Support

For questions about the analytics suite:
1. Check the summary report generated after each export
2. Validate data quality using the built-in validation queries
3. Review the generated CSV files for expected data patterns
4. Use `make analytics-comprehensive` for full automated export

Last updated: 2025-09-26