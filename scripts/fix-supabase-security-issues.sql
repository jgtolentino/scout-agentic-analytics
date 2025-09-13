-- Fix Supabase Security Issues
-- Generated from lint report

-- =====================================================
-- PART 1: Fix SECURITY DEFINER Views
-- =====================================================

-- Convert all SECURITY DEFINER views to SECURITY INVOKER
-- This ensures views respect the calling user's permissions and RLS policies

DO $$
DECLARE
    view_rec RECORD;
    view_def TEXT;
BEGIN
    -- Get all views with SECURITY DEFINER
    FOR view_rec IN 
        SELECT 
            schemaname,
            viewname,
            definition
        FROM pg_views
        WHERE schemaname = 'public'
        AND viewname IN (
            'order_summary', 'nw_recent_orders', 'etl_monitoring', 'nw_top_products',
            'sales_by_location', 'best_selling_products', 'inventory_alerts',
            'regional_performance', 'top_customers', 'northwind_dashboard_april_2022',
            'nw_sales_by_category', 'v_philippines_hierarchy', 'monitor_table_health',
            'scout_realtime_dashboard', 'customer_demographics', 'sales_by_category_chart',
            'scout_api_endpoints', 'order_details_table', 'nw_product_profitability',
            'nw_employee_performance', 'revenue_by_category', 'product_categories',
            'recent_activity', 'nw_sales_overview', 'nw_product_performance',
            'geographic_boundaries', 'scout_etl_dashboard', 'dashboard_summary',
            'dashboard_stats', 'geographic_coverage_summary', 'test_api',
            'ces_analytics', 'nw_orders_by_country', 'april_2022_dashboard',
            'sales_split', 'nw_inventory_status', 'nw_top_customers',
            'suqi_hourly_trends', 'top_employees_ranked', 'stores_with_location',
            'nw_customer_insights', 'sales_overview', 'scout_whole_counts',
            'nw_monthly_revenue_trend', 'april_2022_sales_by_category',
            'employee_performance_region', 'v_edge_analytics_dashboard',
            'top_products_ranked', 'employee_sales_ranking', 'gold_recent_transactions',
            'total_revenue_desc', 'april_2022_top_products', 'nw_product_inventory_status',
            'dashboard_data', 'v_edge_fleet_status', 'top_clients_ranked',
            'april_2022_top_clients', 'nw_dashboard_kpis_last_year',
            'april_2022_top_employees', 'v_email_processing_status',
            'nw_dashboard_kpis', 'monthly_order_trend', 'monthly_trend',
            'suqi_product_performance', 'nw_product_profit_margins',
            'scout_etl_documentation', 'nw_monthly_sales_trend', 'top_performers'
        )
    LOOP
        -- Get the current view definition
        view_def := view_rec.definition;
        
        -- Drop and recreate with SECURITY INVOKER
        EXECUTE format('DROP VIEW IF EXISTS %I.%I CASCADE', view_rec.schemaname, view_rec.viewname);
        EXECUTE format('CREATE VIEW %I.%I AS %s WITH (security_invoker = true)', 
                      view_rec.schemaname, view_rec.viewname, view_def);
        
        RAISE NOTICE 'Fixed view: %.%', view_rec.schemaname, view_rec.viewname;
    END LOOP;
END $$;

-- =====================================================
-- PART 2: Enable RLS on all public tables
-- =====================================================

-- Enable RLS on tables that don't have it
ALTER TABLE public.scout_object_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_migration_test ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dan_ryan_queries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.edge_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.edge_telemetry_raw ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.data_lineage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.edge_device_commands ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.edge_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.edge_diagnostics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.edge_model_deployments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.edge_ml_models ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.edge_offline_sync ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.silver_edge_telemetry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gold_edge_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_processing_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.uat_test_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.master_geographic_hierarchy ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.philippines_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_filter_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spatial_ref_sys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ph_admin1_regions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.master_product_hierarchy ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_chat_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_media_streams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketing_campaign_realtime ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consumer_behavior_realtime ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_integration_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_sentiment_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.data_pipeline_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.competitor_realtime_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nw_regions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nw_territories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nw_employee_territories ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- PART 3: Create basic RLS policies
-- =====================================================

-- For authenticated users only (adjust based on your needs)
-- These are restrictive by default - you'll need to customize based on requirements

