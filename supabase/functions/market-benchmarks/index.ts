/**
 * Market Benchmarks API
 * Category and competitive benchmarking intelligence
 * 
 * Endpoints:
 * GET /market-benchmarks/categories - Get all category intelligence
 * GET /market-benchmarks/category/{name} - Get specific category analysis
 * GET /market-benchmarks/opportunities - Get market opportunities
 * GET /market-benchmarks/competitive/{brand} - Get competitive landscape
 * POST /market-benchmarks/compare - Compare multiple brands/categories
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS'
}

interface BenchmarkRequest {
  brands?: string[]
  categories?: string[]
  includeFinancials?: boolean
  includePricing?: boolean
  timeframe?: string
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    const url = new URL(req.url)
    const pathSegments = url.pathname.split('/').filter(segment => segment !== '')
    const endpoint = pathSegments[pathSegments.length - 1]
    const subEndpoint = pathSegments[pathSegments.length - 2]

    switch (req.method) {
      case 'GET':
        return await handleGetBenchmarks(supabase, endpoint, subEndpoint, url.searchParams, corsHeaders)
      case 'POST':
        return await handlePostBenchmarks(supabase, endpoint, req, corsHeaders)
      default:
        return new Response('Method not allowed', { status: 405, headers: corsHeaders })
    }
  } catch (error) {
    console.error('Market Benchmarks API Error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', message: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }}
    )
  }
})

async function handleGetBenchmarks(
  supabase: any,
  endpoint: string,
  subEndpoint: string,
  params: URLSearchParams,
  headers: Record<string, string>
) {
  switch (subEndpoint) {
    case 'categories':
      return await getAllCategoryBenchmarks(supabase, headers)
    
    case 'category':
      return await getCategoryBenchmark(supabase, endpoint, headers)
    
    case 'opportunities':
      return await getMarketOpportunities(supabase, headers)
    
    case 'competitive':
      return await getCompetitiveLandscape(supabase, endpoint, headers)
    
    default:
      switch (endpoint) {
        case 'market-benchmarks':
          return await getOverallMarketBenchmarks(supabase, headers)
        case 'trends':
          return await getMarketTrends(supabase, headers)
        case 'health':
          return await getMarketHealthIndicators(supabase, headers)
        default:
          return new Response('Endpoint not found', { status: 404, headers })
      }
  }
}

async function handlePostBenchmarks(
  supabase: any,
  endpoint: string,
  req: Request,
  headers: Record<string, string>
) {
  const body = await req.json()

  switch (endpoint) {
    case 'compare':
      return await compareEntities(supabase, body, headers)
    
    case 'analyze':
      return await analyzeMarketPosition(supabase, body, headers)
    
    default:
      return new Response('Endpoint not found', { status: 404, headers })
  }
}

async function getAllCategoryBenchmarks(
  supabase: any,
  headers: Record<string, string>
) {
  const { data, error } = await supabase
    .from('analytics.category_deep_dive')
    .select('*')
    .order('market_size_php', { ascending: false })

  if (error) {
    return new Response(
      JSON.stringify({ error: 'Database error', details: error.message }),
      { status: 500, headers: { ...headers, 'Content-Type': 'application/json' }}
    )
  }

  const categories = data || []
  
  // Calculate market insights
  const totalMarketSize = categories.reduce((sum, cat) => sum + (cat.market_size_php || 0), 0)
  const avgGrowthRate = categories.reduce((sum, cat) => sum + (cat.cagr_percent || 0), 0) / categories.length
  
  const insights = {
    total_market_size_php: totalMarketSize,
    total_categories: categories.length,
    average_growth_rate: avgGrowthRate,
    
    largest_categories: categories
      .slice(0, 5)
      .map(cat => ({ category: cat.category, size_php: cat.market_size_php })),
    
    fastest_growing: categories
      .sort((a, b) => (b.cagr_percent || 0) - (a.cagr_percent || 0))
      .slice(0, 3)
      .map(cat => ({ category: cat.category, growth_rate: cat.cagr_percent })),
    
    most_competitive: categories
      .filter(cat => cat.market_concentration === 'high')
      .map(cat => cat.category),
    
    high_penetration: categories
      .filter(cat => (cat.penetration_percent || 0) > 80)
      .map(cat => ({ category: cat.category, penetration: cat.penetration_percent })),
    
    healthiest_categories: categories
      .filter(cat => (cat.category_health_score || 0) > 80)
      .map(cat => ({ category: cat.category, health_score: cat.category_health_score }))
  }

  return new Response(
    JSON.stringify({
      category_benchmarks: categories,
      market_insights: insights,
      benchmark_metadata: {
        analysis_date: new Date().toISOString(),
        data_confidence: categories.reduce((sum, cat) => sum + (cat.data_confidence || 0.5), 0) / categories.length,
        data_freshness: Math.min(...categories.map(cat => 
          cat.data_freshness ? new Date(cat.data_freshness).getTime() : Date.now()
        ))
      }
    }),
    { headers: { ...headers, 'Content-Type': 'application/json' }}
  )
}

async function getCategoryBenchmark(
  supabase: any,
  categoryName: string,
  headers: Record<string, string>
) {
  // Get category overview
  const { data: categoryData, error: categoryError } = await supabase
    .from('analytics.category_deep_dive')
    .select('*')
    .eq('category', categoryName)
    .single()

  if (categoryError || !categoryData) {
    return new Response('Category not found', { status: 404, headers })
  }

  // Get brand performance in category
  const { data: brandData, error: brandError } = await supabase
    .from('analytics.brand_performance_dashboard')
    .select('*')
    .eq('category', categoryName)
    .order('market_share_percent', { ascending: false })

  if (brandError) {
    return new Response('Database error', { status: 500, headers })
  }

  // Get competitive dynamics
  const { data: competitiveData, error: competitiveError } = await supabase
    .from('analytics.competitive_landscape_matrix')
    .select('*')
    .eq('category', categoryName)

  // Calculate category insights
  const brands = brandData || []
  const competitive = competitiveData || []

  const categoryInsights = {
    market_structure: {
      total_brands: brands.length,
      market_leaders: brands.filter(b => (b.market_share_percent || 0) > 15).length,
      challengers: brands.filter(b => (b.market_share_percent || 0) > 5 && (b.market_share_percent || 0) <= 15).length,
      followers: brands.filter(b => (b.market_share_percent || 0) <= 5).length,
      hhi_index: calculateHHI(brands) // Herfindahl-Hirschman Index
    },
    
    price_dynamics: {
      avg_price_php: brands.reduce((sum, b) => sum + (b.avg_price_php || 0), 0) / brands.length,
      price_range: {
        min: Math.min(...brands.map(b => b.avg_price_php || 0)),
        max: Math.max(...brands.map(b => b.avg_price_php || 0))
      },
      premium_brands: brands.filter(b => b.value_proposition === 'Premium').length,
      value_brands: brands.filter(b => b.value_proposition === 'Value').length
    },
    
    growth_dynamics: {
      category_growth: categoryData.avg_brand_growth,
      growth_leaders: brands
        .filter(b => (b.brand_growth_yoy || 0) > (categoryData.avg_brand_growth || 0))
        .map(b => ({ brand: b.brand_name, growth: b.brand_growth_yoy })),
      declining_brands: brands
        .filter(b => (b.brand_growth_yoy || 0) < 0)
        .map(b => ({ brand: b.brand_name, decline: b.brand_growth_yoy }))
    },
    
    competitive_intensity: {
      total_competitive_pairs: competitive.length,
      high_intensity_battles: competitive
        .filter(c => c.competitive_intensity === 'high')
        .map(c => `${c.primary_brand} vs ${c.competitor_brand}`),
      market_share_battles: competitive
        .filter(c => Math.abs(c.share_gap || 0) < 3)
        .map(c => ({ brands: `${c.primary_brand} vs ${c.competitor_brand}`, gap: c.share_gap }))
    }
  }

  return new Response(
    JSON.stringify({
      category: categoryName,
      category_overview: categoryData,
      category_insights: categoryInsights,
      brand_performance: brands,
      competitive_dynamics: competitive,
      strategic_recommendations: generateCategoryRecommendations(categoryData, categoryInsights)
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

  if (error) {
    return new Response('Database error', { status: 500, headers })
  }

  const opportunities = data || []
  
  // Categorize opportunities
  const opportunityCategories = {
    high_growth_markets: opportunities.filter(o => o.opportunity_type?.includes('High Growth')),
    penetration_opportunities: opportunities.filter(o => o.opportunity_type?.includes('Penetration')),
    fragmented_markets: opportunities.filter(o => o.opportunity_type?.includes('Fragmented')),
    share_gap_opportunities: opportunities.filter(o => o.opportunity_type?.includes('Share Gap')),
    geographic_expansion: opportunities.filter(o => o.geographic_opportunity !== 'Well-distributed market')
  }

  const topOpportunities = opportunities.slice(0, 10).map(opp => ({
    category: opp.category,
    opportunity_score: opp.opportunity_score,
    opportunity_type: opp.opportunity_type,
    market_size_php: opp.market_size_php,
    growth_rate: opp.cagr_percent,
    penetration_gap: 100 - (opp.penetration_percent || 0),
    strategic_recommendation: opp.strategic_recommendation,
    geographic_opportunity: opp.geographic_opportunity,
    key_drivers: extractOpportunityDrivers(opp)
  }))

  return new Response(
    JSON.stringify({
      market_opportunities: topOpportunities,
      opportunity_categories: opportunityCategories,
      summary: {
        total_opportunities_analyzed: opportunities.length,
        high_score_opportunities: opportunities.filter(o => o.opportunity_score > 70).length,
        total_addressable_market: opportunities.reduce((sum, o) => sum + (o.market_size_php || 0), 0),
        avg_growth_rate: opportunities.reduce((sum, o) => sum + (o.cagr_percent || 0), 0) / opportunities.length
      }
    }),
    { headers: { ...headers, 'Content-Type': 'application/json' }}
  )
}

async function getCompetitiveLandscape(
  supabase: any,
  brandName: string,
  headers: Record<string, string>
) {
  // Get brand's competitive position
  const { data: primaryData, error: primaryError } = await supabase
    .from('analytics.competitive_landscape_matrix')
    .select('*')
    .eq('primary_brand', brandName)

  // Get where brand appears as competitor
  const { data: competitorData, error: competitorError } = await supabase
    .from('analytics.competitive_landscape_matrix')
    .select('*')
    .eq('competitor_brand', brandName)

  if (primaryError || competitorError) {
    return new Response('Database error', { status: 500, headers })
  }

  const primaryBattles = primaryData || []
  const competitorBattles = competitorData || []
  
  // Analyze competitive position
  const competitiveAnalysis = {
    brand: brandName,
    as_primary: {
      total_competitors: primaryBattles.length,
      winning_battles: primaryBattles.filter(b => (b.share_gap || 0) > 2).length,
      losing_battles: primaryBattles.filter(b => (b.share_gap || 0) < -2).length,
      close_battles: primaryBattles.filter(b => Math.abs(b.share_gap || 0) <= 2).length,
      
      dominant_against: primaryBattles
        .filter(b => b.competitive_status === 'Dominant')
        .map(b => b.competitor_brand),
      
      threatened_by: primaryBattles
        .filter(b => b.threat_level === 'high')
        .map(b => b.competitor_brand),
      
      price_advantages: primaryBattles
        .filter(b => (b.strategic_insight || '').includes('Advantage'))
        .map(b => ({ competitor: b.competitor_brand, insight: b.strategic_insight }))
    },
    
    as_competitor: {
      threatening: competitorBattles.filter(b => b.threat_level === 'high').length,
      gaining_ground: competitorBattles
        .filter(b => (b.strategic_insight || '').includes('Gaining'))
        .map(b => b.primary_brand),
      losing_ground: competitorBattles
        .filter(b => (b.strategic_insight || '').includes('Losing'))
        .map(b => b.primary_brand)
    }
  }

  // Strategic recommendations
  const strategicInsights = generateCompetitiveRecommendations(competitiveAnalysis, primaryBattles)

  return new Response(
    JSON.stringify({
      competitive_landscape: competitiveAnalysis,
      detailed_battles: primaryBattles,
      reverse_battles: competitorBattles,
      strategic_insights: strategicInsights,
      market_positioning: {
        overall_competitive_strength: calculateCompetitiveStrength(primaryBattles),
        key_vulnerabilities: identifyVulnerabilities(primaryBattles),
        strategic_opportunities: identifyOpportunities(primaryBattles)
      }
    }),
    { headers: { ...headers, 'Content-Type': 'application/json' }}
  )
}

async function compareEntities(
  supabase: any,
  body: BenchmarkRequest,
  headers: Record<string, string>
) {
  const { brands, categories, includeFinancials = true, includePricing = true } = body

  if (brands && brands.length > 1) {
    return await compareBrands(supabase, brands, includeFinancials, includePricing, headers)
  } else if (categories && categories.length > 1) {
    return await compareCategories(supabase, categories, headers)
  } else {
    return new Response('At least 2 brands or categories required for comparison', { 
      status: 400, 
      headers 
    })
  }
}

async function compareBrands(
  supabase: any,
  brands: string[],
  includeFinancials: boolean,
  includePricing: boolean,
  headers: Record<string, string>
) {
  // Get brand intelligence for each brand
  const brandData = await Promise.all(
    brands.map(async (brand) => {
      const { data } = await supabase.rpc('get_brand_intelligence', {
        p_brand_name: brand
      })
      return { brand, data: data?.[0] || null }
    })
  )

  const validBrands = brandData.filter(b => b.data !== null)
  
  if (validBrands.length < 2) {
    return new Response('Insufficient brand data for comparison', { status: 400, headers })
  }

  // Compare metrics
  const comparison = {
    brands_compared: validBrands.map(b => b.brand),
    
    market_share_comparison: validBrands.map(b => ({
      brand: b.brand,
      market_share: b.data.market_share,
      rank_in_comparison: validBrands
        .sort((a, b) => (b.data.market_share || 0) - (a.data.market_share || 0))
        .findIndex(sorted => sorted.brand === b.brand) + 1
    })),
    
    consumer_reach_comparison: validBrands.map(b => ({
      brand: b.brand,
      crp: b.data.crp,
      rank_in_comparison: validBrands
        .sort((a, b) => (b.data.crp || 0) - (a.data.crp || 0))
        .findIndex(sorted => sorted.brand === b.brand) + 1
    })),
    
    growth_comparison: validBrands.map(b => ({
      brand: b.brand,
      growth_rate: b.data.growth_rate,
      rank_in_comparison: validBrands
        .sort((a, b) => (b.data.growth_rate || 0) - (a.data.growth_rate || 0))
        .findIndex(sorted => sorted.brand === b.brand) + 1
    }))
  }

  // Add pricing comparison if requested
  if (includePricing) {
    const pricingData = await Promise.all(
      brands.map(async (brand) => {
        const { data } = await supabase
          .from('metadata.retail_pricing')
          .select('brand_name, srp_php, price_index')
          .eq('brand_name', brand)
          .order('price_date', { ascending: false })
          .limit(5)
        
        const avgPrice = data?.reduce((sum, item) => sum + item.srp_php, 0) / (data?.length || 1) || 0
        const avgIndex = data?.reduce((sum, item) => sum + item.price_index, 0) / (data?.length || 1) || 1
        
        return { brand, avg_price: avgPrice, price_index: avgIndex }
      })
    )
    
    comparison.pricing_comparison = pricingData.map(p => ({
      brand: p.brand,
      avg_price: p.avg_price,
      price_positioning: p.price_index > 1.1 ? 'Premium' : p.price_index < 0.9 ? 'Value' : 'Mainstream',
      rank_in_comparison: pricingData
        .sort((a, b) => b.avg_price - a.avg_price)
        .findIndex(sorted => sorted.brand === p.brand) + 1
    }))
  }

  return new Response(
    JSON.stringify({
      brand_comparison: comparison,
      detailed_data: validBrands,
      insights: generateBrandComparisonInsights(comparison, validBrands)
    }),
    { headers: { ...headers, 'Content-Type': 'application/json' }}
  )
}

async function compareCategories(
  supabase: any,
  categories: string[],
  headers: Record<string, string>
) {
  const { data, error } = await supabase
    .from('analytics.category_deep_dive')
    .select('*')
    .in('category', categories)

  if (error || !data || data.length < 2) {
    return new Response('Insufficient category data for comparison', { status: 400, headers })
  }

  const comparison = {
    categories_compared: data.map(c => c.category),
    
    market_size_comparison: data.map(c => ({
      category: c.category,
      size_php: c.market_size_php,
      rank: data.sort((a, b) => b.market_size_php - a.market_size_php)
        .findIndex(sorted => sorted.category === c.category) + 1
    })),
    
    growth_comparison: data.map(c => ({
      category: c.category,
      growth_rate: c.cagr_percent,
      rank: data.sort((a, b) => b.cagr_percent - a.cagr_percent)
        .findIndex(sorted => sorted.category === c.category) + 1
    })),
    
    penetration_comparison: data.map(c => ({
      category: c.category,
      penetration: c.penetration_percent,
      rank: data.sort((a, b) => b.penetration_percent - a.penetration_percent)
        .findIndex(sorted => sorted.category === c.category) + 1
    })),
    
    health_comparison: data.map(c => ({
      category: c.category,
      health_score: c.category_health_score,
      rank: data.sort((a, b) => b.category_health_score - a.category_health_score)
        .findIndex(sorted => sorted.category === c.category) + 1
    }))
  }

  return new Response(
    JSON.stringify({
      category_comparison: comparison,
      detailed_data: data,
      insights: generateCategoryComparisonInsights(comparison, data)
    }),
    { headers: { ...headers, 'Content-Type': 'application/json' }}
  )
}

// Helper functions
function calculateHHI(brands: any[]): number {
  const shares = brands.map(b => b.market_share_percent || 0)
  return shares.reduce((sum, share) => sum + (share * share), 0)
}

function extractOpportunityDrivers(opportunity: any): string[] {
  const drivers = []
  if (opportunity.cagr_percent > 8) drivers.push('High Growth Market')
  if (opportunity.penetration_percent < 70) drivers.push('Low Penetration')
  if (opportunity.market_concentration === 'low') drivers.push('Fragmented Market')
  if (opportunity.untracked_share > 25) drivers.push('Significant Untracked Share')
  return drivers
}

function generateCategoryRecommendations(categoryData: any, insights: any): string[] {
  const recommendations = []
  
  if (insights.growth_dynamics.declining_brands.length > 0) {
    recommendations.push('Address declining brand performance through innovation or repositioning')
  }
  
  if (insights.market_structure.hhi_index < 1500) {
    recommendations.push('Fragmented market presents consolidation opportunities')
  }
  
  if (insights.competitive_intensity.high_intensity_battles.length > 3) {
    recommendations.push('Intense competition requires differentiation strategies')
  }
  
  return recommendations
}

function generateCompetitiveRecommendations(analysis: any, battles: any[]): string[] {
  const recommendations = []
  
  if (analysis.as_primary.losing_battles > analysis.as_primary.winning_battles) {
    recommendations.push('Defensive strategy needed - strengthen core position')
  }
  
  if (analysis.as_primary.threatened_by.length > 0) {
    recommendations.push(`Monitor threats from: ${analysis.as_primary.threatened_by.join(', ')}`)
  }
  
  return recommendations
}

function calculateCompetitiveStrength(battles: any[]): number {
  if (battles.length === 0) return 50
  
  const wins = battles.filter(b => (b.share_gap || 0) > 2).length
  const total = battles.length
  return Math.round((wins / total) * 100)
}

function identifyVulnerabilities(battles: any[]): string[] {
  return battles
    .filter(b => b.threat_level === 'high')
    .map(b => `Threatened by ${b.competitor_brand}`)
}

function identifyOpportunities(battles: any[]): string[] {
  return battles
    .filter(b => (b.strategic_insight || '').includes('Advantage'))
    .map(b => b.strategic_insight)
}

function generateBrandComparisonInsights(comparison: any, brands: any[]): string[] {
  const insights = []
  
  const leader = comparison.market_share_comparison
    .sort((a, b) => (b.market_share || 0) - (a.market_share || 0))[0]
  
  insights.push(`Market share leader: ${leader.brand} (${leader.market_share}%)`)
  
  const fastestGrowing = comparison.growth_comparison
    .sort((a, b) => (b.growth_rate || 0) - (a.growth_rate || 0))[0]
  
  insights.push(`Fastest growing: ${fastestGrowing.brand} (${fastestGrowing.growth_rate}% YoY)`)
  
  return insights
}

function generateCategoryComparisonInsights(comparison: any, categories: any[]): string[] {
  const insights = []
  
  const largest = comparison.market_size_comparison
    .sort((a, b) => (b.size_php || 0) - (a.size_php || 0))[0]
  
  insights.push(`Largest market: ${largest.category} (₱${largest.size_php}M)`)
  
  return insights
}

async function getOverallMarketBenchmarks(supabase: any, headers: Record<string, string>) {
  // Implementation for overall market benchmarks
  return new Response('Overall market benchmarks endpoint', { headers })
}

async function getMarketTrends(supabase: any, headers: Record<string, string>) {
  // Implementation for market trends
  return new Response('Market trends endpoint', { headers })
}

async function getMarketHealthIndicators(supabase: any, headers: Record<string, string>) {
  // Implementation for market health indicators
  return new Response('Market health indicators endpoint', { headers })
}

async function analyzeMarketPosition(supabase: any, body: any, headers: Record<string, string>) {
  // Implementation for market position analysis
  return new Response('Market position analysis endpoint', { headers })
}