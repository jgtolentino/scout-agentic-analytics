# Scout Analytics Platform - Complete API Documentation

**Version**: 3.0
**Database**: SQL-TBWA-ProjectScout-Reporting-Prod
**Base URL**: `https://suqi-public.vercel.app/api`
**Updated**: September 2025

## Table of Contents

1. [API Overview](#api-overview)
2. [Authentication & Security](#authentication--security)
3. [Analytics Endpoints](#analytics-endpoints)
4. [Data Quality Endpoints](#data-quality-endpoints)
5. [Export Endpoints](#export-endpoints)
6. [Monitoring Endpoints](#monitoring-endpoints)
7. [Error Handling](#error-handling)
8. [Rate Limiting](#rate-limiting)
9. [SDK Examples](#sdk-examples)

## API Overview

### Base Information

**Environment**: Production
**Protocol**: HTTPS only
**Format**: JSON
**Encoding**: UTF-8
**Timezone**: Asia/Manila (GMT+8)

### API Versioning

All API endpoints include version information in the URL path:
- **Current Version**: `v1` (default if not specified)
- **Legacy Support**: `v0` (deprecated, will be removed in Q4 2025)

### Request/Response Format

**Standard Request Headers:**
```http
Content-Type: application/json
Accept: application/json
User-Agent: Scout-Analytics-Client/1.0
```

**Standard Response Format:**
```json
{
  "success": true,
  "data": {
    // Response data here
  },
  "metadata": {
    "timestamp": "2025-09-25T10:30:00+08:00",
    "request_id": "req_abc123def456",
    "api_version": "v1",
    "execution_time_ms": 245
  },
  "pagination": {
    "page": 1,
    "per_page": 100,
    "total_pages": 5,
    "total_items": 450
  }
}
```

**Error Response Format:**
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid date range provided",
    "details": {
      "field": "end_date",
      "expected": "ISO 8601 datetime string",
      "received": "invalid_date"
    }
  },
  "metadata": {
    "timestamp": "2025-09-25T10:30:00+08:00",
    "request_id": "req_abc123def456",
    "api_version": "v1"
  }
}
```

## Authentication & Security

### Authentication Methods

**API Key Authentication** (Recommended for server-to-server)
```http
GET /api/v1/analytics/transactions
Authorization: Bearer sk_live_abc123def456...
```

**Session-based Authentication** (Web applications)
```http
GET /api/v1/analytics/transactions
Cookie: session_id=sess_xyz789abc123...
```

### Security Features

- **HTTPS Required**: All requests must use HTTPS
- **Rate Limiting**: 1000 requests per hour per API key
- **Request Signing**: Optional HMAC-SHA256 request signing
- **IP Allowlisting**: Configure allowed IP addresses per API key
- **CORS Protection**: Configured for allowed origins only

### API Key Management

**Generate API Key:**
```bash
curl -X POST https://suqi-public.vercel.app/api/v1/auth/keys \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Production Analytics",
    "permissions": ["analytics:read", "export:read"],
    "expires_at": "2026-12-31T23:59:59+08:00"
  }'
```

**Response:**
```json
{
  "success": true,
  "data": {
    "key_id": "key_abc123",
    "key": "sk_live_abc123def456...",
    "name": "Production Analytics",
    "permissions": ["analytics:read", "export:read"],
    "created_at": "2025-09-25T10:30:00+08:00",
    "expires_at": "2026-12-31T23:59:59+08:00"
  }
}
```

## Analytics Endpoints

### Transaction Analytics

**GET** `/api/v1/analytics/transactions`

Retrieve comprehensive transaction analytics with filtering and aggregation.

**Parameters:**
| Parameter | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `start_date` | string (ISO 8601) | ✅ | Start date for analytics period | `2025-09-01T00:00:00+08:00` |
| `end_date` | string (ISO 8601) | ✅ | End date for analytics period | `2025-09-25T23:59:59+08:00` |
| `store_id` | string | ❌ | Filter by specific store | `STORE001` |
| `category` | string | ❌ | Filter by Nielsen category | `Soft Drinks` |
| `brand` | string | ❌ | Filter by brand name | `Coca Cola` |
| `aggregation` | string | ❌ | Aggregation level: `day`, `week`, `month` | `day` |
| `include_breakdown` | boolean | ❌ | Include category/store breakdowns | `true` |
| `limit` | integer | ❌ | Maximum records to return (1-1000) | `100` |
| `offset` | integer | ❌ | Number of records to skip | `0` |

**Example Request:**
```bash
curl -G "https://suqi-public.vercel.app/api/v1/analytics/transactions" \
  -H "Authorization: Bearer sk_live_abc123..." \
  -d start_date="2025-09-01T00:00:00+08:00" \
  -d end_date="2025-09-25T23:59:59+08:00" \
  -d aggregation="day" \
  -d include_breakdown="true"
```

**Response:**
```json
{
  "success": true,
  "data": {
    "summary": {
      "total_transactions": 12450,
      "total_revenue": 2845670.50,
      "average_transaction_value": 228.65,
      "total_items": 38920,
      "average_basket_size": 3.13,
      "unique_stores": 45,
      "unique_brands": 156,
      "period_days": 25
    },
    "time_series": [
      {
        "date": "2025-09-01",
        "transactions": 495,
        "revenue": 112340.25,
        "avg_value": 227.05,
        "items": 1547
      },
      {
        "date": "2025-09-02",
        "transactions": 523,
        "revenue": 118750.80,
        "avg_value": 227.11,
        "items": 1638
      }
    ],
    "category_breakdown": [
      {
        "category": "Soft Drinks",
        "transactions": 4250,
        "revenue": 967840.75,
        "percentage": 34.02,
        "avg_value": 227.73
      },
      {
        "category": "Cigarettes",
        "transactions": 2890,
        "revenue": 745620.30,
        "percentage": 26.21,
        "avg_value": 258.02
      }
    ],
    "store_breakdown": [
      {
        "store_id": "STORE001",
        "store_name": "SuperMart Manila",
        "transactions": 847,
        "revenue": 195430.25,
        "percentage": 6.87,
        "avg_value": 230.75
      }
    ]
  },
  "metadata": {
    "timestamp": "2025-09-25T10:30:00+08:00",
    "request_id": "req_trans_abc123",
    "api_version": "v1",
    "execution_time_ms": 245,
    "cache_hit": false,
    "data_freshness": "2025-09-25T10:15:00+08:00"
  }
}
```

### Brand Analytics

**GET** `/api/v1/analytics/brands`

Analyze brand performance, market share, and competitive positioning.

**Parameters:**
| Parameter | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `start_date` | string | ✅ | Start date | `2025-09-01T00:00:00+08:00` |
| `end_date` | string | ✅ | End date | `2025-09-25T23:59:59+08:00` |
| `category` | string | ❌ | Nielsen category filter | `Soft Drinks` |
| `top_n` | integer | ❌ | Number of top brands (1-50) | `10` |
| `metrics` | string | ❌ | Comma-separated metrics | `revenue,transactions,market_share` |
| `include_trends` | boolean | ❌ | Include trend analysis | `true` |

**Example Request:**
```bash
curl -G "https://suqi-public.vercel.app/api/v1/analytics/brands" \
  -H "Authorization: Bearer sk_live_abc123..." \
  -d start_date="2025-09-01T00:00:00+08:00" \
  -d end_date="2025-09-25T23:59:59+08:00" \
  -d category="Soft Drinks" \
  -d top_n="10" \
  -d include_trends="true"
```

**Response:**
```json
{
  "success": true,
  "data": {
    "category_summary": {
      "category": "Soft Drinks",
      "total_brands": 23,
      "total_transactions": 4250,
      "total_revenue": 967840.75,
      "market_concentration": {
        "top_3_share": 67.5,
        "top_5_share": 82.3,
        "hhi_index": 0.245
      }
    },
    "brand_rankings": [
      {
        "rank": 1,
        "brand": "Coca Cola",
        "transactions": 1456,
        "revenue": 345620.50,
        "market_share_percentage": 35.71,
        "avg_transaction_value": 237.36,
        "growth_percentage": 12.5,
        "trend": "increasing"
      },
      {
        "rank": 2,
        "brand": "Pepsi",
        "transactions": 987,
        "revenue": 231450.25,
        "market_share_percentage": 23.91,
        "avg_transaction_value": 234.43,
        "growth_percentage": -2.1,
        "trend": "decreasing"
      }
    ],
    "trend_analysis": {
      "fastest_growing": {
        "brand": "Royal True Orange",
        "growth_percentage": 45.8,
        "base_revenue": 12350.00,
        "current_revenue": 18005.30
      },
      "fastest_declining": {
        "brand": "Sprite",
        "growth_percentage": -15.2,
        "base_revenue": 89430.50,
        "current_revenue": 75840.75
      }
    }
  }
}
```

### Category Analytics

**GET** `/api/v1/analytics/categories`

Analyze Nielsen category performance and cross-category relationships.

**Response includes:**
- Category performance rankings
- Cross-category purchase patterns
- Seasonal trends
- Geographic distribution

### Customer Analytics

**GET** `/api/v1/analytics/customers`

Analyze customer demographics, behavior patterns, and segmentation.

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `demographic_breakdown` | boolean | ❌ | Include age/gender analysis |
| `behavior_patterns` | boolean | ❌ | Include purchase behavior analysis |
| `segmentation` | string | ❌ | Segmentation type: `rfm`, `demographic`, `behavioral` |

**Response includes:**
- Demographic distribution
- Purchase frequency analysis
- Customer lifetime value
- Segment profiles

### Geographic Analytics

**GET** `/api/v1/analytics/geographic`

Analyze performance by geographic regions and store locations.

**Response includes:**
- Regional performance metrics
- Store-level analytics
- Geographic heat map data
- Location-based trends

## Data Quality Endpoints

### Data Quality Dashboard

**GET** `/api/v1/quality/dashboard`

Comprehensive data quality metrics and health indicators.

**Response:**
```json
{
  "success": true,
  "data": {
    "overall_score": 94.5,
    "status": "Excellent",
    "last_updated": "2025-09-25T10:15:00+08:00",
    "metrics": {
      "completeness": {
        "score": 96.2,
        "details": {
          "required_fields": 98.5,
          "brand_detection": 94.8,
          "category_classification": 95.1
        }
      },
      "accuracy": {
        "score": 92.8,
        "details": {
          "brand_accuracy": 94.2,
          "category_accuracy": 91.5,
          "price_validation": 92.7
        }
      },
      "freshness": {
        "score": 95.0,
        "last_ingestion": "2025-09-25T09:45:00+08:00",
        "processing_lag_minutes": 12
      },
      "consistency": {
        "score": 94.1,
        "duplicate_rate": 0.3,
        "validation_pass_rate": 97.8
      }
    },
    "quality_issues": [
      {
        "severity": "medium",
        "category": "brand_detection",
        "message": "Brand detection confidence below threshold for 5.2% of records",
        "affected_records": 648,
        "recommendation": "Review ML model training data"
      }
    ]
  }
}
```

### Validation Rules

**GET** `/api/v1/quality/validation-rules`

Retrieve current data validation rules and thresholds.

**POST** `/api/v1/quality/validation-rules`

Update validation rules (admin access required).

### Quality Reports

**GET** `/api/v1/quality/reports/{report_type}`

Generate detailed quality reports.

**Report Types:**
- `completeness`: Data completeness analysis
- `accuracy`: Data accuracy validation
- `consistency`: Cross-table consistency checks
- `anomalies`: Statistical anomaly detection

## Export Endpoints

### CSV Export

**GET** `/api/v1/export/transactions/csv`

Export transaction data in CSV format for external analytics tools.

**Parameters:**
| Parameter | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `format` | string | ❌ | Export format: `flat`, `normalized` | `flat` |
| `columns` | string | ❌ | Comma-separated column list | `id,date,amount,brand` |
| `compression` | string | ❌ | Compression: `none`, `gzip`, `zip` | `gzip` |

**Example Request:**
```bash
curl -G "https://suqi-public.vercel.app/api/v1/export/transactions/csv" \
  -H "Authorization: Bearer sk_live_abc123..." \
  -d start_date="2025-09-01T00:00:00+08:00" \
  -d end_date="2025-09-25T23:59:59+08:00" \
  -d format="flat" \
  -d compression="gzip" \
  -o transactions_export.csv.gz
```

**Response Headers:**
```http
Content-Type: text/csv
Content-Encoding: gzip
Content-Disposition: attachment; filename="transactions_2025-09-01_2025-09-25.csv.gz"
X-Record-Count: 12450
X-Export-Time: 2025-09-25T10:30:00+08:00
```

### Excel Export

**GET** `/api/v1/export/transactions/excel`

Export transaction data in Excel format with multiple worksheets.

**Response includes:**
- **Summary**: Key metrics and totals
- **Transactions**: Detailed transaction data
- **Categories**: Category breakdown
- **Brands**: Brand performance
- **Stores**: Store-level analytics

### JSON Export

**GET** `/api/v1/export/transactions/json`

Export transaction data in structured JSON format.

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `structure` | string | JSON structure: `flat`, `nested`, `hierarchical` |
| `pretty` | boolean | Pretty-print JSON output |

### Real-time Stream

**GET** `/api/v1/export/transactions/stream` (Server-Sent Events)

Real-time transaction data stream for live dashboards.

**Example Usage:**
```javascript
const eventSource = new EventSource('/api/v1/export/transactions/stream');

eventSource.onmessage = function(event) {
  const transaction = JSON.parse(event.data);
  console.log('New transaction:', transaction);
};
```

## Monitoring Endpoints

### System Health

**GET** `/api/v1/monitoring/health`

System health check with detailed component status.

**Response:**
```json
{
  "success": true,
  "data": {
    "status": "healthy",
    "timestamp": "2025-09-25T10:30:00+08:00",
    "uptime_seconds": 2847360,
    "components": {
      "database": {
        "status": "healthy",
        "response_time_ms": 45,
        "connection_pool": {
          "active": 12,
          "idle": 8,
          "total": 20
        }
      },
      "cache": {
        "status": "healthy",
        "response_time_ms": 2,
        "hit_rate_percentage": 87.5
      },
      "etl_pipeline": {
        "status": "healthy",
        "last_run": "2025-09-25T10:15:00+08:00",
        "success_rate_percentage": 99.2
      }
    },
    "metrics": {
      "requests_per_minute": 245,
      "average_response_time_ms": 125,
      "error_rate_percentage": 0.8
    }
  }
}
```

### Performance Metrics

**GET** `/api/v1/monitoring/metrics`

Detailed performance and usage metrics.

**Response includes:**
- Request volume and patterns
- Response time percentiles
- Error rates and types
- Resource utilization
- Cache performance

### ETL Pipeline Status

**GET** `/api/v1/monitoring/etl`

Current ETL pipeline status and processing metrics.

**Response:**
```json
{
  "success": true,
  "data": {
    "pipeline_status": "running",
    "current_batch": "BATCH_20250925_1030",
    "progress_percentage": 75.5,
    "estimated_completion": "2025-09-25T10:45:00+08:00",
    "processing_stats": {
      "records_processed": 9456,
      "records_successful": 9398,
      "records_failed": 58,
      "processing_rate_per_second": 125
    },
    "recent_batches": [
      {
        "batch_id": "BATCH_20250925_1000",
        "status": "completed",
        "start_time": "2025-09-25T10:00:00+08:00",
        "end_time": "2025-09-25T10:28:00+08:00",
        "records_processed": 12450,
        "success_rate": 99.1
      }
    ],
    "quality_metrics": {
      "overall_quality_score": 94.5,
      "brand_detection_rate": 94.8,
      "category_classification_rate": 95.1
    }
  }
}
```

## Error Handling

### Error Codes

| Code | HTTP Status | Description | Retryable |
|------|-------------|-------------|-----------|
| `VALIDATION_ERROR` | 400 | Invalid request parameters | ❌ |
| `AUTHENTICATION_ERROR` | 401 | Invalid or missing authentication | ❌ |
| `AUTHORIZATION_ERROR` | 403 | Insufficient permissions | ❌ |
| `NOT_FOUND` | 404 | Resource not found | ❌ |
| `RATE_LIMIT_EXCEEDED` | 429 | Rate limit exceeded | ✅ |
| `DATABASE_ERROR` | 500 | Database connection or query error | ✅ |
| `PROCESSING_ERROR` | 500 | Data processing error | ✅ |
| `TIMEOUT_ERROR` | 504 | Request timeout | ✅ |

### Error Response Format

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid date range: end_date must be after start_date",
    "details": {
      "field": "end_date",
      "constraint": "must_be_after_start_date",
      "provided_value": "2025-08-01T00:00:00+08:00",
      "start_date": "2025-09-01T00:00:00+08:00"
    },
    "documentation_url": "https://docs.scout-analytics.com/api/errors#validation_error",
    "support_contact": "api-support@tbwa.com"
  },
  "metadata": {
    "timestamp": "2025-09-25T10:30:00+08:00",
    "request_id": "req_abc123def456",
    "api_version": "v1"
  }
}
```

### Retry Strategy

**Exponential Backoff:**
```
Attempt 1: Immediate
Attempt 2: 1 second delay
Attempt 3: 2 second delay
Attempt 4: 4 second delay
Attempt 5: 8 second delay
Maximum: 5 attempts
```

**Retry-able Errors:**
- Rate limit exceeded (429)
- Server errors (5xx)
- Network timeouts
- Database connection errors

## Rate Limiting

### Rate Limits

| Endpoint Category | Rate Limit | Window |
|------------------|------------|--------|
| Analytics | 1,000 requests | 1 hour |
| Export | 100 requests | 1 hour |
| Monitoring | 10,000 requests | 1 hour |
| Authentication | 100 requests | 15 minutes |

### Rate Limit Headers

```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 847
X-RateLimit-Reset: 1695641400
X-RateLimit-Reset-After: 2847
Retry-After: 2847
```

### Rate Limit Response

```json
{
  "success": false,
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit exceeded: 1000 requests per hour",
    "details": {
      "limit": 1000,
      "window_hours": 1,
      "reset_time": "2025-09-25T11:30:00+08:00",
      "retry_after_seconds": 2847
    }
  }
}
```

## SDK Examples

### JavaScript/TypeScript SDK

```typescript
// scout-analytics-sdk.ts
import axios, { AxiosInstance, AxiosRequestConfig } from 'axios';

interface ScoutConfig {
  apiKey: string;
  baseUrl?: string;
  timeout?: number;
}

interface TransactionAnalyticsParams {
  startDate: string;
  endDate: string;
  storeId?: string;
  category?: string;
  brand?: string;
  aggregation?: 'day' | 'week' | 'month';
  includeBreakdown?: boolean;
  limit?: number;
  offset?: number;
}

export class ScoutAnalyticsSDK {
  private client: AxiosInstance;

  constructor(config: ScoutConfig) {
    this.client = axios.create({
      baseURL: config.baseUrl || 'https://suqi-public.vercel.app/api/v1',
      timeout: config.timeout || 30000,
      headers: {
        'Authorization': `Bearer ${config.apiKey}`,
        'Content-Type': 'application/json',
        'User-Agent': 'Scout-Analytics-SDK/1.0'
      }
    });

    // Add response interceptor for error handling
    this.client.interceptors.response.use(
      (response) => response,
      (error) => {
        if (error.response?.status === 429) {
          const retryAfter = error.response.headers['retry-after'];
          throw new ScoutRateLimitError(
            `Rate limit exceeded. Retry after ${retryAfter} seconds.`,
            parseInt(retryAfter)
          );
        }
        throw new ScoutAPIError(
          error.response?.data?.error?.message || error.message,
          error.response?.status,
          error.response?.data?.error?.code
        );
      }
    );
  }

  /**
   * Get transaction analytics
   */
  async getTransactionAnalytics(
    params: TransactionAnalyticsParams
  ): Promise<TransactionAnalyticsResponse> {
    const response = await this.client.get('/analytics/transactions', {
      params: {
        start_date: params.startDate,
        end_date: params.endDate,
        store_id: params.storeId,
        category: params.category,
        brand: params.brand,
        aggregation: params.aggregation,
        include_breakdown: params.includeBreakdown,
        limit: params.limit,
        offset: params.offset
      }
    });

    return response.data;
  }

  /**
   * Get brand analytics
   */
  async getBrandAnalytics(params: {
    startDate: string;
    endDate: string;
    category?: string;
    topN?: number;
    includeTrends?: boolean;
  }) {
    const response = await this.client.get('/analytics/brands', {
      params: {
        start_date: params.startDate,
        end_date: params.endDate,
        category: params.category,
        top_n: params.topN,
        include_trends: params.includeTrends
      }
    });

    return response.data;
  }

  /**
   * Export transactions to CSV
   */
  async exportTransactions(params: {
    startDate: string;
    endDate: string;
    format?: 'csv' | 'excel' | 'json';
    compression?: 'none' | 'gzip' | 'zip';
  }): Promise<Blob> {
    const response = await this.client.get(`/export/transactions/${params.format || 'csv'}`, {
      params: {
        start_date: params.startDate,
        end_date: params.endDate,
        compression: params.compression
      },
      responseType: 'blob'
    });

    return response.data;
  }

  /**
   * Get system health
   */
  async getSystemHealth() {
    const response = await this.client.get('/monitoring/health');
    return response.data;
  }

  /**
   * Get data quality metrics
   */
  async getDataQuality() {
    const response = await this.client.get('/quality/dashboard');
    return response.data;
  }
}

// Custom error classes
export class ScoutAPIError extends Error {
  constructor(
    message: string,
    public statusCode?: number,
    public errorCode?: string
  ) {
    super(message);
    this.name = 'ScoutAPIError';
  }
}

export class ScoutRateLimitError extends ScoutAPIError {
  constructor(message: string, public retryAfter: number) {
    super(message, 429, 'RATE_LIMIT_EXCEEDED');
    this.name = 'ScoutRateLimitError';
  }
}

// Usage example
const scout = new ScoutAnalyticsSDK({
  apiKey: 'sk_live_abc123def456...',
  baseUrl: 'https://suqi-public.vercel.app/api/v1'
});

// Get transaction analytics
const analytics = await scout.getTransactionAnalytics({
  startDate: '2025-09-01T00:00:00+08:00',
  endDate: '2025-09-25T23:59:59+08:00',
  aggregation: 'day',
  includeBreakdown: true
});

console.log('Total Revenue:', analytics.data.summary.total_revenue);
```

### Python SDK

```python
# scout_analytics_sdk.py
import requests
import json
from typing import Optional, Dict, Any, List
from datetime import datetime, timezone
import time

class ScoutAnalyticsSDK:
    """
    Scout Analytics Platform Python SDK

    Provides easy access to Scout Analytics API with automatic retries,
    rate limit handling, and comprehensive error management.
    """

    def __init__(
        self,
        api_key: str,
        base_url: str = "https://suqi-public.vercel.app/api/v1",
        timeout: int = 30
    ):
        self.api_key = api_key
        self.base_url = base_url
        self.timeout = timeout

        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json',
            'User-Agent': 'Scout-Analytics-Python-SDK/1.0'
        })

    def _make_request(
        self,
        method: str,
        endpoint: str,
        params: Optional[Dict] = None,
        data: Optional[Dict] = None,
        max_retries: int = 3
    ) -> Dict[str, Any]:
        """Make HTTP request with retry logic and error handling"""

        url = f"{self.base_url}/{endpoint.lstrip('/')}"

        for attempt in range(max_retries + 1):
            try:
                response = self.session.request(
                    method=method,
                    url=url,
                    params=params,
                    json=data,
                    timeout=self.timeout
                )

                # Handle rate limiting
                if response.status_code == 429:
                    retry_after = int(response.headers.get('Retry-After', 60))
                    if attempt < max_retries:
                        print(f"Rate limited. Waiting {retry_after} seconds...")
                        time.sleep(retry_after)
                        continue
                    else:
                        raise ScoutRateLimitError(
                            f"Rate limit exceeded after {max_retries} attempts",
                            retry_after
                        )

                response.raise_for_status()
                return response.json()

            except requests.exceptions.RequestException as e:
                if attempt < max_retries and response.status_code >= 500:
                    # Exponential backoff for server errors
                    wait_time = 2 ** attempt
                    print(f"Request failed (attempt {attempt + 1}). Retrying in {wait_time}s...")
                    time.sleep(wait_time)
                    continue

                # Parse error response if available
                try:
                    error_data = response.json()
                    raise ScoutAPIError(
                        error_data.get('error', {}).get('message', str(e)),
                        response.status_code,
                        error_data.get('error', {}).get('code')
                    )
                except (ValueError, AttributeError):
                    raise ScoutAPIError(str(e), getattr(response, 'status_code', None))

    def get_transaction_analytics(
        self,
        start_date: str,
        end_date: str,
        store_id: Optional[str] = None,
        category: Optional[str] = None,
        brand: Optional[str] = None,
        aggregation: Optional[str] = None,
        include_breakdown: bool = True,
        limit: int = 100,
        offset: int = 0
    ) -> Dict[str, Any]:
        """
        Get transaction analytics

        Args:
            start_date: Start date in ISO 8601 format
            end_date: End date in ISO 8601 format
            store_id: Optional store ID filter
            category: Optional category filter
            brand: Optional brand filter
            aggregation: Aggregation level ('day', 'week', 'month')
            include_breakdown: Include category/store breakdowns
            limit: Maximum records to return
            offset: Number of records to skip

        Returns:
            Transaction analytics data
        """
        params = {
            'start_date': start_date,
            'end_date': end_date,
            'include_breakdown': str(include_breakdown).lower(),
            'limit': limit,
            'offset': offset
        }

        # Add optional parameters
        if store_id:
            params['store_id'] = store_id
        if category:
            params['category'] = category
        if brand:
            params['brand'] = brand
        if aggregation:
            params['aggregation'] = aggregation

        return self._make_request('GET', '/analytics/transactions', params=params)

    def get_brand_analytics(
        self,
        start_date: str,
        end_date: str,
        category: Optional[str] = None,
        top_n: int = 10,
        include_trends: bool = True
    ) -> Dict[str, Any]:
        """Get brand analytics and rankings"""
        params = {
            'start_date': start_date,
            'end_date': end_date,
            'top_n': top_n,
            'include_trends': str(include_trends).lower()
        }

        if category:
            params['category'] = category

        return self._make_request('GET', '/analytics/brands', params=params)

    def export_transactions(
        self,
        start_date: str,
        end_date: str,
        format: str = 'csv',
        compression: Optional[str] = None
    ) -> bytes:
        """
        Export transactions data

        Returns:
            Binary data of the exported file
        """
        params = {
            'start_date': start_date,
            'end_date': end_date
        }

        if compression:
            params['compression'] = compression

        url = f"{self.base_url}/export/transactions/{format}"

        response = self.session.get(url, params=params, stream=True)
        response.raise_for_status()

        return response.content

    def get_system_health(self) -> Dict[str, Any]:
        """Get system health status"""
        return self._make_request('GET', '/monitoring/health')

    def get_data_quality(self) -> Dict[str, Any]:
        """Get data quality metrics"""
        return self._make_request('GET', '/quality/dashboard')

# Custom exceptions
class ScoutAPIError(Exception):
    """Base exception for Scout API errors"""
    def __init__(self, message: str, status_code: Optional[int] = None, error_code: Optional[str] = None):
        super().__init__(message)
        self.status_code = status_code
        self.error_code = error_code

class ScoutRateLimitError(ScoutAPIError):
    """Exception for rate limit errors"""
    def __init__(self, message: str, retry_after: int):
        super().__init__(message, 429, 'RATE_LIMIT_EXCEEDED')
        self.retry_after = retry_after

# Usage example
if __name__ == "__main__":
    # Initialize SDK
    scout = ScoutAnalyticsSDK(api_key="sk_live_abc123def456...")

    try:
        # Get transaction analytics
        analytics = scout.get_transaction_analytics(
            start_date="2025-09-01T00:00:00+08:00",
            end_date="2025-09-25T23:59:59+08:00",
            aggregation="day",
            include_breakdown=True
        )

        print(f"Total Revenue: ₱{analytics['data']['summary']['total_revenue']:,.2f}")
        print(f"Total Transactions: {analytics['data']['summary']['total_transactions']:,}")

        # Get brand analytics
        brands = scout.get_brand_analytics(
            start_date="2025-09-01T00:00:00+08:00",
            end_date="2025-09-25T23:59:59+08:00",
            category="Soft Drinks",
            top_n=5
        )

        print("\nTop 5 Soft Drink Brands:")
        for brand in brands['data']['brand_rankings'][:5]:
            print(f"{brand['rank']}. {brand['brand']}: ₱{brand['revenue']:,.2f}")

    except ScoutRateLimitError as e:
        print(f"Rate limited. Retry after {e.retry_after} seconds.")
    except ScoutAPIError as e:
        print(f"API Error: {e} (Status: {e.status_code}, Code: {e.error_code})")
```

### cURL Examples

**Get Transaction Analytics:**
```bash
curl -G "https://suqi-public.vercel.app/api/v1/analytics/transactions" \
  -H "Authorization: Bearer sk_live_abc123..." \
  -H "Accept: application/json" \
  -d start_date="2025-09-01T00:00:00+08:00" \
  -d end_date="2025-09-25T23:59:59+08:00" \
  -d aggregation="day" \
  -d include_breakdown="true" \
  | jq '.data.summary'
```

**Export to CSV:**
```bash
curl -G "https://suqi-public.vercel.app/api/v1/export/transactions/csv" \
  -H "Authorization: Bearer sk_live_abc123..." \
  -d start_date="2025-09-01T00:00:00+08:00" \
  -d end_date="2025-09-25T23:59:59+08:00" \
  -d compression="gzip" \
  -o transactions_export.csv.gz
```

**System Health Check:**
```bash
curl "https://suqi-public.vercel.app/api/v1/monitoring/health" \
  -H "Authorization: Bearer sk_live_abc123..." \
  | jq '.data.status'
```

This comprehensive API documentation provides complete guidance for integrating with the Scout Analytics Platform, including authentication, endpoints, error handling, and SDK usage examples in multiple programming languages.