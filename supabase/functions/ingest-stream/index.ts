import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Row = {
  id?: string;
  device_id?: string;
  ts?: string;
  payload: any;
  src_path?: string;
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-device-id',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { 
      status: 405, 
      headers: corsHeaders 
    });
  }

  // Basic auth: require an edge JWT (storage_uploader or similar)
  const auth = req.headers.get("authorization") || "";
  if (!auth.startsWith("Bearer ")) {
    return new Response("Unauthorized - Bearer token required", { 
      status: 401,
      headers: corsHeaders
    });
  }

  // Optional device hint
  const deviceId = req.headers.get("x-device-id") || "unknown";
  console.log(`Processing stream from device: ${deviceId}`);

  // Content-types supported
  const ct = (req.headers.get("content-type") || "").toLowerCase();
  const okCT = ct.includes("application/x-ndjson") || 
               ct.includes("application/jsonl") || 
               ct.includes("application/octet-stream") ||
               ct.includes("text/plain");
  
  if (!okCT) {
    return new Response("Use Content-Type: application/x-ndjson or application/jsonl", { 
      status: 415,
      headers: corsHeaders
    });
  }

  const supa = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  // Stream parser: split by newline and batch insert
  const reader = req.body?.getReader();
  if (!reader) {
    return new Response("No body", { 
      status: 400,
      headers: corsHeaders
    });
  }

  const decoder = new TextDecoder();
  let carry = "";
  const batch: Row[] = [];
  let linesSeen = 0, inserted = 0, errors = 0;

  async function flush() {
    if (!batch.length) return;
    
    const payload = batch.map((p) => ({
      id: p.id ?? crypto.randomUUID(),
      device_id: p.device_id ?? deviceId,
      captured_at: p.ts ?? new Date().toISOString(),
      src_filename: p.src_path ?? `stream:${deviceId}:${Date.now()}`,
      payload: p.payload,
      ingested_at: new Date().toISOString()
    }));
    
    console.log(`Flushing batch of ${payload.length} records from ${deviceId}`);
    
    const { error } = await supa.from("scout.bronze_edge_raw").insert(payload);
    if (error) {
      console.error("Insert error:", error);
      throw new Error(`Database insert failed: ${error.message}`);
    }
    
    inserted += payload.length;
    batch.length = 0;
  }

  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      
      carry += decoder.decode(value, { stream: true });
      const parts = carry.split(/\r?\n/);
      carry = parts.pop() ?? "";
      
      for (const ln of parts) {
        if (!ln.trim()) continue;
        
        try {
          const obj = JSON.parse(ln);
          batch.push({
            id: obj.id ?? obj.transaction_id,
            device_id: obj.device_id,
            ts: obj.ts ?? obj.timestamp ?? obj.created_at,
            payload: obj,
            src_path: `stream:${deviceId}`
          });
          linesSeen++;
          
          if (batch.length >= 100) { // Smaller batches for streaming
            await flush();
          }
        } catch (parseError) {
          console.warn(`Failed to parse line: ${ln.substring(0, 100)}...`);
          errors++;
        }
      }
    }
    
    // Handle any remaining data in carry
    if (carry.trim()) {
      try {
        const obj = JSON.parse(carry);
        batch.push({
          id: obj.id ?? obj.transaction_id,
          device_id: obj.device_id,
          ts: obj.ts ?? obj.timestamp ?? obj.created_at,
          payload: obj,
          src_path: `stream:${deviceId}`
        });
        linesSeen++;
      } catch (parseError) {
        console.warn(`Failed to parse final chunk: ${carry.substring(0, 100)}...`);
        errors++;
      }
    }
    
    await flush();

    console.log(`Stream processing complete: ${linesSeen} lines, ${inserted} inserted, ${errors} errors`);

    return new Response(JSON.stringify({ 
      success: true,
      device_id: deviceId,
      lines_seen: linesSeen, 
      inserted,
      errors,
      timestamp: new Date().toISOString()
    }), {
      status: 200, 
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
    
  } catch (e) {
    console.error("Stream processing error:", e);
    return new Response(JSON.stringify({ 
      success: false,
      error: String(e), 
      device_id: deviceId,
      lines_seen: linesSeen, 
      inserted,
      errors
    }), { 
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
});