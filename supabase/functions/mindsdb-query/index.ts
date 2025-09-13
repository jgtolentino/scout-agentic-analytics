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
          'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-MDB-KEY',
        },
      })
    }

    const mdbKey = req.headers.get('X-MDB-KEY')
    if (!mdbKey) {
      return new Response(JSON.stringify({ error: 'MindsDB key required' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const body = await req.json()
    const query = body.query || 'SHOW DATABASES;'
    
    // Simulate MindsDB query result
    const result = {
      query,
      columns: ['Database'],
      data: [
        ['mindsdb'],
        ['information_schema'],
        ['scout_forecasts'],
      ],
      execution_time_ms: 45,
      status: 'success',
    }

    return new Response(JSON.stringify({
      message: 'MindsDB query executed',
      result,
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