import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as jose from "https://esm.sh/jose@5";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SUPABASE_JWT_SECRET = Deno.env.get("SUPABASE_JWT_SECRET")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });
const json = (s: number, b: unknown) => new Response(JSON.stringify(b), { status: s, headers: { "content-type": "application/json" } });

Deno.serve(async (req) => {
  try {
    const auth = req.headers.get("authorization") || "";
    const token = auth.toLowerCase().startsWith("bearer ") ? auth.slice(7).trim() : null;
    if (!token) return json(401, { error: "missing_bearer" });

    const { payload } = await jose.jwtVerify(token, new TextEncoder().encode(SUPABASE_JWT_SECRET), {
      algorithms: ["HS256"],
      audience: "authenticated",
    });

    const jti = (payload as any)?.jti;
    if (!jti) return json(400, { error: "missing_jti" });

    const { data, error } = await supabase.from("security.revoked_tokens").select("jti").eq("jti", jti).maybeSingle();
    if (error) return json(500, { error: "revocation_check_failed", detail: error.message });
    if (data) return json(403, { error: "revoked_token" });

    return json(200, { ok: true, payload });
  } catch (e) {
    const msg = String(e?.message || e);
    if (msg.includes("exp")) return json(401, { error: "expired" });
    if (msg.includes("audience")) return json(401, { error: "bad_audience" });
    if (msg.includes("signature")) return json(401, { error: "bad_signature" });
    return json(400, { error: "bad_token", detail: msg });
  }
});