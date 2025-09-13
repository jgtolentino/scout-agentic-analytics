// Creative Effectiveness Scoring Engine
// Applies TBWA's 8-dimensional scoring framework to multimodal extraction results
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

interface ScoringRequest {
  asset_id: string;
  model_preference?: 'llava-critic' | 'claude-opus' | 'nova-pro';
  cultural_context?: {
    market: string;
    language: string;
    cultural_values: string[];
  };
  scoring_options?: {
    include_benchmark_comparison: boolean;
    generate_improvement_suggestions: boolean;
    detailed_explanations: boolean;
  };
}

interface TBWAScoreResult {
  asset_id: string;
  overall_score: number;
  scores: {
    clarity: number;           // Message comprehension
    emotion: number;          // Emotional resonance
    branding: number;         // Brand recognition
    culture: number;          // Cultural fit
    production: number;       // Production quality
    cta: number;             // Call to action
    distinctiveness: number;  // Disruption & originality
    tbwa_dna: number;        // Agency philosophy
  };
  weighted_scores: {
    clarity_weighted: number;
    emotion_weighted: number;
    branding_weighted: number;
    culture_weighted: number;
    production_weighted: number;
    cta_weighted: number;
    distinctiveness_weighted: number;
    tbwa_dna_weighted: number;
  };
  explanation: string;
  confidence_score: number;
  benchmark_percentile?: number;
  improvement_suggestions?: string[];
  processing_time_ms: number;
}

