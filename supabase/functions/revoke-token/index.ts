import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ADMIN_API_KEY = Deno.env.get("ADMIN_API_KEY")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });
const json = (s: number, b: unknown) => new Response(JSON.stringify(b), { status: s, headers: { "content-type": "application/json" } });

Deno.serve(async (req) => {
  if (req.headers.get("x-admin-api-key") !== ADMIN_API_KEY) return json(403, { error: "forbidden" });
  const b = await req.json().catch(() => null) as { jti?: string; email?: string; reason?: string } | null;
  if (!b?.jti) return json(400, { error: "missing_jti" });
  const { error } = await supabase.rpc("revoke_token", { _jti: b.jti, _email: b.email ?? null, _reason: b.reason ?? null });
  if (error) return json(500, { error: "revoke_failed", detail: error.message });
  return json(200, { ok: true, jti: b.jti });
});