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
    const { p_level, p_metric, p_date } = await req.json()
    
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    console.log('Geo Performance:', { p_level, p_metric, p_date })

    // Use latest date if not provided
    const dateFilter = p_date ? `'${p_date}'::date` : '(SELECT MAX(transaction_date) FROM scout.fact_transactions)'

    const { data, error } = await supabase.rpc('execute_sql', {
      query: `
        WITH geo_metrics AS (
          SELECT 
            ft.transaction_date::date as date,
            '${p_level}' as level,
            CASE 
              WHEN '${p_level}' = 'region' THEN COALESCE(s.region_id, 1)
              WHEN '${p_level}' = 'city' THEN COALESCE(s.store_id, 1) -- Use store_id as city proxy
              ELSE COALESCE(s.store_id, 1) -- Default to store level
            END as geo_id,
            '${p_metric}' as metric,
            CASE 
              WHEN '${p_metric}' = 'net_sales_amt' THEN ROUND(SUM(fti.line_amount)::numeric, 2)
              WHEN '${p_metric}' = 'units' THEN ROUND(SUM(fti.quantity)::numeric, 0)
              WHEN '${p_metric}' = 'txn_count' THEN COUNT(DISTINCT ft.transaction_id)::numeric
              WHEN '${p_metric}' = 'avg_ticket' THEN ROUND(AVG(fti.line_amount)::numeric, 2)
              ELSE ROUND(SUM(fti.line_amount)::numeric, 2)
            END as value
          FROM scout.fact_transaction_items fti
          JOIN scout.fact_transactions ft ON fti.transaction_key = ft.transaction_key
          LEFT JOIN scout.dim_stores s ON ft.store_key = s.store_key
          WHERE ft.transaction_date = ${dateFilter}
          GROUP BY ft.transaction_date::date, 
            CASE 
              WHEN '${p_level}' = 'region' THEN s.region_id
              WHEN '${p_level}' = 'city' THEN s.store_id
              ELSE s.store_id
            END
          HAVING SUM(fti.line_amount) > 0
        ),
        metric_stats AS (
          SELECT 
            AVG(value) as mean_value,
            STDDEV(value) as stddev_value
          FROM geo_metrics
        )
        SELECT 
          gm.date::text,
          gm.level,
          gm.geo_id,
          gm.metric,
          gm.value,
          CASE 
            WHEN ms.stddev_value > 0 THEN 
              ROUND(((gm.value - ms.mean_value) / ms.stddev_value)::numeric, 3)
            ELSE 0
          END as zscore,
          CASE 
            WHEN ROW_NUMBER() OVER (ORDER BY gm.value DESC) <= (COUNT(*) OVER() * 0.2) THEN 5
            WHEN ROW_NUMBER() OVER (ORDER BY gm.value DESC) <= (COUNT(*) OVER() * 0.4) THEN 4
            WHEN ROW_NUMBER() OVER (ORDER BY gm.value DESC) <= (COUNT(*) OVER() * 0.6) THEN 3
            WHEN ROW_NUMBER() OVER (ORDER BY gm.value DESC) <= (COUNT(*) OVER() * 0.8) THEN 2
            ELSE 1
          END as quantile_bin,
          ROUND((ROW_NUMBER() OVER (ORDER BY gm.value DESC) * 100.0 / COUNT(*) OVER())::numeric, 1) as index_0_100
        FROM geo_metrics gm
        CROSS JOIN metric_stats ms
        ORDER BY gm.value DESC
        LIMIT 100
      `
    })

    if (error) {
      console.error('Geo Performance Error:', error)
      return new Response(
        JSON.stringify({ error: 'Query failed', details: error.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" }}
      )
    }

    console.log('Geo Performance: Found', data?.length || 0, 'locations')

    return new Response(
      JSON.stringify(data || []),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }}
    )

  } catch (err) {
    console.error('Geo Performance Error:', err)
    return new Response(
      JSON.stringify({ error: 'Internal server error', message: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" }}
    )
  }
})