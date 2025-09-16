# Scout Edge Market Intelligence System

## Overview

Comprehensive market intelligence and brand enrichment system for Philippine FMCG analytics. Integrates market research data with retail pricing intelligence to enhance brand detection and provide competitive insights.

## System Architecture

### Database Schema (medallion architecture)

**Core Tables**:
- `metadata.market_intelligence` - Market sizing and category metrics
- `metadata.brand_metrics` - Brand-level KPIs and market positioning  
- `metadata.retail_pricing` - SRP tracking and pricing data
- `metadata.competitor_benchmarks` - Head-to-head competitive analysis
- `metadata.brand_detection_intelligence` - Enhanced brand matching weights

**Key Functions**:
- `get_brand_intelligence(brand_name)` - Complete brand profile
- `match_brands_with_intelligence(text, threshold)` - Market-weighted matching
- `get_category_intelligence(category)` - Category landscape analysis

### Analytics Views

**6 Business Intelligence Views**:
1. `analytics.brand_performance_dashboard` - Brand KPIs and tier classification
2. `analytics.category_deep_dive` - Category dynamics and growth drivers
3. `analytics.competitive_landscape_matrix` - Market positioning analysis
4. `analytics.market_opportunity_analysis` - Growth opportunities and gaps
5. `analytics.price_intelligence_dashboard` - Pricing analytics and optimization
6. `analytics.brand_health_index` - Composite health scoring

### ETL Pipeline

**3 Python Scripts**:
- `etl/market_intelligence_loader.py` - Market research data processing
- `etl/price_tracker.py` - SRP data loading and channel analysis
- `etl/brand_enrichment.py` - Brand detection enhancement

### API Endpoints (Supabase Edge Functions)

**3 REST APIs**:
- `/functions/v1/brand-intelligence` - Brand metrics and analysis
- `/functions/v1/market-benchmarks` - Category and competitive analysis
- `/functions/v1/price-analytics` - Pricing intelligence and optimization

## Data Coverage

### Market Intelligence
- 6 major FMCG categories (₱137.6B+ market size)
- 152+ brand profiles with market metrics
- Consumer Reach Points (CRP) data
- CAGR growth rates and penetration metrics

### Pricing Intelligence
- 43+ product SKUs with SRP tracking
- Channel markup analysis (traditional trade 15%, modern trade 8%)
- Regional pricing variations
- Price elasticity and optimization insights

### Brand Enhancement
- Market share weighting for disambiguation
- Phonetic clustering for Filipino pronunciation
- Category-specific matching rules
- Confidence scoring with intelligence factors

## Implementation Guide

### 1. Database Setup
```sql
-- Apply migration
\i supabase/migrations/20250917_market_intelligence.sql
\i supabase/migrations/20250917_analytics_views.sql
```

### 2. ETL Data Loading
```bash
# Load market research data
python3 etl/market_intelligence_loader.py

# Load SRP pricing data
python3 etl/price_tracker.py

# Enhance brand detection
python3 etl/brand_enrichment.py
```

### 3. Edge Functions Deployment
```bash
# Deploy API endpoints
supabase functions deploy brand-intelligence
supabase functions deploy market-benchmarks
supabase functions deploy price-analytics
```

## API Documentation

### Brand Intelligence API

**GET** `/functions/v1/brand-intelligence`

**Parameters**:
- `brand` (optional) - Specific brand analysis
- `category` (optional) - Category filter
- `include_competitors` (boolean) - Include competitive analysis

**Response**:
```json
{
  "brand_name": "Safeguard",
  "market_share_percent": 15.2,
  "consumer_reach_points": 85.0,
  "tier": "challenger",
  "category_intelligence": {
    "market_size_php": 42400,
    "growth_rate": 6.5,
    "penetration": 88.0
  },
  "competitors": [...]
}
```

### Market Benchmarks API

**GET** `/functions/v1/market-benchmarks`

**Parameters**:
- `category` - Target category analysis
- `benchmark_type` - "category" | "competitive" | "opportunity"
- `brands` (array) - Brands for comparison

**Response**:
```json
{
  "category": "bar_soap",
  "market_dynamics": {
    "size_php": 42400,
    "leaders": ["Safeguard", "Palmolive"],
    "growth_drivers": [...]
  },
  "competitive_matrix": [...]
}
```

### Price Analytics API

**GET** `/functions/v1/price-analytics`

**Parameters**:
- `sku` (optional) - Specific product analysis
- `brand` (optional) - Brand portfolio pricing
- `channel` (optional) - Channel-specific analysis
- `alert_type` (optional) - Price alert configuration

**Response**:
```json
{
  "sku": "safeguard_pure_white_55g",
  "current_srp": 22.00,
  "channel_analysis": {
    "traditional_trade": 25.30,
    "modern_trade": 23.76
  },
  "price_trends": [...],
  "optimization_recommendations": [...]
}
```

## Usage Examples

### Enhanced Brand Detection
```python
# Market-weighted brand matching
result = cursor.execute("""
  SELECT * FROM match_brands_with_intelligence(
    'Hansel nga hello meron dalawang snack',
    0.5
  ) ORDER BY confidence DESC;
""")
```

### Category Analysis
```python
# Complete category intelligence
result = cursor.execute("""
  SELECT * FROM analytics.category_deep_dive 
  WHERE category = 'snacks_confectionery';
""")
```

### Pricing Intelligence
```python
# Price optimization analysis
result = cursor.execute("""
  SELECT * FROM analytics.price_intelligence_dashboard
  WHERE brand_name = 'Safeguard'
  AND channel = 'modern_trade';
""")
```

## Integration Points

### Scout Edge Frontend
- Brand intelligence widgets in analytics dashboard
- Competitive landscape visualizations
- Pricing optimization recommendations
- Market opportunity identification

### Audio Transcription Enhancement
- Market-weighted brand disambiguation
- Category-specific vocabulary expansion
- Phonetic matching for Filipino pronunciations
- Confidence scoring with market intelligence

### Business Intelligence
- Executive dashboards with market metrics
- Category performance tracking
- Competitive monitoring alerts
- Price optimization workflows

## Performance Considerations

### Query Optimization
- Indexed brand_name and category columns
- Materialized view refresh schedules
- Connection pooling for ETL scripts
- Cached API responses for frequent queries

### Data Freshness
- Market intelligence: Monthly updates
- Pricing data: Weekly SRP monitoring
- Brand metrics: Quarterly market share updates
- Competitive analysis: Event-driven updates

### Scaling Strategy
- Read replicas for analytics queries
- Background job processing for ETL
- API rate limiting and caching
- Incremental data loading patterns

## Monitoring & Maintenance

### Key Metrics
- Data freshness timestamps
- API response times and error rates
- ETL job success/failure tracking
- Brand detection accuracy improvements

### Maintenance Tasks
- Regular data validation checks
- Market research data updates
- SRP monitoring and alerts
- Competitive intelligence refresh

### Troubleshooting
- ETL job failure recovery procedures
- Data quality validation rules
- API endpoint health checks
- Database performance monitoring