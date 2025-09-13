/**
 * Scout v7.1 MindsDB Proxy Edge Function
 * Delegates forecast queries to MindsDB with fallback to SQL seasonal analysis
 * Implements MCP server integration pattern
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface MindsDBRequest {
  operation: 'query' | 'train' | 'predict' | 'status'
  naturalLanguageQuery?: string
  modelName?: string
  predictionHorizon?: number
  filters?: Record<string, any>
  trainingData?: {
    table: string
    targetColumn: string
    features: string[]
    timeColumn?: string
  }
}

interface MindsDBResponse {
  status: 'success' | 'error' | 'fallback'
  operation: string
  data?: any[]
  predictions?: Array<{
    period: string
    predicted_value: number
    confidence: number
    upper_bound?: number
    lower_bound?: number
  }>
  model?: {
    name: string
    status: string
    accuracy?: number
    lastTrained?: string
  }
  error?: string
  fallbackUsed?: boolean
  executionTimeMs: number
}

interface MindsDBConfig {
  host: string
  user: string
  password: string
  database: string
  timeout: number
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const startTime = Date.now()

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

    const requestData: MindsDBRequest = await req.json()
    const { operation, naturalLanguageQuery, modelName, predictionHorizon = 12 } = requestData

    console.log('MindsDB Proxy Request:', {
      operation,
      query: naturalLanguageQuery?.substring(0, 100),
      model: modelName,
      user: user.id
    })

    // Get MindsDB configuration from environment
    const mindsdbApiKey = Deno.env.get('MINDSDB_API_KEY') || 'Postgres_26'
    const mindsdbConfig: MindsDBConfig = {
      host: Deno.env.get('MINDSDB_HOST') || 'cloud.mindsdb.com',
      user: Deno.env.get('MINDSDB_USER') || 'mdb',
      password: mindsdbApiKey, // Use API key as password for MCP integration
      database: Deno.env.get('MINDSDB_DATABASE') || 'mindsdb',
      timeout: 30000 // 30 seconds
    }

    if (!mindsdbApiKey) {
      console.warn('MindsDB API key not configured, using fallback')
      return await handleFallback(operation, requestData, supabase, user, startTime)
    }

    let response: MindsDBResponse

    try {
      switch (operation) {
        case 'query':
          response = await handleQuery(mindsdbConfig, requestData, supabase, user)
          break
        case 'predict':
          response = await handlePredict(mindsdbConfig, requestData, supabase, user)
          break
        case 'train':
          response = await handleTrain(mindsdbConfig, requestData, supabase, user)
          break
        case 'status':
          response = await handleStatus(mindsdbConfig, modelName)
          break
        default:
          throw new Error(`Unsupported operation: ${operation}`)
      }
    } catch (mindsdbError) {
      console.error('MindsDB operation failed, falling back:', mindsdbError)
      response = await handleFallback(operation, requestData, supabase, user, startTime)
    }

    response.executionTimeMs = Date.now() - startTime

    console.log('MindsDB Proxy Success:', {
      operation,
      status: response.status,
      dataPoints: response.data?.length || response.predictions?.length || 0,
      executionTimeMs: response.executionTimeMs,
      fallbackUsed: response.fallbackUsed
    })

    return new Response(
      JSON.stringify(response),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    console.error('MindsDB Proxy Error:', error)
    
    const errorResponse: MindsDBResponse = {
      status: 'error',
      operation: 'unknown',
      error: error.message,
      executionTimeMs: Date.now() - startTime
    }

    return new Response(
      JSON.stringify(errorResponse),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})

async function handleQuery(
  config: MindsDBConfig,
  request: MindsDBRequest,
  supabase: any,
  user: any
): Promise<MindsDBResponse> {
  // Execute general MindsDB query
  const sql = `
    SELECT * FROM ${request.modelName || 'scout_revenue_forecast'}
    WHERE created_at >= NOW() - INTERVAL 7 DAY
    ORDER BY created_at DESC
    LIMIT 100
  `
  
  const result = await executeMindsDBQuery(config, sql)
  
  return {
    status: 'success',
    operation: 'query',
    data: result.data,
    executionTimeMs: 0 // Will be set by caller
  }
}

async function handlePredict(
  config: MindsDBConfig,
  request: MindsDBRequest,
  supabase: any,
  user: any
): Promise<MindsDBResponse> {
  const { modelName = 'scout_revenue_forecast', predictionHorizon = 12, filters = {} } = request
  
  // Build prediction query based on filters
  let whereClause = ''
  const filterParams: string[] = []
  
  if (filters.brand_ids?.length > 0) {
    filterParams.push(`brand_id IN ('${filters.brand_ids.join("', '")}')`)
  }
  if (filters.location_ids?.length > 0) {
    filterParams.push(`location_id IN ('${filters.location_ids.join("', '")}')`)
  }
  
  if (filterParams.length > 0) {
    whereClause = `WHERE ${filterParams.join(' AND ')}`
  }

  const sql = `
    SELECT 
      period,
      predicted_revenue as predicted_value,
      confidence,
      upper_bound,
      lower_bound
    FROM ${modelName}
    ${whereClause}
    ORDER BY period
    LIMIT ${predictionHorizon}
  `
  
  const result = await executeMindsDBQuery(config, sql)
  
  return {
    status: 'success',
    operation: 'predict',
    predictions: result.data.map((row: any) => ({
      period: row.period,
      predicted_value: parseFloat(row.predicted_value || 0),
      confidence: parseFloat(row.confidence || 0.5),
      upper_bound: parseFloat(row.upper_bound || 0),
      lower_bound: parseFloat(row.lower_bound || 0)
    })),
    executionTimeMs: 0
  }
}

async function handleTrain(
  config: MindsDBConfig,
  request: MindsDBRequest,
  supabase: any,
  user: any
): Promise<MindsDBResponse> {
  if (!request.trainingData) {
    throw new Error('Training data configuration is required')
  }

  const { table, targetColumn, features, timeColumn } = request.trainingData
  const modelName = request.modelName || `scout_model_${Date.now()}`
  
  // Create MindsDB model training query
  const featuresList = features.join(', ')
  const orderBy = timeColumn ? `ORDER BY ${timeColumn}` : ''
  
  const sql = `
    CREATE OR REPLACE MODEL ${modelName}
    FROM integration_scout (
      SELECT ${featuresList}, ${targetColumn}
      FROM ${table}
      WHERE tenant_id = '${user.app_metadata?.tenant_id || user.user_metadata?.tenant_id}'
      ${orderBy}
    )
    PREDICT ${targetColumn}
    ${timeColumn ? `ORDER BY ${timeColumn}` : ''}
    WINDOW 12
    HORIZON 12
  `
  
  const result = await executeMindsDBQuery(config, sql)
  
  return {
    status: 'success',
    operation: 'train',
    model: {
      name: modelName,
      status: 'training',
      lastTrained: new Date().toISOString()
    },
    executionTimeMs: 0
  }
}

async function handleStatus(
  config: MindsDBConfig,
  modelName?: string
): Promise<MindsDBResponse> {
  if (!modelName) {
    throw new Error('Model name is required for status check')
  }
  
  const sql = `
    SELECT 
      name,
      status,
      accuracy,
      update_status,
      mindsdb_version,
      error
    FROM models
    WHERE name = '${modelName}'
  `
  
  const result = await executeMindsDBQuery(config, sql)
  
  if (result.data.length === 0) {
    throw new Error(`Model '${modelName}' not found`)
  }
  
  const modelInfo = result.data[0]
  
  return {
    status: 'success',
    operation: 'status',
    model: {
      name: modelInfo.name,
      status: modelInfo.status,
      accuracy: parseFloat(modelInfo.accuracy || 0),
      lastTrained: modelInfo.update_status
    },
    executionTimeMs: 0
  }
}

async function executeMindsDBQuery(config: MindsDBConfig, sql: string): Promise<{ data: any[] }> {
  // Execute HTTP request to MindsDB Cloud API
  const auth = btoa(`${config.user}:${config.password}`)
  
  const response = await fetch(`https://${config.host}/api/sql/query`, {
    method: 'POST',
    headers: {
      'Authorization': `Basic ${auth}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      query: sql,
      database: config.database
    }),
    signal: AbortSignal.timeout(config.timeout)
  })
  
  if (!response.ok) {
    throw new Error(`MindsDB API error: ${response.status} ${response.statusText}`)
  }
  
  const result = await response.json()
  
  if (result.error) {
    throw new Error(`MindsDB query error: ${result.error}`)
  }
  
  return {
    data: result.data || []
  }
}

async function handleFallback(
  operation: string,
  request: MindsDBRequest,
  supabase: any,
  user: any,
  startTime: number
): Promise<MindsDBResponse> {
  console.log('Using SQL seasonal fallback for operation:', operation)
  
  if (operation !== 'predict' && operation !== 'query') {
    throw new Error(`Fallback not available for operation: ${operation}`)
  }
  
  // Implement simple seasonal forecast using SQL
  const tenantId = user.app_metadata?.tenant_id || user.user_metadata?.tenant_id
  const { filters = {}, predictionHorizon = 12 } = request
  
  // Build filter conditions
  const filterConditions: string[] = [`t.tenant_id = '${tenantId}'`]
  
  if (filters.brand_ids?.length > 0) {
    filterConditions.push(`b.brand_external_id = ANY(ARRAY['${filters.brand_ids.join("', '")}'])`)
  }
  if (filters.location_ids?.length > 0) {
    filterConditions.push(`l.location_external_id = ANY(ARRAY['${filters.location_ids.join("', '")}'])`)
  }
  
  const whereClause = filterConditions.join(' AND ')
  
  // SQL for seasonal naive forecast (last year same period)
  const sql = `
    WITH historical_data AS (
      SELECT 
        date_trunc('month', dt.d) as period,
        SUM(t.peso_value) as revenue,
        COUNT(*) as data_points
      FROM scout.fact_transaction_item t
      JOIN scout.dim_time dt ON t.date_id = dt.date_id
      JOIN scout.dim_brand b ON t.brand_id = b.brand_id
      JOIN scout.dim_location l ON t.location_id = l.location_id
      WHERE ${whereClause}
        AND dt.d >= CURRENT_DATE - INTERVAL '24 months'
        AND dt.d < CURRENT_DATE - INTERVAL '12 months'
      GROUP BY date_trunc('month', dt.d)
      ORDER BY period
    ),
    seasonal_forecast AS (
      SELECT 
        (period + INTERVAL '12 months')::date as forecast_period,
        revenue as predicted_value,
        0.6 as confidence, -- Conservative confidence for seasonal naive
        revenue * 1.2 as upper_bound,
        revenue * 0.8 as lower_bound
      FROM historical_data
      WHERE period + INTERVAL '12 months' >= CURRENT_DATE
      ORDER BY forecast_period
      LIMIT ${predictionHorizon}
    )
    SELECT 
      forecast_period as period,
      predicted_value,
      confidence,
      upper_bound,
      lower_bound
    FROM seasonal_forecast
  `
  
  try {
    const { data, error } = await supabase.rpc('fn_execute_sql', {
      _natural_language_query: `Seasonal forecast for ${predictionHorizon} periods`,
      _generated_sql: sql,
      _query_intent: 'forecast_fallback',
      _agent_pipeline: JSON.stringify(['MindsDBProxy', 'SeasonalFallback'])
    })
    
    if (error) {
      throw new Error(`Fallback query failed: ${error.message}`)
    }
    
    const result = data?.[0]
    if (result?.status !== 'success') {
      throw new Error(`Fallback execution failed: ${result?.error_message}`)
    }
    
    const predictions = result.result ? JSON.parse(result.result) : []
    
    // Log fallback usage to job_runs table for monitoring
    await supabase
      .from('platinum.job_runs')
      .insert({
        job_name: 'mindsdb_fallback',
        job_type: 'forecast_fallback',
        status: 'completed',
        records_processed: predictions.length,
        job_output: {
          operation,
          predictions_generated: predictions.length,
          fallback_reason: 'MindsDB unavailable'
        }
      })
    
    return {
      status: 'fallback',
      operation,
      predictions: predictions.map((row: any) => ({
        period: row.period,
        predicted_value: parseFloat(row.predicted_value || 0),
        confidence: parseFloat(row.confidence || 0.6),
        upper_bound: parseFloat(row.upper_bound || 0),
        lower_bound: parseFloat(row.lower_bound || 0)
      })),
      fallbackUsed: true,
      executionTimeMs: Date.now() - startTime
    }
    
  } catch (error) {
    console.error('Seasonal fallback failed:', error)
    throw new Error(`Both MindsDB and fallback failed: ${error.message}`)
  }
}