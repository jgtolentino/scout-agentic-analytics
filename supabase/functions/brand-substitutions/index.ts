import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { p_date_from, p_date_to, p_region_id, p_min_confidence = 0.1 } = await req.json()
    
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    console.log('Brand Substitutions:', { p_date_from, p_date_to, p_region_id, p_min_confidence })

    // Generate brand substitution analysis using market basket analysis
    const { data, error } = await supabase.rpc('execute_sql', {
      query: `
        WITH customer_brand_purchases AS (
          SELECT 
            ft.customer_id,
            ft.transaction_date::date as date,
            COALESCE(s.region_id, 1) as region_id,
            COALESCE(p.brand_id, 999) as brand_id,
            COUNT(DISTINCT ft.transaction_id) as transaction_count
          FROM scout.fact_transaction_items fti
          JOIN scout.fact_transactions ft ON fti.transaction_key = ft.transaction_key
          LEFT JOIN scout.dim_products p ON fti.product_key = p.product_key
          LEFT JOIN scout.dim_stores s ON ft.store_key = s.store_key
          WHERE ft.transaction_date BETWEEN '${p_date_from}'::date AND '${p_date_to}'::date
            AND ft.customer_id IS NOT NULL
            ${p_region_id ? `AND s.region_id = ${p_region_id}` : ''}
          GROUP BY ft.customer_id, ft.transaction_date::date, s.region_id, p.brand_id
          HAVING COUNT(DISTINCT ft.transaction_id) >= 1
        ),
        brand_pairs AS (
          SELECT 
            c1.date,
            c1.region_id,
            c1.brand_id as a_brand_id,
            c2.brand_id as b_brand_id,
            COUNT(DISTINCT c1.customer_id) as support_txn
          FROM customer_brand_purchases c1
          JOIN customer_brand_purchases c2 ON c1.customer_id = c2.customer_id 
            AND c1.date = c2.date 
            AND c1.region_id = c2.region_id
            AND c1.brand_id < c2.brand_id  -- Avoid duplicates and self-pairs
          GROUP BY c1.date, c1.region_id, c1.brand_id, c2.brand_id
          HAVING COUNT(DISTINCT c1.customer_id) >= 2
        ),
        substitution_metrics AS (
          SELECT 
            date,
            region_id,
            a_brand_id,
            b_brand_id,
            support_txn,
            ROUND((support_txn * 1.0 / NULLIF(
              (SELECT COUNT(DISTINCT customer_id) 
               FROM customer_brand_purchases cbp1 
               WHERE cbp1.brand_id = bp.a_brand_id AND cbp1.date = bp.date), 0
            ))::numeric, 3) as conf_a_to_b,
            ROUND((support_txn * 1.0 / NULLIF(
              (SELECT COUNT(DISTINCT customer_id) 
               FROM customer_brand_purchases cbp2 
               WHERE cbp2.brand_id = bp.b_brand_id AND cbp2.date = bp.date), 0
            ))::numeric, 3) as conf_b_to_a,
            ROUND((support_txn / NULLIF(
              GREATEST(
                (SELECT COUNT(DISTINCT customer_id) FROM customer_brand_purchases cbp1 WHERE cbp1.brand_id = bp.a_brand_id AND cbp1.date = bp.date),
                (SELECT COUNT(DISTINCT customer_id) FROM customer_brand_purchases cbp2 WHERE cbp2.brand_id = bp.b_brand_id AND cbp2.date = bp.date)
              ), 0
            ) * 2.0)::numeric, 3) as lift
          FROM brand_pairs bp
        )
        SELECT 
          date::text,
          region_id,
          a_brand_id,
          b_brand_id,
          support_txn,
          conf_a_to_b,
          conf_b_to_a,
          lift,
          ROUND(((COALESCE(conf_a_to_b, 0) + COALESCE(conf_b_to_a, 0)) / 2.0 * COALESCE(lift, 0))::numeric, 4) as substitution_score
        FROM substitution_metrics
        WHERE GREATEST(COALESCE(conf_a_to_b, 0), COALESCE(conf_b_to_a, 0)) >= ${p_min_confidence}
        ORDER BY substitution_score DESC, support_txn DESC
        LIMIT 100
      `
    })

    if (error) {
      console.error('Brand Substitutions Error:', error)
      return new Response(
        JSON.stringify({ error: 'Query failed', details: error.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" }}
      )
    }

    console.log('Brand Substitutions: Found', data?.length || 0, 'relationships')

    return new Response(
      JSON.stringify(data || []),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }}
    )

  } catch (err) {
    console.error('Brand Substitutions Error:', err)
    return new Response(
      JSON.stringify({ error: 'Internal server error', message: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" }}
    )
  }
})