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
    const { p_month, p_region_id } = await req.json()
    
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    console.log('Persona Performance:', { p_month, p_region_id })

    // Convert month to date range
    const monthStart = `'${p_month}'::date`
    const monthEnd = `('${p_month}'::date + INTERVAL '1 month' - INTERVAL '1 day')`

    const { data, error } = await supabase.rpc('execute_sql', {
      query: `
        WITH customer_monthly_metrics AS (
          SELECT 
            '${p_month}'::date as month,
            COALESCE(s.region_id, 1) as region_id,
            ft.customer_id,
            COUNT(DISTINCT ft.transaction_id) as transactions,
            ROUND(SUM(fti.line_amount)::numeric, 2) as total_sales,
            ROUND(AVG(fti.line_amount)::numeric, 2) as avg_ticket
          FROM scout.fact_transaction_items fti
          JOIN scout.fact_transactions ft ON fti.transaction_key = ft.transaction_key
          LEFT JOIN scout.dim_stores s ON ft.store_key = s.store_key
          WHERE ft.transaction_date BETWEEN ${monthStart} AND ${monthEnd}
            AND ft.customer_id IS NOT NULL
            ${p_region_id ? `AND s.region_id = ${p_region_id}` : ''}
          GROUP BY s.region_id, ft.customer_id
          HAVING SUM(fti.line_amount) > 0
        ),
        persona_buckets AS (
          SELECT 
            month,
            region_id,
            customer_id,
            transactions,
            total_sales,
            avg_ticket,
            CASE 
              WHEN total_sales >= 20000 THEN 'VIP Customers'
              WHEN total_sales >= 10000 THEN 'High Value'
              WHEN total_sales >= 5000 THEN 'Medium Value'
              WHEN total_sales >= 1000 THEN 'Regular'
              ELSE 'Occasional'
            END as persona_bucket,
            -- Simple satisfaction score based on repeat visits and spend
            CASE 
              WHEN transactions >= 10 AND total_sales >= 10000 THEN 5.0
              WHEN transactions >= 5 AND total_sales >= 5000 THEN 4.5
              WHEN transactions >= 3 AND total_sales >= 2000 THEN 4.0
              WHEN transactions >= 2 THEN 3.5
              ELSE 3.0
            END as satisfaction_score
          FROM customer_monthly_metrics
        )
        SELECT 
          month::text,
          region_id,
          persona_bucket,
          COUNT(customer_id) as customers,
          SUM(transactions) as transactions,
          ROUND(SUM(total_sales)::numeric, 2) as total_sales,
          ROUND(AVG(avg_ticket)::numeric, 2) as avg_ticket,
          ROUND(AVG(satisfaction_score)::numeric, 2) as avg_satisfaction
        FROM persona_buckets
        GROUP BY month, region_id, persona_bucket
        ORDER BY region_id, total_sales DESC
      `
    })

    if (error) {
      console.error('Persona Performance Error:', error)
      return new Response(
        JSON.stringify({ error: 'Query failed', details: error.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" }}
      )
    }

    console.log('Persona Performance: Found', data?.length || 0, 'persona segments')

    return new Response(
      JSON.stringify(data || []),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }}
    )

  } catch (err) {
    console.error('Persona Performance Error:', err)
    return new Response(
      JSON.stringify({ error: 'Internal server error', message: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" }}
    )
  }
})