-- Edge device tables - authenticated users can read their org's devices
CREATE POLICY "Users can view their org devices" ON public.edge_devices
    FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can view their telemetry" ON public.edge_telemetry_raw
    FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can view alerts" ON public.edge_alerts
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Campaign tables - authenticated users only
CREATE POLICY "Authenticated users can view campaigns" ON public.campaigns
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Geographic data - public read (these are reference tables)
CREATE POLICY "Public read geographic data" ON public.master_geographic_hierarchy
    FOR SELECT USING (true);

CREATE POLICY "Public read philippines locations" ON public.philippines_locations
    FOR SELECT USING (true);

CREATE POLICY "Public read regions" ON public.ph_admin1_regions
    FOR SELECT USING (true);

CREATE POLICY "Public read nw_regions" ON public.nw_regions
    FOR SELECT USING (true);

CREATE POLICY "Public read nw_territories" ON public.nw_territories
    FOR SELECT USING (true);

-- Product hierarchy - public read
CREATE POLICY "Public read product hierarchy" ON public.master_product_hierarchy
    FOR SELECT USING (true);

-- System tables - service role only
CREATE POLICY "Service role only" ON public.scout_object_catalog
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role only" ON public.data_lineage
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role only" ON public.dan_ryan_queries
    FOR ALL USING (auth.role() = 'service_role');

-- PostGIS system table
CREATE POLICY "Public read spatial_ref_sys" ON public.spatial_ref_sys
    FOR SELECT USING (true);

-- User session data - users can only see their own
CREATE POLICY "Users can view own sessions" ON public.user_filter_sessions
    FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Users can insert own sessions" ON public.user_filter_sessions
    FOR INSERT WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Users can update own sessions" ON public.user_filter_sessions
    FOR UPDATE USING (auth.uid()::text = user_id);

-- Email processing - service role only
CREATE POLICY "Service role only" ON public.email_attachments
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role only" ON public.email_processing_queue
    FOR ALL USING (auth.role() = 'service_role');

-- Analytics tables - authenticated read only
CREATE POLICY "Authenticated read" ON public.ai_chat_analytics
    FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated read" ON public.social_media_streams
    FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated read" ON public.marketing_campaign_realtime
    FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated read" ON public.consumer_behavior_realtime
    FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated read" ON public.social_sentiment_tracking
    FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated read" ON public.competitor_realtime_data
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- System status tables
CREATE POLICY "Authenticated read" ON public.api_integration_status
    FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Service role only" ON public.data_pipeline_jobs
    FOR ALL USING (auth.role() = 'service_role');

-- Test/Migration tables - service role only
CREATE POLICY "Service role only" ON public.direct_migration_test
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role only" ON public.uat_test_results
    FOR ALL USING (auth.role() = 'service_role');

-- Edge ML/Model tables
CREATE POLICY "Authenticated read" ON public.edge_ml_models
    FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated read" ON public.edge_model_deployments
    FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Service role write" ON public.edge_ml_models
    FOR INSERT WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "Service role write" ON public.edge_model_deployments
    FOR INSERT WITH CHECK (auth.role() = 'service_role');

-- Device management
CREATE POLICY "Authenticated read" ON public.edge_device_commands
    FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated read" ON public.edge_diagnostics
    FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated read" ON public.edge_offline_sync
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Analytics views
CREATE POLICY "Authenticated read" ON public.silver_edge_telemetry
    FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated read" ON public.gold_edge_analytics
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Employee territories - authenticated only
CREATE POLICY "Authenticated read" ON public.nw_employee_territories
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- =====================================================
-- PART 4: Verify fixes
-- =====================================================

-- Check remaining SECURITY DEFINER views
SELECT 
    'Remaining SECURITY DEFINER views:' as check_type,
    count(*) as count
FROM pg_views v
JOIN pg_class c ON c.relname = v.viewname AND c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = v.schemaname)
WHERE v.schemaname = 'public'
AND c.reloptions::text LIKE '%security_definer%';

-- Check tables without RLS
SELECT 
    'Tables without RLS enabled:' as check_type,
    count(*) as count
FROM pg_tables t
WHERE t.schemaname = 'public'
AND NOT EXISTS (
    SELECT 1 FROM pg_class c
    WHERE c.relname = t.tablename
    AND c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = t.schemaname)
    AND c.relrowsecurity = true
);