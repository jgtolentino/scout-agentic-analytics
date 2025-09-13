import { createClient } from 'jsr:@supabase/supabase-js@^2'
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

// Inline CORS (no _shared import needed)
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create a Supabase client with the Auth header from the request
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const url = new URL(req.url)
    const path = url.pathname.split('/').pop()

    switch (path) {
      case 'summary-metrics':
        return await getSummaryMetrics(supabaseClient)
      case 'brand-performance':
        return await getBrandPerformance(supabaseClient, url)
      case 'store-metrics':
        return await getStoreMetrics(supabaseClient, url)
      case 'transaction-trends':
        return await getTransactionTrends(supabaseClient, url)
      case 'product-categories':
        return await getProductCategories(supabaseClient)
      case 'regional-data':
        return await getRegionalData(supabaseClient)
      case 'insights':
        return await getAIInsights(supabaseClient)
      default:
        return new Response(
          JSON.stringify({
            endpoints: [
              '/scout-dashboard-api/summary-metrics',
              '/scout-dashboard-api/brand-performance',
              '/scout-dashboard-api/store-metrics',
              '/scout-dashboard-api/transaction-trends',
              '/scout-dashboard-api/product-categories',
              '/scout-dashboard-api/regional-data',
              '/scout-dashboard-api/insights'
            ]
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        )
    }
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500
    })
  }
})

// Helper function to get date range
function getDateRange(timeRange?: string) {
  const now = new Date()
  let startDate = new Date()
  
  switch (timeRange) {
    case '7d':
      startDate.setDate(now.getDate() - 7)
      break
    case '30d':
      startDate.setDate(now.getDate() - 30)
      break
    case '90d':
      startDate.setDate(now.getDate() - 90)
      break
    default:
      startDate.setDate(now.getDate() - 30)
  }
  
  return {
    start: startDate.toISOString(),
    end: now.toISOString()
  }
}

