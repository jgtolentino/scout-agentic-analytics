import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  try {
    const { searchParams } = new URL(req.url)
    const exportType = searchParams.get('type') || 'all'
    const date = new Date().toISOString().slice(0, 10)

    console.log(`Starting platinum export for ${date}, type: ${exportType}`)

    // Export daily transactions
    if (exportType === 'all' || exportType === 'daily_transactions') {
      const { data: dailyData, error } = await supabase
        .from('daily_transactions')
        .select('*')
        .gte('transaction_date', date)

      if (!error && dailyData) {
        const csv = convertToCSV(dailyData)
        const { error: uploadError } = await supabase.storage
          .from('scout-platinum')
          .upload(`daily/transactions_${date}.csv`, csv, {
            contentType: 'text/csv',
            upsert: true
          })

        if (uploadError) throw uploadError
        console.log(`Exported daily transactions: ${dailyData.length} records`)
      }
    }

    // Export store rankings
    if (exportType === 'all' || exportType === 'store_rankings') {
      const { data: storeData, error } = await supabase
        .from('store_rankings')
        .select('*')
        .order('revenue_rank')

      if (!error && storeData) {
        const csv = convertToCSV(storeData)
        const { error: uploadError } = await supabase.storage
          .from('scout-platinum')
          .upload(`rankings/stores_${date}.csv`, csv, {
            contentType: 'text/csv',
            upsert: true
          })

        if (uploadError) throw uploadError
        console.log(`Exported store rankings: ${storeData.length} records`)
      }
    }

    // Export ML features
    if (exportType === 'all' || exportType === 'ml_features') {
      const { data: features, error } = await supabase
        .from('store_features')
        .select('*')

      if (!error && features) {
        const jsonData = {
          export_date: date,
          feature_version: 'v1.0',
          store_count: features.length,
          features: features
        }

        const { error: uploadError } = await supabase.storage
          .from('scout-platinum')
          .upload(`ml/store_features_${date}.json`, JSON.stringify(jsonData, null, 2), {
            contentType: 'application/json',
            upsert: true
          })

        if (uploadError) throw uploadError
        console.log(`Exported ML features: ${features.length} stores`)
      }
    }

    // Create GenieView export
    if (exportType === 'all' || exportType === 'genie') {
      // Get today's summary metrics
      const { data: metrics } = await supabase
        .from('daily_transactions')
        .select('*')
        .eq('transaction_date', date)

      const totalRevenue = metrics?.reduce((sum, m) => sum + (m.total_revenue || 0), 0) || 0
      const totalTransactions = metrics?.reduce((sum, m) => sum + (m.transaction_count || 0), 0) || 0

      const genieExport = {
        export_type: 'daily_summary',
        export_date: date,
        metrics_summary: {
          total_revenue: totalRevenue,
          transaction_count: totalTransactions,
          active_devices: metrics?.length || 0,
          avg_transaction_value: totalRevenue / (totalTransactions || 1)
        },
        insights: {
          payment_trends: {
            cash_pct: metrics?.[0]?.cash_pct || 0,
            digital_pct: (metrics?.[0]?.gcash_pct || 0) + (metrics?.[0]?.card_pct || 0)
          },
          peak_periods: {
            morning_pct: metrics?.[0]?.morning_pct || 0,
            afternoon_pct: metrics?.[0]?.afternoon_pct || 0,
            evening_pct: metrics?.[0]?.evening_pct || 0
          }
        },
        recommendations: {
          action_items: [
            totalRevenue > 100000 ? 'Maintain momentum with current strategies' : 'Consider promotional campaigns',
            metrics?.[0]?.digital_pct < 30 ? 'Increase digital payment adoption' : 'Digital adoption is strong'
          ]
        },
        natural_language_summary: `Performance for ${date}: Generated ₱${totalRevenue.toLocaleString()} from ${totalTransactions} transactions across ${metrics?.length || 0} active devices.`
      }

      const { error: genieError } = await supabase
        .from('genie_exports')
        .insert(genieExport)

      if (genieError) throw genieError

      // Also save to storage
      const { error: uploadError } = await supabase.storage
        .from('scout-platinum')
        .upload(`genie/summary_${date}.json`, JSON.stringify(genieExport, null, 2), {
          contentType: 'application/json',
          upsert: true
        })

      if (uploadError) throw uploadError
      console.log('Created GenieView export')
    }

    // Update manifest
    const manifest = {
      generated_at: new Date().toISOString(),
      export_date: date,
      available_exports: {
        daily_transactions: `/daily/transactions_${date}.csv`,
        store_rankings: `/rankings/stores_${date}.csv`,
        ml_features: `/ml/store_features_${date}.json`,
        genie_summary: `/genie/summary_${date}.json`
      }
    }

    const { error: manifestError } = await supabase.storage
      .from('scout-platinum')
      .upload('manifest/latest.json', JSON.stringify(manifest, null, 2), {
        contentType: 'application/json',
        upsert: true
      })

    if (manifestError) throw manifestError

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: `Platinum export completed for ${date}`,
        manifest: manifest
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    console.error('Export error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})

function convertToCSV(data: any[]): string {
  if (!data || data.length === 0) return ''
  
  const headers = Object.keys(data[0])
  const rows = data.map(row => 
    headers.map(header => {
      const value = row[header]
      // Escape quotes and wrap in quotes if contains comma
      if (typeof value === 'string' && (value.includes(',') || value.includes('"'))) {
        return `"${value.replace(/"/g, '""')}"`
      }
      return value ?? ''
    }).join(',')
  )
  
  return [headers.join(','), ...rows].join('\n')
}