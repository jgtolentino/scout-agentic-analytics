#!/usr/bin/env bash
# Apply security fixes to Supabase database
set -euo pipefail

echo "🔒 Applying Supabase security fixes..."
echo "This will:"
echo "1. Convert 67 SECURITY DEFINER views to SECURITY INVOKER"
echo "2. Enable RLS on 36 unprotected tables"
echo "3. Add basic RLS policies"
echo ""

# Backup current state first
echo "📸 Creating backup of current security state..."
:bruno run '
psql "$BRUNO_SECRET_db_url" -v ON_ERROR_STOP=1 <<SQL
-- Backup current view definitions
CREATE TABLE IF NOT EXISTS _security_backup_views AS
SELECT 
    schemaname,
    viewname,
    definition,
    now() as backup_time
FROM pg_views
WHERE schemaname = '\''public'\'';

-- Backup current RLS status
CREATE TABLE IF NOT EXISTS _security_backup_rls AS
SELECT 
    schemaname,
    tablename,
    (SELECT relrowsecurity FROM pg_class WHERE relname = tablename) as rls_enabled,
    now() as backup_time
FROM pg_tables
WHERE schemaname = '\''public'\'';
SQL
'

echo "✅ Backup created"
echo ""

# Apply the fixes
echo "🔧 Applying security fixes..."
:bruno run 'psql "$BRUNO_SECRET_db_url" -f scripts/fix-supabase-security-issues.sql'

echo ""
echo "📊 Verification Report:"
echo "===================="

# Verify fixes
:bruno run '
psql "$BRUNO_SECRET_db_url" -v ON_ERROR_STOP=1 <<SQL
-- Check for remaining SECURITY DEFINER views
SELECT 
    '\''SECURITY DEFINER views remaining:'\'' as metric,
    count(*) as count
FROM pg_views v
WHERE v.schemaname = '\''public'\''
AND EXISTS (
    SELECT 1 FROM pg_class c 
    JOIN pg_rewrite r ON r.ev_class = c.oid
    WHERE c.relname = v.viewname 
    AND r.ev_type = '\''1'\''::char
    AND r.ev_action::text LIKE '\''%security_definer%'\''
);

-- Check tables without RLS
SELECT 
    '\''Tables without RLS:'\'' as metric,
    count(*) as count
FROM pg_tables t
JOIN pg_class c ON c.relname = t.tablename
JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = t.schemaname
WHERE t.schemaname = '\''public'\''
AND NOT c.relrowsecurity;

-- Count RLS policies created
SELECT 
    '\''RLS policies created:'\'' as metric,
    count(*) as count
FROM pg_policies
WHERE schemaname = '\''public'\''
AND policyname LIKE '\''%Users can%'\''
   OR policyname LIKE '\''%Service role%'\''
   OR policyname LIKE '\''%Authenticated%'\''
   OR policyname LIKE '\''%Public read%'\'';
SQL
'

echo ""
echo "🎯 Next Steps:"
echo "============="
echo "1. Review the RLS policies in scripts/fix-supabase-security-issues.sql"
echo "2. Customize policies based on your actual access requirements"
echo "3. Test your application to ensure it still works with RLS enabled"
echo "4. Consider creating more granular policies for different user roles"
echo ""
echo "⚠️  IMPORTANT: The default policies are restrictive!"
echo "   - Most tables only allow authenticated users to read"
echo "   - Some tables are restricted to service_role only"
echo "   - You may need to adjust based on your app's needs"
echo ""
echo "To rollback if needed:"
echo "  psql \$DATABASE_URL -c 'SELECT * FROM _security_backup_views'"
echo "  psql \$DATABASE_URL -c 'SELECT * FROM _security_backup_rls'"