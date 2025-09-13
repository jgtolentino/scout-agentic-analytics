// RAG-Powered Creative Insights Retrieval
// Retrieves relevant creative insights and recommendations using semantic search
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

interface InsightRequest {
  query: string;
  context?: {
    brand?: string;
    market?: string;
    category?: string;
    campaign_goals?: string[];
    current_performance?: {
      engagement_rate?: number;
      brand_recall?: number;
      conversion_rate?: number;
      roi?: number;
    };
  };
  insight_types?: ('pattern' | 'optimization' | 'benchmark' | 'prediction')[];
  categories?: ('visual' | 'emotional' | 'brand' | 'performance')[];
  max_results?: number;
  include_similar_campaigns?: boolean;
}

interface InsightResponse {
  insights: CreativeInsight[];
  similar_campaigns?: SimilarCampaign[];
  performance_gap_analysis?: PerformanceGapAnalysis;
  recommendations: string[];
  query_interpretation: string;
}

interface CreativeInsight {
  id: string;
  title: string;
  description: string;
  insight_type: string;
  category: string;
  confidence: number;
  success_rate: number;
  times_applied: number;
  insight_data: any;
  relevance_score: number;
}

interface SimilarCampaign {
  asset_id: string;
  campaign_id: string;
  similarity_score: number;
  business_outcomes: any;
  creative_summary: string;
}

