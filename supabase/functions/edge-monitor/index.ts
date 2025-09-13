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

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Check processing health
    const { data: healthData, error: healthError } = await supabaseClient
      .rpc('check_edge_processing_health')
    
    if (healthError) throw healthError

    // Get recent processing stats
    const { data: statsData, error: statsError } = await supabaseClient
      .from('edge_processing_stats')
      .select('*')
      .order('processing_date', { ascending: false })
      .limit(7)
    
    if (statsError) throw statsError

    // Check for stale data (no uploads in last hour)
    const { data: recentUploads, error: recentError } = await supabaseClient
      .from('bronze_edge_raw')
      .select('id', { count: 'exact', head: true })
      .gte('ingested_at', new Date(Date.now() - 3600000).toISOString())
    
    if (recentError) throw recentError

    const isDataFresh = (recentUploads?.count || 0) > 0

    // Check for critical alerts
    const alerts = []
    
    for (const metric of healthData) {
      if (metric.status === 'critical') {
        alerts.push({
          severity: 'critical',
          metric: metric.metric,
          value: metric.value,
          message: getAlertMessage(metric.metric, metric.value)
        })
      } else if (metric.status === 'warning') {
        alerts.push({
          severity: 'warning',
          metric: metric.metric,
          value: metric.value,
          message: getAlertMessage(metric.metric, metric.value)
        })
      }
    }

    if (!isDataFresh) {
      alerts.push({
        severity: 'warning',
        metric: 'data_freshness',
        value: 0,
        message: 'No new data received in the last hour'
      })
    }

    // Send alerts if configured
    if (alerts.length > 0 && Deno.env.get('ALERT_WEBHOOK_URL')) {
      await sendAlerts(alerts)
    }

    return new Response(
      JSON.stringify({
        timestamp: new Date().toISOString(),
        health: {
          overall: alerts.filter(a => a.severity === 'critical').length > 0 ? 'critical' : 
                   alerts.filter(a => a.severity === 'warning').length > 0 ? 'warning' : 'healthy',
          metrics: healthData,
          data_fresh: isDataFresh
        },
        stats: statsData,
        alerts: alerts
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200 
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500
      }
    )
  }
})

function getAlertMessage(metric: string, value: number): string {
  switch (metric) {
    case 'error_rate_24h':
      return `Error rate is ${value}% in the last 24 hours`
    case 'backlog_count':
      return `${value} files are stuck in processing`
    case 'avg_processing_time_ms':
      return `Average processing time is ${value}ms`
    default:
      return `${metric} is at ${value}`
  }
}

async function sendAlerts(alerts: any[]) {
  const webhookUrl = Deno.env.get('ALERT_WEBHOOK_URL')
  if (!webhookUrl) return

  try {
    await fetch(webhookUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        text: '🚨 Edge Processing Alerts',
        attachments: alerts.map(alert => ({
          color: alert.severity === 'critical' ? 'danger' : 'warning',
          fields: [
            { title: 'Metric', value: alert.metric, short: true },
            { title: 'Value', value: alert.value, short: true },
            { title: 'Message', value: alert.message, short: false }
          ]
        }))
      })
    })
  } catch (error) {
    console.error('Failed to send alerts:', error)
  }
}