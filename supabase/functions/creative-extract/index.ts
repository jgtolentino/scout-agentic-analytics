// Creative Asset Extraction Pipeline
// Multimodal extraction for video, image, and audio assets with CES integration
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

interface ExtractionRequest {
  asset_id: string;
  file_url: string;
  content_type: string;
  campaign_context?: {
    campaign_name?: string;
    brand_context?: string;
    target_audience?: string;
    competitive_set?: string[];
  };
  extraction_options?: {
    include_frames?: boolean;
    frame_interval?: number; // seconds
    include_transcription?: boolean;
    include_ocr?: boolean;
    include_scene_detection?: boolean;
  };
}

interface MultimodalExtractionResult {
  asset_id: string;
  extraction_type: 'video' | 'image' | 'audio';
  processing_time_ms: number;
  
  // Video-specific extractions
  video_analysis?: {
    duration_seconds: number;
    fps: number;
    resolution: { width: number; height: number };
    scene_boundaries: number[]; // timestamps in seconds
    key_frames: Array<{
      timestamp: number;
      frame_url: string;
      visual_elements: string[];
      text_detected: string[];
    }>;
  };
  
  // Audio extraction (for video and audio files)
  audio_analysis?: {
    duration_seconds: number;
    transcript: string;
    confidence: number;
    language: string;
    brand_mentions: Array<{
      brand: string;
      timestamp: number;
      confidence: number;
    }>;
    sentiment_analysis: {
      overall_sentiment: 'positive' | 'negative' | 'neutral';
      confidence: number;
      emotional_tone: string[];
    };
  };
  
  // Visual analysis (for video and image)
  visual_analysis?: {
    dimensions: { width: number; height: number };
    dominant_colors: string[];
    detected_objects: Array<{
      class: string;
      confidence: number;
      bbox: [number, number, number, number];
    }>;
    text_regions: Array<{
      text: string;
      confidence: number;
      bbox: [number, number, number, number];
      language: string;
    }>;
    brand_elements: Array<{
      brand_name: string;
      element_type: 'logo' | 'text' | 'product';
      confidence: number;
      bbox: [number, number, number, number];
    }>;
  };
  
  // Semantic extraction
  semantic_analysis?: {
    key_themes: string[];
    emotional_elements: string[];
    narrative_structure: string;
    call_to_action: string[];
    cultural_elements: string[];
  };
  
  // Quality metrics
  technical_quality: {
    video_quality?: number; // 0-1 scale
    audio_quality?: number; // 0-1 scale
    production_value: number; // 0-1 scale
    accessibility_score: number; // 0-1 scale
  };
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
    const requestData: ExtractionRequest = await req.json();
    
