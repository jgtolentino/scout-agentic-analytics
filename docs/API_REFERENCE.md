# Market Intelligence API Reference

## Authentication

All endpoints require Supabase authentication:
```javascript
const { data } = await supabase.functions.invoke('brand-intelligence', {
  headers: { Authorization: `Bearer ${token}` }
})
```

## Brand Intelligence API

Base URL: `/functions/v1/brand-intelligence`

### Get Brand Profile

**GET** `/functions/v1/brand-intelligence?brand={brand_name}`

Retrieves comprehensive brand intelligence including market metrics, competitive positioning, and category context.

**Parameters**:
- `brand` (string, optional) - Brand name for analysis
- `category` (string, optional) - Filter by product category
- `include_competitors` (boolean, optional) - Include competitive analysis (default: false)

**Example Request**:
```bash
curl -X GET "https://your-project.supabase.co/functions/v1/brand-intelligence?brand=Safeguard&include_competitors=true" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Response Schema**:
```json
{
  "success": true,
  "data": {
    "brand_profile": {
      "brand_name": "Safeguard",
      "category": "bar_soap", 
      "market_share_percent": 15.2,
      "consumer_reach_points": 85.0,
      "brand_tier": "challenger",
      "growth_rate": 6.5,
      "penetration_percent": 75.0,
      "last_updated": "2025-01-15T10:00:00Z"
    },
    "category_context": {
      "category_name": "bar_soap",
      "market_size_php": 42400000000,
      "total_brands": 25,
      "market_concentration": "moderate",
      "growth_drivers": [
        "Health consciousness trends",
        "Premium product demand"
      ]
    },
    "competitive_analysis": [
      {
        "competitor": "Palmolive",
        "market_share": 18.5,
        "tier": "leader",
        "competitive_gap": 3.3
      }
    ]
  }
}
```

### Brand Search & Matching

**GET** `/functions/v1/brand-intelligence/search?q={query}&threshold={confidence}`

Market-weighted brand search with intelligent matching for audio transcription enhancement.

**Parameters**:
- `q` (string, required) - Search query or audio transcript
- `threshold` (float, optional) - Confidence threshold 0.0-1.0 (default: 0.5)
- `limit` (integer, optional) - Maximum results (default: 10)

**Example**:
```bash
curl -X GET "https://your-project.supabase.co/functions/v1/brand-intelligence/search?q=hansel%20hello%20snack&threshold=0.6" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Response**:
```json
{
  "success": true,
  "data": {
    "matches": [
      {
        "brand_name": "Hello",
        "confidence": 0.85,
        "match_type": "phonetic",
        "market_weight": 1.2,
        "category": "snacks_confectionery"
      },
      {
        "brand_name": "Hansel",
        "confidence": 0.78,
        "match_type": "exact",
        "market_weight": 1.1,
        "category": "snacks_confectionery"
      }
    ],
    "processing_time_ms": 45
  }
}
```

## Market Benchmarks API

Base URL: `/functions/v1/market-benchmarks`

### Category Analysis

**GET** `/functions/v1/market-benchmarks/category/{category}`

Comprehensive category landscape analysis with market dynamics, key players, and growth opportunities.

**Parameters**:
- `category` (string, required) - Product category
- `include_forecasts` (boolean, optional) - Include growth projections
- `benchmark_period` (string, optional) - "ytd" | "quarterly" | "annual"

