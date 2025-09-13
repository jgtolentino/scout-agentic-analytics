import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SRK = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const sb = createClient(SUPABASE_URL, SRK, { auth: { persistSession: false } });

serve(async (req) => {
  try {
    // Optional: require a secret header
    const auth = req.headers.get("x-sentinel-key");
    const expectedKey = Deno.env.get("SENTINEL_KEY");
    
    if (expectedKey && (!auth || auth !== expectedKey)) {
      return new Response("Unauthorized", { status: 401 });
    }

    // Call the quality summary function
    const { data: summary, error: e1 } = await sb.rpc("suqi_get_quality_summary", {});
    if (e1) {
      console.error("Quality summary error:", e1);
      return new Response(JSON.stringify({ 
        ok: false, 
        error: "Failed to get quality summary",
        details: e1.message 
      }), { 
        status: 500, 
        headers: { "content-type": "application/json" }
      });
    }

    // Call the confusion data function
    const { data: confusion, error: e2 } = await sb.rpc("suqi_get_confusion_today", {});
    if (e2) {
      console.error("Confusion data error:", e2);
      return new Response(JSON.stringify({ 
        ok: false, 
        error: "Failed to get confusion data",
        details: e2.message 
      }), { 
        status: 500, 
        headers: { "content-type": "application/json" }
      });
    }

    return new Response(JSON.stringify({ 
      ok: true, 
      summary, 
      confusion 
    }), { 
      headers: { "content-type": "application/json" }
    });

  } catch (error) {
    console.error("Quality sentinel error:", error);
    return new Response(JSON.stringify({ 
      ok: false, 
      error: String(error?.message ?? error) 
    }), { 
      status: 500, 
      headers: { "content-type": "application/json" }
    });
  }
});