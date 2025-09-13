// Supabase Edge Function - SSOT Status Endpoint
import { serve } from 'https://deno.land/std@0.192.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )
  const { data, error } = await supabase
    .from('scout_ssot_audit')
    .select('*')

  if (error) return new Response(JSON.stringify({ error }), { status: 500 })
  return new Response(JSON.stringify(data), {
    headers: { 'Content-Type': 'application/json' }
  })
})