**Example**:
```bash
curl -X GET "https://your-project.supabase.co/functions/v1/market-benchmarks/category/snacks_confectionery?include_forecasts=true" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Response**:
```json
{
  "success": true,
  "data": {
    "category_overview": {
      "name": "snacks_confectionery",
      "market_size_php": 137600000000,
      "cagr_percent": 8.0,
      "penetration_percent": 95.0,
      "hhi_index": 0.24,
      "market_maturity": "growing"
    },
    "market_leaders": [
      {
        "brand": "Jack n Jill",
        "market_share": 22.8,
        "tier": "leader",
        "crp": 92.5
      }
    ],
    "growth_drivers": [
      "Premium snacking trends",
      "Convenience consumption",
      "Health-conscious variants"
    ],
    "opportunities": [
      {
        "segment": "healthy_snacks",
        "potential_php": 15000000000,
        "growth_rate": 12.5
      }
    ]
  }
}
```

### Competitive Matrix

**POST** `/functions/v1/market-benchmarks/compare`

Head-to-head brand comparison with competitive positioning analysis.

**Request Body**:
```json
{
  "brands": ["Safeguard", "Palmolive", "Dove"],
  "metrics": ["market_share", "crp", "growth_rate"],
  "category": "bar_soap"
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "comparison_matrix": [
      {
        "brand": "Palmolive",
        "market_share": 18.5,
        "crp": 88.0,
        "growth_rate": 5.2,
        "competitive_position": "leader"
      },
      {
        "brand": "Safeguard", 
        "market_share": 15.2,
        "crp": 85.0,
        "growth_rate": 6.5,
        "competitive_position": "challenger"
      }
    ],
    "insights": [
      "Safeguard shows higher growth despite lower market share",
      "CRP gap indicates distribution opportunity"
    ]
  }
}
```

## Price Analytics API

Base URL: `/functions/v1/price-analytics`

### Product Pricing Analysis

**GET** `/functions/v1/price-analytics/product/{sku}`

Detailed pricing intelligence for specific products including channel analysis and optimization recommendations.

**Parameters**:
- `sku` (string, required) - Product SKU identifier
- `include_trends` (boolean, optional) - Include historical trends
- `channel` (string, optional) - "traditional_trade" | "modern_trade" | "all"

**Example**:
```bash
curl -X GET "https://your-project.supabase.co/functions/v1/price-analytics/product/safeguard_pure_white_55g?include_trends=true" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Response**:
```json
{
  "success": true,
  "data": {
    "product_info": {
      "sku": "safeguard_pure_white_55g",
      "brand_name": "Safeguard",
      "category": "bar_soap",
      "package_size": "55g"
    },
    "pricing_analysis": {
      "suggested_retail_price": 22.00,
      "channel_pricing": {
        "traditional_trade": {
          "average_price": 25.30,
          "markup_percent": 15.0
        },
        "modern_trade": {
          "average_price": 23.76,
          "markup_percent": 8.0
        }
      },
      "price_position": "competitive",
      "elasticity_index": 0.75
    },
    "optimization_recommendations": [
      {
        "channel": "traditional_trade",
        "recommendation": "Price premium opportunity",
        "potential_uplift": "8-12%"
      }
    ]
  }
}
```

### Price Alerts

**POST** `/functions/v1/price-analytics/alerts`

Configure price monitoring alerts for competitive intelligence.

**Request Body**:
```json
{
  "alert_type": "competitive_price_change",
  "sku": "safeguard_pure_white_55g",
  "threshold_percent": 5.0,
  "channels": ["modern_trade"],
  "notification_email": "analyst@company.com"
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "alert_id": "alert_12345",
    "status": "active",
    "next_check": "2025-01-16T10:00:00Z"
  }
}
```

### Brand Portfolio Pricing

**GET** `/functions/v1/price-analytics/brand/{brand_name}`

Portfolio pricing analysis across all brand SKUs.

**Parameters**:
- `brand_name` (string, required) - Brand identifier
- `optimization_focus` (string, optional) - "revenue" | "margin" | "volume"

**Response**:
```json
{
  "success": true,
  "data": {
    "brand_portfolio": [
      {
        "sku": "safeguard_pure_white_55g", 
        "srp": 22.00,
        "price_index": 1.0,
        "volume_share": 0.35
      }
    ],
    "portfolio_insights": {
      "average_price_premium": 5.2,
      "price_spread": "moderate",
      "optimization_opportunity": "₱2.4M annual"
    }
  }
}
```

## Error Handling

All endpoints return standardized error responses:

```json
{
  "success": false,
  "error": {
    "code": "BRAND_NOT_FOUND",
    "message": "Brand 'XYZ' not found in market intelligence database",
    "details": {
      "available_brands": ["Safeguard", "Palmolive", ...]
    }
  }
}
```

**Common Error Codes**:
- `BRAND_NOT_FOUND` - Specified brand not in database
- `CATEGORY_INVALID` - Invalid category parameter
- `INSUFFICIENT_DATA` - Not enough data for analysis
- `RATE_LIMIT_EXCEEDED` - Too many requests
- `INVALID_PARAMETERS` - Request parameter validation failed

## Rate Limiting

- 100 requests per minute per authenticated user
- 1000 requests per hour per project
- Burst allowance: 20 requests per 10 seconds

## SDKs & Examples

### JavaScript/TypeScript
```javascript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(url, key)

// Get brand intelligence
const { data } = await supabase.functions.invoke('brand-intelligence', {
  body: { brand: 'Safeguard', include_competitors: true }
})
```

### Python
```python
from supabase import create_client

supabase = create_client(url, key)

# Price analytics
response = supabase.functions.invoke(
    'price-analytics',
    {'sku': 'safeguard_pure_white_55g'}
)
```

### cURL Examples
Complete cURL examples for all endpoints are provided in each endpoint section above.