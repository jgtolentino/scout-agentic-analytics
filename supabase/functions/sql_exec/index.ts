/**
 * Scout v7.1 SQL Execution Edge Function
 * Executes validated SQL with audit logging and tenant isolation
 * Implements two-step NL→SQL pipeline (generate → validate → execute)
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface SQLExecutionRequest {
  naturalLanguageQuery: string
  generatedSQL: string
  queryIntent?: string
  agentPipeline?: string[]
  mcpServersUsed?: string[]
  superclaudeFlags?: string[]
  chartSpec?: any
}

interface SQLExecutionResponse {
  executionId: string
  status: 'success' | 'error' | 'timeout'
  rowCount: number
  executionTimeMs: number
  data: any[]
  error?: string
  metadata: {
    rlsEnforced: boolean
    rowLimitApplied: number
    schemaValidationPassed: boolean
    auditLogged: boolean
  }
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

    const requestData: SQLExecutionRequest = await req.json()
    const {
      naturalLanguageQuery,
      generatedSQL,
      queryIntent,
      agentPipeline = ['QueryAgent'],
      mcpServersUsed = ['sequential'],
      superclaudeFlags = [],
      chartSpec
    } = requestData

    // Validate required fields
    if (!naturalLanguageQuery || !generatedSQL) {
      throw new Error('Missing required fields: naturalLanguageQuery and generatedSQL')
    }

    console.log('Executing SQL:', {
      query: naturalLanguageQuery,
      sql: generatedSQL.substring(0, 200) + '...',
      intent: queryIntent,
      user: user.id
    })

    // Execute SQL using the secure fn_execute_sql function
    const { data: executionResult, error } = await supabase.rpc('fn_execute_sql', {
      _natural_language_query: naturalLanguageQuery,
      _generated_sql: generatedSQL,
      _query_intent: queryIntent || 'metric_query',
      _agent_pipeline: JSON.stringify({
        agents: agentPipeline,
        mcp_servers: mcpServersUsed,
        flags: superclaudeFlags,
        timestamp: new Date().toISOString()
      }),
      _chart_spec: chartSpec ? JSON.stringify(chartSpec) : null
    })

    if (error) {
      console.error('SQL Execution Error:', error)
      throw new Error(`Execution failed: ${error.message}`)
    }

    if (!executionResult || executionResult.length === 0) {
      throw new Error('No execution result returned')
    }

    const result = executionResult[0]
    
    // Parse the result data
    let parsedData: any[] = []
    if (result.result && result.status === 'success') {
      try {
        parsedData = typeof result.result === 'string' 
          ? JSON.parse(result.result) 
          : result.result
        
        // Ensure it's an array
        if (!Array.isArray(parsedData)) {
          parsedData = parsedData ? [parsedData] : []
        }
      } catch (parseError) {
        console.error('Failed to parse result data:', parseError)
        parsedData = []
      }
    }

    const response: SQLExecutionResponse = {
      executionId: result.execution_id,
      status: result.status,
      rowCount: result.row_count || 0,
      executionTimeMs: result.execution_time_ms || 0,
      data: parsedData,
      error: result.error_message || undefined,
      metadata: {
        rlsEnforced: true, // Always true in our implementation
        rowLimitApplied: getRoleRowLimit(user),
        schemaValidationPassed: result.status === 'success',
        auditLogged: true // fn_execute_sql always logs
      }
    }

    // Log successful execution for monitoring
    if (result.status === 'success') {
      console.log('SQL Execution Success:', {
        executionId: result.execution_id,
        rowCount: result.row_count,
        executionTimeMs: result.execution_time_ms,
        intent: queryIntent
      })
    } else {
      console.warn('SQL Execution Failed:', {
        executionId: result.execution_id,
        error: result.error_message,
        intent: queryIntent
      })
    }

    return new Response(
      JSON.stringify(response),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    console.error('SQL Exec Function Error:', error)
    
    // Create error response
    const errorResponse: SQLExecutionResponse = {
      executionId: crypto.randomUUID(),
      status: 'error',
      rowCount: 0,
      executionTimeMs: 0,
      data: [],
      error: error.message,
      metadata: {
        rlsEnforced: true,
        rowLimitApplied: 0,
        schemaValidationPassed: false,
        auditLogged: false
      }
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

function getRoleRowLimit(user: any): number {
  const role = user.app_metadata?.role || user.user_metadata?.role || 'analyst'
  
  switch (role) {
    case 'executive':
      return 5000
    case 'store_manager':
      return 20000
    case 'analyst':
      return 100000
    default:
      return 1000
  }
}