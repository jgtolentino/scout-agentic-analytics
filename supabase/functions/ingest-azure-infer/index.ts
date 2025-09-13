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
    
    // Simulate Azure inference processing
    const inference = {
      id: Date.now(),
      input_text: body.input_text || 'sample text',
      inference_result: {
        brand: 'Nike',
        product: 'Running Shoes',
        category: 'Sportswear',
        confidence: 0.95,
      },
      confidence_score: 0.95,
      model_version: 'azure-v1.0',
      created_at: new Date().toISOString(),
      matched: true,
      match_reason: 'high_confidence_brand_match',
    }

    return new Response(JSON.stringify({
      message: 'Azure inference processed',
      inference,
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