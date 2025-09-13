import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  try {
    // CORS handling
    if (req.method === 'OPTIONS') {
      return new Response(null, {
        status: 200,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        },
      })
    }

    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const body = await req.json()
    
    // Simulate Google JSON payload processing
    const payload = {
      id: Date.now(),
      payload_type: body.type || 'product_feed',
      raw_payload: body,
      extracted_fields: {
        products_count: body.products?.length || 0,
        categories: ['electronics', 'clothing', 'home'],
        timestamp: new Date().toISOString(),
      },
      created_at: new Date().toISOString(),
      processed: true,
      matched: true,
      match_reason: 'valid_product_schema',
    }

    return new Response(JSON.stringify({
      message: 'Google JSON payload processed',
      payload,
      status: 'success',
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    })
  }
})