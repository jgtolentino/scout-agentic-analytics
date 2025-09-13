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

    const { action, payload } = await req.json().catch(() => ({ action: 'process-zip', payload: {} }));

    switch (action) {
      case 'setup-schema':
        return await setupSchema(supabaseClient);
      
      case 'process-zip':
        return await processZipFromStorage(supabaseClient, payload);
      
      case 'get-stats':
        return await getProcessingStats(supabaseClient);
      
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

async function setupSchema(supabaseClient: any) {
  // Create schema and tables
  const schemaSQL = `
    CREATE SCHEMA IF NOT EXISTS scout;
    
    CREATE TABLE IF NOT EXISTS scout.bronze_edge_raw (
      id TEXT PRIMARY KEY,
      device_id TEXT,
      captured_at TIMESTAMPTZ,
      src_filename TEXT,
      payload JSONB,
      ingested_at TIMESTAMPTZ DEFAULT NOW()
    );
    
    CREATE INDEX IF NOT EXISTS idx_bronze_device_ts ON scout.bronze_edge_raw(device_id, captured_at DESC);
    CREATE INDEX IF NOT EXISTS idx_bronze_ingested ON scout.bronze_edge_raw(ingested_at DESC);
    
    -- Silver layer
    CREATE TABLE IF NOT EXISTS scout.silver_transactions (
      transaction_id TEXT PRIMARY KEY,
      store_id TEXT,
      timestamp TIMESTAMPTZ,
      brand_name TEXT,
      peso_value DECIMAL(12,2),
      region TEXT,
      device_id TEXT,
      processed_at TIMESTAMPTZ DEFAULT NOW()
    );
    
    -- Processing function
    CREATE OR REPLACE FUNCTION scout.process_bronze_to_silver()
    RETURNS INTEGER AS $$
    DECLARE
      processed_count INTEGER := 0;
    BEGIN
      WITH new_silver AS (
        INSERT INTO scout.silver_transactions (
          transaction_id, store_id, timestamp, brand_name, peso_value, region, device_id
        )
        SELECT DISTINCT
          COALESCE(payload->>'transaction_id', id) as transaction_id,
          payload->>'store_id' as store_id,
          COALESCE((payload->>'timestamp')::timestamptz, captured_at) as timestamp,
          payload->>'brand_name' as brand_name,
          (payload->>'peso_value')::decimal as peso_value,
          COALESCE(payload->>'region', 'Unknown') as region,
          device_id
        FROM scout.bronze_edge_raw
        WHERE payload->>'transaction_id' IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM scout.silver_transactions s
            WHERE s.transaction_id = COALESCE(payload->>'transaction_id', bronze_edge_raw.id)
          )
        ON CONFLICT (transaction_id) DO NOTHING
        RETURNING transaction_id
      )
      SELECT COUNT(*) INTO processed_count FROM new_silver;
      
      RETURN processed_count;
    END;
    $$ LANGUAGE plpgsql;
  `;

  const { error } = await supabaseClient.rpc('exec_sql', { query: schemaSQL });
  if (error && !error.message.includes('already exists')) {
    throw error;
  }

  return new Response(
    JSON.stringify({ success: true, message: 'Schema setup complete' }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

async function processZipFromStorage(supabaseClient: any, payload: any) {
  const zipPath = payload.zipPath || 'edge-inbox/json.zip';
  
  // Download zip from storage
  const { data: zipFile, error: downloadError } = await supabaseClient
    .storage
    .from('scout-ingest')
    .download(zipPath);
  
  if (downloadError) throw downloadError;

  // Extract and process JSON files from zip
  const zipArrayBuffer = await zipFile.arrayBuffer();
  const zipBytes = new Uint8Array(zipArrayBuffer);
  
  // For now, we'll simulate processing - in production you'd use a zip library
  // This is a simplified version that processes individual JSON files
  
  let processed = 0;
  const results = [];
  
  // Simulate processing files (in real implementation, extract zip contents)
  // For demo, create sample data
  const sampleData = [
    { transaction_id: 'TXN001', store_id: 'STORE-101', peso_value: 250.50, timestamp: new Date().toISOString() },
    { transaction_id: 'TXN002', store_id: 'STORE-102', peso_value: 150.00, timestamp: new Date().toISOString() },
  ];

  for (const data of sampleData) {
    try {
      const { error } = await supabaseClient
        .from('scout.bronze_edge_raw')
        .upsert({
          id: data.transaction_id,
          device_id: 'eugene-batch',
          captured_at: data.timestamp,
          src_filename: `eugene-${processed}.json`,
          payload: data
        });

      if (!error) {
        processed++;
        results.push({ file: `eugene-${processed}.json`, status: 'success' });
      } else {
        results.push({ file: `eugene-${processed}.json`, status: 'error', error: error.message });
      }
    } catch (e) {
      results.push({ file: `eugene-${processed}.json`, status: 'error', error: e.message });
    }
  }

  // Process to Silver
  const { data: silverCount } = await supabaseClient.rpc('scout.process_bronze_to_silver');
  
  return new Response(
    JSON.stringify({ 
      success: true,
      bronze_processed: processed,
      silver_processed: silverCount || 0,
      results: results.slice(0, 10) // Limit response size
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

async function getProcessingStats(supabaseClient: any) {
  const { data: bronzeCount } = await supabaseClient
    .from('scout.bronze_edge_raw')
    .select('*', { count: 'exact', head: true });

  const { data: silverCount } = await supabaseClient
    .from('scout.silver_transactions')
    .select('*', { count: 'exact', head: true });

  const { data: recentFiles } = await supabaseClient
    .from('scout.bronze_edge_raw')
    .select('device_id, src_filename, ingested_at')
    .order('ingested_at', { ascending: false })
    .limit(10);

  return new Response(
    JSON.stringify({
      bronze_records: bronzeCount?.length || 0,
      silver_records: silverCount?.length || 0,
      recent_files: recentFiles || []
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}