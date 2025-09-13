import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

function b64urlDecode(s:string) {
  s = s.replace(/-/g,'+').replace(/_/g,'/'); const pad = s.length % 4; if (pad) s += '='.repeat(4-pad);
  return new TextDecoder().decode(Uint8Array.from(atob(s), c => c.charCodeAt(0)));
}

serve(async (req) => {
  try {
    const auth = req.headers.get("authorization") || "";
    const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
    if (!token) return new Response(JSON.stringify({ error: "No Bearer token" }), { status: 400 });

    const parts = token.split(".");
    if (parts.length !== 3) return new Response(JSON.stringify({ error: "Malformed JWT" }), { status: 400 });

    const header = JSON.parse(b64urlDecode(parts[0]));
    const payload = JSON.parse(b64urlDecode(parts[1]));
    return new Response(JSON.stringify({ ok: true, header, payload }, null, 2), { headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { "content-type": "application/json" } });
  }
});