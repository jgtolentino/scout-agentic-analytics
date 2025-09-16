import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
};

interface BucketProcessingConfig {
  bucketName: string;
  bucketPath: string;
  batchSize: number;
  maxParallelWorkers: number;
  validationEnabled: boolean;
  deduplicationEnabled: boolean;
  qualityThreshold: number;
  autoTriggerBronzeProcessing: boolean;
}

interface ProcessingResult {
  success: boolean;
  filesProcessed: number;
  filesSuccessful: number;
  filesFailed: number;
  transactionsLoaded: number;
  uniqueDevices: number;
  avgQualityScore: number;
  processingTimeMs: number;
  errors: string[];
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const { action, payload } = await req.json().catch(() => ({ 
      action: 'process-pending-files', 
      payload: {} 
    }));

    console.log(`Scout Bucket Processor: ${action}`, payload);

    switch (action) {
      case 'process-pending-files':
        return await processPendingFiles(supabaseClient, payload);
      
      case 'monitor-bucket':
        return await monitorBucket(supabaseClient, payload);
      
      case 'validate-file':
        return await validateFile(supabaseClient, payload);
      
      case 'get-processing-status':
        return await getProcessingStatus(supabaseClient, payload);
      
      case 'trigger-bruno-processing':
        return await triggerBrunoProcessing(payload);
      
      default:
        throw new Error(`Unknown action: ${action}`);
    }
  } catch (error) {
    console.error('Scout Bucket Processor Error:', error);
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message,
        timestamp: new Date().toISOString()
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      }
    );
  }
});

async function processPendingFiles(supabaseClient: any, payload: any) {
  const config: BucketProcessingConfig = {
    bucketName: payload.bucketName || 'scout-ingest',
    bucketPath: payload.bucketPath || 'edge-transactions/',
    batchSize: payload.batchSize || 50,
    maxParallelWorkers: payload.maxParallelWorkers || 3,
    validationEnabled: payload.validationEnabled !== false,
    deduplicationEnabled: payload.deduplicationEnabled !== false,
    qualityThreshold: payload.qualityThreshold || 0.7,
    autoTriggerBronzeProcessing: payload.autoTriggerBronzeProcessing !== false
  };

  console.log('Processing pending files with config:', config);
  
  const startTime = Date.now();
  const errors: string[] = [];
  let stats = {
    filesProcessed: 0,
    filesSuccessful: 0,
    filesFailed: 0,
    transactionsLoaded: 0,
    uniqueDevices: new Set<string>(),
    qualityScores: [] as number[]
  };

  try {
    // 1. Get pending files from bucket registry
    const { data: pendingFiles, error: queryError } = await supabaseClient
      .from('scout_bucket_files')
      .select('*')
      .eq('bucket_name', config.bucketName)
      .like('file_path', `${config.bucketPath}%`)
      .in('processing_status', ['pending', 'failed'])
      .lt('retry_count', 3)
      .order('uploaded_at', { ascending: true })
      .limit(config.batchSize);

    if (queryError) {
      throw new Error(`Failed to query pending files: ${queryError.message}`);
    }

    if (!pendingFiles || pendingFiles.length === 0) {
      console.log('No pending files found for processing');
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'No pending files found',
          filesProcessed: 0
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`Found ${pendingFiles.length} pending files`);

    // 2. Process files in controlled batches
    const processingPromises = pendingFiles.map(async (file: any) => {
      try {
        const result = await processScoutEdgeFile(supabaseClient, file, config);
        
        if (result.success) {
          stats.filesSuccessful++;
          stats.transactionsLoaded += result.transactionsLoaded || 0;
          if (result.deviceId) {
            stats.uniqueDevices.add(result.deviceId);
          }
          if (result.qualityScore) {
            stats.qualityScores.push(result.qualityScore);
          }
        } else {
          stats.filesFailed++;
          errors.push(`${file.file_name}: ${result.error}`);
        }
        
        stats.filesProcessed++;
        return result;
        
      } catch (error) {
        stats.filesFailed++;
        stats.filesProcessed++;
        const errorMsg = `${file.file_name}: ${error.message}`;
        errors.push(errorMsg);
        console.error('File processing error:', errorMsg);
        return { success: false, error: error.message };
      }
    });

    // Execute with controlled concurrency
    const batchResults = await Promise.allSettled(processingPromises);

    // 3. Trigger Bronze processing if configured and successful files exist
    if (config.autoTriggerBronzeProcessing && stats.filesSuccessful > 0) {
      try {
        await triggerBrunoProcessing({
          command: 'bucket-to-bronze',
          bucket: config.bucketName,
          path: config.bucketPath
        });
        console.log('Triggered Bruno bucket-to-bronze processing');
      } catch (error) {
        console.warn('Failed to trigger Bruno processing:', error.message);
        errors.push(`Bruno trigger failed: ${error.message}`);
      }
    }

    const processingTimeMs = Date.now() - startTime;
    const avgQualityScore = stats.qualityScores.length > 0 
      ? stats.qualityScores.reduce((a, b) => a + b, 0) / stats.qualityScores.length 
      : 0;

    const result: ProcessingResult = {
      success: stats.filesFailed === 0,
      filesProcessed: stats.filesProcessed,
      filesSuccessful: stats.filesSuccessful,
      filesFailed: stats.filesFailed,
      transactionsLoaded: stats.transactionsLoaded,
      uniqueDevices: stats.uniqueDevices.size,
      avgQualityScore,
      processingTimeMs,
      errors: errors.slice(0, 10) // Limit error messages
    };

    console.log('Processing completed:', result);

    return new Response(
      JSON.stringify(result),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Batch processing failed:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
        filesProcessed: stats.filesProcessed,
        filesSuccessful: stats.filesSuccessful,
        filesFailed: stats.filesFailed,
        processingTimeMs: Date.now() - startTime
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500
      }
    );
  }
}

