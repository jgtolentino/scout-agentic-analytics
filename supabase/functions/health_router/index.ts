import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
serve(() => new Response(JSON.stringify({ ok:true, ts:new Date().toISOString() }),{headers:{'Content-Type':'application/json'}}));
