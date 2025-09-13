/** Shared guard for Supabase Edge (Deno). */
export function verifySignature(req: Request, key: string) {
  const sig = req.headers.get("X-Signature") || "";
  const ts  = req.headers.get("X-Signature-Timestamp") || "";
  const idem= req.headers.get("X-Idempotency-Key") || "";
  if (!sig || !ts) return { ok:false, reason:"missing signature" };

  const url = new URL(req.url);
  const base = [req.method, url.pathname, ts, idem].join("\n");
  const mac = new Uint8Array(
    crypto.subtle.sign("HMAC", crypto.subtle.importKey("raw", new TextEncoder().encode(key), {name:"HMAC", hash:"SHA-256"}, false, ["sign"]), new TextEncoder().encode(base))
      .then(buf => new Uint8Array(buf))
  );
  // NOTE: Deno can't await in non-async; tiny helper:
  // caller must await verifySignatureAsync instead (below).
  throw new Error("Use verifySignatureAsync");
}
export async function verifySignatureAsync(req: Request, key: string) {
  const sig = req.headers.get("X-Signature") || "";
  const ts  = req.headers.get("X-Signature-Timestamp") || "";
  const idem= req.headers.get("X-Idempotency-Key") || "";
  if (!sig || !ts) return { ok:false, reason:"missing signature" };

  const url = new URL(req.url);
  const base = [req.method, url.pathname, ts, idem].join("\n");
  const keyData = await crypto.subtle.importKey("raw", new TextEncoder().encode(key), {name:"HMAC", hash:"SHA-256"}, false, ["sign"]);
  const raw = await crypto.subtle.sign("HMAC", keyData, new TextEncoder().encode(base));
  const exp = Array.from(new Uint8Array(raw)).map(b=>b.toString(16).padStart(2,"0")).join("");
  const ok = crypto.timingSafeEqual(new TextEncoder().encode(exp), new TextEncoder().encode(sig));
  return { ok, reason: ok ? "" : "bad signature" };
}
