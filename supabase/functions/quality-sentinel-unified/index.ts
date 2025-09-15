// Unified Quality Sentinel - Consolidated monitoring function
// Combines quality-sentinel and quality-sentinel-fixed with enhanced error handling
// Provides comprehensive quality monitoring and data validation

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SRK = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const sb = createClient(SUPABASE_URL, SRK, { auth: { persistSession: false } });

interface QualityMetrics {
  summary?: any
  confusion?: any
  system_health?: any
  data_quality?: any
  alerts?: any[]
}

interface SentinelConfig {
  include_summary?: boolean
  include_confusion?: boolean
  include_system_health?: boolean
  include_data_quality?: boolean
  include_alerts?: boolean
  alert_threshold?: number
}

serve(async (req) => {
  try {
    // CORS headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-sentinel-key',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS'
    };

    if (req.method === 'OPTIONS') {
      return new Response('ok', { headers: corsHeaders });
    }

    // Authentication check (optional)
    const auth = req.headers.get("x-sentinel-key");
    const expectedKey = Deno.env.get("SENTINEL_KEY");
    
    if (expectedKey && (!auth || auth !== expectedKey)) {
      return new Response(JSON.stringify({ 
        ok: false, 
        error: "Unauthorized - Invalid sentinel key" 
      }), { 
        status: 401,
        headers: { ...corsHeaders, "content-type": "application/json" }
      });
    }

    // Parse request config
    let config: SentinelConfig = {
      include_summary: true,
      include_confusion: true,
      include_system_health: true,
      include_data_quality: true,
      include_alerts: true,
      alert_threshold: 0.8
    };

    if (req.method === 'POST') {
      try {
        const body = await req.json();
        config = { ...config, ...body };
      } catch (e) {
        // Continue with defaults if body parsing fails
      }
    }

    const metrics: QualityMetrics = {};
    const errors: string[] = [];

    // Quality Summary
    if (config.include_summary) {
      try {
        const { data: summary, error: e1 } = await sb.rpc("suqi_get_quality_summary", {});
        if (e1) {
          console.error("Quality summary error:", e1);
          errors.push(`Quality summary: ${e1.message}`);
        } else {
          metrics.summary = summary;
        }
      } catch (error) {
        console.error("Quality summary exception:", error);
        errors.push(`Quality summary exception: ${error.message}`);
      }
    }

    // Confusion Data
    if (config.include_confusion) {
      try {
        const { data: confusion, error: e2 } = await sb.rpc("suqi_get_confusion_today", {});
        if (e2) {
          console.error("Confusion data error:", e2);
          errors.push(`Confusion data: ${e2.message}`);
        } else {
          metrics.confusion = confusion;
        }
      } catch (error) {
        console.error("Confusion data exception:", error);
        errors.push(`Confusion data exception: ${error.message}`);
      }
    }

    // System Health Check
    if (config.include_system_health) {
      try {
        const healthChecks = await Promise.allSettled([
          sb.from('scout_transactions').select('count', { count: 'exact', head: true }),
          sb.from('master_brands').select('count', { count: 'exact', head: true }),
          sb.from('sari_sari_queries').select('count', { count: 'exact', head: true })
        ]);

        metrics.system_health = {
          transactions_available: healthChecks[0].status === 'fulfilled',
          brands_available: healthChecks[1].status === 'fulfilled',
          queries_logged: healthChecks[2].status === 'fulfilled',
          last_check: new Date().toISOString()
        };
      } catch (error) {
        console.error("System health exception:", error);
        errors.push(`System health exception: ${error.message}`);
      }
    }

    // Data Quality Metrics
    if (config.include_data_quality) {
      try {
        const { data: dataQuality, error: e3 } = await sb.rpc("get_data_quality_metrics", {});
        if (e3) {
          console.error("Data quality error:", e3);
          errors.push(`Data quality: ${e3.message}`);
        } else {
          metrics.data_quality = dataQuality;
        }
      } catch (error) {
        console.error("Data quality exception:", error);
        errors.push(`Data quality exception: ${error.message}`);
        
        // Fallback basic data quality check
        try {
          const { data: basicQuality } = await sb
            .from('scout_transactions')
            .select('transaction_id, total_amount, transaction_date')
            .not('transaction_id', 'is', null)
            .not('total_amount', 'is', null)
            .limit(1000);

          if (basicQuality) {
            const validTransactions = basicQuality.filter(t => 
              t.transaction_id && 
              t.total_amount && 
              t.total_amount > 0 &&
              t.transaction_date
            );

            metrics.data_quality = {
              total_checked: basicQuality.length,
              valid_transactions: validTransactions.length,
              quality_score: validTransactions.length / basicQuality.length,
              last_check: new Date().toISOString(),
              fallback_mode: true
            };
          }
        } catch (fallbackError) {
          errors.push(`Data quality fallback failed: ${fallbackError.message}`);
        }
      }
    }

    // Generate Alerts
    if (config.include_alerts) {
      const alerts: any[] = [];

      // Quality score alerts
      if (metrics.data_quality?.quality_score < config.alert_threshold!) {
        alerts.push({
          type: 'warning',
          message: `Data quality score ${metrics.data_quality.quality_score.toFixed(2)} below threshold ${config.alert_threshold}`,
          timestamp: new Date().toISOString(),
          severity: 'medium'
        });
      }

      // System health alerts
      if (metrics.system_health) {
        const unhealthyServices = Object.entries(metrics.system_health)
          .filter(([key, value]) => key !== 'last_check' && !value)
          .map(([key]) => key);

        if (unhealthyServices.length > 0) {
          alerts.push({
            type: 'error',
            message: `System services unavailable: ${unhealthyServices.join(', ')}`,
            timestamp: new Date().toISOString(),
            severity: 'high'
          });
        }
      }

      // Error alerts
      if (errors.length > 0) {
        alerts.push({
          type: 'error',
          message: `Quality check errors: ${errors.length} failures`,
          details: errors,
          timestamp: new Date().toISOString(),
          severity: errors.length > 2 ? 'high' : 'medium'
        });
      }

      metrics.alerts = alerts;
    }

    // Determine overall status
    const hasErrors = errors.length > 0;
    const hasCriticalAlerts = metrics.alerts?.some(a => a.severity === 'high') || false;
    const overallStatus = hasErrors || hasCriticalAlerts ? 'degraded' : 'healthy';

    return new Response(JSON.stringify({ 
      ok: !hasErrors,
      status: overallStatus,
      timestamp: new Date().toISOString(),
      metrics,
      errors: errors.length > 0 ? errors : undefined,
      config
    }), { 
      headers: { 
        ...corsHeaders,
        "content-type": "application/json" 
      }
    });

  } catch (error) {
    console.error("Quality sentinel error:", error);
    return new Response(JSON.stringify({ 
      ok: false,
      status: 'error',
      error: String(error?.message ?? error),
      timestamp: new Date().toISOString()
    }), { 
      status: 500, 
      headers: { 
        "content-type": "application/json",
        'Access-Control-Allow-Origin': '*'
      }
    });
  }
});

// Deploy with:
// supabase functions deploy quality-sentinel-unified
// supabase secrets set SENTINEL_KEY=your_sentinel_key (optional)