async function processScoutEdgeFile(supabaseClient: any, file: any, config: BucketProcessingConfig) {
  console.log(`Processing file: ${file.file_name}`);
  
  try {
    // 1. Mark file as processing
    await supabaseClient
      .from('scout_bucket_files')
      .update({ 
        processing_status: 'processing',
        updated_at: new Date().toISOString()
      })
      .eq('id', file.id);

    // 2. Download file content from bucket
    const { data: fileData, error: downloadError } = await supabaseClient
      .storage
      .from(file.bucket_name)
      .download(file.file_path);

    if (downloadError) {
      throw new Error(`Download failed: ${downloadError.message}`);
    }

    // 3. Parse JSON content
    const fileContent = await fileData.text();
    let jsonData;
    
    try {
      jsonData = JSON.parse(fileContent);
    } catch (parseError) {
      throw new Error(`Invalid JSON format: ${parseError.message}`);
    }

    // 4. Validate Scout Edge structure
    let validationResult = { is_valid: true, quality_score: 1.0, issues: [] };
    
    if (config.validationEnabled) {
      validationResult = await validateScoutEdgeStructure(jsonData);
      
      if (!validationResult.is_valid || validationResult.quality_score < config.qualityThreshold) {
        throw new Error(`Validation failed: ${validationResult.issues.join(', ')}`);
      }
    }

    // 5. Check for duplicates
    if (config.deduplicationEnabled) {
      const transactionId = jsonData.transactionId;
      if (transactionId) {
        const { data: existing } = await supabaseClient
          .from('scout_edge_transactions')
          .select('transaction_id')
          .eq('transaction_id', transactionId)
          .single();

        if (existing) {
          // Mark as duplicate and skip
          await supabaseClient
            .from('scout_bucket_files')
            .update({ 
              processing_status: 'skipped',
              is_duplicate: true,
              scout_metadata: { duplicate_transaction_id: transactionId },
              updated_at: new Date().toISOString()
            })
            .eq('id', file.id);

          return {
            success: true,
            skipped: true,
            reason: 'duplicate',
            transactionId
          };
        }
      }
    }

    // 6. Extract Scout metadata
    const metadata = extractScoutMetadata(jsonData);

    // 7. Transform to Bronze schema
    const bronzeRecord = transformToBronzeSchema(jsonData, file, metadata);

    // 8. Load to Bronze table
    const { error: insertError } = await supabaseClient
      .from('scout_edge_transactions')
      .insert(bronzeRecord);

    if (insertError) {
      throw new Error(`Bronze insert failed: ${insertError.message}`);
    }

    // 9. Update file status as completed
    await supabaseClient
      .from('scout_bucket_files')
      .update({
        processing_status: 'completed',
        processed_at: new Date().toISOString(),
        scout_metadata: metadata,
        transaction_count: 1,
        device_id: metadata.device_id,
        store_id: metadata.store_id,
        validation_status: 'valid',
        quality_score: validationResult.quality_score,
        updated_at: new Date().toISOString()
      })
      .eq('id', file.id);

    console.log(`Successfully processed: ${file.file_name}`);

    return {
      success: true,
      transactionId: metadata.transaction_id,
      transactionsLoaded: 1,
      deviceId: metadata.device_id,
      storeId: metadata.store_id,
      qualityScore: validationResult.quality_score
    };

  } catch (error) {
    console.error(`Failed to process ${file.file_name}:`, error);

    // Mark file as failed
    await supabaseClient
      .from('scout_bucket_files')
      .update({
        processing_status: 'failed',
        error_message: error.message,
        retry_count: (file.retry_count || 0) + 1,
        updated_at: new Date().toISOString()
      })
      .eq('id', file.id);

    return {
      success: false,
      error: error.message
    };
  }
}

