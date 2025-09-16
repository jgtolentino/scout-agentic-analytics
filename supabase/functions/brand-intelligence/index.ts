/**
 * Brand Intelligence API
 * Comprehensive brand market intelligence and competitive analysis
 * 
 * Endpoints:
 * GET /brand-intelligence?brand={name} - Get brand intelligence summary
 * GET /brand-intelligence/performance?brand={name} - Brand performance metrics
 * GET /brand-intelligence/competitors?brand={name} - Competitive analysis
 * GET /brand-intelligence/pricing?brand={name} - Pricing intelligence
 * POST /brand-intelligence/search - Search brands with market context
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS'
}

interface BrandIntelligenceRequest {
  brand?: string
  category?: string
  limit?: number
  includeCompetitors?: boolean
  includePricing?: boolean
}

interface BrandSearchRequest {
  query: string
  useMarketWeights?: boolean
  confidenceThreshold?: number
  category?: string
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    const url = new URL(req.url)
    const path = url.pathname.split('/').slice(-1)[0]
    const brand = url.searchParams.get('brand')
    const category = url.searchParams.get('category')
    const limit = parseInt(url.searchParams.get('limit') || '10')

    switch (req.method) {
      case 'GET':
        return await handleGetRequest(supabase, path, url.searchParams, corsHeaders)
      case 'POST':
        return await handlePostRequest(supabase, path, req, corsHeaders)
      default:
        return new Response('Method not allowed', { 
          status: 405, 
          headers: corsHeaders 
        })
    }
  } catch (error) {
    console.error('Brand Intelligence API Error:', error)
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error', 
        message: error.message 
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})

async function handleGetRequest(
  supabase: any, 
  endpoint: string, 
  params: URLSearchParams,
  headers: Record<string, string>
) {
  const brand = params.get('brand')
  const category = params.get('category')
  const limit = parseInt(params.get('limit') || '10')

  switch (endpoint) {
    case 'brand-intelligence':
      return await getBrandIntelligence(supabase, brand, headers)
    
    case 'performance':
      return await getBrandPerformance(supabase, brand, headers)
    
    case 'competitors':
      return await getBrandCompetitors(supabase, brand, headers)
    
    case 'pricing':
      return await getBrandPricing(supabase, brand, headers)
    
    case 'category':
      return await getCategoryIntelligence(supabase, category, headers)
    
    case 'opportunities':
      return await getMarketOpportunities(supabase, headers)
    
    case 'health':
      return await getBrandHealthIndex(supabase, brand, headers)
    
    default:
      return await getAllBrandIntelligence(supabase, limit, headers)
  }
}

async function handlePostRequest(
  supabase: any,
  endpoint: string,
  req: Request,
  headers: Record<string, string>
) {
  const body = await req.json()

  switch (endpoint) {
    case 'search':
      return await searchBrands(supabase, body, headers)
    
    case 'analyze':
      return await analyzeBrandPortfolio(supabase, body, headers)
    
    default:
      return new Response('Endpoint not found', { 
        status: 404, 
        headers 
      })
  }
}

async function getBrandIntelligence(
  supabase: any, 
  brand: string | null, 
  headers: Record<string, string>
) {
  if (!brand) {
    return new Response('Brand parameter required', { 
      status: 400, 
      headers 
    })
  }

  const { data, error } = await supabase.rpc('get_brand_intelligence', {
    p_brand_name: brand
  })

  if (error) {
    console.error('Database error:', error)
    return new Response(
      JSON.stringify({ error: 'Database error', details: error.message }),
      { status: 500, headers: { ...headers, 'Content-Type': 'application/json' }}
    )
  }

  if (!data || data.length === 0) {
    return new Response(
      JSON.stringify({ 
        error: 'Brand not found',
        suggestions: await getSimilarBrands(supabase, brand)
      }),
      { status: 404, headers: { ...headers, 'Content-Type': 'application/json' }}
    )
  }

  return new Response(
    JSON.stringify({
      brand: data[0],
      metadata: {
        last_updated: new Date().toISOString(),
        data_source: 'scout_market_intelligence',
        confidence_level: data[0].confidence_score
      }
    }),
    { headers: { ...headers, 'Content-Type': 'application/json' }}
  )
}

async function getBrandPerformance(
  supabase: any,
  brand: string | null,
  headers: Record<string, string>
) {
  if (!brand) {
    return new Response('Brand parameter required', { 
      status: 400, 
      headers 
    })
  }

  const { data, error } = await supabase
    .from('analytics.brand_performance_dashboard')
    .select('*')
    .ilike('brand_name', brand)
    .single()

  if (error || !data) {
    return new Response('Brand performance data not found', { 
      status: 404, 
      headers 
    })
  }

  return new Response(
    JSON.stringify({
      performance: data,
      insights: {
        tier_analysis: data.brand_tier,
        growth_classification: data.growth_status,
        value_proposition: data.value_proposition,
        channel_strength: data.channels_available,
        competitive_threats: data.direct_competitors
      }
    }),
    { headers: { ...headers, 'Content-Type': 'application/json' }}
  )
}

async function getBrandCompetitors(
  supabase: any,
  brand: string | null,
  headers: Record<string, string>
) {
  if (!brand) {
    return new Response('Brand parameter required', { 
      status: 400, 
      headers 
    })
  }

  const { data, error } = await supabase
    .from('analytics.competitive_landscape_matrix')
    .select('*')
    .eq('primary_brand', brand)

  if (error) {
    return new Response('Database error', { status: 500, headers })
  }

  const competitors = data || []
  
  // Get market share comparison
  const shareComparison = competitors.map(comp => ({
    competitor: comp.competitor_brand,
    market_share_gap: comp.share_gap,
    position: comp.share_position,
    pricing_vs_primary: comp.price_premium_percent,
    growth_advantage: comp.growth_advantage,
    competitive_status: comp.competitive_status,
    strategic_insight: comp.strategic_insight,
    threat_level: comp.threat_level
  }))

  return new Response(
    JSON.stringify({
      primary_brand: brand,
      competitive_analysis: shareComparison,
      summary: {
        total_competitors: competitors.length,
        main_threats: competitors
          .filter(c => c.threat_level === 'high')
          .map(c => c.competitor_brand),
        opportunities: competitors
          .filter(c => c.strategic_insight?.includes('Advantage'))
          .map(c => c.strategic_insight)
      }
    }),
    { headers: { ...headers, 'Content-Type': 'application/json' }}
  )
}

async function getBrandPricing(
  supabase: any,
  brand: string | null,
  headers: Record<string, string>
) {
  if (!brand) {
    return new Response('Brand parameter required', { 
      status: 400, 
      headers 
    })
  }

  const { data, error } = await supabase
    .from('analytics.price_intelligence_dashboard')
    .select('*')
    .eq('brand_name', brand)
    .order('price_date', { ascending: false })

  if (error) {
    return new Response('Database error', { status: 500, headers })
  }

  if (!data || data.length === 0) {
    return new Response('Pricing data not found', { status: 404, headers })
  }

  // Aggregate pricing insights
  const pricingInsights = {
    total_skus: data.length,
    average_price: data.reduce((sum, item) => sum + (item.srp_php || 0), 0) / data.length,
    price_range: {
      min: Math.min(...data.map(item => item.srp_php || 0)),
      max: Math.max(...data.map(item => item.srp_php || 0))
    },
    price_positioning: data[0].price_tier,
    channels: [...new Set(data.map(item => item.channel))],
    regions: [...new Set(data.map(item => item.region))],
    alerts: data.filter(item => item.price_alert !== 'Normal'),
    recent_pricing: data.slice(0, 5)
  }

  return new Response(
    JSON.stringify({
      brand: brand,
      pricing_intelligence: pricingInsights,
      detailed_pricing: data
    }),
    { headers: { ...headers, 'Content-Type': 'application/json' }}
  )
}

async function getCategoryIntelligence(
  supabase: any,
  category: string | null,
  headers: Record<string, string>
) {
  if (!category) {
    return new Response('Category parameter required', { 
      status: 400, 
      headers 
    })
  }

  const { data, error } = await supabase.rpc('get_category_intelligence', {
    p_category: category
  })

  if (error || !data || data.length === 0) {
    return new Response('Category data not found', { status: 404, headers })
  }

  return new Response(
    JSON.stringify({
      category_analysis: data[0],
      insights: {
        market_maturity: data[0].market_size_php > 50000 ? 'Large Market' : 'Developing Market',
        growth_stage: data[0].growth_rate > 8 ? 'High Growth' : 
                     data[0].growth_rate > 4 ? 'Moderate Growth' : 'Mature',
        competition_level: data[0].concentration_level,
        key_opportunities: data[0].key_trends
      }
    }),
    { headers: { ...headers, 'Content-Type': 'application/json' }}
  )
}

async function getMarketOpportunities(
  supabase: any,
  headers: Record<string, string>
) {
  const { data, error } = await supabase
    .from('analytics.market_opportunity_analysis')
    .select('*')
    .order('opportunity_score', { ascending: false })
    .limit(10)

  if (error) {
    return new Response('Database error', { status: 500, headers })
  }

  const opportunities = data || []
  
  return new Response(
    JSON.stringify({
      top_opportunities: opportunities,
      summary: {
        total_categories_analyzed: opportunities.length,
        high_opportunity_categories: opportunities
          .filter(opp => opp.opportunity_score > 70)
          .map(opp => opp.category),
        average_opportunity_score: opportunities.length > 0 
          ? opportunities.reduce((sum, opp) => sum + opp.opportunity_score, 0) / opportunities.length 
          : 0
      }
    }),
    { headers: { ...headers, 'Content-Type': 'application/json' }}
  )
}

async function getBrandHealthIndex(
  supabase: any,
  brand: string | null,
  headers: Record<string, string>
) {
  const query = supabase
    .from('analytics.brand_health_index')
    .select('*')
    .order('brand_health_score', { ascending: false })

  if (brand) {
    query.eq('brand_name', brand).single()
  } else {
    query.limit(20)
  }

  const { data, error } = await query

  if (error) {
    return new Response('Database error', { status: 500, headers })
  }

  if (!data) {
    return new Response('Brand health data not found', { status: 404, headers })
  }

  return new Response(
    JSON.stringify({
      brand_health: brand ? data : { brands: data },
      insights: brand ? {
        health_score: data.brand_health_score,
        classification: data.health_classification,
        strengths: data.strengths.filter(s => s !== null),
        improvement_areas: data.areas_for_improvement.filter(a => a !== null),
        benchmarking: {
          vs_category_avg: data.market_share_percent,
          growth_vs_market: data.brand_growth_yoy
        }
      } : {
        healthiest_brands: data.slice(0, 5).map(b => b.brand_name),
        average_health_score: data.reduce((sum, b) => sum + b.brand_health_score, 0) / data.length,
        brands_needing_attention: data.filter(b => b.health_classification === 'Needs Attention').length
      }
    }),
    { headers: { ...headers, 'Content-Type': 'application/json' }}
  )
}

async function searchBrands(
  supabase: any,
  body: BrandSearchRequest,
  headers: Record<string, string>
) {
  const { query, useMarketWeights = true, confidenceThreshold = 0.6, category } = body

  if (!query) {
    return new Response('Search query required', { status: 400, headers })
  }

  const { data, error } = await supabase.rpc('match_brands_with_intelligence', {
    p_input_text: query,
    p_confidence_threshold: confidenceThreshold,
    p_use_market_weights: useMarketWeights
  })

  if (error) {
    return new Response('Database error', { status: 500, headers })
  }

  let results = data || []
  
  // Filter by category if specified
  if (category) {
    results = results.filter(r => 
      r.category?.toLowerCase().includes(category.toLowerCase())
    )
  }

  return new Response(
    JSON.stringify({
      search_query: query,
      matches: results,
      search_metadata: {
        total_matches: results.length,
        confidence_threshold: confidenceThreshold,
        market_weighted: useMarketWeights,
        category_filter: category || 'none'
      }
    }),
    { headers: { ...headers, 'Content-Type': 'application/json' }}
  )
}

async function analyzeBrandPortfolio(
  supabase: any,
  body: { brands: string[] },
  headers: Record<string, string>
) {
  const { brands } = body

  if (!brands || !Array.isArray(brands) || brands.length === 0) {
    return new Response('Brands array required', { status: 400, headers })
  }

  // Get brand intelligence for all brands
  const brandAnalysis = await Promise.all(
    brands.map(async (brand) => {
      const { data } = await supabase.rpc('get_brand_intelligence', {
        p_brand_name: brand
      })
      return data?.[0] || null
    })
  )

  const validBrands = brandAnalysis.filter(b => b !== null)
  
  if (validBrands.length === 0) {
    return new Response('No valid brands found', { status: 404, headers })
  }

  // Portfolio analysis
  const portfolioInsights = {
    total_brands: validBrands.length,
    total_market_share: validBrands.reduce((sum, b) => sum + (b.market_share || 0), 0),
    average_crp: validBrands.reduce((sum, b) => sum + (b.crp || 0), 0) / validBrands.length,
    categories_covered: [...new Set(validBrands.map(b => b.category))],
    
    leaders: validBrands.filter(b => (b.market_share || 0) > 15),
    challengers: validBrands.filter(b => (b.market_share || 0) > 5 && (b.market_share || 0) <= 15),
    followers: validBrands.filter(b => (b.market_share || 0) <= 5),
    
    growth_brands: validBrands.filter(b => (b.growth_rate || 0) > 8),
    declining_brands: validBrands.filter(b => (b.growth_rate || 0) < 0),
    
    premium_brands: validBrands.filter(b => (b.avg_price || 0) > 50),
    value_brands: validBrands.filter(b => (b.avg_price || 0) < 20),
    
    portfolio_health_score: validBrands.reduce((sum, b) => sum + (b.confidence_score || 0.5), 0) / validBrands.length * 100
  }

  return new Response(
    JSON.stringify({
      portfolio_analysis: portfolioInsights,
      brand_details: validBrands,
      recommendations: generatePortfolioRecommendations(portfolioInsights)
    }),
    { headers: { ...headers, 'Content-Type': 'application/json' }}
  )
}

async function getSimilarBrands(supabase: any, brand: string): Promise<string[]> {
  const { data } = await supabase
    .from('metadata.enhanced_brand_master')
    .select('brand_name')
    .ilike('brand_name', `%${brand}%`)
    .limit(5)
    
  return data?.map(b => b.brand_name) || []
}

async function getAllBrandIntelligence(
  supabase: any,
  limit: number,
  headers: Record<string, string>
) {
  const { data, error } = await supabase
    .from('analytics.brand_performance_dashboard')
    .select('brand_name, category, consumer_reach_points, market_share_percent, brand_tier, growth_status')
    .order('consumer_reach_points', { ascending: false })
    .limit(limit)

  if (error) {
    return new Response('Database error', { status: 500, headers })
  }

  return new Response(
    JSON.stringify({
      brands: data || [],
      summary: {
        total_brands_returned: (data || []).length,
        top_brand_by_crp: data?.[0]?.brand_name || null,
        categories_represented: [...new Set((data || []).map(b => b.category))]
      }
    }),
    { headers: { ...headers, 'Content-Type': 'application/json' }}
  )
}

function generatePortfolioRecommendations(insights: any): string[] {
  const recommendations = []

  if (insights.leaders.length === 0) {
    recommendations.push('Consider acquiring or developing market-leading brands')
  }

  if (insights.growth_brands.length < insights.total_brands * 0.3) {
    recommendations.push('Portfolio needs more high-growth brands for future sustainability')
  }

  if (insights.declining_brands.length > 0) {
    recommendations.push(`Address declining performance in ${insights.declining_brands.length} brand(s)`)
  }

  if (insights.categories_covered.length < 3) {
    recommendations.push('Consider diversification across more categories')
  }

  if (insights.portfolio_health_score < 70) {
    recommendations.push('Overall portfolio health needs improvement - focus on data quality and brand strengthening')
  }

  return recommendations
}