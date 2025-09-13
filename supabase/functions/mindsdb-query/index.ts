/**
 * Scout v7.1 MindsDB Query Edge Function
 * Direct query interface to MindsDB with MCP integration
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { corsHeaders } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface MindsDBQueryRequest {
  query: string
  database?: string
}

interface MindsDBQueryResponse {
  status: 'success' | 'error'
  message: string
  result?: {
    query: string
    columns: string[]
    data: any[][]
    execution_time_ms: number
    status: string
  }
  error?: string
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const startTime = Date.now()

  try {
    // Authenticate request
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    const { data: { user } } = await supabase.auth.getUser()
    if (!user) {
      throw new Error('Unauthorized')
    }

    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const requestData: MindsDBQueryRequest = await req.json()
    const query = requestData.query || 'SHOW DATABASES;'
    const database = requestData.database || 'mindsdb'
    
    // Get MindsDB configuration
    const mindsdbApiKey = Deno.env.get('MINDSDB_API_KEY') || 'Postgres_26'
    const mindsdbHost = Deno.env.get('MINDSDB_HOST') || 'cloud.mindsdb.com'
    const mindsdbUser = Deno.env.get('MINDSDB_USER') || 'mdb'

    console.log('MindsDB Query Request:', {
      query: query.substring(0, 100),
      database,
      user: user.id
    })

    // Execute query against MindsDB Cloud API
    const auth = btoa(`${mindsdbUser}:${mindsdbApiKey}`)
    
    const response = await fetch(`https://${mindsdbHost}/api/sql/query`, {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${auth}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        query: query,
        database: database
      }),
      signal: AbortSignal.timeout(30000) // 30 second timeout
    })
    
    if (!response.ok) {
      throw new Error(`MindsDB API error: ${response.status} ${response.statusText}`)
    }
    
    const mindsdbResult = await response.json()
    
    if (mindsdbResult.error) {
      throw new Error(`MindsDB query error: ${mindsdbResult.error}`)
    }

    const executionTime = Date.now() - startTime

    const result: MindsDBQueryResponse = {
      status: 'success',
      message: 'MindsDB query executed successfully',
      result: {
        query,
        columns: mindsdbResult.columns || [],
        data: mindsdbResult.data || [],
        execution_time_ms: executionTime,
        status: 'success'
      }
    }

    // Log performance metrics
    await supabase
      .from('scout_performance.model_queries')
      .insert({
        query_text: query.substring(0, 1000),
        execution_time_ms: executionTime,
        model_provider: 'mindsdb_cloud',
        result_count: mindsdbResult.data?.length || 0,
        success: true,
        user_id: user.id,
        created_at: new Date().toISOString()
      })
      .select()

    console.log('MindsDB Query Success:', {
      executionTimeMs: executionTime,
      resultRows: mindsdbResult.data?.length || 0,
      user: user.id
    })

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
    })

  } catch (error) {
    const executionTime = Date.now() - startTime
    
    console.error('MindsDB Query Error:', error)

    // Log error metrics if we have user context
    try {
      const supabase = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_ANON_KEY') ?? ''
      )
      
      await supabase
        .from('scout_performance.model_queries')
        .insert({
          query_text: (await req.json().catch(() => ({})))?.query?.substring(0, 1000) || 'unknown',
          execution_time_ms: executionTime,
          model_provider: 'mindsdb_cloud',
          result_count: 0,
          success: false,
          error_message: error.message,
          created_at: new Date().toISOString()
        })
        .select()
    } catch (logError) {
      console.error('Failed to log error metrics:', logError)
    }
    
    return new Response(JSON.stringify({
      status: 'error',
      message: 'MindsDB query failed',
      error: error.message
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
    })
  }
})