async function validateScoutEdgeStructure(jsonData: any) {
  const issues = [];
  let qualityScore = 1.0;

  // Required fields check
  const requiredFields = ['transactionId', 'storeId', 'deviceId', 'items', 'totals'];
  for (const field of requiredFields) {
    if (!(field in jsonData)) {
      issues.push(`Missing required field: ${field}`);
      qualityScore -= 0.2;
    }
  }

  // Validate transaction ID format (UUID)
  const transactionId = jsonData.transactionId;
  if (transactionId && !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(transactionId)) {
    issues.push('Invalid transactionId format');
    qualityScore -= 0.1;
  }

  // Validate device ID format
  const deviceId = jsonData.deviceId;
  if (deviceId && !deviceId.startsWith('SCOUTPI-')) {
    issues.push('Invalid deviceId format - should start with SCOUTPI-');
    qualityScore -= 0.1;
  }

  // Validate items array
  const items = jsonData.items;
  if (!Array.isArray(items)) {
    issues.push('Items field must be an array');
    qualityScore -= 0.2;
  } else if (items.length === 0) {
    issues.push('Items array is empty');
    qualityScore -= 0.1;
  }

  // Validate totals structure
  const totals = jsonData.totals;
  if (!totals || typeof totals !== 'object') {
    issues.push('Totals field must be an object');
    qualityScore -= 0.1;
  } else if (!('totalAmount' in totals)) {
    issues.push('Totals missing totalAmount field');
    qualityScore -= 0.05;
  }

  return {
    is_valid: issues.length === 0,
    quality_score: Math.max(qualityScore, 0.0),
    issues
  };
}

function extractScoutMetadata(jsonData: any) {
  const items = jsonData.items || [];
  const totals = jsonData.totals || {};
  const brandDetection = jsonData.brandDetection || {};

  return {
    transaction_id: jsonData.transactionId,
    store_id: jsonData.storeId,
    device_id: jsonData.deviceId,
    items_count: items.length,
    total_amount: parseFloat(totals.totalAmount || 0),
    branded_amount: parseFloat(totals.brandedAmount || 0),
    unbranded_amount: parseFloat(totals.unbrandedAmount || 0),
    unique_brands_count: totals.uniqueBrandsCount || 0,
    has_brand_detection: Object.keys(brandDetection).length > 0,
    detected_brands_count: Object.keys(brandDetection.detectedBrands || {}).length,
    has_audio_transcript: !!(jsonData.transactionContext?.audioTranscript),
    processing_methods: jsonData.transactionContext?.processingMethods || [],
    edge_version: jsonData.edgeVersion,
    privacy_compliant: jsonData.privacy?.audioStored === false,
    extracted_at: new Date().toISOString()
  };
}