// TBWA's 8-dimensional weighting system
const TBWA_WEIGHTS = {
  clarity: 1.2,           // Enhanced for creative analysis precision
  emotion: 1.3,          // Emotional impact strength
  branding: 1.1,         // Brand presence and recall
  culture: 1.4,          // Cultural alignment (highest weight)
  production: 1.0,       // Technical execution baseline
  cta: 1.1,             // Action clarity
  distinctiveness: 1.5,  // Disruption & originality (highest weight)
  tbwa_dna: 1.3         // Agency principles
};

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
    const requestData: ScoringRequest = await req.json();
    
    if (!requestData.asset_id) {
      return new Response(JSON.stringify({ 
        error: 'asset_id is required' 
      }), { 
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    console.log(`Starting CES scoring for asset: ${requestData.asset_id}`);
    const startTime = Date.now();

    // Retrieve asset and extraction results
    const { data: asset, error: assetError } = await supa
      .from('ces.creative_assets')
      .select('*')
      .eq('id', requestData.asset_id)
      .single();

    if (assetError || !asset) {
      return new Response(JSON.stringify({ 
        error: 'Asset not found or not processed' 
      }), { 
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Check if asset has extraction results
    if (!asset.quality_metrics?.extraction_result) {
      return new Response(JSON.stringify({ 
        error: 'Asset must be processed through creative-extract first' 
      }), { 
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Update asset status to scoring
    await supa
      .from('ces.creative_assets')
      .update({ 
        processing_status: 'scoring',
        processing_metadata: {
          ...asset.processing_metadata,
          scoring_started_at: new Date().toISOString(),
          model_preference: requestData.model_preference || 'claude-opus'
        }
      })
      .eq('id', requestData.asset_id);

    // Perform TBWA 8-dimensional scoring
    const scoringResult = await performTBWAScoring(
      asset,
      requestData
    );

    // Store evaluation results
    await storeEvaluationResults(supa, scoringResult);

    // Update asset status to completed
    const processingTime = Date.now() - startTime;
    await supa
      .from('ces.creative_assets')
      .update({ 
        processing_status: 'completed',
        scored_at: new Date().toISOString(),
        processing_metadata: {
          ...asset.processing_metadata,
          scoring_time_ms: processingTime,
          scoring_completed_at: new Date().toISOString()
        }
      })
      .eq('id', requestData.asset_id);

    console.log(`CES scoring completed for asset: ${requestData.asset_id} in ${processingTime}ms`);

    return new Response(JSON.stringify({
      success: true,
      asset_id: requestData.asset_id,
      scoring_result: scoringResult,
      processing_time_ms: processingTime
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('CES scoring error:', error);
    
    return new Response(JSON.stringify({ 
      error: 'Scoring failed',
      details: error instanceof Error ? error.message : String(error)
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});

async function performTBWAScoring(
  asset: any,
  request: ScoringRequest
): Promise<TBWAScoreResult> {
  const startTime = Date.now();
  const extractionResult = asset.quality_metrics.extraction_result;
  
  // Initialize scoring structure
  const baseScores = await calculateBaseScores(asset, extractionResult, request);
  
  // Apply TBWA weighting system
  const weightedScores = applyTBWAWeights(baseScores);
  
  // Calculate overall score
  const overallScore = calculateOverallScore(weightedScores);
  
  // Generate explanation
  const explanation = await generateScoringExplanation(
    asset,
    baseScores,
    weightedScores,
    request
  );
  
  // Calculate confidence
  const confidenceScore = calculateConfidenceScore(extractionResult, baseScores);
  
  // Benchmark comparison (if requested)
  let benchmarkPercentile;
  if (request.scoring_options?.include_benchmark_comparison) {
    benchmarkPercentile = await calculateBenchmarkPercentile(overallScore, asset.brand_context);
  }
  
  // Improvement suggestions (if requested)
  let improvementSuggestions;
  if (request.scoring_options?.generate_improvement_suggestions) {
    improvementSuggestions = generateImprovementSuggestions(baseScores, extractionResult);
  }

  return {
    asset_id: asset.id,
    overall_score: Math.round(overallScore * 10) / 10,
    scores: baseScores,
    weighted_scores: weightedScores,
    explanation,
    confidence_score: Math.round(confidenceScore * 100) / 100,
    benchmark_percentile: benchmarkPercentile,
    improvement_suggestions: improvementSuggestions,
    processing_time_ms: Date.now() - startTime
  };
}

async function calculateBaseScores(
  asset: any, 
  extractionResult: any,
  request: ScoringRequest
): Promise<TBWAScoreResult['scores']> {
  // This would integrate with actual AI models in production
  // For now, providing sophisticated simulation based on extraction results
  
  const hasAudio = extractionResult.audio_analysis;
  const hasVisual = extractionResult.visual_analysis;
  const hasSemantic = extractionResult.semantic_analysis;
  const hasVideo = extractionResult.video_analysis;
  const qualityMetrics = extractionResult.technical_quality;

  // Clarity: Message comprehension
  let clarity = 7.0; // Base score
  if (hasAudio?.transcript) {
    clarity += hasAudio.confidence > 0.8 ? 1.5 : 0.5;
  }
  if (hasVisual?.text_regions?.length > 0) {
    clarity += 1.0;
  }
  if (hasSemantic?.call_to_action?.length > 0) {
    clarity += 0.5;
  }

  // Emotion: Emotional resonance
  let emotion = 6.5; // Base score
  if (hasSemantic?.emotional_elements?.length > 2) {
    emotion += 1.5;
  }
  if (hasAudio?.sentiment_analysis?.overall_sentiment === 'positive') {
    emotion += hasAudio.sentiment_analysis.confidence > 0.8 ? 1.0 : 0.5;
  }
  if (hasVisual?.dominant_colors?.includes('#FF6B35') || hasVisual?.dominant_colors?.includes('#004E89')) {
    emotion += 0.5; // Strong emotional colors
  }

  // Branding: Brand recognition
  let branding = 6.0; // Base score
  if (hasVisual?.brand_elements?.length > 0) {
    const avgBrandConfidence = hasVisual.brand_elements.reduce((sum: number, el: any) => 
      sum + el.confidence, 0) / hasVisual.brand_elements.length;
    branding += avgBrandConfidence > 0.8 ? 2.0 : 1.0;
  }
  if (hasAudio?.brand_mentions?.length > 0) {
    branding += 1.0;
  }

  // Culture: Cultural fit (critical for Philippine market)
  let culture = 7.5; // Higher base for cultural emphasis
  if (request.cultural_context?.market === 'philippines') {
    if (hasSemantic?.cultural_elements?.includes('Filipino values') || 
        hasSemantic?.cultural_elements?.includes('local community')) {
      culture += 1.5;
    }
  }
  if (hasAudio?.language === 'fil-en') {
    culture += 1.0; // Code-switching bonus
  }

  // Production: Technical execution
  let production = qualityMetrics.production_value * 10; // Scale to 0-10
  if (qualityMetrics.video_quality) {
    production = Math.max(production, qualityMetrics.video_quality * 10);
  }
  if (qualityMetrics.audio_quality) {
    production = Math.max(production, qualityMetrics.audio_quality * 10);
  }

  // CTA: Call to action clarity
  let cta = 5.5; // Base score
  if (hasSemantic?.call_to_action?.length > 0) {
    cta += hasSemantic.call_to_action.length * 1.2;
  }
  if (hasVisual?.text_regions?.some((region: any) => 
    region.text.toLowerCase().includes('buy') || 
    region.text.toLowerCase().includes('visit') ||
    region.text.toLowerCase().includes('call'))) {
    cta += 1.5;
  }

  // Distinctiveness: Disruption & originality
  let distinctiveness = 6.8; // Base score
  if (hasSemantic?.key_themes?.includes('innovation') || 
      hasSemantic?.key_themes?.includes('unique approach')) {
    distinctiveness += 1.5;
  }
  if (hasVisual?.detected_objects?.some((obj: any) => obj.class === 'product' && obj.confidence > 0.9)) {
    distinctiveness += 0.7; // Clear product differentiation
  }

  // TBWA DNA: Agency philosophy alignment
  let tbwa_dna = 7.2; // Base score
  if (hasSemantic?.key_themes?.includes('premium positioning') ||
      hasSemantic?.narrative_structure === 'problem-solution-benefit') {
    tbwa_dna += 1.3;
  }
  if (hasSemantic?.emotional_elements?.includes('aspiration')) {
    tbwa_dna += 0.8;
  }

  // Cap all scores at 10
  return {
    clarity: Math.min(10, Math.max(1, clarity)),
    emotion: Math.min(10, Math.max(1, emotion)),
    branding: Math.min(10, Math.max(1, branding)),
    culture: Math.min(10, Math.max(1, culture)),
    production: Math.min(10, Math.max(1, production)),
    cta: Math.min(10, Math.max(1, cta)),
    distinctiveness: Math.min(10, Math.max(1, distinctiveness)),
    tbwa_dna: Math.min(10, Math.max(1, tbwa_dna))
  };
}

function applyTBWAWeights(baseScores: TBWAScoreResult['scores']): TBWAScoreResult['weighted_scores'] {
  return {
    clarity_weighted: Math.round((baseScores.clarity * TBWA_WEIGHTS.clarity) * 10) / 10,
    emotion_weighted: Math.round((baseScores.emotion * TBWA_WEIGHTS.emotion) * 10) / 10,
    branding_weighted: Math.round((baseScores.branding * TBWA_WEIGHTS.branding) * 10) / 10,
    culture_weighted: Math.round((baseScores.culture * TBWA_WEIGHTS.culture) * 10) / 10,
    production_weighted: Math.round((baseScores.production * TBWA_WEIGHTS.production) * 10) / 10,
    cta_weighted: Math.round((baseScores.cta * TBWA_WEIGHTS.cta) * 10) / 10,
    distinctiveness_weighted: Math.round((baseScores.distinctiveness * TBWA_WEIGHTS.distinctiveness) * 10) / 10,
    tbwa_dna_weighted: Math.round((baseScores.tbwa_dna * TBWA_WEIGHTS.tbwa_dna) * 10) / 10
  };
}

function calculateOverallScore(weightedScores: TBWAScoreResult['weighted_scores']): number {
  const totalWeight = Object.values(TBWA_WEIGHTS).reduce((sum, weight) => sum + weight, 0);
  const weightedSum = Object.values(weightedScores).reduce((sum, score) => sum + score, 0);
  
  return weightedSum / totalWeight;
}

async function generateScoringExplanation(
  asset: any,
  baseScores: TBWAScoreResult['scores'],
  weightedScores: TBWAScoreResult['weighted_scores'],
  request: ScoringRequest
): Promise<string> {
  const extractionResult = asset.quality_metrics.extraction_result;
  
  let explanation = `Creative Effectiveness Analysis for ${asset.filename}:\n\n`;
  
  // Highlight strongest dimensions
  const topDimension = Object.entries(baseScores)
    .sort(([,a], [,b]) => b - a)[0];
  
  explanation += `🎯 **Strongest Dimension**: ${topDimension[0].charAt(0).toUpperCase() + topDimension[0].slice(1)} (${topDimension[1]}/10)\n`;
  
  // Cultural context analysis
  if (baseScores.culture >= 8.0) {
    explanation += `🌏 **Cultural Resonance**: Excellent alignment with target market values and communication style.\n`;
  } else if (baseScores.culture < 6.0) {
    explanation += `⚠️ **Cultural Fit**: Consider enhancing cultural relevance for better market connection.\n`;
  }
  
  // Brand integration assessment
  if (baseScores.branding >= 8.0) {
    explanation += `🏢 **Brand Integration**: Strong brand presence with clear recognition elements.\n`;
  }
  
  // Emotional impact analysis
  if (baseScores.emotion >= 8.0) {
    explanation += `❤️ **Emotional Impact**: High emotional resonance with compelling storytelling.\n`;
  }
  
  // Technical quality notes
  if (baseScores.production >= 8.5) {
    explanation += `⚡ **Production Quality**: Professional execution meeting broadcast standards.\n`;
  } else if (baseScores.production < 7.0) {
    explanation += `🔧 **Production Notes**: Technical quality could benefit from enhancement.\n`;
  }
  
  // TBWA DNA alignment
  if (baseScores.tbwa_dna >= 8.0) {
    explanation += `🎨 **TBWA Philosophy**: Strong alignment with agency's creative principles and approach.\n`;
  }
  
  explanation += `\n**Overall Assessment**: ${calculateOverallScore(weightedScores) >= 8.0 ? 'Exceptional creative effectiveness' : calculateOverallScore(weightedScores) >= 7.0 ? 'Strong creative performance' : 'Good foundation with optimization opportunities'}.`;
  
  return explanation;
}

function calculateConfidenceScore(extractionResult: any, baseScores: TBWAScoreResult['scores']): number {
  let confidence = 0.75; // Base confidence
  
  // Increase confidence based on data availability
  if (extractionResult.audio_analysis?.confidence > 0.8) confidence += 0.1;
  if (extractionResult.visual_analysis?.brand_elements?.length > 0) confidence += 0.1;
  if (extractionResult.semantic_analysis) confidence += 0.05;
  
  // Confidence moderated by score consistency
  const scores = Object.values(baseScores);
  const scoreVariance = scores.reduce((acc, score) => acc + Math.pow(score - (scores.reduce((a, b) => a + b) / scores.length), 2), 0) / scores.length;
  
  if (scoreVariance < 2.0) confidence += 0.05; // Consistent scores increase confidence
  if (scoreVariance > 4.0) confidence -= 0.1; // High variance reduces confidence
  
  return Math.min(0.98, Math.max(0.5, confidence));
}

async function calculateBenchmarkPercentile(overallScore: number, brandContext?: string): Promise<number> {
  // Simulate benchmark comparison against industry standards
  // In production, this would query the benchmark database
  
  let percentile = 50; // Base percentile
  
  if (overallScore >= 9.0) percentile = 95;
  else if (overallScore >= 8.5) percentile = 88;
  else if (overallScore >= 8.0) percentile = 75;
  else if (overallScore >= 7.5) percentile = 65;
  else if (overallScore >= 7.0) percentile = 55;
  else if (overallScore < 6.0) percentile = 25;
  
  // Adjust for brand context (premium brands have higher thresholds)
  if (brandContext && ['premium', 'luxury'].some(term => brandContext.toLowerCase().includes(term))) {
    percentile = Math.max(10, percentile - 10);
  }
  
  return Math.min(99, Math.max(5, percentile));
}

function generateImprovementSuggestions(baseScores: TBWAScoreResult['scores'], extractionResult: any): string[] {
  const suggestions: string[] = [];
  
  // Analyze weakest dimensions and provide specific recommendations
  const sortedScores = Object.entries(baseScores).sort(([,a], [,b]) => a - b);
  
  for (const [dimension, score] of sortedScores.slice(0, 3)) {
    if (score < 7.5) {
      switch (dimension) {
        case 'clarity':
          suggestions.push("Enhance message clarity with more direct communication and clearer value propositions");
          break;
        case 'emotion':
          suggestions.push("Strengthen emotional connection through storytelling, music, or visual narratives");
          break;
        case 'branding':
          suggestions.push("Increase brand visibility and integration throughout the creative execution");
          break;
        case 'culture':
          suggestions.push("Incorporate more local cultural elements and communication patterns relevant to the target market");
          break;
        case 'production':
          suggestions.push("Improve technical production quality including audio clarity, visual composition, and editing");
          break;
        case 'cta':
          suggestions.push("Add clear, compelling calls-to-action with specific next steps for the audience");
          break;
        case 'distinctiveness':
          suggestions.push("Develop more unique creative concepts that stand out from competitive messaging");
          break;
        case 'tbwa_dna':
          suggestions.push("Align creative approach more closely with TBWA's strategic philosophy and methodology");
          break;
      }
    }
  }
  
  // Technical suggestions based on extraction results
  if (extractionResult.technical_quality?.accessibility_score < 0.7) {
    suggestions.push("Improve accessibility with better contrast ratios and text legibility");
  }
  
  if (extractionResult.audio_analysis && extractionResult.audio_analysis.confidence < 0.8) {
    suggestions.push("Enhance audio quality and clarity for better speech recognition and impact");
  }
  
  return suggestions.slice(0, 5); // Return top 5 suggestions
}

async function storeEvaluationResults(supa: any, result: TBWAScoreResult) {
  // Store evaluation results in the ces.evaluations table
  const { error } = await supa.from('ces.evaluations').insert({
    asset_id: result.asset_id,
    scores: result.scores,
    weighted_scores: result.weighted_scores,
    overall_score: result.overall_score,
    explanation: result.explanation,
    confidence_score: result.confidence_score,
    benchmark_percentile: result.benchmark_percentile,
    improvement_suggestions: result.improvement_suggestions,
    evaluation_metadata: {
      processing_time_ms: result.processing_time_ms,
      model_used: 'tbwa-ces-v3',
      evaluated_at: new Date().toISOString()
    }
  });

  if (error) {
    console.error('Error storing evaluation results:', error);
    throw error;
  }

  console.log(`Stored evaluation results for asset: ${result.asset_id}`);
}