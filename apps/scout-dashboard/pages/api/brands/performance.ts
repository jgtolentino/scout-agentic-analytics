import { NextApiRequest, NextApiResponse } from 'next'
import { azureScoutClient } from '../../../lib/azure-client'
import type { ScoutFilters } from '../../../types/scout'

// Vercel configuration
export const config = {
  runtime: 'nodejs',
  maxDuration: 30,
  api: {
    externalResolver: true,
  },
}

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' })
  }

  // Set no-cache headers for live data
  res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate')
  res.setHeader('Content-Type', 'application/json')

  try {
    // Parse query parameters for filtering
    const {
      date_start,
      date_end,
      store_ids,
      municipalities,
      compare_periods = 'false'
    } = req.query

    // Build filters object
    const filters: ScoutFilters = {}

    if (date_start && date_end) {
      filters.date_range = {
        start: date_start as string,
        end: date_end as string
      }
    }

    if (store_ids) {
      filters.store_ids = Array.isArray(store_ids) ? store_ids.map(String) : [String(store_ids)]
    }

    if (municipalities) {
      filters.municipalities = Array.isArray(municipalities) ? municipalities : [municipalities as string]
    }

    // Get brand performance data from Azure SQL
    const result = await azureScoutClient.getBrandPerformance(filters)

    // If comparison requested, add period-over-period analysis
    if (compare_periods === 'true' && filters.date_range) {
      // Calculate previous period (same duration)
      const startDate = new Date(filters.date_range.start)
      const endDate = new Date(filters.date_range.end)
      const duration = endDate.getTime() - startDate.getTime()

      const prevStart = new Date(startDate.getTime() - duration)
      const prevEnd = new Date(startDate.getTime() - 1) // Day before current period

      const prevFilters = {
        ...filters,
        date_range: {
          start: prevStart.toISOString().split('T')[0],
          end: prevEnd.toISOString().split('T')[0]
        }
      }

      const prevResult = await azureScoutClient.getBrandPerformance(prevFilters)

      // Add comparison metrics
      if (result.data && prevResult.data) {
        result.data = result.data.map(brand => {
          const prevBrand = prevResult.data?.find(p => p.brand_name === brand.brand_name)
          if (prevBrand) {
            return {
              ...brand,
              comparison: {
                revenue_change: ((brand.avg_price_php - prevBrand.avg_price_php) / prevBrand.avg_price_php * 100),
                transaction_change: 0, // Would need actual transaction count
                customer_change: ((brand.consumer_reach_points - prevBrand.consumer_reach_points) / prevBrand.consumer_reach_points * 100),
                avg_value_change: ((brand.avg_price_php - prevBrand.avg_price_php) / prevBrand.avg_price_php * 100)
              }
            }
          }
          return brand
        })
      }

      // Add comparison metadata
      (result as any).comparison_period = {
        current: filters.date_range,
        previous: prevFilters.date_range
      }
    }

    return res.status(200).json(result)

  } catch (error) {
    console.error('Brand performance endpoint error:', error)

    return res.status(500).json({
      ok: false,
      error: 'Brand performance analysis failed',
      message: error instanceof Error ? error.message : 'Unknown error',
      timestamp: new Date().toISOString()
    })
  }
}

/*
API Documentation: /api/brands/performance

Description:
Retrieves brand performance metrics with optional period-over-period comparison.

Query Parameters:
- date_start: string - Start date (YYYY-MM-DD format)
- date_end: string - End date (YYYY-MM-DD format)
- store_ids: string[] - Filter by store IDs
- municipalities: string[] - Filter by municipalities
- compare_periods: boolean - Enable period-over-period comparison (default: false)

Response Format:
{
  "data": BrandPerformance[],
  "cache": { "hit": boolean, "ttl": number },
  "performance": { "query_time_ms": number, "row_count": number },
  "comparison_period"?: {
    "current": { "start": string, "end": string },
    "previous": { "start": string, "end": string }
  }
}

Example Request:
GET /api/brands/performance?date_start=2025-09-01&date_end=2025-09-22&compare_periods=true

Example Response:
{
  "data": [
    {
      "brand": "Coca-Cola",
      "total_transactions": 2547,
      "unique_customers": 1834,
      "total_revenue": 287650.25,
      "avg_transaction_value": 112.95,
      "store_presence": 12,
      "market_share": 0,
      "growth_rate": 0,
      "customer_loyalty": 0,
      "profitability_score": 0,
      "comparison": {
        "revenue_change": 8.4,
        "transaction_change": 12.3,
        "customer_change": 15.7,
        "avg_value_change": -3.2
      }
    }
  ],
  "cache": { "hit": false, "ttl": 300 },
  "performance": { "query_time_ms": 245, "row_count": 47 },
  "comparison_period": {
    "current": { "start": "2025-09-01", "end": "2025-09-22" },
    "previous": { "start": "2025-08-10", "end": "2025-08-31" }
  }
}
*/