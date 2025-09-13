/**
 * QueryAgent - Natural Language to SQL Conversion
 * Scout v7.1 Agentic Analytics Platform
 * 
 * Transforms business questions into executable SQL queries with semantic awareness,
 * Filipino language support, and comprehensive security guardrails.
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// =============================================================================
// TYPES & INTERFACES
// =============================================================================

interface QueryAgentRequest {
  natural_language_query: string
  user_context: {
    tenant_id: string
    role: 'executive' | 'store_manager' | 'analyst'
    brand_access?: string[]
    location_access?: string[]
  }
  options?: {
    include_explanation?: boolean
    validate_only?: boolean
    language?: 'en' | 'fil'
  }
}

interface QueryAgentResponse {
  generated_sql: string
  confidence_score: number
  query_intent: 'revenue_analysis' | 'competitive_analysis' | 'forecasting' | 'operational'
  semantic_entities: string[]
  guardrails_applied: string[]
  explanation?: string
  validation_errors?: string[]
  metadata: {
    processing_time_ms: number
    template_used?: string
    fallback_applied?: boolean
  }
}

interface SemanticEntity {
  type: 'brand' | 'category' | 'location' | 'date' | 'metric'
  value: string
  aliases: string[]
  confidence: number
}

// =============================================================================
// SEMANTIC MODEL & TEMPLATES
// =============================================================================

const SEMANTIC_MODEL = {
  entities: {
    brands: ['Alaska', 'Nestle', 'Unilever', 'P&G', 'Colgate', 'Johnson', 'Coca-Cola'],
    categories: ['Milk', 'Coffee', 'Shampoo', 'Soap', 'Toothpaste', 'Baby Care', 'Beverages'],
    locations: ['NCR', 'Cebu', 'Davao', 'Iloilo', 'Baguio', 'Cagayan de Oro'],
    metrics: ['revenue', 'units', 'tx_count', 'avg_basket', 'margin'],
    time_periods: ['today', 'yesterday', 'this week', 'last week', 'this month', 'last month', 'this quarter', 'last quarter', 'this year', 'last year']
  },
  
  filipino_aliases: {
    // Revenue terms
    'kita': 'revenue',
    'benta': 'revenue', 
    'sales': 'revenue',
    'pera': 'revenue',
    
    // Unit terms
    'bilang': 'units',
    'dami': 'units',
    'pieces': 'units',
    
    // Time periods
    'ngayon': 'today',
    'kahapon': 'yesterday',
    'ngayong linggo': 'this week',
    'nakaraang linggo': 'last week',
    'ngayong buwan': 'this month',
    'nakaraang buwan': 'last month',
    
    // Locations
    'Maynila': 'NCR',
    'Manila': 'NCR',
    'Cebu City': 'Cebu',
    'Davao City': 'Davao'
  }
}

const SQL_TEMPLATES = {
  revenue_trend: `
    SELECT 
      date_trunc('{{period}}', dt.d) as period,
      SUM(t.peso_value) as revenue,
      COUNT(DISTINCT t.transaction_id) as transaction_count
    FROM scout.fact_transaction_item t
    JOIN scout.dim_time dt ON t.date_id = dt.date_id
    JOIN scout.dim_brand b ON t.brand_id = b.brand_id
    WHERE dt.d >= '{{start_date}}'::date
      AND dt.d <= '{{end_date}}'::date
      {{brand_filter}}
      {{location_filter}}
      AND auth.jwt() ->> 'tenant_id' = t.tenant_id
    GROUP BY period
    ORDER BY period
  `,
  
  brand_performance: `
    SELECT 
      b.brand_name,
      SUM(t.peso_value) as revenue,
      SUM(t.units) as units_sold,
      COUNT(DISTINCT t.transaction_id) as transactions
    FROM scout.fact_transaction_item t
    JOIN scout.dim_brand b ON t.brand_id = b.brand_id
    JOIN scout.dim_time dt ON t.date_id = dt.date_id
    WHERE dt.d >= '{{start_date}}'::date
      AND dt.d <= '{{end_date}}'::date
      {{brand_filter}}
      {{location_filter}}
      AND auth.jwt() ->> 'tenant_id' = t.tenant_id
    GROUP BY b.brand_name
    ORDER BY revenue DESC
    {{row_limit}}
  `,
  
  category_analysis: `
    SELECT 
      c.category_name,
      SUM(t.peso_value) as revenue,
      ROUND(AVG(t.peso_value), 2) as avg_transaction_value,
      COUNT(DISTINCT t.sku_id) as unique_skus
    FROM scout.fact_transaction_item t
    JOIN scout.dim_category c ON t.category_id = c.category_id
    JOIN scout.dim_time dt ON t.date_id = dt.date_id
    WHERE dt.d >= '{{start_date}}'::date
      AND dt.d <= '{{end_date}}'::date
      {{category_filter}}
      {{location_filter}}
      AND auth.jwt() ->> 'tenant_id' = t.tenant_id
    GROUP BY c.category_name
    ORDER BY revenue DESC
    {{row_limit}}
  `,
  
  location_performance: `
    SELECT 
      l.location_name,
      l.region,
      SUM(t.peso_value) as revenue,
      COUNT(DISTINCT DATE(dt.d)) as active_days,
      ROUND(SUM(t.peso_value) / COUNT(DISTINCT DATE(dt.d)), 2) as daily_avg_revenue
    FROM scout.fact_transaction_item t
    JOIN scout.dim_location l ON t.location_id = l.location_id
    JOIN scout.dim_time dt ON t.date_id = dt.date_id
    WHERE dt.d >= '{{start_date}}'::date
      AND dt.d <= '{{end_date}}'::date
      {{location_filter}}
      AND auth.jwt() ->> 'tenant_id' = t.tenant_id
    GROUP BY l.location_name, l.region
    ORDER BY revenue DESC
    {{row_limit}}
  `
}

// =============================================================================
// QUERY INTENT CLASSIFICATION
// =============================================================================

class IntentClassifier {
  private static readonly INTENT_PATTERNS = {
    revenue_analysis: [
      'revenue', 'sales', 'kita', 'benta', 'income', 'earning',
      'profit', 'performance', 'trend', 'growth'
    ],
    competitive_analysis: [
      'competitor', 'competition', 'market share', 'brand comparison',
      'vs', 'versus', 'compare', 'competitive', 'rival'
    ],
    forecasting: [
      'forecast', 'predict', 'projection', 'future', 'estimate',
      'trend', 'outlook', 'expected', 'anticipated'
    ],
    operational: [
      'inventory', 'stock', 'transaction', 'customer', 'store',
      'location', 'staff', 'operational', 'daily', 'hourly'
    ]
  }

  static classify(query: string): string {
    const lowercaseQuery = query.toLowerCase()
    const scores: Record<string, number> = {}

    for (const [intent, patterns] of Object.entries(this.INTENT_PATTERNS)) {
      scores[intent] = patterns.reduce((score, pattern) => {
        return score + (lowercaseQuery.includes(pattern) ? 1 : 0)
      }, 0)
    }

    const topIntent = Object.entries(scores).reduce((a, b) => 
      scores[a[0]] > scores[b[0]] ? a : b
    )[0]

    return topIntent as keyof typeof this.INTENT_PATTERNS
  }
}

// =============================================================================
// ENTITY EXTRACTION & NORMALIZATION
// =============================================================================

class EntityExtractor {
  static extract(query: string): SemanticEntity[] {
    const entities: SemanticEntity[] = []
    const lowercaseQuery = query.toLowerCase()

    // Extract brands
    for (const brand of SEMANTIC_MODEL.entities.brands) {
      if (lowercaseQuery.includes(brand.toLowerCase())) {
        entities.push({
          type: 'brand',
          value: brand,
          aliases: [brand],
          confidence: 0.9
        })
      }
    }

    // Extract categories
    for (const category of SEMANTIC_MODEL.entities.categories) {
      if (lowercaseQuery.includes(category.toLowerCase())) {
        entities.push({
          type: 'category',
          value: category,
          aliases: [category],
          confidence: 0.85
        })
      }
    }

    // Extract locations
    for (const location of SEMANTIC_MODEL.entities.locations) {
      if (lowercaseQuery.includes(location.toLowerCase())) {
        entities.push({
          type: 'location',
          value: location,
          aliases: [location],
          confidence: 0.8
        })
      }
    }

    // Extract Filipino aliases
    for (const [filipino, english] of Object.entries(SEMANTIC_MODEL.filipino_aliases)) {
      if (lowercaseQuery.includes(filipino)) {
        const existingEntity = entities.find(e => e.value === english)
        if (existingEntity) {
          existingEntity.aliases.push(filipino)
        } else {
          entities.push({
            type: this.getEntityType(english),
            value: english,
            aliases: [filipino, english],
            confidence: 0.75
          })
        }
      }
    }

    // Extract time periods
    for (const period of SEMANTIC_MODEL.entities.time_periods) {
      if (lowercaseQuery.includes(period)) {
        entities.push({
          type: 'date',
          value: period,
          aliases: [period],
          confidence: 0.9
        })
      }
    }

    return entities
  }

  private static getEntityType(value: string): SemanticEntity['type'] {
    if (SEMANTIC_MODEL.entities.brands.includes(value)) return 'brand'
    if (SEMANTIC_MODEL.entities.categories.includes(value)) return 'category'
    if (SEMANTIC_MODEL.entities.locations.includes(value)) return 'location'
    if (SEMANTIC_MODEL.entities.metrics.includes(value)) return 'metric'
    return 'date'
  }
}

// =============================================================================
// SQL GENERATION ENGINE
// =============================================================================

class SQLGenerator {
  static generate(
    intent: string,
    entities: SemanticEntity[],
    userContext: QueryAgentRequest['user_context']
  ): { sql: string; template: string; confidence: number } {
    
    const timeRange = this.extractTimeRange(entities)
    const brands = entities.filter(e => e.type === 'brand').map(e => e.value)
    const categories = entities.filter(e => e.type === 'category').map(e => e.value)
    const locations = entities.filter(e => e.type === 'location').map(e => e.value)

    let template: string
    let templateName: string

    // Select appropriate template based on intent
    switch (intent) {
      case 'revenue_analysis':
        if (brands.length > 0) {
          template = SQL_TEMPLATES.brand_performance
          templateName = 'brand_performance'
        } else if (categories.length > 0) {
          template = SQL_TEMPLATES.category_analysis
          templateName = 'category_analysis'
        } else if (locations.length > 0) {
          template = SQL_TEMPLATES.location_performance
          templateName = 'location_performance'
        } else {
          template = SQL_TEMPLATES.revenue_trend
          templateName = 'revenue_trend'
        }
        break
      
      default:
        template = SQL_TEMPLATES.revenue_trend
        templateName = 'revenue_trend'
    }

    // Apply template substitutions
    let sql = template
      .replace('{{start_date}}', timeRange.start)
      .replace('{{end_date}}', timeRange.end)
      .replace('{{period}}', timeRange.period)

    // Apply filters
    sql = sql.replace('{{brand_filter}}', this.buildBrandFilter(brands))
    sql = sql.replace('{{category_filter}}', this.buildCategoryFilter(categories))
    sql = sql.replace('{{location_filter}}', this.buildLocationFilter(locations))
    
    // Apply role-based row limits
    sql = sql.replace('{{row_limit}}', this.buildRowLimit(userContext.role))

    // Calculate confidence based on entity extraction quality
    const confidence = this.calculateConfidence(entities, intent)

    return {
      sql: sql.trim(),
      template: templateName,
      confidence
    }
  }

  private static extractTimeRange(entities: SemanticEntity[]): { start: string; end: string; period: string } {
    const dateEntities = entities.filter(e => e.type === 'date')
    
    if (dateEntities.length === 0) {
      // Default to last 30 days
      return {
        start: "CURRENT_DATE - INTERVAL '30 days'",
        end: "CURRENT_DATE",
        period: "day"
      }
    }

    const timeEntity = dateEntities[0].value
    const now = new Date()

    switch (timeEntity) {
      case 'today':
        return {
          start: "CURRENT_DATE",
          end: "CURRENT_DATE",
          period: "hour"
        }
      case 'yesterday':
        return {
          start: "CURRENT_DATE - INTERVAL '1 day'",
          end: "CURRENT_DATE - INTERVAL '1 day'",
          period: "hour"
        }
      case 'this week':
        return {
          start: "date_trunc('week', CURRENT_DATE)",
          end: "CURRENT_DATE",
          period: "day"
        }
      case 'last week':
        return {
          start: "date_trunc('week', CURRENT_DATE - INTERVAL '1 week')",
          end: "date_trunc('week', CURRENT_DATE) - INTERVAL '1 day'",
          period: "day"
        }
      case 'this month':
        return {
          start: "date_trunc('month', CURRENT_DATE)",
          end: "CURRENT_DATE",
          period: "day"
        }
      case 'last month':
        return {
          start: "date_trunc('month', CURRENT_DATE - INTERVAL '1 month')",
          end: "date_trunc('month', CURRENT_DATE) - INTERVAL '1 day'",
          period: "day"
        }
      default:
        return {
          start: "CURRENT_DATE - INTERVAL '30 days'",
          end: "CURRENT_DATE",
          period: "day"
        }
    }
  }

  private static buildBrandFilter(brands: string[]): string {
    if (brands.length === 0) return ''
    const brandList = brands.map(b => `'${b}'`).join(', ')
    return `AND b.brand_name IN (${brandList})`
  }

  private static buildCategoryFilter(categories: string[]): string {
    if (categories.length === 0) return ''
    const categoryList = categories.map(c => `'${c}'`).join(', ')
    return `AND c.category_name IN (${categoryList})`
  }

  private static buildLocationFilter(locations: string[]): string {
    if (locations.length === 0) return ''
    const locationList = locations.map(l => `'${l}'`).join(', ')
    return `AND l.region IN (${locationList})`
  }

  private static buildRowLimit(role: string): string {
    const limits = {
      executive: 'LIMIT 5000',
      store_manager: 'LIMIT 20000', 
      analyst: 'LIMIT 100000'
    }
    return limits[role as keyof typeof limits] || 'LIMIT 1000'
  }

  private static calculateConfidence(entities: SemanticEntity[], intent: string): number {
    const baseConfidence = 0.6
    const entityBonus = Math.min(entities.length * 0.1, 0.3)
    const intentBonus = intent !== 'operational' ? 0.1 : 0
    
    return Math.min(baseConfidence + entityBonus + intentBonus, 1.0)
  }
}

// =============================================================================
// SECURITY GUARDRAILS
// =============================================================================

class SecurityGuardrails {
  static validate(sql: string, userContext: QueryAgentRequest['user_context']): {
    isValid: boolean
    errors: string[]
    guardrailsApplied: string[]
  } {
    const errors: string[] = []
    const guardrailsApplied: string[] = []

    // Check for SQL injection patterns
    const injectionPatterns = [
      /;\s*(drop|delete|update|insert|create|alter)\s/i,
      /union\s+select/i,
      /--\s*$/m,
      /\/\*.*\*\//,
      /exec\s*\(/i,
      /xp_cmdshell/i
    ]

    for (const pattern of injectionPatterns) {
      if (pattern.test(sql)) {
        errors.push(`Potential SQL injection detected: ${pattern.source}`)
      }
    }

    // Ensure RLS is applied
    if (!sql.includes("auth.jwt() ->> 'tenant_id'")) {
      errors.push("Row Level Security (RLS) constraint missing")
    } else {
      guardrailsApplied.push("RLS tenant isolation")
    }

    // Check for role-based limits
    const hasLimit = sql.includes('LIMIT')
    if (!hasLimit) {
      errors.push("Role-based row limit missing")
    } else {
      guardrailsApplied.push(`Role-based limit (${userContext.role})`)
    }

    // Validate table access
    const allowedTables = [
      'scout.fact_transaction_item',
      'scout.dim_time',
      'scout.dim_brand',
      'scout.dim_category',
      'scout.dim_location',
      'scout.dim_sku'
    ]

    const tablePattern = /FROM\s+(\w+\.\w+)/gi
    let match
    while ((match = tablePattern.exec(sql)) !== null) {
      const table = match[1]
      if (!allowedTables.includes(table)) {
        errors.push(`Unauthorized table access: ${table}`)
      }
    }

    if (errors.length === 0) {
      guardrailsApplied.push("SQL injection prevention")
      guardrailsApplied.push("Table access validation")
    }

    return {
      isValid: errors.length === 0,
      errors,
      guardrailsApplied
    }
  }
}

// =============================================================================
// MAIN QUERY AGENT
// =============================================================================

class QueryAgent {
  static async process(request: QueryAgentRequest): Promise<QueryAgentResponse> {
    const startTime = Date.now()
    
    try {
      // 1. Classify query intent
      const intent = IntentClassifier.classify(request.natural_language_query)
      
      // 2. Extract semantic entities
      const entities = EntityExtractor.extract(request.natural_language_query)
      
      // 3. Generate SQL
      const sqlResult = SQLGenerator.generate(intent, entities, request.user_context)
      
      // 4. Apply security guardrails
      const validation = SecurityGuardrails.validate(sqlResult.sql, request.user_context)
      
      if (!validation.isValid) {
        return {
          generated_sql: '',
          confidence_score: 0,
          query_intent: intent as QueryAgentResponse['query_intent'],
          semantic_entities: entities.map(e => `${e.type}:${e.value}`),
          guardrails_applied: [],
          validation_errors: validation.errors,
          metadata: {
            processing_time_ms: Date.now() - startTime,
            fallback_applied: false
          }
        }
      }

      return {
        generated_sql: sqlResult.sql,
        confidence_score: sqlResult.confidence,
        query_intent: intent as QueryAgentResponse['query_intent'],
        semantic_entities: entities.map(e => `${e.type}:${e.value}`),
        guardrails_applied: validation.guardrailsApplied,
        explanation: request.options?.include_explanation ? 
          this.generateExplanation(intent, entities, sqlResult.template) : undefined,
        metadata: {
          processing_time_ms: Date.now() - startTime,
          template_used: sqlResult.template,
          fallback_applied: false
        }
      }
      
    } catch (error) {
      return {
        generated_sql: '',
        confidence_score: 0,
        query_intent: 'operational',
        semantic_entities: [],
        guardrails_applied: [],
        validation_errors: [`Processing error: ${error.message}`],
        metadata: {
          processing_time_ms: Date.now() - startTime,
          fallback_applied: true
        }
      }
    }
  }

  private static generateExplanation(intent: string, entities: SemanticEntity[], template: string): string {
    const entityDescriptions = entities.map(e => `${e.type}: ${e.value}`).join(', ')
    return `Generated ${intent} query using ${template} template. Extracted entities: ${entityDescriptions}`
  }
}

// =============================================================================
// EDGE FUNCTION HANDLER
// =============================================================================

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
      }
    })
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' }
    })
  }

  try {
    const request: QueryAgentRequest = await req.json()
    
    // Validate required fields
    if (!request.natural_language_query || !request.user_context?.tenant_id || !request.user_context?.role) {
      return new Response(JSON.stringify({ 
        error: 'Missing required fields: natural_language_query, user_context.tenant_id, user_context.role' 
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    const response = await QueryAgent.process(request)
    
    return new Response(JSON.stringify(response), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      }
    })
    
  } catch (error) {
    return new Response(JSON.stringify({ 
      error: 'Internal server error',
      details: error.message 
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})