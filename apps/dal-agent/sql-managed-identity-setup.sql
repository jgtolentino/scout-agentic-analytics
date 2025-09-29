-- Scout Analytics - Managed Identity + AAD Contained User Setup
-- Run as SQL Admin to configure secure authentication

-- 1. Create login in master database (run in master)
USE master;
GO

-- Create login for Function App managed identity
-- Replace 'scout-func-mi' with your actual Function App managed identity name
IF NOT EXISTS (SELECT * FROM sys.sql_logins WHERE name = 'scout-func-mi')
BEGIN
    CREATE LOGIN [scout-func-mi] FROM EXTERNAL PROVIDER;
    PRINT '✅ Created login for scout-func-mi in master';
END
ELSE
BEGIN
    PRINT 'ℹ️ Login scout-func-mi already exists in master';
END
GO

-- 2. Switch to target database and create contained user
USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Create contained user for Function App
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'scout-func-mi' AND type = 'E')
BEGIN
    CREATE USER [scout-func-mi] FROM EXTERNAL PROVIDER;
    PRINT '✅ Created contained user scout-func-mi';
END
ELSE
BEGIN
    PRINT 'ℹ️ User scout-func-mi already exists';
END
GO

-- Grant necessary permissions
EXEC sp_addrolemember 'db_datareader', 'scout-func-mi';
EXEC sp_addrolemember 'db_datawriter', 'scout-func-mi';
PRINT '✅ Granted db_datareader and db_datawriter roles to scout-func-mi';

-- Grant specific permissions for analytics views
GRANT SELECT ON dbo.v_flat_export_sheet TO [scout-func-mi];
GRANT SELECT ON gold.v_docs_rag TO [scout-func-mi];
PRINT '✅ Granted SELECT permissions on analytics views';

-- Grant execute permissions for stored procedures (if needed)
-- GRANT EXECUTE ON sp_refresh_analytics_views TO [scout-func-mi];

-- Verify permissions
SELECT
    dp.name AS principal_name,
    dp.type_desc AS principal_type,
    r.name AS role_name
FROM sys.database_role_members rm
JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
JOIN sys.database_principals dp ON rm.member_principal_id = dp.principal_id
WHERE dp.name = 'scout-func-mi';

PRINT '✅ Managed Identity authentication setup complete';
PRINT 'ℹ️ Next: Configure Function App with system-assigned managed identity';
PRINT 'ℹ️ Update connection strings to use MI authentication';