-- Check Scout Schema Access and Permissions
-- This shows what access is currently configured for the scout schema

-- =====================================================
-- 1. Check if scout schema exists
-- =====================================================
SELECT 
    'Scout schema exists?' as check,
    EXISTS(SELECT 1 FROM pg_namespace WHERE nspname = 'scout') as result;

-- =====================================================
-- 2. List all objects in scout schema
-- =====================================================
SELECT 
    '--- TABLES IN SCOUT SCHEMA ---' as section;

SELECT 
    schemaname,
    tablename,
    tableowner,
    hasindexes,
    hasrules,
    hastriggers
FROM pg_tables 
WHERE schemaname = 'scout'
ORDER BY tablename;

SELECT 
    '--- VIEWS IN SCOUT SCHEMA ---' as section;

SELECT 
    schemaname,
    viewname,
    viewowner
FROM pg_views 
WHERE schemaname = 'scout'
ORDER BY viewname;

-- =====================================================
-- 3. Check permissions on scout schema
-- =====================================================
SELECT 
    '--- SCHEMA PERMISSIONS ---' as section;

SELECT 
    nspname as schema_name,
    rolname as role_name,
    has_schema_privilege(rolname, nspname, 'USAGE') as has_usage,
    has_schema_privilege(rolname, nspname, 'CREATE') as has_create
FROM pg_namespace
CROSS JOIN pg_roles
WHERE nspname = 'scout'
AND rolname IN ('anon', 'authenticated', 'service_role', 'postgres')
ORDER BY rolname;

-- =====================================================
-- 4. Check table/view permissions
-- =====================================================
SELECT 
    '--- TABLE/VIEW PERMISSIONS ---' as section;

SELECT DISTINCT
    schemaname,
    tablename as object_name,
    'table' as object_type,
    grantee,
    string_agg(privilege_type, ', ' ORDER BY privilege_type) as privileges
FROM information_schema.table_privileges
WHERE table_schema = 'scout'
AND grantee IN ('anon', 'authenticated', 'service_role')
GROUP BY schemaname, tablename, grantee

UNION ALL

SELECT DISTINCT
    schemaname,
    viewname as object_name,
    'view' as object_type,
    grantee,
    string_agg(privilege_type, ', ' ORDER BY privilege_type) as privileges
FROM information_schema.table_privileges tp
JOIN pg_views v ON v.viewname = tp.table_name AND v.schemaname = tp.table_schema
WHERE table_schema = 'scout'
AND grantee IN ('anon', 'authenticated', 'service_role')
GROUP BY schemaname, viewname, grantee
ORDER BY object_type, object_name, grantee;

-- =====================================================
-- 5. Check if key views exist
-- =====================================================
SELECT 
    '--- KEY VIEWS STATUS ---' as section;

SELECT 
    'dal_transactions_flat' as view_name,
    to_regclass('scout.dal_transactions_flat') IS NOT NULL as exists
UNION ALL
SELECT 
    'v_gold_transactions_flat',
    to_regclass('scout.v_gold_transactions_flat') IS NOT NULL
UNION ALL
SELECT 
    'v_silver_transactions',
    to_regclass('scout.v_silver_transactions') IS NOT NULL
UNION ALL
SELECT 
    'v_bronze_edge_raw',
    to_regclass('scout.v_bronze_edge_raw') IS NOT NULL;

-- =====================================================
-- 6. Check PostgREST exposure
-- =====================================================
SELECT 
    '--- POSTGREST SCHEMA EXPOSURE ---' as section;

-- This shows current PostgREST config
SELECT 
    current_setting('pgrst.db_schemas', true) as exposed_schemas,
    CASE 
        WHEN current_setting('pgrst.db_schemas', true) LIKE '%scout%' 
        THEN 'YES - Scout is exposed to PostgREST'
        ELSE 'NO - Scout is NOT exposed (this causes 406 errors!)'
    END as scout_exposed;

-- =====================================================
-- 7. Sample data check
-- =====================================================
SELECT 
    '--- SAMPLE DATA IN SCOUT TABLES ---' as section;

SELECT 
    'bronze_transactions' as table_name,
    count(*) as row_count
FROM scout.bronze_transactions
UNION ALL
SELECT 
    'silver_transactions',
    count(*)
FROM scout.silver_transactions
UNION ALL
SELECT 
    'gold_transactions',
    count(*)
FROM scout.gold_transactions;