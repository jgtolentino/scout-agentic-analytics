-- Schema Extraction Script 4: Schema Creation Statements
-- Purpose: Extract all schema creation statements and permissions
-- Usage: Run in Azure SQL Query Editor or via sqlcmd

SET NOCOUNT ON;

PRINT '=== SCHEMA CREATION STATEMENTS ===';
PRINT 'Server: sqltbwaprojectscoutserver.database.windows.net';
PRINT 'Database: SQL-TBWA-ProjectScout-Reporting-Prod';
PRINT 'Generated: ' + CONVERT(varchar(20), GETDATE(), 120);
PRINT '';

-- 1. Generate schema creation statements
PRINT '=== CREATE SCHEMA STATEMENTS ===';
PRINT '-- Execute these statements in order to recreate database schemas';
PRINT '';

SELECT
    'CREATE SCHEMA [' + s.name + '] AUTHORIZATION [' + p.name + '];' as create_statement
FROM sys.schemas s
INNER JOIN sys.database_principals p ON s.principal_id = p.principal_id
WHERE s.name NOT IN ('sys', 'INFORMATION_SCHEMA', 'guest', 'dbo')
  AND s.name NOT IN ('db_owner', 'db_accessadmin', 'db_securityadmin', 'db_ddladmin',
                     'db_datareader', 'db_datawriter', 'db_denydatareader',
                     'db_denydatawriter', 'db_backupoperator')
ORDER BY s.name;

PRINT '';
PRINT 'GO';
PRINT '';

-- 2. Schema usage analysis
PRINT '=== SCHEMA USAGE ANALYSIS ===';

WITH SchemaUsage AS (
    SELECT
        s.name as schema_name,
        COUNT(CASE WHEN o.type = 'U' THEN 1 END) as table_count,
        COUNT(CASE WHEN o.type = 'V' THEN 1 END) as view_count,
        COUNT(CASE WHEN o.type = 'P' THEN 1 END) as procedure_count,
        COUNT(CASE WHEN o.type IN ('FN', 'IF', 'TF') THEN 1 END) as function_count,
        COUNT(o.object_id) as total_objects
    FROM sys.schemas s
    LEFT JOIN sys.objects o ON s.schema_id = o.schema_id
    WHERE s.name NOT IN ('sys', 'INFORMATION_SCHEMA', 'guest')
      AND s.name NOT IN ('db_owner', 'db_accessadmin', 'db_securityadmin', 'db_ddladmin',
                         'db_datareader', 'db_datawriter', 'db_denydatareader',
                         'db_denydatawriter', 'db_backupoperator')
    GROUP BY s.name, s.schema_id
)
SELECT
    schema_name,
    table_count,
    view_count,
    procedure_count,
    function_count,
    total_objects,
    CASE
        WHEN schema_name = 'dbo' THEN 'Default Schema - Core Business Objects'
        WHEN schema_name = 'bronze' THEN 'Bronze Layer - Raw Data Ingestion'
        WHEN schema_name = 'silver' THEN 'Silver Layer - Cleaned Data'
        WHEN schema_name = 'gold' THEN 'Gold Layer - Analytics Ready Data'
        WHEN schema_name = 'scout' THEN 'Scout Analytics - Primary Analytics Source'
        WHEN schema_name = 'ref' THEN 'Reference Data - Lookup Tables'
        WHEN schema_name = 'staging' THEN 'Staging Area - Data Processing'
        WHEN schema_name = 'ces' THEN 'Campaign Effectiveness System'
        WHEN schema_name = 'poc' THEN 'Proof of Concept - Testing'
        WHEN schema_name = 'ops' THEN 'Operations - Monitoring and Logs'
        WHEN schema_name = 'cdc' THEN 'Change Data Capture'
        ELSE 'Custom Schema'
    END as schema_purpose
FROM SchemaUsage
ORDER BY total_objects DESC, schema_name;

-- 3. Schema dependencies analysis
PRINT '';
PRINT '=== SCHEMA DEPENDENCIES ===';

WITH SchemaDependencies AS (
    SELECT DISTINCT
        s1.name as referencing_schema,
        s2.name as referenced_schema,
        COUNT(*) as reference_count
    FROM sys.sql_expression_dependencies d
    INNER JOIN sys.objects o1 ON d.referencing_id = o1.object_id
    INNER JOIN sys.schemas s1 ON o1.schema_id = s1.schema_id
    INNER JOIN sys.objects o2 ON d.referenced_id = o2.object_id
    INNER JOIN sys.schemas s2 ON o2.schema_id = s2.schema_id
    WHERE s1.name != s2.name  -- Cross-schema dependencies only
    GROUP BY s1.name, s2.name
)
SELECT
    referencing_schema + ' -> ' + referenced_schema as dependency_chain,
    reference_count
