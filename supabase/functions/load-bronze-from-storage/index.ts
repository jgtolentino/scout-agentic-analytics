import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const { action, payload } = await req.json().catch(() => ({ action: 'load-from-storage', payload: {} }));

    switch (action) {
      case 'load-from-storage':
        return await loadFromStorage(supabaseClient, payload);
      
      case 'process-batch':
        return await processBatch(supabaseClient, payload);
      
      case 'get-storage-stats':
        return await getStorageStats(supabaseClient);
      
      default:
        throw new Error(`Unknown action: ${action}`);
    }
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      }
    );
  }
});

async function loadFromStorage(supabaseClient: any, payload: any) {
  const { bucketName = 'scout-ingest', filePath, batchSize = 100 } = payload;
  
  // List files in storage
  const { data: files, error: listError } = await supabaseClient
    .storage
    .from(bucketName)
    .list('', {
      limit: batchSize,
      sortBy: { column: 'created_at', order: 'asc' }
    });

  if (listError) throw listError;

  let processed = 0;
  const results = [];

  for (const file of files || []) {
    if (!file.name.endsWith('.json')) continue;

    try {
      // Download file
      const { data: fileData, error: downloadError } = await supabaseClient
        .storage
        .from(bucketName)
        .download(file.name);

      if (downloadError) throw downloadError;

      // Parse JSON content
      const content = await fileData.text();
      const jsonData = JSON.parse(content);

      // Insert into bronze layer
      const { error: insertError } = await supabaseClient
        .from('scout.bronze_edge_raw')
        .upsert({
          id: jsonData.transaction_id || `storage-${file.name.replace('.json', '')}`,
          device_id: jsonData.device_id || 'storage-import',
          captured_at: jsonData.timestamp || file.created_at,
          src_filename: file.name,
          payload: jsonData
        });

      if (!insertError) {
        processed++;
        results.push({ file: file.name, status: 'success' });
        
        // Optionally delete processed file
        if (payload.deleteAfterProcessing) {
          await supabaseClient.storage.from(bucketName).remove([file.name]);
        }
      } else {
        results.push({ file: file.name, status: 'error', error: insertError.message });
      }
    } catch (e) {
      results.push({ file: file.name, status: 'error', error: e.message });
    }
  }

  return new Response(
    JSON.stringify({ 
      success: true,
      processed,
      total_files: files?.length || 0,
      results: results.slice(0, 10) // Limit response size
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

async function processBatch(supabaseClient: any, payload: any) {
  const { limit = 1000 } = payload;
  
  // Process bronze to silver
  const { data: processed, error } = await supabaseClient
    .rpc('scout.process_bronze_to_silver');

  if (error) throw error;

  return new Response(
    JSON.stringify({ 
      success: true,
      silver_processed: processed || 0
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

async function getStorageStats(supabaseClient: any) {
  const { data: files, error } = await supabaseClient
    .storage
    .from('scout-ingest')
    .list('');

  if (error) throw error;

  const jsonFiles = files?.filter(f => f.name.endsWith('.json')) || [];
  const totalSize = jsonFiles.reduce((sum, file) => sum + (file.metadata?.size || 0), 0);

  return new Response(
    JSON.stringify({
      total_files: files?.length || 0,
      json_files: jsonFiles.length,
      total_size_bytes: totalSize,
      recent_files: jsonFiles.slice(-5).map(f => ({
        name: f.name,
        created_at: f.created_at,
        size: f.metadata?.size
      }))
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}