    if (!requestData.asset_id || !requestData.file_url || !requestData.content_type) {
      return new Response(JSON.stringify({ 
        error: 'asset_id, file_url, and content_type are required' 
      }), { 
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    console.log(`Starting extraction for asset: ${requestData.asset_id}`);
    const startTime = Date.now();

    // Update asset status to processing
    await supa
      .from('ces.creative_assets')
      .update({ 
        processing_status: 'processing',
        processing_metadata: {
          started_at: new Date().toISOString(),
          extraction_options: requestData.extraction_options
        }
      })
      .eq('id', requestData.asset_id);

    // Determine extraction type based on content type
    const extractionType = getExtractionType(requestData.content_type);
    
    // Perform multimodal extraction
    const extractionResult = await performMultimodalExtraction(
      requestData, 
      extractionType
    );

    // Store extraction results
    await storeExtractionResults(supa, extractionResult);

    // Update asset status to completed
    const processingTime = Date.now() - startTime;
    await supa
      .from('ces.creative_assets')
      .update({ 
        processing_status: 'completed',
        processed_at: new Date().toISOString(),
        processing_metadata: {
          ...requestData.extraction_options,
          processing_time_ms: processingTime,
          extraction_completed_at: new Date().toISOString()
        }
      })
      .eq('id', requestData.asset_id);

    console.log(`Extraction completed for asset: ${requestData.asset_id} in ${processingTime}ms`);

    return new Response(JSON.stringify({
      success: true,
      asset_id: requestData.asset_id,
      extraction_result: extractionResult,
      processing_time_ms: processingTime
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('Creative extraction error:', error);
    
    return new Response(JSON.stringify({ 
      error: 'Extraction failed',
      details: error instanceof Error ? error.message : String(error)
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});

function getExtractionType(contentType: string): 'video' | 'image' | 'audio' {
  if (contentType.startsWith('video/')) return 'video';
  if (contentType.startsWith('audio/')) return 'audio';
  return 'image'; // includes image/ and application/pdf
}

async function performMultimodalExtraction(
  request: ExtractionRequest,
  extractionType: 'video' | 'image' | 'audio'
): Promise<MultimodalExtractionResult> {
  const startTime = Date.now();
  
  // Initialize result structure
  const result: MultimodalExtractionResult = {
    asset_id: request.asset_id,
    extraction_type: extractionType,
    processing_time_ms: 0,
    technical_quality: {
      production_value: 0,
      accessibility_score: 0
    }
  };

  try {
    switch (extractionType) {
      case 'video':
        await extractVideoContent(request, result);
        break;
      case 'image':
        await extractImageContent(request, result);
        break;
      case 'audio':
        await extractAudioContent(request, result);
        break;
    }

    // Perform semantic analysis for all types
    await performSemanticAnalysis(request, result);

  } catch (error) {
    console.error(`Extraction error for ${extractionType}:`, error);
    throw error;
  }

  result.processing_time_ms = Date.now() - startTime;
  return result;
}

async function extractVideoContent(
  request: ExtractionRequest, 
  result: MultimodalExtractionResult
) {
  // Simulate video analysis - in production, use FFmpeg/MediaInfo
  result.video_analysis = {
    duration_seconds: Math.random() * 120 + 15, // 15-135 seconds
    fps: 30,
    resolution: { width: 1920, height: 1080 },
    scene_boundaries: [0, 5.2, 12.8, 25.1, 33.7], // Scene detection timestamps
    key_frames: []
  };

  // Generate key frames (simulate frame extraction)
  const frameCount = Math.min(10, Math.floor(result.video_analysis.duration_seconds / 5));
  for (let i = 0; i < frameCount; i++) {
    const timestamp = (result.video_analysis.duration_seconds / frameCount) * i;
    result.video_analysis.key_frames.push({
      timestamp,
      frame_url: `${request.file_url}#t=${timestamp}`,
      visual_elements: generateVisualElements(),
      text_detected: generateDetectedText()
    });
  }

  // Extract visual analysis from video frames
  result.visual_analysis = await generateVisualAnalysis('video');
  
  // Extract audio if present
  if (request.extraction_options?.include_transcription !== false) {
    result.audio_analysis = await generateAudioAnalysis(request);
  }

  // Calculate video quality metrics
  result.technical_quality.video_quality = 0.85 + Math.random() * 0.15; // 0.85-1.0
  result.technical_quality.audio_quality = 0.80 + Math.random() * 0.20; // 0.80-1.0
  result.technical_quality.production_value = calculateProductionValue(result);
  result.technical_quality.accessibility_score = calculateAccessibilityScore(result);
}

async function extractImageContent(
  request: ExtractionRequest, 
  result: MultimodalExtractionResult
) {
  // Simulate image analysis - in production, use vision models
  result.visual_analysis = await generateVisualAnalysis('image');
  
  // Calculate image quality metrics
  result.technical_quality.production_value = 0.75 + Math.random() * 0.25; // 0.75-1.0
  result.technical_quality.accessibility_score = calculateAccessibilityScore(result);
}

async function extractAudioContent(
  request: ExtractionRequest, 
  result: MultimodalExtractionResult
) {
  // Extract audio transcription and analysis
  result.audio_analysis = await generateAudioAnalysis(request);
  
  // Calculate audio quality metrics
  result.technical_quality.audio_quality = 0.82 + Math.random() * 0.18; // 0.82-1.0
  result.technical_quality.production_value = result.technical_quality.audio_quality! * 0.9;
  result.technical_quality.accessibility_score = calculateAccessibilityScore(result);
}

async function generateVisualAnalysis(type: 'video' | 'image'): Promise<MultimodalExtractionResult['visual_analysis']> {
  // Simulate computer vision analysis
  return {
    dimensions: { width: 1920, height: 1080 },
    dominant_colors: ['#FF6B35', '#004E89', '#FFFFFF', '#1A1A1A'],
    detected_objects: [
      { class: 'person', confidence: 0.92, bbox: [100, 200, 300, 600] },
      { class: 'product', confidence: 0.88, bbox: [400, 300, 200, 400] }
    ],
    text_regions: [
      { 
        text: 'Premium Quality', 
        confidence: 0.95, 
        bbox: [50, 50, 300, 80],
        language: 'en'
      }
    ],
    brand_elements: [
      {
        brand_name: 'TBWA',
        element_type: 'logo',
        confidence: 0.96,
        bbox: [1600, 50, 200, 100]
      }
    ]
  };
}

async function generateAudioAnalysis(request: ExtractionRequest): Promise<MultimodalExtractionResult['audio_analysis']> {
  // Simulate audio transcription and analysis
  const transcripts = [
    "Discover the difference with our premium quality products that transform your everyday experiences.",
    "Experience innovation that speaks to your lifestyle and values.",
    "Join thousands who have already made the smart choice."
  ];
  
  return {
    duration_seconds: Math.random() * 60 + 30, // 30-90 seconds
    transcript: transcripts[Math.floor(Math.random() * transcripts.length)],
    confidence: 0.87 + Math.random() * 0.13, // 0.87-1.0
    language: 'en',
    brand_mentions: [
      {
        brand: request.campaign_context?.brand_context || 'Generic Brand',
        timestamp: 5.2,
        confidence: 0.91
      }
    ],
    sentiment_analysis: {
      overall_sentiment: 'positive',
      confidence: 0.89,
      emotional_tone: ['confident', 'aspirational', 'trustworthy']
    }
  };
}

async function performSemanticAnalysis(
  request: ExtractionRequest,
  result: MultimodalExtractionResult
) {
  // Simulate semantic analysis using LLM
  result.semantic_analysis = {
    key_themes: ['premium quality', 'innovation', 'lifestyle enhancement'],
    emotional_elements: ['aspiration', 'trust', 'confidence'],
    narrative_structure: 'problem-solution-benefit',
    call_to_action: ['discover', 'experience', 'join'],
    cultural_elements: ['modern lifestyle', 'premium positioning']
  };
}

function generateVisualElements(): string[] {
  const elements = [
    'product shot', 'lifestyle scene', 'brand logo', 'text overlay',
    'person interaction', 'environment context', 'color transition'
  ];
  return elements.slice(0, Math.floor(Math.random() * 4) + 2);
}

function generateDetectedText(): string[] {
  const texts = [
    'Premium Quality', 'Innovation', 'Experience More', 'Join Us',
    'Transform', 'Discover', 'Excellence', 'Lifestyle'
  ];
  return texts.slice(0, Math.floor(Math.random() * 3) + 1);
}

function calculateProductionValue(result: MultimodalExtractionResult): number {
  let score = 0.7; // Base score
  
  // Video quality contribution
  if (result.technical_quality.video_quality) {
    score += result.technical_quality.video_quality * 0.3;
  }
  
  // Audio quality contribution
  if (result.technical_quality.audio_quality) {
    score += result.technical_quality.audio_quality * 0.2;
  }
  
  // Visual elements contribution
  if (result.visual_analysis?.detected_objects.length) {
    score += Math.min(0.1, result.visual_analysis.detected_objects.length * 0.02);
  }
  
  return Math.min(1.0, score);
}

function calculateAccessibilityScore(result: MultimodalExtractionResult): number {
  let score = 0.5; // Base score
  
  // Text detection contribution
  if (result.visual_analysis?.text_regions.length) {
    score += 0.2;
  }
  
  // Transcription contribution
  if (result.audio_analysis?.transcript) {
    score += 0.3;
  }
  
  // Color contrast (simulated)
  if (result.visual_analysis?.dominant_colors.length && result.visual_analysis.dominant_colors.length >= 2) {
    score += 0.2; // Assume good contrast
  }
  
  return Math.min(1.0, score);
}

async function storeExtractionResults(
  supa: any,
  result: MultimodalExtractionResult
) {
  // Store extraction results in the database
  const { error } = await supa.from('ces.creative_assets').update({
    quality_metrics: {
      extraction_result: result,
      multimodal_analysis: {
        video_analysis: result.video_analysis,
        audio_analysis: result.audio_analysis,
        visual_analysis: result.visual_analysis,
        semantic_analysis: result.semantic_analysis
      },
      technical_quality: result.technical_quality
    }
  }).eq('id', result.asset_id);

  if (error) {
    console.error('Error storing extraction results:', error);
    throw error;
  }

  console.log(`Stored extraction results for asset: ${result.asset_id}`);
}