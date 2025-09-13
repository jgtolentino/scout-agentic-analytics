// Creative Asset Upload Handler
// Handles multimodal asset uploads with validation and metadata extraction
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

interface UploadRequest {
  filename: string;
  content_type: string;
  file_size: number;
  campaign_context?: {
    campaign_name?: string;
    brand_context?: string;
    target_audience?: string;
    competitive_set?: string[];
    market?: string;
    language?: string;
  };
  upload_options?: {
    auto_extract: boolean;
    auto_score: boolean;
    quality_preset: 'standard' | 'high_quality' | 'broadcast';
    processing_priority: 'low' | 'medium' | 'high';
  };
}

interface UploadResponse {
  asset_id: string;
  upload_url: string;
  file_path: string;
  expires_in: number;
  processing_steps: string[];
  estimated_processing_time_ms: number;
}

// File validation constants
const MAX_FILE_SIZES = {
  'video': 500 * 1024 * 1024,  // 500MB
  'image': 100 * 1024 * 1024,  // 100MB
  'audio': 200 * 1024 * 1024,  // 200MB
  'application': 50 * 1024 * 1024  // 50MB for PDFs
};

const SUPPORTED_TYPES = {
  'video': ['video/mp4', 'video/mov', 'video/webm', 'video/quicktime'],
  'image': ['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'application/pdf'],
  'audio': ['audio/mp3', 'audio/wav', 'audio/m4a', 'audio/mpeg']
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
    const requestData: UploadRequest = await req.json();
    
    if (!requestData.filename || !requestData.content_type || !requestData.file_size) {
      return new Response(JSON.stringify({ 
        error: 'filename, content_type, and file_size are required' 
      }), { 
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    console.log(`Upload request: ${requestData.filename} (${requestData.content_type})`);

    // Validate file type and size
    const validation = validateUpload(requestData);
    if (!validation.valid) {
      return new Response(JSON.stringify({ 
        error: validation.error 
      }), { 
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const supa = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Generate asset ID and storage path
    const assetId = crypto.randomUUID();
    const assetType = getAssetType(requestData.content_type);
    const storagePrefix = `ces-assets/${assetType}/${new Date().getFullYear()}/${(new Date().getMonth() + 1).toString().padStart(2, '0')}`;
    const filePath = `${storagePrefix}/${assetId}_${sanitizeFilename(requestData.filename)}`;

    // Create asset record
    const assetRecord = {
      id: assetId,
      filename: requestData.filename,
      file_size: requestData.file_size,
      content_type: requestData.content_type,
      file_path: filePath,
      campaign_name: requestData.campaign_context?.campaign_name,
      brand_context: requestData.campaign_context?.brand_context,
      target_audience: requestData.campaign_context?.target_audience,
      competitive_set: requestData.campaign_context?.competitive_set,
      market: requestData.campaign_context?.market || 'global',
      language: requestData.campaign_context?.language || 'en',
      processing_status: 'pending_upload',
      upload_metadata: {
        uploaded_at: new Date().toISOString(),
        upload_options: requestData.upload_options,
        user_agent: req.headers.get('user-agent'),
        ip_address: req.headers.get('x-forwarded-for') || 'unknown'
      }
    };

    const { error: insertError } = await supa
      .from('ces.creative_assets')
      .insert(assetRecord);

    if (insertError) {
      console.error('Error creating asset record:', insertError);
      return new Response(JSON.stringify({ 
        error: 'Failed to create asset record',
        details: insertError.message 
      }), { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Generate signed upload URL
    const { data: uploadData, error: uploadError } = await supa.storage
      .from('creative-assets')
      .createSignedUploadUrl(filePath, {
        upsert: true
      });

    if (uploadError || !uploadData) {
      console.error('Error creating signed URL:', uploadError);
      return new Response(JSON.stringify({ 
        error: 'Failed to create upload URL',
        details: uploadError?.message 
      }), { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Generate processing steps and time estimates
    const processingInfo = generateProcessingInfo(requestData, assetType);

    console.log(`Upload URL generated for asset: ${assetId}`);

    const response: UploadResponse = {
      asset_id: assetId,
      upload_url: uploadData.signedUrl,
      file_path: filePath,
      expires_in: 3600, // 1 hour
      processing_steps: processingInfo.steps,
      estimated_processing_time_ms: processingInfo.estimatedTime
    };

    return new Response(JSON.stringify({
      success: true,
      upload_info: response,
      next_steps: [
        "Upload your file to the provided upload_url using PUT method",
        "Call /complete-upload with the asset_id to trigger processing",
        "Monitor processing status via /asset-status endpoint"
      ]
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('Upload handler error:', error);
    
    return new Response(JSON.stringify({ 
      error: 'Upload initialization failed',
      details: error instanceof Error ? error.message : String(error)
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});

function validateUpload(request: UploadRequest): { valid: boolean; error?: string } {
  // Check file size
  const assetType = getAssetType(request.content_type);
  const maxSize = MAX_FILE_SIZES[assetType];
  
  if (request.file_size > maxSize) {
    return {
      valid: false,
      error: `File size ${formatBytes(request.file_size)} exceeds maximum allowed size of ${formatBytes(maxSize)} for ${assetType} files`
    };
  }

  // Check content type
  const supportedTypes = SUPPORTED_TYPES[assetType];
  if (!supportedTypes?.includes(request.content_type)) {
    return {
      valid: false,
      error: `Unsupported content type: ${request.content_type}. Supported types for ${assetType}: ${supportedTypes?.join(', ')}`
    };
  }

  // Check filename
  if (!/^[\w\-. ]+\.[a-zA-Z0-9]{2,6}$/.test(request.filename)) {
    return {
      valid: false,
      error: 'Invalid filename format. Use alphanumeric characters, spaces, hyphens, and dots only'
    };
  }

  // Check minimum file size (avoid empty uploads)
  if (request.file_size < 1024) { // 1KB minimum
    return {
      valid: false,
      error: 'File size too small. Minimum file size is 1KB'
    };
  }

  return { valid: true };
}

function getAssetType(contentType: string): 'video' | 'image' | 'audio' | 'application' {
  if (contentType.startsWith('video/')) return 'video';
  if (contentType.startsWith('audio/')) return 'audio';
  if (contentType.startsWith('image/') || contentType === 'application/pdf') return 'image';
  return 'application';
}

function sanitizeFilename(filename: string): string {
  // Remove or replace unsafe characters
  return filename
    .replace(/[^a-zA-Z0-9\-_.]/g, '_')
    .replace(/_{2,}/g, '_')
    .toLowerCase();
}

function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

function generateProcessingInfo(request: UploadRequest, assetType: string): {
  steps: string[];
  estimatedTime: number;
} {
  const steps: string[] = [];
  let estimatedTime = 0;

  // Base processing steps
  steps.push('File validation and metadata extraction');
  estimatedTime += 2000;

  // Asset-type specific processing
  switch (assetType) {
    case 'video':
      steps.push('Video analysis: frame extraction, scene detection');
      steps.push('Audio extraction and transcription');
      steps.push('Visual element detection (objects, text, brands)');
      estimatedTime += 15000; // 15 seconds for video
      break;
    
    case 'image':
      steps.push('Image analysis: composition, color, quality assessment');
      steps.push('OCR text recognition and brand detection');
      steps.push('Visual element analysis');
      estimatedTime += 5000; // 5 seconds for image
      break;
    
    case 'audio':
      steps.push('Audio quality assessment');
      steps.push('Speech-to-text transcription');
      steps.push('Sentiment and brand mention analysis');
      estimatedTime += 8000; // 8 seconds for audio
      break;
  }

  // Semantic analysis (common to all)
  steps.push('Semantic analysis: themes, emotions, narrative structure');
  estimatedTime += 3000;

  // Optional scoring
  if (request.upload_options?.auto_score) {
    steps.push('Creative effectiveness scoring (TBWA 8-dimensions)');
    steps.push('Benchmark comparison and improvement suggestions');
    estimatedTime += 5000;
  }

  // Quality preset adjustments
  const qualityMultiplier = request.upload_options?.quality_preset === 'broadcast' ? 1.5 : 
                           request.upload_options?.quality_preset === 'high_quality' ? 1.2 : 1.0;
  
  estimatedTime = Math.round(estimatedTime * qualityMultiplier);

  steps.push('Results storage and indexing');
  estimatedTime += 1000;

  return { steps, estimatedTime };
}

// Handle upload completion notification
export async function handleUploadComplete(assetId: string): Promise<void> {
  const supa = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  try {
    // Update asset status
    await supa
      .from('ces.creative_assets')
      .update({ 
        processing_status: 'uploaded',
        file_url: `${Deno.env.get("SUPABASE_URL")}/storage/v1/object/public/creative-assets/${assetId}`,
        uploaded_at: new Date().toISOString()
      })
      .eq('id', assetId);

    // Retrieve asset details for processing
    const { data: asset } = await supa
      .from('ces.creative_assets')
      .select('*')
      .eq('id', assetId)
      .single();

    if (!asset) {
      throw new Error('Asset not found');
    }

    // Trigger extraction pipeline
    if (asset.upload_metadata?.upload_options?.auto_extract !== false) {
      await triggerCreativeExtraction(asset);
    }

    console.log(`Upload completed and processing triggered for asset: ${assetId}`);

  } catch (error) {
    console.error(`Error handling upload completion for ${assetId}:`, error);
    
    // Update asset status to error
    await supa
      .from('ces.creative_assets')
      .update({ 
        processing_status: 'error',
        processing_metadata: {
          error: error instanceof Error ? error.message : String(error),
          failed_at: new Date().toISOString()
        }
      })
      .eq('id', assetId);
  }
}

async function triggerCreativeExtraction(asset: any): Promise<void> {
  try {
    // Call creative extraction function
    const extractionResponse = await fetch(`${Deno.env.get("SUPABASE_URL")}/functions/v1/creative-extract`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        asset_id: asset.id,
        file_url: asset.file_url,
        content_type: asset.content_type,
        campaign_context: {
          campaign_name: asset.campaign_name,
          brand_context: asset.brand_context,
          target_audience: asset.target_audience,
          competitive_set: asset.competitive_set
        },
        extraction_options: {
          include_frames: true,
          frame_interval: 5,
          include_transcription: true,
          include_ocr: true,
          include_scene_detection: true
        }
      })
    });

    if (!extractionResponse.ok) {
      throw new Error(`Extraction failed: ${extractionResponse.statusText}`);
    }

    const extractionResult = await extractionResponse.json();
    console.log(`Creative extraction completed for asset: ${asset.id}`);

    // Trigger scoring if requested
    if (asset.upload_metadata?.upload_options?.auto_score) {
      await triggerCreativeScoring(asset.id);
    }

  } catch (error) {
    console.error(`Error triggering extraction for ${asset.id}:`, error);
    throw error;
  }
}

async function triggerCreativeScoring(assetId: string): Promise<void> {
  try {
    // Add small delay to ensure extraction is complete
    await new Promise(resolve => setTimeout(resolve, 1000));

    const scoringResponse = await fetch(`${Deno.env.get("SUPABASE_URL")}/functions/v1/ces-score`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        asset_id: assetId,
        model_preference: 'claude-opus',
        cultural_context: {
          market: 'philippines',
          language: 'fil-en',
          cultural_values: ['family', 'community', 'aspiration']
        },
        scoring_options: {
          include_benchmark_comparison: true,
          generate_improvement_suggestions: true,
          detailed_explanations: true
        }
      })
    });

    if (!scoringResponse.ok) {
      throw new Error(`Scoring failed: ${scoringResponse.statusText}`);
    }

    console.log(`Creative scoring completed for asset: ${assetId}`);

  } catch (error) {
    console.error(`Error triggering scoring for ${assetId}:`, error);
    // Don't throw - scoring failure shouldn't break the main flow
  }
}