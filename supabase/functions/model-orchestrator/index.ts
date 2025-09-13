// Model Orchestration Service
// Manages AI model selection, fallback chains, and cost optimization
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

interface ModelRequest {
  task: 'creative_scoring' | 'multimodal_analysis' | 'text_analysis' | 'visual_analysis';
  asset_type: 'video' | 'image' | 'audio';
  complexity: 'low' | 'medium' | 'high' | 'critical';
  budget_preference?: 'cost_optimized' | 'balanced' | 'performance';
  priority?: 'speed' | 'accuracy' | 'cost';
  input_data: any;
  context?: {
    brand: string;
    market: string;
    campaign_type: string;
  };
}

interface ModelProvider {
  name: string;
  type: 'primary' | 'secondary' | 'fallback';
  cost_per_token: number;
  avg_response_time_ms: number;
  accuracy_score: number;
  availability: number;
  supported_tasks: string[];
  supported_asset_types: string[];
}

interface ModelResponse {
  provider_used: string;
  response_data: any;
  processing_time_ms: number;
  cost_estimate: number;
  confidence_score: number;
  fallback_chain?: string[];
  error?: string;
}

// Model provider configurations
const MODEL_PROVIDERS: ModelProvider[] = [
  // Primary Models - Specialized
  {
    name: 'llava-critic',
    type: 'primary',
    cost_per_token: 0.001,
    avg_response_time_ms: 2500,
    accuracy_score: 0.92,
    availability: 0.95,
    supported_tasks: ['visual_analysis', 'creative_scoring'],
    supported_asset_types: ['image', 'video']
  },
  {
    name: 'q-align',
    type: 'primary', 
    cost_per_token: 0.0015,
    avg_response_time_ms: 3000,
    accuracy_score: 0.94,
    availability: 0.93,
    supported_tasks: ['visual_analysis', 'multimodal_analysis'],
    supported_asset_types: ['image', 'video', 'audio']
  },
  {
    name: 'score2instruct',
    type: 'primary',
    cost_per_token: 0.002,
    avg_response_time_ms: 2800,
    accuracy_score: 0.93,
    availability: 0.91,
    supported_tasks: ['creative_scoring', 'visual_analysis'],
    supported_asset_types: ['video', 'image']
  },
  
  // Secondary Models - General Purpose High Quality
  {
    name: 'claude-opus',
    type: 'secondary',
    cost_per_token: 0.015,
    avg_response_time_ms: 4000,
    accuracy_score: 0.96,
    availability: 0.98,
    supported_tasks: ['creative_scoring', 'multimodal_analysis', 'text_analysis', 'visual_analysis'],
    supported_asset_types: ['video', 'image', 'audio']
  },
  {
    name: 'nova-pro',
    type: 'secondary',
    cost_per_token: 0.008,
    avg_response_time_ms: 3500,
    accuracy_score: 0.93,
    availability: 0.96,
    supported_tasks: ['multimodal_analysis', 'creative_scoring'],
    supported_asset_types: ['image', 'video', 'audio']
  },
  
  // Fallback Models - Reliable & Cost-Effective
  {
    name: 'gpt-4o',
    type: 'fallback',
    cost_per_token: 0.01,
    avg_response_time_ms: 5000,
    accuracy_score: 0.95,
    availability: 0.99,
    supported_tasks: ['text_analysis', 'creative_scoring', 'visual_analysis'],
    supported_asset_types: ['image', 'video', 'audio']
  },
  {
    name: 'gemini-1.5-pro',
    type: 'fallback',
    cost_per_token: 0.007,
    avg_response_time_ms: 4500,
    accuracy_score: 0.91,
    availability: 0.97,
    supported_tasks: ['multimodal_analysis', 'text_analysis'],
    supported_asset_types: ['video', 'image', 'audio']
  }
];

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { 
      status: 405, 
      headers: corsHeaders 
    });
  }

  try {
    const requestData: ModelRequest = await req.json();
    
    if (!requestData.task || !requestData.asset_type || !requestData.input_data) {
      return new Response(JSON.stringify({ 
        error: 'task, asset_type, and input_data are required' 
      }), { 
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    console.log(`Model orchestration request: ${requestData.task} for ${requestData.asset_type}`);
    const startTime = Date.now();

    // Select optimal model based on request parameters
    const modelChain = selectModelChain(requestData);
    
    // Attempt processing through model chain
    const response = await processWithModelChain(requestData, modelChain);
    
    const processingTime = Date.now() - startTime;
    
    // Log usage for optimization
    await logModelUsage({
      task: requestData.task,
      asset_type: requestData.asset_type,
      provider_used: response.provider_used,
      processing_time_ms: processingTime,
      cost_estimate: response.cost_estimate,
      success: !response.error
    });

    console.log(`Model orchestration completed: ${response.provider_used} in ${processingTime}ms`);

    return new Response(JSON.stringify({
      success: !response.error,
      model_response: response,
      processing_time_ms: processingTime
    }), {
      status: response.error ? 500 : 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('Model orchestration error:', error);
    
    return new Response(JSON.stringify({ 
      error: 'Model orchestration failed',
      details: error instanceof Error ? error.message : String(error)
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});

function selectModelChain(request: ModelRequest): ModelProvider[] {
  // Filter models by capability
  const capableModels = MODEL_PROVIDERS.filter(model =>
    model.supported_tasks.includes(request.task) &&
    model.supported_asset_types.includes(request.asset_type)
  );

  // Define selection strategy
  let strategy: 'cost_optimized' | 'performance' | 'balanced' = 'balanced';
  
  if (request.budget_preference) {
    switch (request.budget_preference) {
      case 'cost_optimized':
        strategy = 'cost_optimized';
        break;
      case 'performance':
        strategy = 'performance';
        break;
      default:
        strategy = 'balanced';
    }
  }

  // Sort models based on strategy
  let sortedModels: ModelProvider[];
  
  switch (strategy) {
    case 'cost_optimized':
      sortedModels = capableModels.sort((a, b) => a.cost_per_token - b.cost_per_token);
      break;
    case 'performance':
      sortedModels = capableModels.sort((a, b) => b.accuracy_score - a.accuracy_score);
      break;
    default: // balanced
      sortedModels = capableModels.sort((a, b) => {
        const scoreA = (a.accuracy_score * 0.4) + (a.availability * 0.3) + ((1 - a.cost_per_token/0.02) * 0.3);
        const scoreB = (b.accuracy_score * 0.4) + (b.availability * 0.3) + ((1 - b.cost_per_token/0.02) * 0.3);
        return scoreB - scoreA;
      });
  }

  // Apply complexity-based adjustments
  if (request.complexity === 'critical' || request.complexity === 'high') {
    // Prioritize accuracy for complex tasks
    sortedModels = sortedModels.sort((a, b) => b.accuracy_score - a.accuracy_score);
  } else if (request.complexity === 'low') {
    // Cost optimize for simple tasks
    sortedModels = sortedModels.sort((a, b) => a.cost_per_token - b.cost_per_token);
  }

  // Ensure we have a good fallback chain
  const primaryModels = sortedModels.filter(m => m.type === 'primary').slice(0, 2);
  const secondaryModels = sortedModels.filter(m => m.type === 'secondary').slice(0, 1);
  const fallbackModels = sortedModels.filter(m => m.type === 'fallback').slice(0, 1);

  return [...primaryModels, ...secondaryModels, ...fallbackModels];
}

async function processWithModelChain(
  request: ModelRequest, 
  modelChain: ModelProvider[]
): Promise<ModelResponse> {
  const fallbackChain: string[] = [];
  let lastError: Error | null = null;

  for (const model of modelChain) {
    try {
      console.log(`Attempting processing with ${model.name}...`);
      
      const startTime = Date.now();
      const result = await callModelProvider(model, request);
      const processingTime = Date.now() - startTime;

      // Calculate cost estimate
      const tokenEstimate = estimateTokens(request.input_data);
      const costEstimate = tokenEstimate * model.cost_per_token;

      return {
        provider_used: model.name,
        response_data: result,
        processing_time_ms: processingTime,
        cost_estimate: Math.round(costEstimate * 10000) / 10000, // 4 decimal places
        confidence_score: result.confidence || 0.9,
        fallback_chain: fallbackChain.length > 0 ? fallbackChain : undefined
      };

    } catch (error) {
      console.warn(`Model ${model.name} failed:`, error);
      fallbackChain.push(model.name);
      lastError = error instanceof Error ? error : new Error(String(error));
      
      // Continue to next model in chain
      continue;
    }
  }

  // All models in chain failed
  return {
    provider_used: 'none',
    response_data: null,
    processing_time_ms: 0,
    cost_estimate: 0,
    confidence_score: 0,
    fallback_chain,
    error: lastError?.message || 'All models in chain failed'
  };
}

async function callModelProvider(model: ModelProvider, request: ModelRequest): Promise<any> {
  // Simulate model calls with realistic behavior
  // In production, these would be actual API calls to respective services
  
  // Simulate network latency and processing time
  const processingTime = model.avg_response_time_ms + (Math.random() * 1000 - 500);
  await new Promise(resolve => setTimeout(resolve, Math.max(100, processingTime)));

  // Simulate occasional failures based on availability
  if (Math.random() > model.availability) {
    throw new Error(`${model.name} temporarily unavailable`);
  }

  // Generate model-specific response based on task
  switch (request.task) {
    case 'creative_scoring':
      return generateCreativeScoringResponse(model, request);
    case 'multimodal_analysis':
      return generateMultimodalAnalysisResponse(model, request);
    case 'visual_analysis':
      return generateVisualAnalysisResponse(model, request);
    case 'text_analysis':
      return generateTextAnalysisResponse(model, request);
    default:
      throw new Error(`Unsupported task: ${request.task}`);
  }
}

function generateCreativeScoringResponse(model: ModelProvider, request: ModelRequest): any {
  // Model-specific scoring approaches
  const baseScore = 7.2 + (Math.random() * 2.5); // 7.2-9.7 range
  const confidence = model.accuracy_score + (Math.random() * 0.1 - 0.05);
  
  let explanation = '';
  switch (model.name) {
    case 'llava-critic':
      explanation = 'Visual-first analysis with emphasis on composition, color psychology, and brand visibility';
      break;
    case 'claude-opus':
      explanation = 'Comprehensive multimodal analysis considering cultural context, emotional resonance, and strategic alignment';
      break;
    case 'nova-pro':
      explanation = 'AI-powered creative assessment focusing on audience engagement and performance prediction';
      break;
    default:
      explanation = 'Creative effectiveness evaluation based on industry best practices and audience research';
  }

  return {
    overall_score: Math.round(baseScore * 10) / 10,
    confidence,
    explanation,
    model_insights: {
      strengths: ['strong visual impact', 'clear messaging', 'brand integration'],
      improvements: ['enhance cultural relevance', 'strengthen call-to-action'],
      predicted_performance: confidence > 0.9 ? 'high' : 'medium'
    }
  };
}

function generateMultimodalAnalysisResponse(model: ModelProvider, request: ModelRequest): any {
  const confidence = model.accuracy_score + (Math.random() * 0.1 - 0.05);
  
  return {
    visual_elements: {
      detected_objects: Math.floor(Math.random() * 5) + 2,
      text_regions: Math.floor(Math.random() * 3) + 1,
      brand_presence_score: Math.random() * 0.3 + 0.7
    },
    audio_analysis: request.asset_type === 'video' || request.asset_type === 'audio' ? {
      sentiment: 'positive',
      clarity_score: Math.random() * 0.3 + 0.7,
      brand_mentions: Math.floor(Math.random() * 3)
    } : null,
    semantic_understanding: {
      key_themes: ['innovation', 'quality', 'lifestyle'],
      emotional_tone: 'aspirational',
      cultural_relevance: Math.random() * 0.4 + 0.6
    },
    confidence
  };
}

function generateVisualAnalysisResponse(model: ModelProvider, request: ModelRequest): any {
  const confidence = model.accuracy_score + (Math.random() * 0.1 - 0.05);
  
  return {
    composition_analysis: {
      rule_of_thirds: Math.random() > 0.3,
      visual_balance: Math.random() * 0.4 + 0.6,
      focal_points: Math.floor(Math.random() * 3) + 1
    },
    color_analysis: {
      dominant_colors: ['#FF6B35', '#004E89', '#FFFFFF'],
      color_harmony: Math.random() * 0.3 + 0.7,
      brand_consistency: Math.random() * 0.4 + 0.6
    },
    brand_elements: {
      logo_visibility: Math.random() * 0.4 + 0.6,
      text_legibility: Math.random() * 0.3 + 0.7,
      brand_placement: 'prominent'
    },
    confidence
  };
}

function generateTextAnalysisResponse(model: ModelProvider, request: ModelRequest): any {
  const confidence = model.accuracy_score + (Math.random() * 0.1 - 0.05);
  
  return {
    readability: {
      grade_level: Math.floor(Math.random() * 4) + 8,
      clarity_score: Math.random() * 0.3 + 0.7,
      word_count: Math.floor(Math.random() * 100) + 50
    },
    sentiment: {
      overall: 'positive',
      confidence: Math.random() * 0.3 + 0.7,
      emotional_intensity: Math.random() * 0.5 + 0.5
    },
    linguistic_features: {
      active_voice: Math.random() > 0.4,
      call_to_action_strength: Math.random() * 0.4 + 0.6,
      brand_voice_alignment: Math.random() * 0.3 + 0.7
    },
    confidence
  };
}

function estimateTokens(inputData: any): number {
  // Rough token estimation for cost calculation
  const jsonString = JSON.stringify(inputData);
  return Math.floor(jsonString.length / 4); // Approximation: 4 chars per token
}

async function logModelUsage(usage: {
  task: string;
  asset_type: string;
  provider_used: string;
  processing_time_ms: number;
  cost_estimate: number;
  success: boolean;
}): Promise<void> {
  try {
    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    await supa.from('ces.model_usage_logs').insert({
      task_type: usage.task,
      asset_type: usage.asset_type,
      model_provider: usage.provider_used,
      processing_time_ms: usage.processing_time_ms,
      cost_estimate: usage.cost_estimate,
      success: usage.success,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.warn('Failed to log model usage:', error);
    // Don't throw - logging failure shouldn't break the main flow
  }
}