interface PerformanceGapAnalysis {
  current_vs_benchmark: {
    engagement_gap: number;
    recall_gap: number;
    conversion_gap: number;
    roi_gap: number;
  };
  improvement_potential: number;
  priority_areas: string[];
}

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
    const requestData: InsightRequest = await req.json();
    
    if (!requestData.query) {
      return new Response(JSON.stringify({ 
        error: 'query is required' 
      }), { 
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    console.log(`RAG insights request: "${requestData.query}"`);

    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Generate query embedding for semantic search
    const queryEmbedding = await generateQueryEmbedding(requestData.query);

    // Retrieve relevant insights using vector similarity
    const insights = await retrieveRelevantInsights(
      supa,
      queryEmbedding,
      requestData
    );

    // Find similar campaigns if requested
    let similarCampaigns: SimilarCampaign[] = [];
    if (requestData.include_similar_campaigns) {
      similarCampaigns = await findSimilarCampaigns(
        supa,
        queryEmbedding,
        requestData.context
      );
    }

    // Perform performance gap analysis if current performance provided
    let performanceGapAnalysis: PerformanceGapAnalysis | undefined;
    if (requestData.context?.current_performance) {
      performanceGapAnalysis = await analyzePerformanceGaps(
        supa,
        requestData.context.current_performance,
        requestData.context
      );
    }

    // Generate contextual recommendations
    const recommendations = await generateContextualRecommendations(
      insights,
      similarCampaigns,
      performanceGapAnalysis,
      requestData.context
    );

    // Interpret query intent for transparency
    const queryInterpretation = interpretQueryIntent(requestData.query, requestData.context);

    console.log(`Retrieved ${insights.length} insights for query: "${requestData.query}"`);

    const response: InsightResponse = {
      insights: insights.slice(0, requestData.max_results || 10),
      similar_campaigns: similarCampaigns.slice(0, 5),
      performance_gap_analysis: performanceGapAnalysis,
      recommendations,
      query_interpretation: queryInterpretation
    };

    return new Response(JSON.stringify({
      success: true,
      rag_insights: response,
      metadata: {
        insights_found: insights.length,
        similar_campaigns_found: similarCampaigns.length,
        query_processing_time_ms: Date.now() - Date.now(), // Placeholder
        embedding_model: 'openai-ada-v2'
      }
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('RAG insights error:', error);
    
    return new Response(JSON.stringify({ 
      error: 'RAG insights retrieval failed',
      details: error instanceof Error ? error.message : String(error)
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});

async function generateQueryEmbedding(query: string): Promise<number[]> {
  // In production: call OpenAI embeddings API
  // For development: simulate embedding
  const dimensions = 1536;
  const vector = Array(dimensions).fill(0).map(() => Math.random() - 0.5);
  const magnitude = Math.sqrt(vector.reduce((sum, val) => sum + val * val, 0));
  return vector.map(val => val / magnitude);
}

async function retrieveRelevantInsights(
  supa: any,
  queryEmbedding: number[],
  request: InsightRequest
): Promise<CreativeInsight[]> {
  try {
    // Build filter conditions
    const insightTypes = request.insight_types || ['pattern', 'optimization', 'benchmark', 'prediction'];
    const categories = request.categories || ['visual', 'emotional', 'brand', 'performance'];

    // In production: use vector similarity search
    // SELECT *, (1 - (insight_embedding <=> $1)) AS relevance_score
    // FROM ces.creative_insights
    // WHERE insight_type = ANY($2) AND category = ANY($3)
    // AND (applicable_brands = '{}' OR $4 = ANY(applicable_brands))
    // ORDER BY relevance_score DESC LIMIT $5

    // Simulated results for development
    const mockInsights: CreativeInsight[] = [
      {
        id: 'insight-001',
        title: 'Emotional storytelling drives 23% higher brand recall',
        description: 'Campaigns featuring aspirational narratives with relatable protagonists achieve significantly higher brand recall scores compared to product-focused approaches.',
        insight_type: 'pattern',
        category: 'emotional',
        confidence: 0.89,
        success_rate: 0.76,
        times_applied: 156,
        insight_data: {
          lift_percentage: 0.23,
          sample_size: 156,
          key_elements: ['relatable_protagonist', 'growth_journey', 'authentic_challenge'],
          optimal_duration: '30-45 seconds'
        },
        relevance_score: 0.87
      },
      {
        id: 'insight-002',
        title: 'Logo placement in final 5 seconds increases conversion by 18%',
        description: 'Strategic logo placement timing significantly impacts conversion rates, with final-frame positioning outperforming early placement.',
        insight_type: 'optimization',
        category: 'brand',
        confidence: 0.84,
        success_rate: 0.82,
        times_applied: 89,
        insight_data: {
          conversion_lift: 0.18,
          optimal_timing: 'final_5_seconds',
          brand_visibility_score: 0.75,
          testing_campaigns: 89
        },
        relevance_score: 0.82
      },
      {
        id: 'insight-003',
        title: 'Cultural authenticity increases engagement by 34% in Philippines',
        description: 'Creative assets that incorporate authentic Filipino cultural elements see significantly higher engagement rates in the Philippine market.',
        insight_type: 'pattern',
        category: 'performance',
        confidence: 0.91,
        success_rate: 0.88,
        times_applied: 67,
        insight_data: {
          engagement_lift: 0.34,
          key_cultural_elements: ['family_values', 'local_language', 'cultural_celebrations'],
          market_specificity: 'philippines'
        },
        relevance_score: request.context?.market === 'philippines' ? 0.94 : 0.65
      }
    ];

    // Filter based on request parameters
    return mockInsights
      .filter(insight => insightTypes.includes(insight.insight_type as any))
      .filter(insight => categories.includes(insight.category as any))
      .sort((a, b) => b.relevance_score - a.relevance_score);

  } catch (error) {
    console.error('Error retrieving insights:', error);
    return [];
  }
}

async function findSimilarCampaigns(
  supa: any,
  queryEmbedding: number[],
  context?: any
): Promise<SimilarCampaign[]> {
  try {
    // In production: use ces.find_similar_campaigns function
    // SELECT * FROM ces.find_similar_campaigns($1, 0.7, 10)

    // Simulated results
    const mockSimilarCampaigns: SimilarCampaign[] = [
      {
        asset_id: 'asset-sim-001',
        campaign_id: 'campaign-nike-greatness',
        similarity_score: 0.89,
        business_outcomes: {
          engagement_rate: 0.048,
          brand_recall: 0.72,
          conversion_rate: 0.034,
          roi: 3.2,
          sales_lift: 0.24
        },
        creative_summary: 'Aspirational athlete journey with emotional storytelling and strong brand integration'
      },
      {
        asset_id: 'asset-sim-002',
        campaign_id: 'campaign-adidas-unstoppable',
        similarity_score: 0.84,
        business_outcomes: {
          engagement_rate: 0.041,
          brand_recall: 0.68,
          conversion_rate: 0.029,
          roi: 2.8,
          sales_lift: 0.19
        },
        creative_summary: 'Diverse athletes overcoming challenges with cinematic production quality'
      }
    ];

    return mockSimilarCampaigns;

  } catch (error) {
    console.error('Error finding similar campaigns:', error);
    return [];
  }
}

async function analyzePerformanceGaps(
  supa: any,
  currentPerformance: any,
  context?: any
): Promise<PerformanceGapAnalysis> {
  // Get benchmark data for comparison
  const benchmarkData = await getBenchmarkData(supa, context);

  const gapAnalysis: PerformanceGapAnalysis = {
    current_vs_benchmark: {
      engagement_gap: (benchmarkData.avg_engagement_rate - (currentPerformance.engagement_rate || 0)) / benchmarkData.avg_engagement_rate,
      recall_gap: (benchmarkData.avg_brand_recall - (currentPerformance.brand_recall || 0)) / benchmarkData.avg_brand_recall,
      conversion_gap: (benchmarkData.avg_conversion_rate - (currentPerformance.conversion_rate || 0)) / benchmarkData.avg_conversion_rate,
      roi_gap: (benchmarkData.avg_roi - (currentPerformance.roi || 0)) / benchmarkData.avg_roi
    },
    improvement_potential: 0,
    priority_areas: []
  };

  // Calculate overall improvement potential
  const gaps = Object.values(gapAnalysis.current_vs_benchmark);
  gapAnalysis.improvement_potential = gaps.reduce((sum, gap) => sum + Math.max(0, gap), 0) / gaps.length;

  // Identify priority areas (largest gaps)
  const gapEntries = Object.entries(gapAnalysis.current_vs_benchmark);
  gapEntries.sort((a, b) => b[1] - a[1]);
  gapAnalysis.priority_areas = gapEntries
    .filter(([_, gap]) => gap > 0.1) // 10% gap threshold
    .map(([area, _]) => area.replace('_gap', ''))
    .slice(0, 3);

  return gapAnalysis;
}

async function getBenchmarkData(supa: any, context?: any): Promise<any> {
  // In production: query benchmark data based on context
  // Return market-specific benchmarks
  
  return {
    avg_engagement_rate: context?.market === 'philippines' ? 0.038 : 0.032,
    avg_brand_recall: context?.market === 'philippines' ? 0.62 : 0.58,
    avg_conversion_rate: context?.market === 'philippines' ? 0.028 : 0.025,
    avg_roi: context?.market === 'philippines' ? 2.4 : 2.1
  };
}

async function generateContextualRecommendations(
  insights: CreativeInsight[],
  similarCampaigns: SimilarCampaign[],
  gapAnalysis?: PerformanceGapAnalysis,
  context?: any
): Promise<string[]> {
  const recommendations: string[] = [];

  // Recommendations based on top insights
  for (const insight of insights.slice(0, 3)) {
    if (insight.insight_type === 'optimization') {
      recommendations.push(`${insight.title.toLowerCase()} - Apply this optimization for immediate impact`);
    } else if (insight.insight_type === 'pattern') {
      recommendations.push(`Leverage the pattern: ${insight.title.toLowerCase()}`);
    }
  }

  // Recommendations based on performance gaps
  if (gapAnalysis?.priority_areas.length) {
    gapAnalysis.priority_areas.forEach(area => {
      switch (area) {
        case 'engagement':
          recommendations.push('Increase visual impact and emotional resonance to boost engagement rates');
          break;
        case 'recall':
          recommendations.push('Strengthen brand element prominence and consistency for better recall');
          break;
        case 'conversion':
          recommendations.push('Enhance call-to-action clarity and urgency to improve conversions');
          break;
        case 'roi':
          recommendations.push('Optimize media efficiency and target audience precision for better ROI');
          break;
      }
    });
  }

  // Recommendations based on similar campaigns
  if (similarCampaigns.length > 0) {
    const topCampaign = similarCampaigns[0];
    if (topCampaign.business_outcomes.roi > 2.5) {
      recommendations.push(`Consider creative elements from high-performing campaign: ${topCampaign.creative_summary}`);
    }
  }

  // Context-specific recommendations
  if (context?.market === 'philippines') {
    recommendations.push('Incorporate authentic Filipino cultural elements to increase local market engagement');
  }

  if (context?.campaign_goals?.includes('brand_awareness')) {
    recommendations.push('Focus on emotional storytelling and brand integration to maximize awareness impact');
  }

  return recommendations.slice(0, 5); // Limit to top 5 recommendations
}

function interpretQueryIntent(query: string, context?: any): string {
  const queryLower = query.toLowerCase();
  
  if (queryLower.includes('improve') || queryLower.includes('optimize')) {
    return 'Optimization request: Looking for actionable improvements to creative performance';
  } else if (queryLower.includes('benchmark') || queryLower.includes('compare')) {
    return 'Benchmarking request: Seeking performance comparisons and industry standards';
  } else if (queryLower.includes('why') || queryLower.includes('reason')) {
    return 'Analysis request: Understanding the reasoning behind creative effectiveness patterns';
  } else if (queryLower.includes('predict') || queryLower.includes('forecast')) {
    return 'Prediction request: Estimating likely outcomes for creative strategies';
  } else {
    return 'General insight request: Retrieving relevant creative effectiveness knowledge';
  }
}