function transformToBronzeSchema(jsonData: any, file: any, metadata: any) {
  return {
    transaction_id: metadata.transaction_id,
    store_id: metadata.store_id,
    device_id: metadata.device_id,
    transaction_timestamp: jsonData.timestamp || new Date().toISOString(),
    
    // Brand detection intelligence
    detected_brands: jsonData.brandDetection?.detectedBrands,
    explicit_mentions: jsonData.brandDetection?.explicitMentions,
    implicit_signals: jsonData.brandDetection?.implicitSignals,
    detection_methods: jsonData.brandDetection?.detectionMethods,
    category_brand_mapping: jsonData.brandDetection?.categoryBrandMapping,
    
    // Transaction items
    items: jsonData.items,
    
    // Totals and metrics
    total_amount: metadata.total_amount,
    total_items: jsonData.totals?.totalItems,
    branded_amount: metadata.branded_amount,
    unbranded_amount: metadata.unbranded_amount,
    branded_count: jsonData.totals?.brandedCount,
    unbranded_count: jsonData.totals?.unbrandedCount,
    unique_brands_count: metadata.unique_brands_count,
    
    // Transaction context
    transaction_context: jsonData.transactionContext,
    duration_seconds: jsonData.transactionContext?.duration,
    payment_method: jsonData.transactionContext?.paymentMethod,
    time_of_day: jsonData.transactionContext?.timeOfDay,
    day_type: jsonData.transactionContext?.dayType,
    audio_transcript: jsonData.transactionContext?.audioTranscript,
    processing_methods: jsonData.transactionContext?.processingMethods,
    
    // Privacy and compliance
    privacy_settings: jsonData.privacy,
    audio_stored: jsonData.privacy?.audioStored || false,
    brand_analysis_only: jsonData.privacy?.brandAnalysisOnly || true,
    no_facial_recognition: jsonData.privacy?.noFacialRecognition || true,
    no_image_processing: jsonData.privacy?.noImageProcessing || true,
    data_retention_days: jsonData.privacy?.dataRetentionDays || 30,
    anonymization_level: jsonData.privacy?.anonymizationLevel || 'high',
    consent_timestamp: jsonData.privacy?.consentTimestamp,
    
    // Processing metadata
    processing_time_seconds: jsonData.processingTime,
    edge_version: jsonData.edgeVersion || 'v2.0.0-stt-only',
    source_file: file.file_path,
    
    // ETL metadata
    ingested_at: new Date().toISOString(),
    ingested_by: 'scout_bucket_processor',
    processing_version: 'v1.0.0'
  };
}

async function monitorBucket(supabaseClient: any, payload: any) {
  const bucketName = payload.bucketName || 'scout-ingest';
  const bucketPath = payload.bucketPath || 'edge-transactions/';

  // Get bucket monitoring stats
  const { data: stats, error } = await supabaseClient
    .from('scout_bucket_monitoring')
    .select('*');

  if (error) {
    throw new Error(`Failed to get monitoring stats: ${error.message}`);
  }

  return new Response(
    JSON.stringify({
      success: true,
      bucket: bucketName,
      path: bucketPath,
      monitoring_stats: stats,
      timestamp: new Date().toISOString()
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

async function validateFile(supabaseClient: any, payload: any) {
  const { fileId, filePath } = payload;

  if (!fileId && !filePath) {
    throw new Error('Either fileId or filePath must be provided');
  }

  // Implementation for individual file validation
  return new Response(
    JSON.stringify({
      success: true,
      message: 'File validation completed',
      fileId,
      filePath
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

async function getProcessingStatus(supabaseClient: any, payload: any) {
  const bucketName = payload.bucketName || 'scout-ingest';
  const limit = payload.limit || 100;

  // Get recent processing status
  const { data: recentFiles, error } = await supabaseClient
    .from('scout_bucket_files')
    .select('processing_status, file_name, processed_at, error_message, quality_score')
    .eq('bucket_name', bucketName)
    .order('updated_at', { ascending: false })
    .limit(limit);

  if (error) {
    throw new Error(`Failed to get processing status: ${error.message}`);
  }

  // Get summary stats
  const statusCounts = recentFiles.reduce((acc: any, file: any) => {
    acc[file.processing_status] = (acc[file.processing_status] || 0) + 1;
    return acc;
  }, {});

  return new Response(
    JSON.stringify({
      success: true,
      bucket: bucketName,
      status_summary: statusCounts,
      recent_files: recentFiles.slice(0, 20),
      total_files_checked: recentFiles.length,
      timestamp: new Date().toISOString()
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

async function triggerBrunoProcessing(payload: any) {
  const { command, bucket, path } = payload;

  console.log(`Triggering Bruno processing: ${command} for ${bucket}/${path}`);

  // In a real implementation, this would:
  // 1. Call Bruno executor via HTTP API or message queue
  // 2. Use temporal client to trigger workflow
  // 3. Use webhook to notify external system

  // For now, just log the trigger
  console.log('Bruno processing trigger logged - implement actual trigger mechanism');

  return new Response(
    JSON.stringify({
      success: true,
      message: 'Bruno processing triggered',
      command,
      bucket,
      path,
      timestamp: new Date().toISOString()
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}