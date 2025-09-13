-- Fix 406 Errors and Security Issues
-- This resolves the immediate app breakage and security vulnerabilities

-- =====================================================
-- PART 1: Make all PUBLIC views use SECURITY INVOKER
-- This ensures RLS is respected by views
-- =====================================================
DO $$
DECLARE r record;
BEGIN
  RAISE NOTICE 'Converting all PUBLIC views to SECURITY INVOKER...';
  FOR r IN
    SELECT schemaname, viewname
    FROM pg_catalog.pg_views
    WHERE schemaname = 'public'
  LOOP
    BEGIN
      EXECUTE format('ALTER VIEW %I.%I SET (security_invoker = true);', r.schemaname, r.viewname);
      RAISE NOTICE 'Fixed view: %.%', r.schemaname, r.viewname;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Could not alter view %.%: %', r.schemaname, r.viewname, SQLERRM;
    END;
  END LOOP;
END$$;

-- =====================================================
-- PART 2: Drop unnecessary demo views (optional cleanup)
-- These are Northwind demo views that aren't needed
-- =====================================================
DROP VIEW IF EXISTS
  public.nw_recent_orders,
  public.nw_top_products,
  public.nw_sales_by_category,
  public.nw_sales_overview,
  public.nw_product_performance,
  public.nw_inventory_status,
  public.nw_top_customers,
  public.nw_dashboard_kpis,
  public.nw_dashboard_kpis_last_year,
  public.nw_monthly_revenue_trend,
  public.nw_monthly_sales_trend,
  public.nw_orders_by_country,
  public.nw_employee_performance,
  public.nw_customer_insights,
  public.nw_product_profitability,
  public.nw_product_inventory_status,
  public.nw_product_profit_margins,
  public.nw_regions,
  public.nw_territories,
  public.nw_employee_territories,
  public.northwind_dashboard_april_2022,
  public.april_2022_dashboard,
  public.april_2022_sales_by_category,
  public.april_2022_top_products,
  public.april_2022_top_clients,
  public.april_2022_top_employees
CASCADE;

RAISE NOTICE 'Dropped Northwind demo views';

-- =====================================================
-- PART 3: Enable RLS on all PUBLIC tables
-- This is required for any table in exposed schemas
-- =====================================================
DO $$
DECLARE r record;
BEGIN
  RAISE NOTICE 'Enabling RLS on all PUBLIC tables...';
  FOR r IN
    SELECT schemaname, tablename
    FROM pg_catalog.pg_tables
    WHERE schemaname = 'public'
    AND tablename NOT LIKE 'pg_%'  -- Skip system tables
    AND tablename NOT IN ('spatial_ref_sys')  -- Skip PostGIS
  LOOP
    BEGIN
      EXECUTE format('ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY;', r.schemaname, r.tablename);
      RAISE NOTICE 'Enabled RLS on: %.%', r.schemaname, r.tablename;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Could not enable RLS on %.%: %', r.schemaname, r.tablename, SQLERRM;
    END;
  END LOOP;
END$$;

-- =====================================================
-- PART 4: Create permissive read policies for app access
-- Only for tables that your app actually needs
-- =====================================================
DO $$
DECLARE t text[];
DECLARE x text;
BEGIN
  RAISE NOTICE 'Creating read policies for app tables...';
  
  -- List of tables your app might query
  t := ARRAY[
    'campaigns',
    'edge_devices',
    'edge_telemetry_raw',
    'edge_alerts',
    'silver_edge_telemetry',
    'gold_edge_analytics',
    'master_geographic_hierarchy',
    'philippines_locations',
    'ph_admin1_regions',
    'master_product_hierarchy',
    'scout_object_catalog',
    'user_filter_sessions'
  ];
  
  FOREACH x IN ARRAY t LOOP
    BEGIN
      -- Check if table exists
      IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = x) THEN
        -- Drop existing policy if any
        EXECUTE format('DROP POLICY IF EXISTS allow_read ON public.%I', x);
        
        -- Create new permissive read policy
        EXECUTE format(
          'CREATE POLICY allow_read ON public.%I
           FOR SELECT TO anon, authenticated USING (true)',
          x
        );
        RAISE NOTICE 'Created read policy for: %', x;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Could not create policy for %: %', x, SQLERRM;
    END;
  END LOOP;
END$$;

-- =====================================================
-- PART 5: Special handling for PostGIS table
-- =====================================================
ALTER TABLE public.spatial_ref_sys ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS allow_read ON public.spatial_ref_sys;
CREATE POLICY allow_read ON public.spatial_ref_sys
  FOR SELECT TO anon, authenticated USING (true);

-- =====================================================
-- VERIFICATION
-- =====================================================
SELECT 
    'Views with SECURITY DEFINER' as check_type,
    count(*) as remaining_count
FROM pg_views v
JOIN pg_class c ON c.relname = v.viewname 
JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = v.schemaname
WHERE v.schemaname = 'public'
AND NOT (c.reloptions::text LIKE '%security_invoker%' OR c.reloptions IS NULL)

UNION ALL

SELECT 
    'Tables without RLS in public',
    count(*)
FROM pg_tables t
JOIN pg_class c ON c.relname = t.tablename
JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = t.schemaname
WHERE t.schemaname = 'public'
AND NOT c.relrowsecurity

UNION ALL

SELECT 
    'Tables with read policies',
    count(*)
FROM pg_policies
WHERE schemaname = 'public'
AND policyname = 'allow_read';

-- =====================================================
-- IMPORTANT MANUAL STEP REQUIRED!
-- =====================================================
-- Go to Supabase Dashboard:
-- 1. Project Settings → API → Exposed Schemas
-- 2. Add 'scout' to the list (keep 'storage' if using Supabase Storage)
-- 3. Save changes
-- 
-- This fixes the 406 errors when your app sends Accept-Profile: scout
-- =====================================================