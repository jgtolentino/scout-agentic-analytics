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

    const { action, payload } = await req.json().catch(() => ({ action: 'process-real-zip', payload: {} }));

    switch (action) {
      case 'process-real-zip':
        return await processRealZip(supabaseClient, payload);
      
      case 'get-real-stats':
        return await getRealStats(supabaseClient);
      
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

async function processRealZip(supabaseClient: any, payload: any) {
  const zipPath = payload.zipPath || 'edge-inbox/json.zip';
  
  // Download the actual ZIP file from storage
  const { data: zipFile, error: downloadError } = await supabaseClient
    .storage
    .from('scout-ingest')
    .download(zipPath);
  
  if (downloadError) throw downloadError;

  // Get ZIP file as ArrayBuffer for processing
  const zipArrayBuffer = await zipFile.arrayBuffer();
  const zipBytes = new Uint8Array(zipArrayBuffer);
  
  console.log(`Downloaded ZIP: ${zipBytes.length} bytes`);

  // For Deno, we'll use the standard ZIP library
  // Import ZIP processing capability
  const { readZip } = await import("https://deno.land/x/jszip@0.11.0/mod.ts");
  
  let processed = 0;
  let errors = 0;
  const results = [];
  
  try {
    // Read ZIP file contents
    const zip = await readZip(zipBytes);
    
    console.log(`ZIP contains ${Object.keys(zip.files).length} files`);
    
    // Process each JSON file in the ZIP
    for (const [fileName, file] of Object.entries(zip.files)) {
      if (!fileName.endsWith('.json')) continue;
      if (file.dir) continue; // Skip directories
      
      try {
        // Extract file content
        const content = await file.async('text');
        const jsonData = JSON.parse(content);
        
        // Determine device ID from file path
        let deviceId = 'unknown';
        if (fileName.includes('scoutpi-0002')) deviceId = 'scoutpi-0002';
        if (fileName.includes('scoutpi-0006')) deviceId = 'scoutpi-0006';
        
        // Create record for bronze layer
        const record = {
          id: jsonData.transaction_id || `${deviceId}-${fileName.replace('.json', '').replace(/[^a-zA-Z0-9-]/g, '-')}`,
          device_id: deviceId,
          captured_at: jsonData.timestamp || jsonData.created_at || new Date().toISOString(),
          src_filename: fileName,
          payload: jsonData
        };
        
        // Insert into bronze table
        const { error: insertError } = await supabaseClient
          .from('scout.bronze_edge_raw')
          .upsert(record, { onConflict: 'id' });
        
        if (!insertError) {
          processed++;
          if (processed <= 10) {
            results.push({ file: fileName, status: 'success', id: record.id });
          }
        } else {
          errors++;
          if (results.length <= 10) {
            results.push({ file: fileName, status: 'error', error: insertError.message });
          }
        }
        
        // Progress logging every 100 files
        if (processed % 100 === 0) {
          console.log(`Processed ${processed} files so far...`);
        }
        
      } catch (fileError) {
        errors++;
        if (results.length <= 10) {
          results.push({ file: fileName, status: 'error', error: fileError.message });
        }
      }
    }
    
    console.log(`Processing complete: ${processed} success, ${errors} errors`);
    
    return new Response(
      JSON.stringify({ 
        success: true,
        message: `Processed Eugene's real ZIP file`,
        total_files_in_zip: Object.keys(zip.files).filter(f => f.endsWith('.json')).length,
        records_processed: processed,
        errors: errors,
        sample_results: results
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
    
  } catch (zipError) {
    throw new Error(`ZIP processing failed: ${zipError.message}`);
  }
}

async function getRealStats(supabaseClient: any) {
  try {
    // Get actual counts from database
    const { count: bronzeCount, error: bronzeError } = await supabaseClient
      .from('scout.bronze_edge_raw')
      .select('*', { count: 'exact', head: true });

    const { data: deviceCounts, error: deviceError } = await supabaseClient
      .from('scout.bronze_edge_raw')
      .select('device_id')
      .limit(1000);

    // Count by device
    const devices = {};
    if (deviceCounts) {
      for (const row of deviceCounts) {
        const device = row.device_id || 'unknown';
        devices[device] = (devices[device] || 0) + 1;
      }
    }

    // Get recent files
    const { data: recentFiles } = await supabaseClient
      .from('scout.bronze_edge_raw')
      .select('device_id, src_filename, ingested_at')
      .order('ingested_at', { ascending: false })
      .limit(5);

    return new Response(
      JSON.stringify({
        success: true,
        total_bronze_records: bronzeCount || 0,
        devices: devices,
        recent_files: recentFiles || [],
        bronze_error: bronzeError?.message
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ 
        success: false,
        error: error.message
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
}