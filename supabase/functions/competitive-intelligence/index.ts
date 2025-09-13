import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    console.log('Competitive Intelligence: Fetching comprehensive bundle...')

    // Get comprehensive competitive intelligence data using scout schema
    const { data, error } = await supabase.rpc('execute_sql', {
      query: `
        WITH latest_data AS (
          SELECT 
            MAX(transaction_date) as latest_date,
            MIN(transaction_date) as earliest_date,
            COUNT(DISTINCT transaction_date) as days_available
          FROM scout.fact_transactions
          WHERE transaction_date >= CURRENT_DATE - INTERVAL '90 days'
        ),
        market_share_data AS (
          SELECT 
            COALESCE(p.brand_id, 999) as brand_id,
            ROUND(SUM(fti.line_amount)::numeric, 2) as net_sales_amt
          FROM scout.fact_transaction_items fti
          JOIN scout.fact_transactions ft ON fti.transaction_key = ft.transaction_key
          LEFT JOIN scout.dim_products p ON fti.product_key = p.product_key
          WHERE ft.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
          GROUP BY p.brand_id
          ORDER BY net_sales_amt DESC
          LIMIT 20
        ),
        geographic_performance AS (
          SELECT 
            'region' as level,
            'net_sales_amt' as metric,
            (SELECT latest_date FROM latest_data) as date,
            json_agg(
              json_build_object(
                'geo_id', COALESCE(s.region_id, 1),
                'geo_name', COALESCE(s.region, 'Unknown Region'),
                'index', ROW_NUMBER() OVER (ORDER BY SUM(fti.line_amount) DESC),
                'bin', CASE 
                  WHEN ROW_NUMBER() OVER (ORDER BY SUM(fti.line_amount) DESC) <= 2 THEN 5
                  WHEN ROW_NUMBER() OVER (ORDER BY SUM(fti.line_amount) DESC) <= 5 THEN 4
                  WHEN ROW_NUMBER() OVER (ORDER BY SUM(fti.line_amount) DESC) <= 10 THEN 3
                  WHEN ROW_NUMBER() OVER (ORDER BY SUM(fti.line_amount) DESC) <= 15 THEN 2
                  ELSE 1
                END
              )
            ) as rows
          FROM scout.fact_transaction_items fti
          JOIN scout.fact_transactions ft ON fti.transaction_key = ft.transaction_key
          LEFT JOIN scout.dim_stores s ON ft.store_key = s.store_key
          WHERE ft.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
          GROUP BY s.region_id, s.region
          HAVING SUM(fti.line_amount) > 0
        ),
        persona_data AS (
          SELECT 
            DATE_TRUNC('month', ft.transaction_date)::date as month,
            COALESCE(s.region_id, 1) as region_id,
            CASE 
              WHEN SUM(fti.line_amount) > 10000 THEN 'High Value'
              WHEN SUM(fti.line_amount) > 5000 THEN 'Medium Value'
              ELSE 'Standard'
            END as persona_bucket,
            COUNT(DISTINCT ft.customer_id) as customers,
            COUNT(DISTINCT ft.transaction_id) as transactions,
            ROUND(SUM(fti.line_amount)::numeric, 2) as total_sales
          FROM scout.fact_transaction_items fti
          JOIN scout.fact_transactions ft ON fti.transaction_key = ft.transaction_key
          LEFT JOIN scout.dim_stores s ON ft.store_key = s.store_key
          WHERE ft.transaction_date >= CURRENT_DATE - INTERVAL '90 days'
          AND ft.customer_id IS NOT NULL
          GROUP BY DATE_TRUNC('month', ft.transaction_date), s.region_id
          HAVING COUNT(DISTINCT ft.transaction_id) >= 1
        )
        SELECT json_build_object(
          'as_of', (SELECT latest_date FROM latest_data)::text,
          'horizon_days', 30,
          'market_share', (
            SELECT COALESCE(json_agg(
              json_build_object(
                'brand_id', brand_id,
                'net_sales_amt', net_sales_amt
              )
            ), '[]'::json)
            FROM market_share_data
          ),
          'substitutions', '[]'::json,
          'geo_latest', (
            SELECT COALESCE(json_agg(
              json_build_object(
                'level', level,
                'metric', metric,
                'date', date::text,
                'rows', rows
              )
            ), '[]'::json)
            FROM geographic_performance
          ),
          'persona', (
            SELECT COALESCE(json_agg(
              json_build_object(
                'month', month::text,
                'region_id', region_id,
                'persona_bucket', persona_bucket,
                'customers', customers,
                'transactions', transactions,
                'total_sales', total_sales
              )
            ), '[]'::json)
            FROM persona_data
          )
        ) as bundle
      `
    })

    if (error) {
      console.error('Database query error:', error)
      return new Response(
        JSON.stringify({ 
          error: 'Database query failed',
          details: error.message 
        }),
        { 
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        }
      )
    }

    // Extract the bundle from the result
    const bundle = data && data[0] ? data[0].bundle : {
      as_of: new Date().toISOString().split('T')[0],
      horizon_days: 30,
      market_share: [],
      substitutions: [],
      geo_latest: [],
      persona: []
    }

    console.log('Competitive Intelligence: Bundle created successfully')
    console.log('Market Share entries:', bundle.market_share?.length || 0)
    console.log('Geographic blocks:', bundle.geo_latest?.length || 0)
    console.log('Persona segments:', bundle.persona?.length || 0)

    return new Response(
      JSON.stringify(bundle),
      { 
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      }
    )

  } catch (err) {
    console.error('Competitive Intelligence Error:', err)
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        message: err.message 
      }),
      { 
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      }
    )
  }
})