// Get summary metrics
async function getSummaryMetrics(supabaseClient: any) {
  const { data, error } = await supabaseClient
    .from('transactions')
    .select('total_amount, quantity')
    .gte('created_at', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString())

  if (error) throw error

  const totalRevenue = data?.reduce((sum: number, t: any) => sum + (t.total_amount || 0), 0) || 0
  const totalUnits = data?.reduce((sum: number, t: any) => sum + (t.quantity || 0), 0) || 0

  return new Response(
    JSON.stringify({
      totalRevenue,
      totalUnits,
      avgOrderValue: data?.length ? totalRevenue / data.length : 0,
      transactionCount: data?.length || 0
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
  )
}

// Get brand performance
async function getBrandPerformance(supabaseClient: any, url: URL) {
  const timeRange = url.searchParams.get('timeRange') || '30d'
  const { start } = getDateRange(timeRange)

  // Try RPC first
  let result = await supabaseClient.rpc('get_brand_performance', {
    time_range: timeRange
  })

  if (result.error) {
    // Fallback to direct query
    result = await supabaseClient
      .from('transactions')
      .select('brand_name, total_amount, quantity')
      .gte('created_at', start)
      .not('brand_name', 'is', null)
  }

  if (result.error) throw result.error

  // Aggregate by brand
  const brandData = result.data?.reduce((acc: any, t: any) => {
    const brand = t.brand_name || 'Unknown'
    if (!acc[brand]) {
      acc[brand] = { revenue: 0, units: 0, transactions: 0 }
    }
    acc[brand].revenue += t.total_amount || 0
    acc[brand].units += t.quantity || 0
    acc[brand].transactions += 1
    return acc
  }, {})

  const brands = Object.entries(brandData || {})
    .map(([name, data]: [string, any]) => ({
      name,
      revenue: data.revenue,
      units: data.units,
      growth: Math.random() * 20 - 10 // Placeholder for actual growth calculation
    }))
    .sort((a, b) => b.revenue - a.revenue)
    .slice(0, 10)

  return new Response(
    JSON.stringify(brands),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
  )
}

// Get store metrics
async function getStoreMetrics(supabaseClient: any, url: URL) {
  const timeRange = url.searchParams.get('timeRange') || '30d'
  const { start } = getDateRange(timeRange)

  const { data, error } = await supabaseClient
    .from('transactions')
    .select('store_name, total_amount, quantity, customer_id')
    .gte('created_at', start)
    .not('store_name', 'is', null)

  if (error) throw error

  // Aggregate by store
  const storeData = data?.reduce((acc: any, t: any) => {
    const store = t.store_name
    if (!acc[store]) {
      acc[store] = { revenue: 0, units: 0, transactions: 0, customers: new Set() }
    }
    acc[store].revenue += t.total_amount || 0
    acc[store].units += t.quantity || 0
    acc[store].transactions += 1
    if (t.customer_id) acc[store].customers.add(t.customer_id)
    return acc
  }, {})

  const stores = Object.entries(storeData || {})
    .map(([name, data]: [string, any]) => ({
      name,
      revenue: data.revenue,
      transactions: data.transactions,
      avgBasketSize: data.transactions ? data.revenue / data.transactions : 0,
      customerCount: data.customers.size
    }))
    .sort((a, b) => b.revenue - a.revenue)
    .slice(0, 20)

  return new Response(
    JSON.stringify(stores),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
  )
}

// Get transaction trends
async function getTransactionTrends(supabaseClient: any, url: URL) {
  const timeRange = url.searchParams.get('timeRange') || '30d'
  const { start } = getDateRange(timeRange)

  const { data, error } = await supabaseClient
    .from('transactions')
    .select('created_at, total_amount, quantity')
    .gte('created_at', start)
    .order('created_at', { ascending: true })

  if (error) throw error

  // Group by day
  const dailyData = data?.reduce((acc: any, t: any) => {
    const date = new Date(t.created_at).toISOString().split('T')[0]
    if (!acc[date]) {
      acc[date] = { revenue: 0, transactions: 0, units: 0 }
    }
    acc[date].revenue += t.total_amount || 0
    acc[date].transactions += 1
    acc[date].units += t.quantity || 0
    return acc
  }, {})

  const trends = Object.entries(dailyData || {})
    .map(([date, data]: [string, any]) => ({
      date,
      revenue: data.revenue,
      transactions: data.transactions,
      avgOrderValue: data.transactions ? data.revenue / data.transactions : 0
    }))
    .sort((a, b) => a.date.localeCompare(b.date))

  return new Response(
    JSON.stringify(trends),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
  )
}

// Get product categories
async function getProductCategories(supabaseClient: any) {
  const { data, error } = await supabaseClient
    .from('transactions')
    .select('category_name, total_amount, quantity')
    .gte('created_at', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString())
    .not('category_name', 'is', null)

  if (error) throw error

  // Aggregate by category
  const categoryData = data?.reduce((acc: any, t: any) => {
    const category = t.category_name
    if (!acc[category]) {
      acc[category] = { revenue: 0, units: 0 }
    }
    acc[category].revenue += t.total_amount || 0
    acc[category].units += t.quantity || 0
    return acc
  }, {})

  const categories = Object.entries(categoryData || {})
    .map(([name, data]: [string, any]) => ({
      name,
      value: data.revenue,
      units: data.units
    }))
    .sort((a, b) => b.value - a.value)

  return new Response(
    JSON.stringify(categories),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
  )
}

// Get regional data
async function getRegionalData(supabaseClient: any) {
  const { data, error } = await supabaseClient
    .from('transactions')
    .select('region, total_amount, quantity')
    .gte('created_at', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString())
    .not('region', 'is', null)

  if (error) throw error

  // Aggregate by region
  const regionData = data?.reduce((acc: any, t: any) => {
    const region = t.region
    if (!acc[region]) {
      acc[region] = { revenue: 0, units: 0, transactions: 0 }
    }
    acc[region].revenue += t.total_amount || 0
    acc[region].units += t.quantity || 0
    acc[region].transactions += 1
    return acc
  }, {})

  const regions = Object.entries(regionData || {})
    .map(([name, data]: [string, any]) => ({
      region: name,
      revenue: data.revenue,
      units: data.units,
      storeCount: Math.floor(data.transactions / 10) || 1 // Placeholder
    }))

  return new Response(
    JSON.stringify(regions),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
  )
}

// Get AI insights
async function getAIInsights(supabaseClient: any) {
  // For now, return mock insights
  const insights = [
    {
      type: 'trend',
      title: 'Revenue Growth Opportunity',
      description: 'North region shows 15% higher growth potential based on current trends',
      impact: 'high',
      metric: '+₱2.5M potential'
    },
    {
      type: 'alert',
      title: 'Inventory Alert',
      description: 'Top 3 brands running low on popular SKUs',
      impact: 'medium',
      metric: '3 brands affected'
    },
    {
      type: 'recommendation',
      title: 'Cross-sell Opportunity',
      description: 'Customers buying Brand A also purchase Brand B 73% of the time',
      impact: 'medium',
      metric: '73% correlation'
    }
  ]

  return new Response(
    JSON.stringify(insights),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
  )
}