FROM SchemaDependencies
ORDER BY referencing_schema, referenced_schema;

-- 4. Critical objects by schema
PRINT '';
PRINT '=== CRITICAL OBJECTS BY SCHEMA ===';

-- Identify critical analytics objects
SELECT
    s.name as schema_name,
    o.name as object_name,
    o.type_desc,
    CASE
        WHEN o.name LIKE '%export%' THEN 'Export Object'
        WHEN o.name LIKE '%analytics%' THEN 'Analytics Object'
        WHEN o.name LIKE '%flat%' THEN 'Flat Data Object'
        WHEN o.name LIKE '%xtab%' OR o.name LIKE '%cross%' THEN 'Cross-Tab Object'
        WHEN o.name LIKE '%dashboard%' THEN 'Dashboard Object'
        WHEN o.name LIKE '%nielsen%' THEN 'Nielsen Taxonomy Object'
        WHEN o.name LIKE '%brand%' THEN 'Brand Management Object'
        WHEN o.name LIKE '%transaction%' THEN 'Transaction Processing Object'
        ELSE 'Standard Object'
    END as object_category,
    o.create_date,
    o.modify_date
FROM sys.objects o
INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE s.name IN ('dbo', 'scout', 'gold', 'bronze', 'ref', 'ces')
  AND o.type IN ('U', 'V', 'P', 'FN', 'IF', 'TF')
  AND (
    o.name LIKE '%export%' OR
    o.name LIKE '%analytics%' OR
    o.name LIKE '%flat%' OR
    o.name LIKE '%xtab%' OR
    o.name LIKE '%dashboard%' OR
    o.name LIKE '%nielsen%' OR
    o.name LIKE '%brand%' OR
    o.name LIKE '%transaction%'
  )
ORDER BY
    CASE object_category
        WHEN 'Export Object' THEN 1
        WHEN 'Analytics Object' THEN 2
        WHEN 'Dashboard Object' THEN 3
        WHEN 'Flat Data Object' THEN 4
        WHEN 'Cross-Tab Object' THEN 5
        WHEN 'Nielsen Taxonomy Object' THEN 6
        WHEN 'Brand Management Object' THEN 7
        WHEN 'Transaction Processing Object' THEN 8
        ELSE 9
    END,
    s.name,
    o.name;

-- 5. Schema creation order recommendation
PRINT '';
PRINT '=== RECOMMENDED SCHEMA CREATION ORDER ===';
PRINT '-- Based on dependencies and medallion architecture';
PRINT '';

SELECT
    ROW_NUMBER() OVER (ORDER BY creation_priority) as step_number,
    schema_name,
    creation_priority,
    reason
FROM (
    VALUES
        ('ref', 1, 'Reference data - no dependencies'),
        ('bronze', 2, 'Raw data ingestion - minimal dependencies'),
        ('staging', 3, 'Data processing - depends on bronze'),
        ('scout', 4, 'Primary analytics - depends on ref and bronze'),
        ('gold', 5, 'Analytics ready - depends on scout'),
        ('dbo', 6, 'Views and analytics - depends on gold and scout'),
        ('ces', 7, 'Campaign effectiveness - depends on scout'),
        ('ops', 8, 'Operations monitoring - depends on core schemas'),
        ('cdc', 9, 'Change data capture - depends on operational schemas'),
        ('poc', 10, 'Proof of concept - for testing')
) AS SchemaOrder(schema_name, creation_priority, reason)
ORDER BY creation_priority;

-- 6. Data lineage summary
PRINT '';
PRINT '=== DATA LINEAGE SUMMARY ===';
PRINT '-- Medallion Architecture Data Flow';
PRINT '';

SELECT
    'Bronze -> Scout -> Gold -> DBO Views' as data_flow,
    'Raw ingestion -> Clean transactional -> Analytics ready -> Business views' as transformation_stages,
    'PayloadTransactions -> SalesInteractions -> scout_dashboard_transactions -> v_flat_export_sheet' as example_lineage;

PRINT '';
PRINT '=== SCHEMA EXTRACTION COMPLETE ===';