-- Fix Scout Schema Access for 406 Errors
-- This grants proper permissions to resolve PGRST106 errors

-- =====================================================
-- STEP 1: Grant schema usage and table/view access
-- =====================================================
GRANT USAGE ON SCHEMA scout TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA scout TO anon, authenticated;
GRANT SELECT ON ALL VIEWS IN SCHEMA scout TO anon, authenticated;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA scout TO anon, authenticated;

-- Future objects will also be accessible
ALTER DEFAULT PRIVILEGES IN SCHEMA scout 
  GRANT SELECT ON TABLES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA scout 
  GRANT SELECT ON SEQUENCES TO anon, authenticated;

-- =====================================================
-- STEP 2: Verify the view exists
-- =====================================================
DO $$
BEGIN
  IF to_regclass('scout.dal_transactions_flat') IS NULL THEN
    RAISE NOTICE 'WARNING: scout.dal_transactions_flat does not exist!';
    RAISE NOTICE 'You need to create this view first.';
  ELSE
    RAISE NOTICE 'SUCCESS: scout.dal_transactions_flat exists';
  END IF;
  
  -- Check other expected views
  IF to_regclass('scout.v_gold_transactions_flat') IS NOT NULL THEN
    RAISE NOTICE 'Found: scout.v_gold_transactions_flat';
  END IF;
  
  IF to_regclass('scout.v_silver_transactions') IS NOT NULL THEN
    RAISE NOTICE 'Found: scout.v_silver_transactions';
  END IF;
END $$;

-- =====================================================
-- STEP 3: List all accessible objects in scout schema
-- =====================================================
SELECT 
  'Tables in scout schema:' as info,
  string_agg(tablename, ', ') as objects
FROM pg_tables 
WHERE schemaname = 'scout'

UNION ALL

SELECT 
  'Views in scout schema:',
  string_agg(viewname, ', ')
FROM pg_views 
WHERE schemaname = 'scout';

-- =====================================================
-- STEP 4: Test permissions
-- =====================================================
-- Switch to anon role and test
SET LOCAL ROLE anon;
SELECT count(*) as anon_can_query_scout_tables 
FROM scout.bronze_transactions 
LIMIT 1;
RESET ROLE;

-- Success message
SELECT 'Scout schema permissions granted successfully!' as status;