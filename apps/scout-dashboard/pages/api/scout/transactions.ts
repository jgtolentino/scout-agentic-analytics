import { NextApiRequest, NextApiResponse } from 'next'
import { azureScoutClient } from '../../../lib/azure-client'
import type { ScoutFilters, QueryOptions } from '../../../types/scout'

// Vercel runtime configuration
export const config = {
  runtime: 'nodejs',
  maxDuration: 30,
  api: {
    externalResolver: true,
  },
}

// API Route: /api/scout/transactions
// Get Scout v7 transaction data with filtering and pagination from Azure SQL
export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' })
  }

  try {
    // Parse query parameters
    const {
      store_ids,
      brands,
      categories,
      date_start,
      date_end,
      time_of_day,
      age_brackets,
      genders,
      municipalities,
      min_amount,
      max_amount,
      limit = '1000',
      offset = '0',
      sort_by = 'TransactionDate',
      sort_order = 'desc'
    } = req.query

    // Build filters object
    const filters: ScoutFilters = {}

    if (store_ids) {
      filters.store_ids = Array.isArray(store_ids) ? store_ids.map(String) : [String(store_ids)]
    }

    if (brands) {
      filters.brands = Array.isArray(brands) ? brands : [brands as string]
    }

    if (categories) {
      filters.categories = Array.isArray(categories) ? categories : [categories as string]
    }

    if (date_start && date_end) {
      filters.date_range = {
        start: date_start as string,
        end: date_end as string
      }
    }

    if (time_of_day) {
      filters.time_of_day = Array.isArray(time_of_day) ? time_of_day : [time_of_day as string]
    }

    if (age_brackets) {
      filters.age_brackets = Array.isArray(age_brackets) ? age_brackets : [age_brackets as string]
    }

    if (genders) {
      filters.genders = Array.isArray(genders) ? genders : [genders as string]
    }

    if (municipalities) {
      filters.municipalities = Array.isArray(municipalities) ? municipalities : [municipalities as string]
    }

    if (min_amount) {
      filters.min_amount = parseFloat(min_amount as string)
    }

    if (max_amount) {
      filters.max_amount = parseFloat(max_amount as string)
    }

    // Build options object
    const options: QueryOptions = {
      limit: Math.min(parseInt(limit as string), 10000), // Cap at 10k rows
      offset: parseInt(offset as string),
      sort_by: sort_by as string,
      sort_order: sort_order as 'asc' | 'desc'
    }

    // Fetch data from Azure SQL
    const result = await azureScoutClient.getTransactions(filters, options)

    // Set no-cache headers for live data
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate')
    res.setHeader('X-Query-Time', result.performance?.query_time_ms?.toString() || '0')
    res.setHeader('X-Row-Count', result.performance?.row_count?.toString() || '0')

    if (result.cache?.hit) {
      res.setHeader('X-Cache-Status', 'HIT')
    } else {
      res.setHeader('X-Cache-Status', 'MISS')
    }

    return res.status(200).json(result)

  } catch (error) {
    console.error('Error in /api/scout/transactions:', error)

    return res.status(500).json({
      error: 'Internal server error',
      message: error instanceof Error ? error.message : 'Unknown error',
      timestamp: new Date().toISOString()
    })
  }
}

// API Documentation

/*
API Documentation: /api/scout/transactions

Description:
Retrieves Scout v7 transaction data with comprehensive filtering, pagination, and caching.

Query Parameters:
- store_ids: string[] - Filter by store IDs (e.g., "102,103,104")
- brands: string[] - Filter by brand names
- categories: string[] - Filter by product categories
- date_start: string - Start date (YYYY-MM-DD format)
- date_end: string - End date (YYYY-MM-DD format)
- time_of_day: string[] - Filter by time segments ("Morning", "Afternoon", "Evening", "Night")
- age_brackets: string[] - Filter by age brackets
- genders: string[] - Filter by gender ("Male", "Female")
- municipalities: string[] - Filter by municipality names
- min_amount: number - Minimum transaction amount
- max_amount: number - Maximum transaction amount
- limit: number - Results per page (default: 1000, max: 10000)
- offset: number - Pagination offset (default: 0)
- sort_by: string - Sort field (default: "transactiondate")
- sort_order: "asc" | "desc" - Sort direction (default: "desc")
- cache_ttl: number - Cache TTL in seconds (default: 300)

Response Format:
{
  "data": ScoutTransaction[],
  "meta": {
    "total": number,
    "page": number,
    "limit": number,
    "has_more": boolean
  },
  "cache": {
    "hit": boolean,
    "ttl": number
  },
  "performance": {
    "query_time_ms": number,
    "row_count": number
  }
}

Example Request:
GET /api/scout/transactions?store_ids=102,103&brands=Coca-Cola&date_start=2025-09-01&date_end=2025-09-22&limit=100

Example Response:
{
  "data": [
    {
      "transaction_id": "4d644af4-729a-41ce-98c7-43ffb8bf34cb",
      "store_id": "103",
      "store_name": "Riza Store",
      "brand": "Coca-Cola",
      "category": "Beverages",
      "total_price": 45.00,
      "age": 47,
      "gender": "Male",
      "transaction_ts": "2025-09-18T14:30:00Z",
      "latitude": 14.676,
      "longitude": 121.0437
    }
  ],
  "meta": {
    "total": 1,
    "page": 1,
    "limit": 100,
    "has_more": false
  },
  "cache": {
    "hit": false,
    "ttl": 300
  },
  "performance": {
    "query_time_ms": 150,
    "row_count": 1
  }
}

Error Responses:
- 405: Method not allowed (only GET supported)
- 400: Bad request (invalid parameters)
- 500: Internal server error

Headers:
- Cache-Control: Caching directives
- X-Cache-TTL: Cache TTL in seconds
- X-Cache-Status: "HIT" or "MISS"
- X-Query-Time: Query execution time in milliseconds
- X-Row-Count: Number of rows returned
*/