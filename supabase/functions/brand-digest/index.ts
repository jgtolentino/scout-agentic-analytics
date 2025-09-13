// functions/brand-digest/index.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

export const config = { runtime: 'edge' };

export default async (req: Request) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!, 
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );
  
  // Fetch brand metrics
  const { data: metrics, error: metricsError } = await supabase
    .from('scout.gold_brand_metrics_daily')
    .select('*')
    .order('day', { ascending: false })
    .limit(30);
    
  if (metricsError) {
    return new Response(
      JSON.stringify({ ok: false, error: metricsError.message }), 
      { status: 500 }
    );
  }
  
  // Fetch active follows for digest
  const { data: follows, error: followsError } = await supabase
    .from('agentdash.metric_follows')
    .select('*')
    .eq('active', true);
    
  if (followsError) {
    return new Response(
      JSON.stringify({ ok: false, error: followsError.message }), 
      { status: 500 }
    );
  }
  
  // Calculate insights (simplified)
  const insights = metrics?.reduce((acc, metric) => {
    const brand = metric.brand;
    if (!acc[brand]) {
      acc[brand] = {
        totalAudioHits: 0,
        totalVisionHits: 0,
        totalFusedHits: 0,
        trend: 'stable'
      };
    }
    acc[brand].totalAudioHits += metric.audio_hits || 0;
    acc[brand].totalVisionHits += metric.vision_hits || 0;
    acc[brand].totalFusedHits += metric.fused_hits || 0;
    return acc;
  }, {});
  
  // Write insights to table
  if (insights && Object.keys(insights).length > 0) {
    const insightRecords = Object.entries(insights).map(([brand, data]) => ({
      metric_key: 'brand_fused_signals',
      period: new Date().toISOString().split('T')[0],
      insight: {
        brand,
        ...data,
        timestamp: new Date().toISOString()
      }
    }));
    
    await supabase
      .from('agentdash.metric_insights')
      .insert(insightRecords);
  }
  
  return new Response(
    JSON.stringify({ 
      ok: true, 
      metricsCount: metrics?.length || 0,
      followsCount: follows?.length || 0,
      insights: insights 
    }), 
    { headers: {'Content-Type':'application/json'} }
  );
}