// Creative Feature Embeddings Generator
// Converts extracted creative features into vector embeddings for semantic similarity and business outcome correlation
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

interface EmbeddingRequest {
  asset_id: string;
  creative_features?: {
    visual_elements: string[];
    audio_features?: any;
    text_content: string[];
    brand_elements: any;
    technical_quality: any;
    semantic_analysis: any;
  };
  campaign_context?: {
    campaign_id: string;
    brand: string;
    market: string;
    objectives: string[];
    target_audience: string;
    business_goals: string[];
  };
  embedding_options?: {
    include_visual: boolean;
    include_audio: boolean;
    include_text: boolean;
    include_semantic: boolean;
    embedding_model: 'openai' | 'cohere' | 'huggingface';
  };
}

interface BusinessOutcome {
  campaign_id: string;
  engagement_rate: number;
  brand_recall: number;
  conversion_rate: number;
  roi: number;
  sales_lift: number;
  sentiment_score: number;
  cac: number;
  media_efficiency: number;
  behavioral_response: number;
  brand_equity_change: number;
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
    const requestData: EmbeddingRequest = await req.json();
    
    if (!requestData.asset_id) {
      return new Response(JSON.stringify({ 
        error: 'asset_id is required' 
      }), { 
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    console.log(`Generating embeddings for asset: ${requestData.asset_id}`);

    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Retrieve extraction results if not provided
    let creativeFeatures = requestData.creative_features;
    if (!creativeFeatures) {
      const { data: extraction } = await supa
        .from('ces.creative_extractions')
        .select('*')
        .eq('asset_id', requestData.asset_id)
        .single();
      
      if (!extraction) {
        return new Response(JSON.stringify({ 
          error: 'Creative features not found. Run extraction first.' 
        }), { 
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }
      
      creativeFeatures = extraction.features;
    }

    // Generate comprehensive feature text for embedding
    const featureText = await generateFeatureText(creativeFeatures, requestData.campaign_context);
    
    // Generate embeddings using selected model
    const embedding = await generateEmbedding(
      featureText, 
      requestData.embedding_options?.embedding_model || 'openai'
    );

    // Store embeddings in vector database
    const embeddingRecord = {
      asset_id: requestData.asset_id,
      campaign_id: requestData.campaign_context?.campaign_id,
      feature_embedding: embedding.vector,
      feature_text: featureText,
      embedding_metadata: {
        model: requestData.embedding_options?.embedding_model || 'openai',
        dimensions: embedding.dimensions,
        generated_at: new Date().toISOString(),
        feature_components: {
          visual_weight: 0.4,
          text_weight: 0.3,
          semantic_weight: 0.2,
          audio_weight: 0.1
        }
      }
    };

    const { error: insertError } = await supa
      .from('ces.creative_embeddings')
      .insert(embeddingRecord);

    if (insertError) {
      console.error('Error storing embeddings:', insertError);
      return new Response(JSON.stringify({ 
        error: 'Failed to store embeddings',
        details: insertError.message 
      }), { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Find similar campaigns based on creative features
    const similarCampaigns = await findSimilarCampaigns(embedding.vector, requestData.asset_id);

    // Predict business outcomes based on similar campaigns
    const outcomePredictions = await predictBusinessOutcomes(
      similarCampaigns, 
      requestData.campaign_context
    );

    console.log(`Embeddings generated and stored for asset: ${requestData.asset_id}`);

    return new Response(JSON.stringify({
      success: true,
      embedding_info: {
        asset_id: requestData.asset_id,
        dimensions: embedding.dimensions,
        model_used: requestData.embedding_options?.embedding_model || 'openai',
        feature_components: embeddingRecord.embedding_metadata.feature_components
      },
      similar_campaigns: similarCampaigns.slice(0, 5), // Top 5 similar
      outcome_predictions: outcomePredictions,
      insights: {
        creative_similarity_found: similarCampaigns.length > 0,
        prediction_confidence: outcomePredictions.confidence,
        recommended_optimizations: generateOptimizationRecommendations(
          creativeFeatures, 
          outcomePredictions
        )
      }
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('Embedding generation error:', error);
    
    return new Response(JSON.stringify({ 
      error: 'Embedding generation failed',
      details: error instanceof Error ? error.message : String(error)
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});

async function generateFeatureText(
  features: any, 
  context?: any
): Promise<string> {
  // Create comprehensive text representation of creative features
  const components = [];

  // Visual elements
  if (features.visual_elements) {
    components.push(`Visual: ${features.visual_elements.join(', ')}`);
  }

  // Text content
  if (features.text_content) {
    components.push(`Text: ${features.text_content.join(' ')}`);
  }

  // Brand elements
  if (features.brand_elements) {
    const brandText = [
      features.brand_elements.logo_prominence && `logo prominent`,
      features.brand_elements.color_scheme && `colors ${features.brand_elements.color_scheme.join(', ')}`,
      features.brand_elements.typography && `typography ${features.brand_elements.typography}`,
      features.brand_elements.brand_voice && `voice ${features.brand_elements.brand_voice}`
    ].filter(Boolean).join(', ');
    components.push(`Brand: ${brandText}`);
  }

  // Semantic analysis
  if (features.semantic_analysis) {
    components.push(`Themes: ${features.semantic_analysis.themes?.join(', ')}`);
    components.push(`Emotion: ${features.semantic_analysis.emotional_tone}`);
    components.push(`Narrative: ${features.semantic_analysis.narrative_structure}`);
  }

  // Campaign context
  if (context) {
    components.push(`Market: ${context.market}`);
    components.push(`Audience: ${context.target_audience}`);
    components.push(`Goals: ${context.business_goals?.join(', ')}`);
  }

  return components.join(' | ');
}

async function generateEmbedding(
  text: string, 
  model: string
): Promise<{ vector: number[]; dimensions: number }> {
  // For production, integrate with actual embedding models
  // This is a simulation showing the interface
  
  switch (model) {
    case 'openai':
      return await generateOpenAIEmbedding(text);
    case 'cohere':
      return await generateCohereEmbedding(text);
    case 'huggingface':
      return await generateHuggingFaceEmbedding(text);
    default:
      return await generateOpenAIEmbedding(text);
  }
}

async function generateOpenAIEmbedding(text: string): Promise<{ vector: number[]; dimensions: number }> {
  // Simulate OpenAI Ada v2 embedding (1536 dimensions)
  // In production: call OpenAI embeddings API
  const dimensions = 1536;
  const vector = Array(dimensions).fill(0).map(() => Math.random() - 0.5);
  
  // Normalize vector
  const magnitude = Math.sqrt(vector.reduce((sum, val) => sum + val * val, 0));
  const normalizedVector = vector.map(val => val / magnitude);
  
  return { vector: normalizedVector, dimensions };
}

async function generateCohereEmbedding(text: string): Promise<{ vector: number[]; dimensions: number }> {
  // Simulate Cohere embedding (4096 dimensions)
  const dimensions = 4096;
  const vector = Array(dimensions).fill(0).map(() => Math.random() - 0.5);
  const magnitude = Math.sqrt(vector.reduce((sum, val) => sum + val * val, 0));
  return { vector: vector.map(val => val / magnitude), dimensions };
}

async function generateHuggingFaceEmbedding(text: string): Promise<{ vector: number[]; dimensions: number }> {
  // Simulate sentence-transformers embedding (768 dimensions)
  const dimensions = 768;
  const vector = Array(dimensions).fill(0).map(() => Math.random() - 0.5);
  const magnitude = Math.sqrt(vector.reduce((sum, val) => sum + val * val, 0));
  return { vector: vector.map(val => val / magnitude), dimensions };
}

async function findSimilarCampaigns(
  queryVector: number[], 
  excludeAssetId: string
): Promise<Array<{
  asset_id: string;
  campaign_id: string;
  similarity_score: number;
  business_outcomes?: BusinessOutcome;
}>> {
  // In production: use pgvector similarity search
  // SELECT asset_id, campaign_id, 1 - (feature_embedding <=> $1) AS similarity
  // FROM ces.creative_embeddings 
  // WHERE asset_id != $2
  // ORDER BY similarity DESC LIMIT 10
  
  // Simulation for development
  const mockSimilar = [
    {
      asset_id: 'asset-001',
      campaign_id: 'campaign-001',
      similarity_score: 0.87,
      business_outcomes: {
        campaign_id: 'campaign-001',
        engagement_rate: 0.045,
        brand_recall: 0.62,
        conversion_rate: 0.032,
        roi: 2.4,
        sales_lift: 0.18,
        sentiment_score: 0.73,
        cac: 45.2,
        media_efficiency: 1.32,
        behavioral_response: 0.28,
        brand_equity_change: 0.12
      }
    },
    {
      asset_id: 'asset-002', 
      campaign_id: 'campaign-002',
      similarity_score: 0.82,
      business_outcomes: {
        campaign_id: 'campaign-002',
        engagement_rate: 0.038,
        brand_recall: 0.58,
        conversion_rate: 0.029,
        roi: 2.1,
        sales_lift: 0.15,
        sentiment_score: 0.69,
        cac: 52.1,
        media_efficiency: 1.18,
        behavioral_response: 0.24,
        brand_equity_change: 0.08
      }
    }
  ];
  
  return mockSimilar;
}

async function predictBusinessOutcomes(
  similarCampaigns: any[], 
  context?: any
): Promise<{
  predictions: BusinessOutcome;
  confidence: number;
  reasoning: string;
}> {
  if (similarCampaigns.length === 0) {
    return {
      predictions: {
        campaign_id: context?.campaign_id || 'unknown',
        engagement_rate: 0.025,
        brand_recall: 0.45,
        conversion_rate: 0.022,
        roi: 1.8,
        sales_lift: 0.12,
        sentiment_score: 0.65,
        cac: 60.0,
        media_efficiency: 1.0,
        behavioral_response: 0.20,
        brand_equity_change: 0.05
      },
      confidence: 0.3,
      reasoning: 'No similar campaigns found. Using market averages.'
    };
  }

  // Weighted average based on similarity scores
  const totalWeight = similarCampaigns.reduce((sum, campaign) => sum + campaign.similarity_score, 0);
  
  const predictions: BusinessOutcome = {
    campaign_id: context?.campaign_id || 'predicted',
    engagement_rate: 0,
    brand_recall: 0,
    conversion_rate: 0,
    roi: 0,
    sales_lift: 0,
    sentiment_score: 0,
    cac: 0,
    media_efficiency: 0,
    behavioral_response: 0,
    brand_equity_change: 0
  };

  // Calculate weighted averages
  for (const campaign of similarCampaigns) {
    if (!campaign.business_outcomes) continue;
    
    const weight = campaign.similarity_score / totalWeight;
    const outcomes = campaign.business_outcomes;
    
    predictions.engagement_rate += outcomes.engagement_rate * weight;
    predictions.brand_recall += outcomes.brand_recall * weight;
    predictions.conversion_rate += outcomes.conversion_rate * weight;
    predictions.roi += outcomes.roi * weight;
    predictions.sales_lift += outcomes.sales_lift * weight;
    predictions.sentiment_score += outcomes.sentiment_score * weight;
    predictions.cac += outcomes.cac * weight;
    predictions.media_efficiency += outcomes.media_efficiency * weight;
    predictions.behavioral_response += outcomes.behavioral_response * weight;
    predictions.brand_equity_change += outcomes.brand_equity_change * weight;
  }

  const avgSimilarity = totalWeight / similarCampaigns.length;
  
  return {
    predictions,
    confidence: Math.min(avgSimilarity * 1.2, 0.95), // Cap at 95%
    reasoning: `Predicted based on ${similarCampaigns.length} similar campaigns with average similarity of ${(avgSimilarity * 100).toFixed(1)}%`
  };
}

function generateOptimizationRecommendations(
  features: any, 
  predictions: any
): string[] {
  const recommendations = [];

  // Analyze predictions against benchmarks
  if (predictions.predictions.engagement_rate < 0.03) {
    recommendations.push('Increase visual impact and emotional resonance to boost engagement');
  }

  if (predictions.predictions.brand_recall < 0.5) {
    recommendations.push('Strengthen brand element prominence and consistency');
  }

  if (predictions.predictions.conversion_rate < 0.025) {
    recommendations.push('Enhance call-to-action clarity and urgency');
  }

  if (predictions.predictions.roi < 2.0) {
    recommendations.push('Optimize media efficiency and target audience precision');
  }

  // Creative-specific recommendations
  if (features.semantic_analysis?.emotional_tone === 'neutral') {
    recommendations.push('Add emotional storytelling elements to increase memorability');
  }

  if (features.brand_elements?.logo_prominence < 0.7) {
    recommendations.push('Increase logo visibility and brand element integration');
  }

  return recommendations.length > 0 ? recommendations : ['Current creative approach shows strong optimization potential'];
}