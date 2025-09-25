-- Schema Extraction Script 1: Complete Database Inventory
-- Purpose: Catalog all objects in the production database
-- Usage: Run in Azure SQL Query Editor or via sqlcmd

SET NOCOUNT ON;

PRINT '=== PRODUCTION DATABASE INVENTORY ===';
PRINT 'Server: sqltbwaprojectscoutserver.database.windows.net';
PRINT 'Database: SQL-TBWA-ProjectScout-Reporting-Prod';
PRINT 'Generated: ' + CONVERT(varchar(20), GETDATE(), 120);
PRINT '';

-- 1. Schema inventory
PRINT '=== SCHEMAS ===';
SELECT
    s.name as schema_name,
    s.schema_id,
    p.name as principal_name
FROM sys.schemas s
JOIN sys.database_principals p ON s.principal_id = p.principal_id
WHERE s.name NOT IN ('sys', 'INFORMATION_SCHEMA', 'db_owner', 'db_accessadmin', 'db_securityadmin', 'db_ddladmin', 'db_datareader', 'db_datawriter', 'db_denydatareader', 'db_denydatawriter', 'db_backupoperator')
ORDER BY s.name;

-- 2. Table inventory by schema
PRINT '';
PRINT '=== TABLES BY SCHEMA ===';
SELECT
    s.name as schema_name,
    t.name as table_name,
    t.object_id,
    t.create_date,
    t.modify_date,
    (SELECT COUNT(*) FROM sys.columns c WHERE c.object_id = t.object_id) as column_count
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
ORDER BY s.name, t.name;

-- 3. View inventory by schema
PRINT '';
PRINT '=== VIEWS BY SCHEMA ===';
SELECT
    s.name as schema_name,
    v.name as view_name,
    v.object_id,
    v.create_date,
    v.modify_date,
    CASE WHEN m.definition IS NOT NULL THEN 'Has Definition' ELSE 'No Definition' END as definition_status
FROM sys.views v
JOIN sys.schemas s ON v.schema_id = s.schema_id
LEFT JOIN sys.sql_modules m ON v.object_id = m.object_id
ORDER BY s.name, v.name;

-- 4. Stored procedure inventory
PRINT '';
PRINT '=== STORED PROCEDURES BY SCHEMA ===';
SELECT
    s.name as schema_name,
    p.name as procedure_name,
    p.object_id,
    p.create_date,
    p.modify_date,
    CASE WHEN m.definition IS NOT NULL THEN 'Has Definition' ELSE 'No Definition' END as definition_status
FROM sys.procedures p
JOIN sys.schemas s ON p.schema_id = s.schema_id
LEFT JOIN sys.sql_modules m ON p.object_id = m.object_id
ORDER BY s.name, p.name;

-- 5. Function inventory
PRINT '';
PRINT '=== FUNCTIONS BY SCHEMA ===';
SELECT
    s.name as schema_name,
    o.name as function_name,
    o.object_id,
    o.create_date,
    o.modify_date,
    o.type_desc
FROM sys.objects o
JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE o.type IN ('FN', 'IF', 'TF')
ORDER BY s.name, o.name;

-- 6. Index summary
PRINT '';
PRINT '=== INDEX SUMMARY ===';
SELECT
    s.name as schema_name,
    t.name as table_name,
    i.name as index_name,
    i.type_desc,
    i.is_unique,
    i.is_primary_key,
    (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id) as column_count
FROM sys.indexes i
JOIN sys.tables t ON i.object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE i.name IS NOT NULL
ORDER BY s.name, t.name, i.name;

-- 7. Foreign key relationships
PRINT '';
PRINT '=== FOREIGN KEY RELATIONSHIPS ===';
SELECT
    s1.name as parent_schema,
    t1.name as parent_table,
    fk.name as foreign_key_name,
    s2.name as referenced_schema,
    t2.name as referenced_table,
    (SELECT STRING_AGG(c1.name, ', ') FROM sys.foreign_key_columns fkc
     JOIN sys.columns c1 ON fkc.parent_object_id = c1.object_id AND fkc.parent_column_id = c1.column_id
     WHERE fkc.constraint_object_id = fk.object_id) as parent_columns,
    (SELECT STRING_AGG(c2.name, ', ') FROM sys.foreign_key_columns fkc
     JOIN sys.columns c2 ON fkc.referenced_object_id = c2.object_id AND fkc.referenced_column_id = c2.column_id
     WHERE fkc.constraint_object_id = fk.object_id) as referenced_columns
FROM sys.foreign_keys fk
JOIN sys.tables t1 ON fk.parent_object_id = t1.object_id
JOIN sys.schemas s1 ON t1.schema_id = s1.schema_id
JOIN sys.tables t2 ON fk.referenced_object_id = t2.object_id
JOIN sys.schemas s2 ON t2.schema_id = s2.schema_id
ORDER BY s1.name, t1.name;

-- 8. Object count summary
PRINT '';
PRINT '=== OBJECT COUNT SUMMARY ===';
SELECT
    'Tables' as object_type,
    COUNT(*) as count
FROM sys.tables
UNION ALL
SELECT
    'Views' as object_type,
    COUNT(*) as count
FROM sys.views
UNION ALL
SELECT
    'Stored Procedures' as object_type,
    COUNT(*) as count
FROM sys.procedures
UNION ALL
SELECT
    'Functions' as object_type,
    COUNT(*) as count
FROM sys.objects
WHERE type IN ('FN', 'IF', 'TF')
UNION ALL
SELECT
    'Foreign Keys' as object_type,
    COUNT(*) as count
FROM sys.foreign_keys
ORDER BY object_type;

PRINT '';
PRINT '=== INVENTORY COMPLETE ===';