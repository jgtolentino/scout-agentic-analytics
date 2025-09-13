// 🚀 AUTO-TRIGGER ETL SYSTEM FOR SCOUT-INGEST UPLOADS
// Automatically processes any new data uploaded to scout-ingest bucket

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

interface StorageWebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE';
  table: string;
  record: {
    name: string;
    bucket_id: string;
    owner: string;
    created_at: string;
    updated_at: string;
    last_accessed_at: string;
    metadata: any;
  };
  schema: string;
  old_record?: any;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405, headers: corsHeaders });
  }

  try {
    // Handle both webhook payloads and manual triggers
    let payload: StorageWebhookPayload;
    
    try {
      payload = await req.json();
    } catch (e) {
      return new Response(JSON.stringify({ error: 'Invalid JSON payload' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
    console.log('🔔 Storage webhook triggered:', payload);

    // Only process INSERT events (new files)
    if (payload.type !== 'INSERT') {
      return new Response(JSON.stringify({ skipped: true, reason: 'Not an INSERT event' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Only process files in scout-ingest bucket
    if (payload.record.bucket_id !== 'scout-ingest') {
      return new Response(JSON.stringify({ skipped: true, reason: 'Not scout-ingest bucket' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const fileName = payload.record.name;
    const fileSize = payload.record.metadata?.size || 0;
    
    console.log(`📁 Processing new file: ${fileName} (${fileSize} bytes)`);

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // Determine processing strategy based on file type
    let processingResult;
    
    if (fileName.endsWith('.zip')) {
      // 📦 Process ZIP files (like Eugene's 720KB data)
      console.log(`🔄 Processing ZIP file: ${fileName}`);
      processingResult = await processZipFile(supabase, fileName);
      
    } else {
      // ⏭️ Skip unsupported file types for now
      console.log(`⏭️ Skipping unsupported file: ${fileName}`);
      return new Response(JSON.stringify({ 
        skipped: true, 
        reason: `Unsupported file type: ${fileName}` 
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // 📊 Log the processing event
    console.log(`✅ Processing complete for ${fileName}:`, processingResult);

    return new Response(JSON.stringify({
      success: true,
      fileName,
      fileSize,
      processingResult,
      timestamp: new Date().toISOString()
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('❌ Storage webhook error:', error);
    return new Response(JSON.stringify({ 
      success: false, 
      error: error.message 
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});

// 📦 Process ZIP files (Eugene's data format)
async function processZipFile(supabase: any, fileName: string) {
  try {
    console.log(`🔧 Calling process-eugene-data for ${fileName}`);
    
    // Call our existing process-eugene-data function
    const response = await fetch(
      `${Deno.env.get('SUPABASE_URL')}/functions/v1/process-eugene-data`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`
        },
        body: JSON.stringify({
          action: 'process-zip',
          payload: { zipPath: fileName }
        })
      }
    );

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`ZIP processing failed: ${response.status} - ${errorText}`);
    }

    const result = await response.json();
    
    return {
      success: true,
      recordsProcessed: result.bronze_processed || 0,
      silverProcessed: result.silver_processed || 0,
      method: 'zip_extraction',
      details: result
    };

  } catch (error) {
    return {
      success: false,
      error: error.message,
      method: 'zip_extraction'
    };
  }
}