Use in any ingestion function:

import { verifySignatureAsync } from "../_common/guard.ts";
const { ok, reason } = await verifySignatureAsync(req, Deno.env.get("PIPELINE_SIGNING_KEY")!);
if (!ok) return new Response(JSON.stringify({ error:"unauthorized", reason }), { status:401 });
