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
    const { p_month_from, p_month_to } = await req.json()
    
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    console.log('Monthly Churn:', { p_month_from, p_month_to })

    const monthTo = p_month_to || p_month_from

    const { data, error } = await supabase.rpc('execute_sql', {
      query: `
        WITH cohort_months AS (
          SELECT generate_series(
            '${p_month_from}'::date,
            '${monthTo}'::date,
            '1 month'::interval
          )::date as cohort_month
        ),
        customer_cohorts AS (
          SELECT 
            DATE_TRUNC('month', MIN(ft.transaction_date))::date as cohort_month,
            ft.customer_id,
            COUNT(DISTINCT ft.transaction_id) as initial_transactions,
            SUM(fti.line_amount) as initial_value
          FROM scout.fact_transaction_items fti
          JOIN scout.fact_transactions ft ON fti.transaction_key = ft.transaction_key
          WHERE ft.customer_id IS NOT NULL
          GROUP BY ft.customer_id
          HAVING DATE_TRUNC('month', MIN(ft.transaction_date))::date BETWEEN '${p_month_from}'::date AND '${monthTo}'::date
        ),
        cohort_sizes AS (
          SELECT 
            cohort_month,
            COUNT(customer_id) as initial_count,
            ROUND(AVG(initial_value)::numeric, 2) as avg_initial_value
          FROM customer_cohorts
          GROUP BY cohort_month
        ),
        retention_analysis AS (
          SELECT 
            cc.cohort_month,
            cs.initial_count,
            cs.avg_initial_value,
            COUNT(DISTINCT CASE 
              WHEN ft.transaction_date >= cc.cohort_month + INTERVAL '1 month'
                AND ft.transaction_date < cc.cohort_month + INTERVAL '2 months'
              THEN ft.customer_id 
            END) as retained_next_month
          FROM customer_cohorts cc
          JOIN cohort_sizes cs ON cc.cohort_month = cs.cohort_month
          LEFT JOIN scout.fact_transactions ft ON cc.customer_id = ft.customer_id
          GROUP BY cc.cohort_month, cs.initial_count, cs.avg_initial_value
        )
        SELECT 
          cohort_month::text,
          initial_count,
          retained_next_month,
          CASE 
            WHEN initial_count > 0 THEN 
              ROUND((retained_next_month * 100.0 / initial_count)::numeric, 2)
            ELSE 0
          END as retention_pct,
          CASE 
            WHEN initial_count > 0 THEN 
              ROUND(((initial_count - COALESCE(retained_next_month, 0)) * 100.0 / initial_count)::numeric, 2)
            ELSE 0
          END as churn_pct
        FROM retention_analysis
        ORDER BY cohort_month
      `
    })

    if (error) {
      console.error('Monthly Churn Error:', error)
      return new Response(
        JSON.stringify({ error: 'Query failed', details: error.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" }}
      )
    }

    console.log('Monthly Churn: Found', data?.length || 0, 'cohort months')

    return new Response(
      JSON.stringify(data || []),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }}
    )

  } catch (err) {
    console.error('Monthly Churn Error:', err)
    return new Response(
      JSON.stringify({ error: 'Internal server error', message: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" }}
    )
  }
})