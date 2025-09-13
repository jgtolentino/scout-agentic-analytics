// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Ajv from "https://esm.sh/ajv@8"; 
import addFormats from "https://esm.sh/ajv-formats@2";

const ajv = new Ajv({ allErrors: true, strict: false }); 
addFormats(ajv);
const schema = JSON.parse(await Deno.readTextFile(new URL("./schema.json", import.meta.url)));
const validate = ajv.compile(schema);

serve(async (req) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  
  const auth = req.headers.get("authorization") ?? "";
  if (!auth.toLowerCase().startsWith("bearer ")) return new Response("Unauthorized", { status: 401 });
  
  const payload = await req.json().catch(() => null);
  if (!payload || !validate(payload)) {
    return new Response(JSON.stringify({ error: "schema", details: validate.errors }), { 
      status: 400, 
      headers: { "content-type": "application/json" }
    });
  }
  
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!, 
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, 
    { auth: { persistSession: false }}
  );
  
  // Write transaction header
  const { error: txErr } = await supabase.from("scout_gold_transactions").insert({
    transaction_id: payload.transaction_id, 
    store_id: payload.store.id, 
    tz_offset_min: payload.store.tz_offset_min,
    ts_utc: payload.ts_utc, 
    tx_start_ts: payload.tx_start_ts, 
    tx_end_ts: payload.tx_end_ts,
    request_type: payload.request.request_type, 
    request_mode: payload.request.request_mode, 
    payment_method: payload.request.payment_method,
    gender: payload.request.gender, 
    age_bracket: payload.request.age_bracket,
    region_id: payload.geo.region_id, 
    city_id: payload.geo.city_id, 
    barangay_id: payload.geo.barangay_id,
    suggestion_offered: payload.suggestion?.offered ?? null, 
    suggestion_accepted: payload.suggestion?.accepted ?? null,
    asked_brand_id: payload.substitution?.asked_brand_id ?? null, 
    final_brand_id: payload.substitution?.final_brand_id ?? null,
    transaction_amount: payload.amounts?.transaction_amount ?? null, 
    price_source: payload.amounts?.price_source ?? null,
    raw: payload
  });
  
  if (txErr) return new Response(JSON.stringify({ error: txErr.message }), { status: 500 });

  // Write items
  const items = (payload.items || []).map((i: any) => ({
    transaction_id: payload.transaction_id, 
    category_id: i.category_id ?? null, 
    category_name: i.category_name,
    brand_id: i.brand_id ?? null, 
    brand_name: i.brand_name ?? null, 
    product_name: i.product_name,
    local_name: i.local_name ?? null, 
    qty: i.qty, 
    unit: i.unit ?? "pc", 
    unit_price: i.unit_price ?? null,
    total_price: i.total_price ?? null, 
    detection_method: i.detection_method, 
    confidence: i.confidence
  }));
  
  const { error: itErr } = await supabase.from("scout_gold_transaction_items").insert(items);
  if (itErr) return new Response(JSON.stringify({ error: itErr.message }), { status: 500 });

  // Sidecar: decision trace and transcripts
  const trace = (payload as any).decision_trace;
  if (trace) {
    // Store full trace
    await supabase.from("edge_decision_trace").insert({ 
      transaction_id: payload.transaction_id, 
      trace 
    });
    
    // Extract and store conversation turns if present
    const turns = trace?.stt?.turns as Array<any> | undefined;
    if (Array.isArray(turns) && turns.length) {
      const rows = turns.map(t => ({
        transaction_id: payload.transaction_id,
        t_seconds: Number(t.t ?? 0),
        speaker: String(t.speaker ?? 'unknown').slice(0,16),
        text: String(t.text ?? '')
      }));
      await supabase.from("staging_transcripts").insert(rows).catch(() => {});
    }
  }
  
  return new Response(JSON.stringify({ ok: true }), { 
    headers: { "content-type": "application/json" }
  });
});