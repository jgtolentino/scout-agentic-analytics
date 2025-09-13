import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  try {
    const body = await req.json()
    // TODO: route to template executor (write result to generated_insights)
    return new Response(JSON.stringify({ ok: true, template_id: body?.template_id ?? null }), {
      headers: { "content-type": "application/json" }
    })
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 400 })
  }
})