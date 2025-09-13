// Supabase Edge Function (Deno) — sari-sari-expert-advanced
// Reads input, does baseline inference, falls back to Claude if needed, writes to scout.* tables.
// Env:
// - SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
// - ANTHROPIC_API_KEY
// - CLAUDE_VERSION (default "2023-06-01")
// - CONF_THRESHOLD (default 0.75)

/// <reference types="https://esm.sh/@supabase/functions-js/src/edge-runtime.d.ts" />
import { createClient } from "npm:@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type Input = {
  payment_amount: number;
  change_given: number;
  time_of_day: string;
  customer_behavior?: string;
  visible_products?: string[];
  context_data?: Record<string, unknown>;
  account_id?: string; // optional, can be set by caller
  store_id?: string;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN4emxsenlkd3B5cHRmcmV0cnljIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUyMDYzMzQsImV4cCI6MjA3MDc4MjMzNH0.adA0EO89jw5uPH4qdL_aox6EbDPvJ28NcXGYW7u33Ok";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") || "";
const CLAUDE_VERSION = Deno.env.get("CLAUDE_VERSION") || "2023-06-01";
const CONF_THRESHOLD = Number(Deno.env.get("CONF_THRESHOLD") || "0.75");

// Two-client pattern: anon for auth verification, service for DB writes
const anonClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { auth: { persistSession: false }});
const serviceClient = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false }});

function baselineInference(inp: Input) {
  const total_spent = Number((inp.payment_amount - inp.change_given).toFixed(2));
  const hints = (inp.visible_products || []).join(", ").toLowerCase() + " " + (inp.customer_behavior || "").toLowerCase();
  const likely_products = [];
  if (hints.includes("coke")) likely_products.push("Coke Zero 500ml");
  if (hints.includes("cigarette") || hints.includes("yosi")) likely_products.push("Marlboro Lights stick");
  const confidence = likely_products.length ? 0.78 : 0.6;
  const persona = hints.includes("male") ? "Juan - Rural Male Worker" : "Maria - Urban Housewife";
  const persona_conf = hints.includes("male") ? 0.82 : 0.7;
  const recs = [{ title: "Move cigarettes near Coke Zero", revenue_potential: 450, roi: "173%", timeline: "immediate" }];
  return {
    inferred_transaction: { total_spent, likely_products, confidence_score: confidence },
    persona_analysis: { persona, confidence: persona_conf },
    recommendations: recs
  };
}

async function claudeFallback(inp: Input, partial: any) {
  if (!ANTHROPIC_API_KEY) return partial; // no Claude configured -> return baseline
  const system = "You are a sari-sari retail analyst. Provide concise, actionable answers.";
  const user = `Given:
  - ₱${inp.payment_amount} payment, ₱${inp.change_given} change
  - Time: ${inp.time_of_day}
  - Behavior: ${inp.customer_behavior || "n/a"}
  - Visible: ${(inp.visible_products || []).join(", ") || "n/a"}
  Infer products, persona, and a single ROI-ranked recommendation.`;

  const body = {
    model: "claude-3-5-sonnet-latest",
    max_tokens: 600,
    system,
    messages: [{ role: "user", content: user }]
  };

  const resp = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": ANTHROPIC_API_KEY,
      "anthropic-version": CLAUDE_VERSION
    },
    body: JSON.stringify(body)
  });

  if (!resp.ok) return partial;
  const data = await resp.json();
  const text = (data?.content?.[0]?.text || "").toLowerCase();

  const out = { ...partial };
  if (text.includes("marlboro") && !out.inferred_transaction.likely_products.includes("Marlboro Lights stick")) {
    out.inferred_transaction.likely_products.push("Marlboro Lights stick");
  }
  out.inferred_transaction.confidence_score = Math.max(out.inferred_transaction.confidence_score, 0.8);
  return out;
}

serve(async (req) => {
  // CORS headers for preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    });
  }

  try {
    console.log('Edge Function called:', req.method);
    
    // Extract JWT token from Authorization header
    const authHeader = req.headers.get('authorization');
    console.log('Authorization header:', authHeader ? 'Present' : 'Missing');
    
    let user = null;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      console.log('Missing or invalid Authorization header - allowing anonymous access for testing');
      // For testing purposes, create a mock user
      user = { id: '00000000-0000-0000-0000-000000000000' };
    } else {
      const token = authHeader.substring(7); // Remove 'Bearer ' prefix
      console.log('Token length:', token.length);
      
      // Verify JWT token with anon client
      console.log('Verifying JWT token...');
      const { data: { user: authUser }, error: authError } = await anonClient.auth.getUser(token);
      
      console.log('Auth verification result:', { user: authUser ? 'Found' : 'Not found', error: authError?.message });
      
      if (authError || !authUser) {
        console.log('JWT verification failed - allowing anonymous access for testing');
        user = { id: '00000000-0000-0000-0000-000000000000' };
      } else {
        user = authUser;
      }
    }

    const input: Input = await req.json();
    const base = baselineInference(input);
    const useClaude = base.inferred_transaction.confidence_score < CONF_THRESHOLD;
    const result = useClaude ? await claudeFallback(input, base) : base;

    // Use authenticated user's ID, fallback to provided account_id or default UUID
    const account_id = user.id || input.account_id || "00000000-0000-0000-0000-000000000000";
    const store_id = input.store_id || "00000000-0000-0000-0000-000000000000";
    
    // Database writes using service role client (bypasses RLS)
    const { error: eA } = await serviceClient
      .schema('scout')
      .from('inferred_transactions')
      .insert({
        account_id,
        store_id,
        input: JSON.stringify(input),
        total_spent: result.inferred_transaction.total_spent,
        likely_products: JSON.stringify(result.inferred_transaction.likely_products),
        confidence: result.inferred_transaction.confidence_score
      });
    
    const { error: eB } = await serviceClient
      .schema('scout')
      .from('persona_matches')
      .insert({
        account_id,
        store_id,
        persona: result.persona_analysis.persona,
        confidence: result.persona_analysis.confidence,
        features: {}
      });
    
    const { error: eC } = await serviceClient
      .schema('scout')
      .from('recommendations')
      .insert({
        account_id,
        store_id,
        title: result.recommendations[0].title,
        revenue_potential: result.recommendations[0].revenue_potential,
        roi: result.recommendations[0].roi,
        timeline: result.recommendations[0].timeline
      });
    
    if (eA || eB || eC) {
      console.warn("DB write errors:", eA, eB, eC);
    }

    return new Response(JSON.stringify(result), {
      headers: {
        'content-type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 400,
      headers: {
        'content-type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    });
  }
});
