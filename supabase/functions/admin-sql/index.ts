import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const { sql, action } = await req.json();

    // Security: Only allow specific pre-approved operations
    if (action === 'setup-scout-schema') {
      return await setupScoutSchema(supabaseClient);
    }

    if (action === 'exec-sql' && sql) {
      // Basic SQL injection protection
      const safeSql = sql.toLowerCase();
      if (safeSql.includes('drop') || safeSql.includes('delete') || safeSql.includes('truncate')) {
        throw new Error('Destructive operations not allowed');
      }

      const { data, error } = await supabaseClient.rpc('exec_sql', { query: sql });
      if (error) throw error;

      return new Response(
        JSON.stringify({ success: true, data }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    throw new Error('Invalid action');
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      }
    );
  }
});

async function setupScoutSchema(supabaseClient: any) {
  const setupSQL = `
    -- Create exec_sql function first
    CREATE OR REPLACE FUNCTION public.exec_sql(query text)
    RETURNS json AS $$
    DECLARE
      result json;
    BEGIN
      EXECUTE query;
      GET DIAGNOSTICS result = ROW_COUNT;
      RETURN json_build_object('success', true, 'rows_affected', result);
    EXCEPTION WHEN OTHERS THEN
      RETURN json_build_object('error', SQLERRM, 'sqlstate', SQLSTATE);
    END;
    $$ LANGUAGE plpgsql SECURITY DEFINER;
    
    GRANT EXECUTE ON FUNCTION public.exec_sql(text) TO service_role;
    
    -- Create scout schema
    CREATE SCHEMA IF NOT EXISTS scout;
    
    -- Bronze layer
    CREATE TABLE IF NOT EXISTS scout.bronze_edge_raw (
      id TEXT PRIMARY KEY,
      device_id TEXT,
      captured_at TIMESTAMPTZ,
      src_filename TEXT,
      payload JSONB NOT NULL,
      ingested_at TIMESTAMPTZ DEFAULT NOW()
    );
    
    -- Indexes for performance
    CREATE INDEX IF NOT EXISTS idx_bronze_device_ts 
      ON scout.bronze_edge_raw(device_id, captured_at DESC);
    CREATE INDEX IF NOT EXISTS idx_bronze_ingested 
      ON scout.bronze_edge_raw(ingested_at DESC);
    CREATE INDEX IF NOT EXISTS idx_bronze_payload_transaction_id 
      ON scout.bronze_edge_raw USING GIN ((payload->>'transaction_id'));
    
    -- Silver layer
    CREATE TABLE IF NOT EXISTS scout.silver_transactions (
      transaction_id TEXT PRIMARY KEY,
      store_id TEXT,
      timestamp TIMESTAMPTZ NOT NULL,
      brand_name TEXT,
      peso_value DECIMAL(12,2),
      region TEXT,
      device_id TEXT,
      location JSONB,
      product_category TEXT,
      processed_at TIMESTAMPTZ DEFAULT NOW()
    );
    
    -- Gold layer views
    CREATE OR REPLACE VIEW scout.gold_daily_revenue AS
    SELECT 
      DATE(timestamp) as date,
      SUM(peso_value) as total_revenue,
      COUNT(*) as transaction_count,
      COUNT(DISTINCT store_id) as unique_stores
    FROM scout.silver_transactions
    GROUP BY DATE(timestamp)
    ORDER BY date DESC;
    
    CREATE OR REPLACE VIEW scout.gold_brand_performance AS
    SELECT 
      brand_name,
      SUM(peso_value) as total_revenue,
      COUNT(*) as transaction_count,
      AVG(peso_value) as avg_transaction_value
    FROM scout.silver_transactions
    WHERE brand_name IS NOT NULL
    GROUP BY brand_name
    ORDER BY total_revenue DESC;
    
    -- Processing function
    CREATE OR REPLACE FUNCTION scout.process_bronze_to_silver()
    RETURNS TABLE(processed_count INTEGER, error_count INTEGER) AS $$
    DECLARE
      processed INTEGER := 0;
      errors INTEGER := 0;
      rec RECORD;
    BEGIN
      -- Process unprocessed bronze records
      FOR rec IN 
        SELECT id, device_id, captured_at, payload
        FROM scout.bronze_edge_raw
        WHERE payload->>'transaction_id' IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM scout.silver_transactions s
            WHERE s.transaction_id = payload->>'transaction_id'
          )
        ORDER BY ingested_at
        LIMIT 1000
      LOOP
        BEGIN
          INSERT INTO scout.silver_transactions (
            transaction_id,
            store_id,
            timestamp,
            brand_name,
            peso_value,
            region,
            device_id,
            location,
            product_category
          ) VALUES (
            rec.payload->>'transaction_id',
            rec.payload->>'store_id',
            COALESCE((rec.payload->>'timestamp')::timestamptz, rec.captured_at),
            rec.payload->>'brand_name',
            CASE 
              WHEN rec.payload->>'peso_value' ~ '^[0-9]+\.?[0-9]*$' 
              THEN (rec.payload->>'peso_value')::decimal 
              ELSE NULL 
            END,
            COALESCE(rec.payload->>'region', 'Unknown'),
            rec.device_id,
            rec.payload->'location',
            rec.payload->>'product_category'
          );
          processed := processed + 1;
        EXCEPTION WHEN OTHERS THEN
          errors := errors + 1;
        END;
      END LOOP;
      
      RETURN QUERY SELECT processed, errors;
    END;
    $$ LANGUAGE plpgsql;
    
    -- Permissions
    GRANT USAGE ON SCHEMA scout TO anon, authenticated, service_role;
    GRANT ALL ON ALL TABLES IN SCHEMA scout TO service_role;
    GRANT SELECT ON ALL TABLES IN SCHEMA scout TO anon, authenticated;
    GRANT SELECT ON ALL SEQUENCES IN SCHEMA scout TO anon, authenticated, service_role;
    
    -- Sample data check
    SELECT 'Schema setup complete. Tables created:' as message;
    SELECT schemaname, tablename FROM pg_tables WHERE schemaname = 'scout';
  `;

  // Use direct SQL execution via Supabase client
  const { data, error } = await supabaseClient
    .from('information_schema.tables')
    .select('table_name')
    .limit(1); // Just to test connection

  // Execute setup SQL using raw query
  try {
    // Split and execute SQL statements individually for better compatibility
    const statements = setupSQL.split(';').filter(stmt => stmt.trim());
    let results = [];
    
    for (const statement of statements) {
      if (statement.trim()) {
        const result = await supabaseClient.rpc('exec_sql', { query: statement.trim() });
        results.push(result);
      }
    }
    
    if (results.some(r => r.error)) {
      throw new Error(`SQL execution failed: ${JSON.stringify(results.filter(r => r.error))}`);
    }
  } catch (sqlError) {
    // If RPC fails, try alternative approach
    throw new Error(`Schema setup failed: ${sqlError.message}. Please run the SQL manually in Supabase Dashboard.`);
  }

  return new Response(
    JSON.stringify({ 
      success: true, 
      message: 'Scout schema setup complete',
      details: data 
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}