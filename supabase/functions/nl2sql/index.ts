/**
 * Scout v7.1 NL→SQL Edge Function
 * Converts natural language queries to SQL using semantic model awareness
 * Implements QueryAgent with Architect persona and guardrails
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface NL2SQLRequest {
  naturalLanguageQuery: string
  filters?: Record<string, any>
  cohorts?: Array<{
    key: string
    name: string
    filters: Record<string, any>
  }>
  role?: 'executive' | 'analyst' | 'store_manager'
  context?: {
    currentPage?: string
    previousQueries?: string[]
    userIntent?: string
  }
}

interface NL2SQLResponse {
  generatedSQL: string
  queryIntent: string
  confidence: number
  explanation: string
  semanticEntities: string[]
  estimatedRowCount: number
  executionWarnings?: string[]
  shouldDelegateToMindsDB?: boolean
  delegationReason?: string
}

const SEMANTIC_MODEL = {
  entities: {
    brand: { pk: 'brand_id', label: 'brand_name', table: 'scout.dim_brand' },
    category: { pk: 'category_id', label: 'category_name', table: 'scout.dim_category' },
    sku: { pk: 'sku_id', label: 'sku_name', table: 'scout.dim_sku' },
    location: { pk: 'location_id', label: 'region || \'/\' || city || \'/\' || barangay', table: 'scout.dim_location' },
    date: { pk: 'd', label: 'd', table: 'scout.dim_time' }
  },
  metrics: {
    revenue: { sql: 'sum(peso_value)', grain: ['date', 'brand', 'category', 'location'], format: 'currency' },
    units: { sql: 'sum(qty)', grain: ['date', 'brand', 'category', 'location'], format: 'number' },
    tx_count: { sql: 'count(distinct tx_id)', grain: ['date', 'location'], format: 'number' },
    avg_basket: { sql: 'sum(peso_value)/nullif(count(distinct tx_id),0)', grain: ['date', 'location'], format: 'currency' }
  },
  aliases: {
    synonyms: [
      ['yosi', 'cigarettes', 'tobacco', 'sigarilyo'],
      ['sari-sari', 'sari sari', 'sari store', 'convenience store', 'tindahan'],
      ['revenue', 'sales', 'gross sales', 'income', 'kita'],
      ['units', 'quantity', 'qty', 'pieces', 'bilang']
    ],
    colloquial: {
      'how much': 'revenue',
      'how many': 'units',
      'what sold': 'top products by revenue',
      'best selling': 'top products by units',
      'compare': 'cohort analysis',
      'trend': 'time series',
      'forecast': 'prediction',
      'predict': 'forecast'
    }
  }
}

const QUERY_TEMPLATES = {
  metric_simple: `
    SELECT 
      {time_dimension} as period,
      {metric_calculation} as {metric_name}
    FROM scout.fact_transaction_item t
    JOIN scout.dim_time dt ON t.date_id = dt.date_id
    {additional_joins}
    WHERE t.tenant_id = $1
      {filter_conditions}
    GROUP BY {time_dimension}
    ORDER BY {time_dimension}
  `,
  cohort_comparison: `
    WITH cohort_data AS (
      {cohort_queries_union}
    )
    SELECT 
      cohort_key,
      period,
      {metric_calculation} as {metric_name}
    FROM cohort_data
    GROUP BY cohort_key, period
    ORDER BY cohort_key, period
  `,
  top_performers: `
    SELECT 
      {dimension_label} as name,
      {metric_calculation} as {metric_name},
      ROW_NUMBER() OVER (ORDER BY {metric_calculation} DESC) as rank
    FROM scout.fact_transaction_item t
    JOIN {dimension_table} d ON t.{dimension_pk} = d.{dimension_pk}
    {additional_joins}
    WHERE t.tenant_id = $1
      {filter_conditions}
    GROUP BY {dimension_label}
    ORDER BY {metric_calculation} DESC
    LIMIT {limit}
  `
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    // Get user context
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) {
      throw new Error('Unauthorized')
    }

    const requestData: NL2SQLRequest = await req.json()
    const { naturalLanguageQuery, filters = {}, cohorts = [], role = 'analyst', context = {} } = requestData

    // Step 1: Analyze query intent and extract entities
    const queryAnalysis = analyzeQuery(naturalLanguageQuery)
    
    // Step 2: Check if should delegate to MindsDB
    const { data: delegationCheck } = await supabase.rpc('fn_should_delegate_to_mindsdb', {
      _natural_language_query: naturalLanguageQuery,
      _intent_score: queryAnalysis.confidence
    })

    if (delegationCheck?.[0]?.should_delegate) {
      return new Response(
        JSON.stringify({
          shouldDelegateToMindsDB: true,
          delegationReason: delegationCheck[0].delegation_reason,
          queryIntent: 'forecast',
          confidence: delegationCheck[0].confidence
        } as NL2SQLResponse),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      )
    }

    // Step 3: Generate SQL based on query intent
    const sqlGeneration = await generateSQL(queryAnalysis, filters, cohorts, role)
    
    // Step 4: Validate generated SQL
    const { data: validationResult } = await supabase.rpc('fn_validate_sql', {
      _sql: sqlGeneration.sql,
      _user_role: role
    })

    if (!validationResult?.[0]?.is_valid) {
      throw new Error(`SQL Validation Failed: ${validationResult?.[0]?.error_message}`)
    }

    // Step 5: Estimate row count (simple heuristic)
    const estimatedRowCount = estimateRowCount(queryAnalysis, role)

    const response: NL2SQLResponse = {
      generatedSQL: sqlGeneration.sql,
      queryIntent: queryAnalysis.intent,
      confidence: queryAnalysis.confidence,
      explanation: sqlGeneration.explanation,
      semanticEntities: queryAnalysis.entities,
      estimatedRowCount: estimatedRowCount,
      executionWarnings: sqlGeneration.warnings,
      shouldDelegateToMindsDB: false
    }

    return new Response(
      JSON.stringify(response),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    console.error('NL2SQL Error:', error)
    return new Response(
      JSON.stringify({ 
        error: error.message,
        shouldDelegateToMindsDB: false
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})

function analyzeQuery(query: string): {
  intent: string
  confidence: number
  entities: string[]
  metrics: string[]
  timeGranularity: string
  comparisonType?: string
} {
  const queryLower = query.toLowerCase()
  
  // Intent classification
  let intent = 'metric_query'
  let confidence = 0.7
  
  if (queryLower.includes('compare') || queryLower.includes('vs') || queryLower.includes('versus')) {
    intent = 'comparison'
    confidence = 0.9
  } else if (queryLower.includes('top') || queryLower.includes('best') || queryLower.includes('highest')) {
    intent = 'top_performers'
    confidence = 0.85
  } else if (queryLower.includes('trend') || queryLower.includes('over time') || queryLower.includes('monthly')) {
    intent = 'time_series'
    confidence = 0.8
  }

  // Entity extraction using semantic model aliases
  const entities: string[] = []
  const metrics: string[] = []
  
  // Check for entity mentions
  Object.keys(SEMANTIC_MODEL.entities).forEach(entity => {
    if (queryLower.includes(entity)) {
      entities.push(entity)
    }
  })
  
  // Check for metric mentions and aliases
  Object.keys(SEMANTIC_MODEL.metrics).forEach(metric => {
    if (queryLower.includes(metric)) {
      metrics.push(metric)
    }
  })
  
  // Check colloquial aliases
  Object.entries(SEMANTIC_MODEL.aliases.colloquial).forEach(([phrase, metric]) => {
    if (queryLower.includes(phrase)) {
      metrics.push(metric)
    }
  })
  
  // Default to revenue if no metric specified
  if (metrics.length === 0) {
    metrics.push('revenue')
  }

  // Time granularity detection
  let timeGranularity = 'week'
  if (queryLower.includes('daily') || queryLower.includes('day')) timeGranularity = 'day'
  else if (queryLower.includes('monthly') || queryLower.includes('month')) timeGranularity = 'month'
  else if (queryLower.includes('quarterly') || queryLower.includes('quarter')) timeGranularity = 'quarter'
  else if (queryLower.includes('yearly') || queryLower.includes('year')) timeGranularity = 'year'

  return {
    intent,
    confidence,
    entities,
    metrics,
    timeGranularity
  }
}

async function generateSQL(
  analysis: ReturnType<typeof analyzeQuery>,
  filters: Record<string, any>,
  cohorts: any[],
  role: string
): Promise<{
  sql: string
  explanation: string
  warnings: string[]
}> {
  const warnings: string[] = []
  let template = QUERY_TEMPLATES.metric_simple
  
  // Select template based on intent
  if (analysis.intent === 'comparison' && cohorts.length > 0) {
    template = QUERY_TEMPLATES.cohort_comparison
  } else if (analysis.intent === 'top_performers') {
    template = QUERY_TEMPLATES.top_performers
  }
  
  // Get primary metric
  const primaryMetric = analysis.metrics[0] || 'revenue'
  const metricDef = SEMANTIC_MODEL.metrics[primaryMetric as keyof typeof SEMANTIC_MODEL.metrics]
  
  if (!metricDef) {
    throw new Error(`Unknown metric: ${primaryMetric}`)
  }
  
  // Build time dimension
  const timeDimension = `date_trunc('${analysis.timeGranularity}', dt.d)`
  
  // Build joins
  const joins = ['JOIN scout.dim_time dt ON t.date_id = dt.date_id']
  
  if (analysis.entities.includes('brand') || filters.brand_ids) {
    joins.push('JOIN scout.dim_brand b ON t.brand_id = b.brand_id')
  }
  if (analysis.entities.includes('category') || filters.category_ids) {
    joins.push('JOIN scout.dim_category c ON t.category_id = c.category_id')
  }
  if (analysis.entities.includes('location') || filters.location_ids) {
    joins.push('JOIN scout.dim_location l ON t.location_id = l.location_id')
  }
  
  // Build filter conditions
  const filterConditions: string[] = []
  
  if (filters.brand_ids?.length > 0) {
    filterConditions.push(`AND b.brand_external_id = ANY(ARRAY[${filters.brand_ids.map((id: string) => `'${id}'`).join(',')}])`)
  }
  if (filters.category_ids?.length > 0) {
    filterConditions.push(`AND c.category_external_id = ANY(ARRAY[${filters.category_ids.map((id: string) => `'${id}'`).join(',')}])`)
  }
  if (filters.location_ids?.length > 0) {
    filterConditions.push(`AND l.location_external_id = ANY(ARRAY[${filters.location_ids.map((id: string) => `'${id}'`).join(',')}])`)
  }
  if (filters.date_from) {
    filterConditions.push(`AND dt.d >= '${filters.date_from}'`)
  }
  if (filters.date_to) {
    filterConditions.push(`AND dt.d <= '${filters.date_to}'`)
  }
  
  // Apply role-based limits
  const rowLimit = role === 'executive' ? 5000 : role === 'store_manager' ? 20000 : 100000
  
  // Generate final SQL
  const sql = template
    .replace(/{time_dimension}/g, timeDimension)
    .replace(/{metric_calculation}/g, metricDef.sql)
    .replace(/{metric_name}/g, primaryMetric)
    .replace(/{additional_joins}/g, joins.slice(1).join('\n    '))
    .replace(/{filter_conditions}/g, filterConditions.join('\n      '))
    .replace(/{limit}/g, '10') // Default limit for top performers
  
  // Add row limit
  const finalSQL = `${sql}\nLIMIT ${rowLimit}`
  
  const explanation = `Generated ${analysis.intent} query for ${primaryMetric} metric with ${analysis.timeGranularity} granularity. Applied ${filterConditions.length} filters and ${role} role limits.`
  
  if (role === 'executive' && rowLimit < 10000) {
    warnings.push('Executive role has reduced row limit for performance')
  }
  
  return {
    sql: finalSQL,
    explanation,
    warnings
  }
}

function estimateRowCount(analysis: ReturnType<typeof analyzeQuery>, role: string): number {
  // Simple heuristic based on query type and role limits
  const baseEstimate = analysis.intent === 'top_performers' ? 10 : 
                      analysis.timeGranularity === 'day' ? 365 :
                      analysis.timeGranularity === 'week' ? 52 :
                      analysis.timeGranularity === 'month' ? 12 : 4
  
  const roleLimit = role === 'executive' ? 5000 : role === 'store_manager' ? 20000 : 100000
  
  return Math.min(baseEstimate * 10, roleLimit)
}