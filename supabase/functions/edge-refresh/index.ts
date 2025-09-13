// supabase/functions/edge-refresh/index.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

export const config = { runtime: 'edge' };

export default async (req: Request) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!, 
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );
  
  try {
    // Refresh edge gold views
    const { error } = await supabase.rpc('refresh_edge_gold');
    
    if (error) {
      console.error('Gold refresh error:', error);
      return new Response(
        JSON.stringify({ ok: false, error: error.message }), 
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }
    
    // Get summary stats
    const { data: stats } = await supabase
      .from('edge_analytics_summary')
      .select('*')
      .order('hour', { ascending: false })
      .limit(1)
      .single();
    
    return new Response(
      JSON.stringify({ 
        ok: true, 
        refreshed_at: new Date().toISOString(),
        latest_stats: stats
      }), 
      { headers: { 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ ok: false, error: error.message }), 
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
}