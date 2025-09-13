/**
 * Agent Orchestrator - Scout v7.1 Agentic Analytics Platform
 * Coordinates multi-agent workflows and manages the agentic analytics pipeline
 * 
 * Handles sequential and parallel agent execution, quality gates, error handling,
 * and performance optimization across the entire agent ecosystem.
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

// =============================================================================
// TYPES & INTERFACES
// =============================================================================

interface OrchestrationRequest {
  natural_language_query: string
  user_context: {
    tenant_id: string
    role: 'executive' | 'store_manager' | 'analyst'
    brand_access?: string[]
    location_access?: string[]
  }
  orchestration_config?: {
    flow_type?: 'standard' | 'enhanced' | 'competitive' | 'forecasting'
    enable_parallel_execution?: boolean
    skip_agents?: string[]
    quality_gates_enabled?: boolean
    max_execution_time_ms?: number
  }
  narrative_preferences?: {
    audience: 'executive' | 'analyst' | 'store_manager'
    tone: 'formal' | 'conversational' | 'urgent'
    length: 'brief' | 'standard' | 'detailed'
    language: 'en' | 'fil'
  }
}

interface OrchestrationResponse {
  execution_summary: {
    flow_type: string
    total_execution_time_ms: number
    agents_executed: string[]
    agents_skipped: string[]
    quality_gates_passed: number
    quality_gates_failed: number
    success_rate: number
  }
  query_results: {
    generated_sql: string
    query_results?: any
    confidence_score: number
  }
  retrieved_context: {
    chunks: any[]
    knowledge_graph_paths: any[]
    competitive_context: any[]
  }
  chart_specifications: {
    charts: any[]
    transformations: any[]
    accessibility_config: any
  }
  narrative_output: {
    executive_summary: any
    key_insights: any[]
    recommendations: any[]
    competitive_intelligence: any[]
  }
  metadata: {
    processing_chain: ProcessingStep[]
    error_recovery_actions: string[]
    performance_metrics: PerformanceMetrics
    validation_results: ValidationResult[]
  }
}

interface ProcessingStep {
  agent: string
  start_time: number
  end_time: number
  status: 'success' | 'failure' | 'partial' | 'skipped'
  input_size: number
  output_size: number
  error_message?: string
}

interface PerformanceMetrics {
  total_latency_ms: number
  agent_latencies: Record<string, number>
  parallel_efficiency: number
  cache_hit_ratio: number
  token_usage: number
  api_calls_made: number
}

interface ValidationResult {
  validator: string
  passed: boolean
  confidence: number
  issues: string[]
  recommendations: string[]
}

interface AgentExecutionContext {
  request_id: string
  tenant_id: string
  user_role: string
  execution_plan: ExecutionPlan
  shared_context: Record<string, any>
  error_recovery_stack: string[]
  performance_tracker: PerformanceTracker
}

interface ExecutionPlan {
  flow_type: string
  stages: ExecutionStage[]
  quality_gates: QualityGate[]
  fallback_strategies: FallbackStrategy[]
  timeout_limits: Record<string, number>
}

interface ExecutionStage {
  name: string
  agents: AgentConfig[]
  execution_mode: 'sequential' | 'parallel'
  dependencies: string[]
  quality_gate: string
  timeout_ms: number
}

interface AgentConfig {
  name: string
  endpoint: string
  timeout_ms: number
  retry_attempts: number
  quality_threshold: number
  fallback_agent?: string
}

interface QualityGate {
  name: string
  validators: QualityValidator[]
  pass_threshold: number
  failure_action: 'continue' | 'retry' | 'abort' | 'fallback'
}

interface QualityValidator {
  name: string
  type: 'sql_validation' | 'data_consistency' | 'narrative_coherence' | 'performance_threshold'
  parameters: Record<string, any>
  weight: number
}

interface FallbackStrategy {
  trigger_condition: string
  fallback_agents: string[]
  fallback_flow: string
  degraded_quality_acceptable: boolean
}

interface PerformanceTracker {
  start_time: number
  stage_times: Record<string, { start: number; end: number }>
  api_calls: number
  token_usage: number
  cache_hits: number
  cache_misses: number
}

// =============================================================================
// EXECUTION PLAN GENERATOR
// =============================================================================

class ExecutionPlanGenerator {
  static generatePlan(
    query: string,
    config: OrchestrationRequest['orchestration_config'],
    userContext: OrchestrationRequest['user_context']
  ): ExecutionPlan {
    
    const flowType = config?.flow_type || this.detectFlowType(query)
    const enableParallel = config?.enable_parallel_execution ?? true
    
    const plans = {
      standard: this.generateStandardPlan(enableParallel),
      enhanced: this.generateEnhancedPlan(enableParallel),
      competitive: this.generateCompetitivePlan(enableParallel),
      forecasting: this.generateForecastingPlan(enableParallel)
    }
    
    const plan = plans[flowType as keyof typeof plans] || plans.standard
    
    // Apply role-based optimizations
    return this.optimizeForRole(plan, userContext.role, config)
  }

  private static detectFlowType(query: string): string {
    const queryLower = query.toLowerCase()
    
    // Forecasting indicators
    if (queryLower.includes('forecast') || queryLower.includes('predict') || 
        queryLower.includes('projection') || queryLower.includes('future')) {
      return 'forecasting'
    }
    
    // Competitive analysis indicators
    if (queryLower.includes('competitor') || queryLower.includes('vs') || 
        queryLower.includes('compare') || queryLower.includes('market share')) {
      return 'competitive'
    }
    
    // Enhanced analysis indicators
    if (queryLower.includes('insight') || queryLower.includes('analysis') || 
        queryLower.includes('trend') || queryLower.includes('pattern')) {
      return 'enhanced'
    }
    
    return 'standard'
  }

  private static generateStandardPlan(enableParallel: boolean): ExecutionPlan {
    return {
      flow_type: 'standard',
      stages: [
        {
          name: 'query_generation',
          agents: [{ 
            name: 'QueryAgent', 
            endpoint: '/supabase/functions/v1/agents-query',
            timeout_ms: 5000,
            retry_attempts: 2,
            quality_threshold: 0.7
          }],
          execution_mode: 'sequential',
          dependencies: [],
          quality_gate: 'sql_validation',
          timeout_ms: 8000
        },
        {
          name: 'visualization',
          agents: [{ 
            name: 'ChartVisionAgent', 
            endpoint: '/supabase/functions/v1/agents-chart',
            timeout_ms: 8000,
            retry_attempts: 1,
            quality_threshold: 0.6
          }],
          execution_mode: 'sequential',
          dependencies: ['query_generation'],
          quality_gate: 'chart_validation',
          timeout_ms: 10000
        },
        {
          name: 'narrative_generation',
          agents: [{ 
            name: 'NarrativeAgent', 
            endpoint: '/supabase/functions/v1/agents-narrative',
            timeout_ms: 12000,
            retry_attempts: 1,
            quality_threshold: 0.6
          }],
          execution_mode: 'sequential',
          dependencies: ['query_generation', 'visualization'],
          quality_gate: 'narrative_validation',
          timeout_ms: 15000
        }
      ],
      quality_gates: [
        {
          name: 'sql_validation',
          validators: [
            { name: 'sql_syntax', type: 'sql_validation', parameters: {}, weight: 0.4 },
            { name: 'rls_compliance', type: 'sql_validation', parameters: {}, weight: 0.6 }
          ],
          pass_threshold: 0.8,
          failure_action: 'retry'
        },
        {
          name: 'chart_validation',
          validators: [
            { name: 'chart_type_validity', type: 'data_consistency', parameters: {}, weight: 0.5 },
            { name: 'accessibility_compliance', type: 'data_consistency', parameters: {}, weight: 0.5 }
          ],
          pass_threshold: 0.7,
          failure_action: 'continue'
        },
        {
          name: 'narrative_validation',
          validators: [
            { name: 'content_coherence', type: 'narrative_coherence', parameters: {}, weight: 0.6 },
            { name: 'insight_accuracy', type: 'narrative_coherence', parameters: {}, weight: 0.4 }
          ],
          pass_threshold: 0.6,
          failure_action: 'continue'
        }
      ],
      fallback_strategies: [
        {
          trigger_condition: 'agent_timeout',
          fallback_agents: ['fallback_sql_generator'],
          fallback_flow: 'minimal',
          degraded_quality_acceptable: true
        }
      ],
      timeout_limits: {
        total: 30000,
        per_stage: 15000,
        per_agent: 12000
      }
    }
  }

  private static generateEnhancedPlan(enableParallel: boolean): ExecutionPlan {
    const standardPlan = this.generateStandardPlan(enableParallel)
    
    // Add RetrieverAgent to the plan
    standardPlan.stages.splice(1, 0, {
      name: 'context_retrieval',
      agents: [{ 
        name: 'RetrieverAgent', 
        endpoint: '/supabase/functions/v1/agents-retriever',
        timeout_ms: 10000,
        retry_attempts: 1,
        quality_threshold: 0.5
      }],
      execution_mode: 'sequential',
      dependencies: ['query_generation'],
      quality_gate: 'context_validation',
      timeout_ms: 12000
    })
    
    // Add context validation quality gate
    standardPlan.quality_gates.push({
      name: 'context_validation',
      validators: [
        { name: 'relevance_score', type: 'data_consistency', parameters: { min_relevance: 0.5 }, weight: 0.7 },
        { name: 'context_coverage', type: 'data_consistency', parameters: { min_coverage: 0.3 }, weight: 0.3 }
      ],
      pass_threshold: 0.5,
      failure_action: 'continue'
    })
    
    // Update dependencies
    standardPlan.stages.find(s => s.name === 'visualization')!.dependencies.push('context_retrieval')
    standardPlan.stages.find(s => s.name === 'narrative_generation')!.dependencies.push('context_retrieval')
    
    standardPlan.flow_type = 'enhanced'
    standardPlan.timeout_limits.total = 45000
    
    return standardPlan
  }

  private static generateCompetitivePlan(enableParallel: boolean): ExecutionPlan {
    const enhancedPlan = this.generateEnhancedPlan(enableParallel)
    
    if (enableParallel) {
      // Make query and retrieval parallel
      const retrievalStage = enhancedPlan.stages.find(s => s.name === 'context_retrieval')!
      retrievalStage.dependencies = []
      retrievalStage.execution_mode = 'parallel'
      
      // Update downstream dependencies
      enhancedPlan.stages.find(s => s.name === 'visualization')!.dependencies = ['query_generation', 'context_retrieval']
    }
    
    enhancedPlan.flow_type = 'competitive'
    return enhancedPlan
  }

  private static generateForecastingPlan(enableParallel: boolean): ExecutionPlan {
    const standardPlan = this.generateStandardPlan(enableParallel)
    
    // Add MindsDB integration stage
    standardPlan.stages.splice(1, 0, {
      name: 'forecasting',
      agents: [{ 
        name: 'MindsDBAgent', 
        endpoint: '/supabase/functions/v1/mindsdb-proxy',
        timeout_ms: 15000,
        retry_attempts: 1,
        quality_threshold: 0.7,
        fallback_agent: 'QueryAgent' // Fallback to SQL seasonal analysis
      }],
      execution_mode: 'sequential',
      dependencies: ['query_generation'],
      quality_gate: 'forecasting_validation',
      timeout_ms: 18000
    })
    
    standardPlan.quality_gates.push({
      name: 'forecasting_validation',
      validators: [
        { name: 'prediction_confidence', type: 'data_consistency', parameters: { min_confidence: 0.6 }, weight: 0.8 },
        { name: 'model_accuracy', type: 'data_consistency', parameters: { min_accuracy: 0.7 }, weight: 0.2 }
      ],
      pass_threshold: 0.7,
      failure_action: 'fallback'
    })
    
    standardPlan.flow_type = 'forecasting'
    standardPlan.timeout_limits.total = 60000
    
    return standardPlan
  }

  private static optimizeForRole(
    plan: ExecutionPlan, 
    role: string, 
    config?: OrchestrationRequest['orchestration_config']
  ): ExecutionPlan {
    
    // Executive role optimizations
    if (role === 'executive') {
      // Reduce timeouts for faster response
      plan.timeout_limits.total *= 0.8
      plan.stages.forEach(stage => {
        stage.timeout_ms *= 0.8
        stage.agents.forEach(agent => {
          agent.timeout_ms *= 0.8
        })
      })
      
      // Lower quality thresholds for speed
      plan.stages.forEach(stage => {
        stage.agents.forEach(agent => {
          agent.quality_threshold *= 0.9
        })
      })
    }
    
    // Apply skip configuration
    if (config?.skip_agents?.length) {
      plan.stages = plan.stages.filter(stage => 
        !stage.agents.some(agent => config.skip_agents!.includes(agent.name))
      )
    }
    
    // Apply max execution time
    if (config?.max_execution_time_ms) {
      plan.timeout_limits.total = Math.min(plan.timeout_limits.total, config.max_execution_time_ms)
    }
    
    return plan
  }
}

// =============================================================================
// AGENT EXECUTOR
// =============================================================================

class AgentExecutor {
  private context: AgentExecutionContext

  constructor(context: AgentExecutionContext) {
    this.context = context
  }

  async executeStage(stage: ExecutionStage, sharedData: Record<string, any>): Promise<{
    results: Record<string, any>
    errors: Record<string, string>
    performance: Record<string, number>
  }> {
    
    const stageStartTime = Date.now()
    this.context.performance_tracker.stage_times[stage.name] = { start: stageStartTime, end: 0 }
    
    const results: Record<string, any> = {}
    const errors: Record<string, string> = {}
    const performance: Record<string, number> = {}
    
    if (stage.execution_mode === 'parallel') {
      // Execute agents in parallel
      const promises = stage.agents.map(agent => 
        this.executeAgent(agent, sharedData).catch(error => ({ 
          agent: agent.name, 
          error: error.message,
          result: null 
        }))
      )
      
      const outcomes = await Promise.allSettled(promises)
      
      outcomes.forEach((outcome, index) => {
        const agent = stage.agents[index]
        if (outcome.status === 'fulfilled' && outcome.value.result) {
          results[agent.name] = outcome.value.result
          performance[agent.name] = outcome.value.executionTime || 0
        } else {
          errors[agent.name] = outcome.value?.error || 'Unknown error'
          performance[agent.name] = 0
        }
      })
      
    } else {
      // Execute agents sequentially
      for (const agent of stage.agents) {
        try {
          const agentResult = await this.executeAgent(agent, { ...sharedData, ...results })
          results[agent.name] = agentResult.result
          performance[agent.name] = agentResult.executionTime
        } catch (error) {
          errors[agent.name] = error.message
          performance[agent.name] = 0
          
          // Stop sequential execution on critical errors
          if (!agent.fallback_agent) {
            break
          }
        }
      }
    }
    
    const stageEndTime = Date.now()
    this.context.performance_tracker.stage_times[stage.name].end = stageEndTime
    
    return { results, errors, performance }
  }

  private async executeAgent(agent: AgentConfig, input: Record<string, any>): Promise<{
    result: any
    executionTime: number
  }> {
    
    const startTime = Date.now()
    
    try {
      const response = await this.callAgentEndpoint(agent, input)
      const executionTime = Date.now() - startTime
      
      // Validate response quality
      if (this.validateAgentResponse(response, agent.quality_threshold)) {
        this.context.performance_tracker.api_calls++
        return { result: response, executionTime }
      } else {
        throw new Error(`Agent ${agent.name} response quality below threshold`)
      }
      
    } catch (error) {
      const executionTime = Date.now() - startTime
      
      // Try fallback agent if available
      if (agent.fallback_agent && agent.retry_attempts > 0) {
        return this.executeFallbackAgent(agent, input, error.message)
      }
      
      throw error
    }
  }

  private async callAgentEndpoint(agent: AgentConfig, input: Record<string, any>): Promise<any> {
    const requestBody = this.prepareAgentInput(agent.name, input)
    
    const response = await fetch(agent.endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${Deno.env.get('SUPABASE_ANON_KEY')}`,
      },
      body: JSON.stringify(requestBody),
      signal: AbortSignal.timeout(agent.timeout_ms)
    })
    
    if (!response.ok) {
      throw new Error(`Agent ${agent.name} HTTP ${response.status}: ${response.statusText}`)
    }
    
    return await response.json()
  }

  private prepareAgentInput(agentName: string, sharedData: Record<string, any>): any {
    const baseInput = {
      user_context: {
        tenant_id: this.context.tenant_id,
        role: this.context.user_role
      }
    }

    switch (agentName) {
      case 'QueryAgent':
        return {
          ...baseInput,
          natural_language_query: sharedData.natural_language_query,
          options: {
            include_explanation: true,
            language: sharedData.narrative_preferences?.language || 'en'
          }
        }
      
      case 'RetrieverAgent':
        return {
          ...baseInput,
          query_context: sharedData.natural_language_query,
          retrieval_depth: 'medium',
          search_scope: {
            time_range: {
              start: new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString(),
              end: new Date().toISOString()
            }
          }
        }
      
      case 'ChartVisionAgent':
        return {
          ...baseInput,
          query_results: sharedData.QueryAgent?.sql_results || {},
          visualization_intent: this.detectVisualizationIntent(sharedData.natural_language_query),
          audience_context: {
            executive_summary: this.context.user_role === 'executive',
            technical_detail: this.context.user_role === 'analyst'
          }
        }
      
      case 'NarrativeAgent':
        return {
          ...baseInput,
          data_insights: this.extractInsightsFromResults(sharedData),
          chart_context: sharedData.ChartVisionAgent?.chart_specifications || [],
          narrative_style: sharedData.narrative_preferences || {
            audience: this.context.user_role,
            tone: 'formal',
            length: 'standard',
            language: 'en'
          },
          business_context: {
            current_period: {
              start: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
              end: new Date().toISOString()
            }
          }
        }
      
      default:
        return { ...baseInput, ...sharedData }
    }
  }

  private detectVisualizationIntent(query: string): string {
    const queryLower = query.toLowerCase()
    
    if (queryLower.includes('trend') || queryLower.includes('over time')) return 'trend'
    if (queryLower.includes('compare') || queryLower.includes('vs')) return 'comparison'
    if (queryLower.includes('distribution') || queryLower.includes('breakdown')) return 'distribution'
    if (queryLower.includes('correlation') || queryLower.includes('relationship')) return 'correlation'
    if (queryLower.includes('composition') || queryLower.includes('share')) return 'composition'
    
    return 'comparison' // Default
  }

  private extractInsightsFromResults(sharedData: Record<string, any>): any[] {
    // Convert agent results into standardized insight format
    const insights: any[] = []
    
    // Extract insights from QueryAgent results
    if (sharedData.QueryAgent) {
      insights.push({
        type: 'performance',
        title: 'Query Analysis Results',
        description: `Generated SQL query with ${sharedData.QueryAgent.confidence_score} confidence`,
        confidence: sharedData.QueryAgent.confidence_score,
        impact_level: 'medium',
        data_source: 'query_agent',
        metrics: {
          primary_value: sharedData.QueryAgent.generated_sql.length,
          confidence: sharedData.QueryAgent.confidence_score
        },
        context: {
          time_period: 'current',
          entities: sharedData.QueryAgent.semantic_entities || [],
          dimensions: ['sql', 'confidence']
        }
      })
    }
    
    // Extract insights from RetrieverAgent results
    if (sharedData.RetrieverAgent?.retrieved_chunks) {
      const chunks = sharedData.RetrieverAgent.retrieved_chunks
      insights.push({
        type: 'correlation',
        title: 'Contextual Intelligence Retrieved',
        description: `Found ${chunks.length} relevant context chunks`,
        confidence: chunks.length > 0 ? 0.8 : 0.3,
        impact_level: chunks.length > 5 ? 'high' : 'medium',
        data_source: 'retriever_agent',
        metrics: {
          primary_value: chunks.length,
          secondary_value: chunks.reduce((sum: number, c: any) => sum + c.relevance_score, 0) / chunks.length
        },
        context: {
          time_period: 'current',
          entities: chunks.map((c: any) => c.metadata?.domain).filter(Boolean),
          dimensions: ['context', 'relevance']
        }
      })
    }
    
    return insights
  }

  private validateAgentResponse(response: any, threshold: number): boolean {
    if (!response) return false
    
    // Basic validation - check for required fields and confidence scores
    if (response.confidence_score !== undefined) {
      return response.confidence_score >= threshold
    }
    
    if (response.recommendation_metadata?.confidence_score !== undefined) {
      return response.recommendation_metadata.confidence_score >= threshold
    }
    
    if (response.narrative_metadata?.confidence_level !== undefined) {
      return response.narrative_metadata.confidence_level >= threshold
    }
    
    // If no confidence score available, basic validation passed
    return true
  }

  private async executeFallbackAgent(
    originalAgent: AgentConfig, 
    input: Record<string, any>, 
    originalError: string
  ): Promise<{ result: any; executionTime: number }> {
    
    this.context.error_recovery_stack.push(
      `${originalAgent.name} failed: ${originalError}, trying fallback: ${originalAgent.fallback_agent}`
    )
    
    // Simplified fallback execution
    const fallbackStartTime = Date.now()
    
    try {
      // For now, return a basic fallback result
      const fallbackResult = {
        fallback_used: true,
        original_agent: originalAgent.name,
        fallback_agent: originalAgent.fallback_agent,
        error_message: originalError,
        degraded_quality: true
      }
      
      return {
        result: fallbackResult,
        executionTime: Date.now() - fallbackStartTime
      }
      
    } catch (fallbackError) {
      throw new Error(`Both ${originalAgent.name} and fallback ${originalAgent.fallback_agent} failed`)
    }
  }
}

// =============================================================================
// QUALITY GATE VALIDATOR
// =============================================================================

class QualityGateValidator {
  static async validateStage(
    gate: QualityGate,
    stageResults: Record<string, any>,
    context: AgentExecutionContext
  ): Promise<ValidationResult> {
    
    const validatorResults: { score: number; issues: string[] }[] = []
    
    for (const validator of gate.validators) {
      const result = await this.runValidator(validator, stageResults, context)
      validatorResults.push(result)
    }
    
    // Calculate weighted average score
    const totalWeight = gate.validators.reduce((sum, v) => sum + v.weight, 0)
    const weightedScore = validatorResults.reduce((sum, result, index) => 
      sum + (result.score * gate.validators[index].weight), 0
    ) / totalWeight
    
    const passed = weightedScore >= gate.pass_threshold
    const allIssues = validatorResults.flatMap(r => r.issues)
    
    return {
      validator: gate.name,
      passed,
      confidence: weightedScore,
      issues: allIssues,
      recommendations: this.generateRecommendations(gate, allIssues, weightedScore)
    }
  }

  private static async runValidator(
    validator: QualityValidator,
    results: Record<string, any>,
    context: AgentExecutionContext
  ): Promise<{ score: number; issues: string[] }> {
    
    const issues: string[] = []
    let score = 1.0
    
    switch (validator.type) {
      case 'sql_validation':
        return this.validateSQL(results, validator.parameters)
      
      case 'data_consistency':
        return this.validateDataConsistency(results, validator.parameters)
      
      case 'narrative_coherence':
        return this.validateNarrativeCoherence(results, validator.parameters)
      
      case 'performance_threshold':
        return this.validatePerformance(context.performance_tracker, validator.parameters)
      
      default:
        issues.push(`Unknown validator type: ${validator.type}`)
        score = 0.5
    }
    
    return { score, issues }
  }

  private static validateSQL(
    results: Record<string, any>,
    parameters: Record<string, any>
  ): { score: number; issues: string[] } {
    
    const issues: string[] = []
    let score = 1.0
    
    const queryResult = results.QueryAgent
    if (!queryResult) {
      issues.push('No SQL query results found')
      return { score: 0, issues }
    }
    
    // Check for required RLS constraints
    if (!queryResult.generated_sql?.includes("auth.jwt() ->> 'tenant_id'")) {
      issues.push('Missing Row Level Security (RLS) constraints')
      score -= 0.4
    }
    
    // Check for role-based limits
    if (!queryResult.generated_sql?.includes('LIMIT')) {
      issues.push('Missing role-based row limits')
      score -= 0.3
    }
    
    // Check confidence score
    if (queryResult.confidence_score < 0.7) {
      issues.push(`Low confidence score: ${queryResult.confidence_score}`)
      score -= 0.2
    }
    
    // Check for validation errors
    if (queryResult.validation_errors?.length > 0) {
      issues.push(...queryResult.validation_errors)
      score -= 0.3
    }
    
    return { score: Math.max(0, score), issues }
  }

  private static validateDataConsistency(
    results: Record<string, any>,
    parameters: Record<string, any>
  ): { score: number; issues: string[] } {
    
    const issues: string[] = []
    let score = 1.0
    
    // Validate retriever results if present
    if (results.RetrieverAgent) {
      const chunks = results.RetrieverAgent.retrieved_chunks || []
      const minRelevance = parameters.min_relevance || 0.5
      const minCoverage = parameters.min_coverage || 0.3
      
      const relevantChunks = chunks.filter((c: any) => c.relevance_score >= minRelevance)
      const coverage = relevantChunks.length / Math.max(chunks.length, 1)
      
      if (coverage < minCoverage) {
        issues.push(`Low context coverage: ${(coverage * 100).toFixed(1)}%`)
        score -= 0.3
      }
    }
    
    // Validate chart specifications if present
    if (results.ChartVisionAgent) {
      const charts = results.ChartVisionAgent.chart_specifications || []
      if (charts.length === 0) {
        issues.push('No chart specifications generated')
        score -= 0.5
      } else {
        // Check accessibility compliance
        const accessibilityConfig = results.ChartVisionAgent.accessibility_metadata
        if (!accessibilityConfig?.wcag_level) {
          issues.push('Missing accessibility configuration')
          score -= 0.2
        }
      }
    }
    
    return { score: Math.max(0, score), issues }
  }

  private static validateNarrativeCoherence(
    results: Record<string, any>,
    parameters: Record<string, any>
  ): { score: number; issues: string[] } {
    
    const issues: string[] = []
    let score = 1.0
    
    const narrativeResult = results.NarrativeAgent
    if (!narrativeResult) {
      issues.push('No narrative results found')
      return { score: 0, issues }
    }
    
    // Check executive summary quality
    const summary = narrativeResult.executive_summary
    if (!summary || summary.content.length < 50) {
      issues.push('Executive summary too short or missing')
      score -= 0.3
    }
    
    // Check insights quality
    const insights = narrativeResult.key_insights || []
    if (insights.length === 0) {
      issues.push('No key insights generated')
      score -= 0.3
    }
    
    // Check recommendations quality
    const recommendations = narrativeResult.actionable_recommendations || []
    if (recommendations.length === 0) {
      issues.push('No actionable recommendations generated')
      score -= 0.2
    }
    
    // Check narrative metadata confidence
    if (narrativeResult.narrative_metadata?.confidence_level < 0.6) {
      issues.push(`Low narrative confidence: ${narrativeResult.narrative_metadata?.confidence_level}`)
      score -= 0.2
    }
    
    return { score: Math.max(0, score), issues }
  }

  private static validatePerformance(
    tracker: PerformanceTracker,
    parameters: Record<string, any>
  ): { score: number; issues: string[] } {
    
    const issues: string[] = []
    let score = 1.0
    
    const maxLatency = parameters.max_latency_ms || 45000
    const currentLatency = Date.now() - tracker.start_time
    
    if (currentLatency > maxLatency) {
      issues.push(`Execution time exceeded threshold: ${currentLatency}ms > ${maxLatency}ms`)
      score -= 0.4
    }
    
    // Check individual stage performance
    Object.entries(tracker.stage_times).forEach(([stage, times]) => {
      const stageLatency = times.end - times.start
      const stageThreshold = parameters[`${stage}_max_ms`] || 15000
      
      if (stageLatency > stageThreshold) {
        issues.push(`Stage ${stage} exceeded threshold: ${stageLatency}ms > ${stageThreshold}ms`)
        score -= 0.1
      }
    })
    
    return { score: Math.max(0, score), issues }
  }

  private static generateRecommendations(
    gate: QualityGate,
    issues: string[],
    score: number
  ): string[] {
    
    const recommendations: string[] = []
    
    if (score < gate.pass_threshold) {
      recommendations.push(`Quality score ${score.toFixed(2)} below threshold ${gate.pass_threshold}`)
    }
    
    if (issues.length > 0) {
      recommendations.push('Review and address validation issues')
    }
    
    if (gate.failure_action === 'retry' && score < gate.pass_threshold) {
      recommendations.push('Consider retrying with adjusted parameters')
    }
    
    if (gate.failure_action === 'fallback' && score < gate.pass_threshold) {
      recommendations.push('Execute fallback strategy to maintain service quality')
    }
    
    return recommendations
  }
}

// =============================================================================
// MAIN ORCHESTRATOR
// =============================================================================

class AgentOrchestrator {
  static async process(request: OrchestrationRequest): Promise<OrchestrationResponse> {
    const startTime = Date.now()
    const requestId = crypto.randomUUID()
    
    // Initialize execution context
    const executionPlan = ExecutionPlanGenerator.generatePlan(
      request.natural_language_query,
      request.orchestration_config,
      request.user_context
    )
    
    const context: AgentExecutionContext = {
      request_id: requestId,
      tenant_id: request.user_context.tenant_id,
      user_role: request.user_context.role,
      execution_plan: executionPlan,
      shared_context: {
        natural_language_query: request.natural_language_query,
        narrative_preferences: request.narrative_preferences
      },
      error_recovery_stack: [],
      performance_tracker: {
        start_time: startTime,
        stage_times: {},
        api_calls: 0,
        token_usage: 0,
        cache_hits: 0,
        cache_misses: 0
      }
    }
    
    const executor = new AgentExecutor(context)
    const processingSteps: ProcessingStep[] = []
    const validationResults: ValidationResult[] = []
    
    let agentsExecuted: string[] = []
    let agentsSkipped: string[] = []
    let qualityGatesPassed = 0
    let qualityGatesFailed = 0
    let aggregatedResults: Record<string, any> = { ...context.shared_context }
    
    // Execute stages sequentially
    for (const stage of executionPlan.stages) {
      const stageStartTime = Date.now()
      
      try {
        // Check stage dependencies
        const dependenciesMet = stage.dependencies.every(dep => 
          agentsExecuted.includes(dep) || aggregatedResults[dep]
        )
        
        if (!dependenciesMet) {
          // Skip stage due to unmet dependencies
          stage.agents.forEach(agent => agentsSkipped.push(agent.name))
          continue
        }
        
        // Execute stage
        const stageResults = await executor.executeStage(stage, aggregatedResults)
        
        // Record processing steps
        Object.entries(stageResults.results).forEach(([agentName, result]) => {
          processingSteps.push({
            agent: agentName,
            start_time: stageStartTime,
            end_time: Date.now(),
            status: 'success',
            input_size: JSON.stringify(aggregatedResults).length,
            output_size: JSON.stringify(result).length
          })
          agentsExecuted.push(agentName)
        })
        
        Object.entries(stageResults.errors).forEach(([agentName, error]) => {
          processingSteps.push({
            agent: agentName,
            start_time: stageStartTime,
            end_time: Date.now(),
            status: 'failure',
            input_size: JSON.stringify(aggregatedResults).length,
            output_size: 0,
            error_message: error
          })
          agentsSkipped.push(agentName)
        })
        
        // Merge results
        aggregatedResults = { ...aggregatedResults, ...stageResults.results }
        
        // Run quality gate validation if enabled
        if (request.orchestration_config?.quality_gates_enabled !== false) {
          const qualityGate = executionPlan.quality_gates.find(qg => qg.name === stage.quality_gate)
          if (qualityGate) {
            const validationResult = await QualityGateValidator.validateStage(
              qualityGate,
              stageResults.results,
              context
            )
            
            validationResults.push(validationResult)
            
            if (validationResult.passed) {
              qualityGatesPassed++
            } else {
              qualityGatesFailed++
              
              // Handle quality gate failure
              if (qualityGate.failure_action === 'abort') {
                break
              }
            }
          }
        }
        
      } catch (error) {
        // Stage execution failed
        stage.agents.forEach(agent => {
          processingSteps.push({
            agent: agent.name,
            start_time: stageStartTime,
            end_time: Date.now(),
            status: 'failure',
            input_size: 0,
            output_size: 0,
            error_message: error.message
          })
          agentsSkipped.push(agent.name)
        })
      }
    }
    
    const totalExecutionTime = Date.now() - startTime
    const successRate = agentsExecuted.length / (agentsExecuted.length + agentsSkipped.length)
    
    return {
      execution_summary: {
        flow_type: executionPlan.flow_type,
        total_execution_time_ms: totalExecutionTime,
        agents_executed: agentsExecuted,
        agents_skipped: agentsSkipped,
        quality_gates_passed: qualityGatesPassed,
        quality_gates_failed: qualityGatesFailed,
        success_rate: successRate
      },
      query_results: {
        generated_sql: aggregatedResults.QueryAgent?.generated_sql || '',
        query_results: aggregatedResults.QueryAgent?.sql_results,
        confidence_score: aggregatedResults.QueryAgent?.confidence_score || 0
      },
      retrieved_context: {
        chunks: aggregatedResults.RetrieverAgent?.retrieved_chunks || [],
        knowledge_graph_paths: aggregatedResults.RetrieverAgent?.knowledge_graph_paths || [],
        competitive_context: aggregatedResults.RetrieverAgent?.competitive_context || []
      },
      chart_specifications: {
        charts: aggregatedResults.ChartVisionAgent?.chart_specifications || [],
        transformations: aggregatedResults.ChartVisionAgent?.data_transformations || [],
        accessibility_config: aggregatedResults.ChartVisionAgent?.accessibility_metadata || {}
      },
      narrative_output: {
        executive_summary: aggregatedResults.NarrativeAgent?.executive_summary || {},
        key_insights: aggregatedResults.NarrativeAgent?.key_insights || [],
        recommendations: aggregatedResults.NarrativeAgent?.actionable_recommendations || [],
        competitive_intelligence: aggregatedResults.NarrativeAgent?.competitive_intelligence || []
      },
      metadata: {
        processing_chain: processingSteps,
        error_recovery_actions: context.error_recovery_stack,
        performance_metrics: {
          total_latency_ms: totalExecutionTime,
          agent_latencies: this.calculateAgentLatencies(processingSteps),
          parallel_efficiency: this.calculateParallelEfficiency(processingSteps, executionPlan),
          cache_hit_ratio: context.performance_tracker.cache_hits / 
            Math.max(context.performance_tracker.cache_hits + context.performance_tracker.cache_misses, 1),
          token_usage: context.performance_tracker.token_usage,
          api_calls_made: context.performance_tracker.api_calls
        },
        validation_results: validationResults
      }
    }
  }

  private static calculateAgentLatencies(steps: ProcessingStep[]): Record<string, number> {
    const latencies: Record<string, number> = {}
    
    steps.forEach(step => {
      latencies[step.agent] = step.end_time - step.start_time
    })
    
    return latencies
  }

  private static calculateParallelEfficiency(
    steps: ProcessingStep[],
    plan: ExecutionPlan
  ): number {
    
    // Simple efficiency calculation: ratio of parallel to total execution time
    const parallelStages = plan.stages.filter(s => s.execution_mode === 'parallel')
    const totalStages = plan.stages.length
    
    return parallelStages.length / Math.max(totalStages, 1)
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
    const request: OrchestrationRequest = await req.json()
    
    // Validate required fields
    if (!request.natural_language_query || !request.user_context?.tenant_id || !request.user_context?.role) {
      return new Response(JSON.stringify({ 
        error: 'Missing required fields: natural_language_query, user_context.tenant_id, user_context.role' 
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    const response = await AgentOrchestrator.process(request)
    
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