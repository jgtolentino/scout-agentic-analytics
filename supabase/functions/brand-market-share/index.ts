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
    const { p_date_from, p_date_to, p_region_id, p_category_id } = await req.json()
    
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    console.log('Brand Market Share:', { p_date_from, p_date_to, p_region_id, p_category_id })

    const { data, error } = await supabase.rpc('execute_sql', {
      query: `
        WITH brand_sales AS (
          SELECT 
            COALESCE(p.brand_id, 999) as brand_id,
            ROUND(SUM(fti.line_amount)::numeric, 2) as net_sales_amt,
            ROUND(SUM(fti.quantity)::numeric, 0) as units
          FROM scout.fact_transaction_items fti
          JOIN scout.fact_transactions ft ON fti.transaction_key = ft.transaction_key
          LEFT JOIN scout.dim_products p ON fti.product_key = p.product_key
          LEFT JOIN scout.dim_stores s ON ft.store_key = s.store_key
          WHERE ft.transaction_date BETWEEN '${p_date_from}'::date AND '${p_date_to}'::date
            ${p_region_id ? `AND s.region_id = ${p_region_id}` : ''}
            ${p_category_id ? `AND p.category_id = ${p_category_id}` : ''}
          GROUP BY p.brand_id
          HAVING SUM(fti.line_amount) > 0
        ),
        total_sales AS (
          SELECT 
            SUM(net_sales_amt) as category_total_amt,
            SUM(units) as category_total_units
          FROM brand_sales
        )
        SELECT 
          bs.brand_id,
          bs.net_sales_amt,
          bs.units,
          ROUND((bs.net_sales_amt / NULLIF(ts.category_total_amt, 0) * 100)::numeric, 2) as brand_share_pct_amt,
          ROUND((bs.units / NULLIF(ts.category_total_units, 0) * 100)::numeric, 2) as brand_share_pct_units,
          ts.category_total_amt,
          ts.category_total_units
        FROM brand_sales bs
        CROSS JOIN total_sales ts
        ORDER BY bs.net_sales_amt DESC
        LIMIT 50
      `
    })

    if (error) {
      console.error('Brand Market Share Error:', error)
      return new Response(
        JSON.stringify({ error: 'Query failed', details: error.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" }}
      )
    }

    console.log('Brand Market Share: Found', data?.length || 0, 'brands')

    return new Response(
      JSON.stringify(data || []),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }}
    )

  } catch (err) {
    console.error('Brand Market Share Error:', err)
    return new Response(
      JSON.stringify({ error: 'Internal server error', message: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" }}
    )
  }
})