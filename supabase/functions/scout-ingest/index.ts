import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    const { action, payload } = await req.json()

    switch (action) {
      case 'process-storage-upload':
        return await processStorageUpload(supabaseClient, payload)
      
      case 'validate-and-ingest':
        return await validateAndIngest(supabaseClient, payload)
      
      case 'batch-process':
        return await batchProcess(supabaseClient, payload)
      
      default:
        throw new Error(`Unknown action: ${action}`)
    }
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      }
    )
  }
})

async function processStorageUpload(supabaseClient: any, payload: any) {
  const { bucket, path } = payload
  
  // Download file from storage
  const { data: fileData, error: downloadError } = await supabaseClient
    .storage
    .from(bucket)
    .download(path)
  
  if (downloadError) throw downloadError
  
  // Parse JSON data
  const jsonData = JSON.parse(await fileData.text())
  
  // Insert into bronze table
  const { data, error } = await supabaseClient
    .from('bronze_edge_raw')
    .insert({
      device_id: jsonData.device_id || path.split('/')[3],
      captured_at: jsonData.timestamp || new Date().toISOString(),
      src_filename: path.split('/').pop(),
      payload: jsonData,
      source_type: 'edge_upload'
    })
  
  if (error) throw error
  
  // Move file to processed folder
  const processedPath = path.replace('/bronze/', '/processed/')
  await supabaseClient.storage
    .from(bucket)
    .move(path, processedPath)
  
  return new Response(
    JSON.stringify({ 
      success: true, 
      message: 'File processed successfully',
      bronze_id: data[0]?.id 
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}

async function validateAndIngest(supabaseClient: any, payload: any) {
  const { data, device_id, batch_id } = payload
  
  // Validate required fields
  const requiredFields = ['transaction_id', 'store_id', 'timestamp']
  const validation_errors = []
  
  for (const record of data) {
    for (const field of requiredFields) {
      if (!record[field]) {
        validation_errors.push({
          record_id: record.transaction_id,
          field,
          error: 'Missing required field'
        })
      }
    }
  }
  
  // Calculate data quality score
  const quality_score = 1 - (validation_errors.length / (data.length * requiredFields.length))
  
  // Insert into bronze with validation results
  const { data: insertedData, error } = await supabaseClient
    .from('bronze_edge_raw')
    .insert(
      data.map((record: any) => ({
        device_id,
        captured_at: record.timestamp,
        payload: record,
        batch_id,
        data_quality_score: quality_score,
        validation_flags: {
          has_errors: validation_errors.length > 0,
          error_count: validation_errors.length,
          errors: validation_errors
        }
      }))
    )
  
  if (error) throw error
  
  // Trigger silver processing if quality is good
  if (quality_score > 0.8) {
    await supabaseClient.rpc('process_bronze_to_silver', {
      p_batch_id: batch_id
    })
  }
  
  return new Response(
    JSON.stringify({ 
      success: true,
      records_processed: data.length,
      quality_score,
      validation_errors: validation_errors.length,
      silver_processing: quality_score > 0.8
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}

async function batchProcess(supabaseClient: any, payload: any) {
  const { start_date, end_date, source_bucket } = payload
  
  // List all files in date range
  const { data: files, error: listError } = await supabaseClient
    .storage
    .from(source_bucket)
    .list('scout/v1/bronze', {
      limit: 100,
      offset: 0
    })
  
  if (listError) throw listError
  
  const results = []
  
  for (const file of files) {
    if (file.name.endsWith('.json')) {
      try {
        const result = await processStorageUpload(supabaseClient, {
          bucket: source_bucket,
          path: `scout/v1/bronze/${file.name}`
        })
        results.push({ file: file.name, status: 'success' })
      } catch (error) {
        results.push({ file: file.name, status: 'error', error: error.message })
      }
    }
  }
  
  return new Response(
    JSON.stringify({ 
      success: true,
      files_processed: results.length,
      results
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}