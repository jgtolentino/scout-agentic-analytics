-- Schema Extraction Script 2: View and Procedure Definitions
-- Purpose: Extract complete DDL for all views and stored procedures
-- Usage: Run in Azure SQL Query Editor or via sqlcmd

SET NOCOUNT ON;

PRINT '=== VIEW AND PROCEDURE DEFINITIONS ===';
PRINT 'Server: sqltbwaprojectscoutserver.database.windows.net';
PRINT 'Database: SQL-TBWA-ProjectScout-Reporting-Prod';
PRINT 'Generated: ' + CONVERT(varchar(20), GETDATE(), 120);
PRINT '';

-- 1. Extract all view definitions
PRINT '=== VIEW DEFINITIONS ===';
DECLARE @schema_name nvarchar(128);
DECLARE @object_name nvarchar(128);
DECLARE @definition nvarchar(max);

-- Cursor for all views
DECLARE view_cursor CURSOR FOR
SELECT
    s.name as schema_name,
    v.name as view_name
FROM sys.views v
JOIN sys.schemas s ON v.schema_id = s.schema_id
ORDER BY s.name, v.name;

OPEN view_cursor;
FETCH NEXT FROM view_cursor INTO @schema_name, @object_name;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Get view definition
    SELECT @definition = m.definition
    FROM sys.sql_modules m
    JOIN sys.views v ON m.object_id = v.object_id
    WHERE v.name = @object_name AND SCHEMA_NAME(v.schema_id) = @schema_name;

    IF @definition IS NOT NULL
    BEGIN
        PRINT '-- ========================================';
        PRINT '-- View: ' + @schema_name + '.' + @object_name;
        PRINT '-- ========================================';
        PRINT @definition;
        PRINT '';
        PRINT 'GO';
        PRINT '';
    END
    ELSE
    BEGIN
        PRINT '-- View ' + @schema_name + '.' + @object_name + ' has no definition available';
        PRINT '';
    END

    FETCH NEXT FROM view_cursor INTO @schema_name, @object_name;
END

CLOSE view_cursor;
DEALLOCATE view_cursor;

-- 2. Extract all stored procedure definitions
PRINT '=== STORED PROCEDURE DEFINITIONS ===';

-- Cursor for all stored procedures
DECLARE proc_cursor CURSOR FOR
SELECT
    s.name as schema_name,
    p.name as procedure_name
FROM sys.procedures p
JOIN sys.schemas s ON p.schema_id = s.schema_id
ORDER BY s.name, p.name;

OPEN proc_cursor;
FETCH NEXT FROM proc_cursor INTO @schema_name, @object_name;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Get procedure definition
    SELECT @definition = m.definition
    FROM sys.sql_modules m
    JOIN sys.procedures p ON m.object_id = p.object_id
    WHERE p.name = @object_name AND SCHEMA_NAME(p.schema_id) = @schema_name;

    IF @definition IS NOT NULL
    BEGIN
        PRINT '-- ========================================';
        PRINT '-- Stored Procedure: ' + @schema_name + '.' + @object_name;
        PRINT '-- ========================================';
        PRINT @definition;
        PRINT '';
        PRINT 'GO';
        PRINT '';
    END
    ELSE
    BEGIN
        PRINT '-- Stored Procedure ' + @schema_name + '.' + @object_name + ' has no definition available';
        PRINT '';
    END

    FETCH NEXT FROM proc_cursor INTO @schema_name, @object_name;
END

CLOSE proc_cursor;
DEALLOCATE proc_cursor;

-- 3. Extract all function definitions
PRINT '=== FUNCTION DEFINITIONS ===';

-- Cursor for all functions
DECLARE func_cursor CURSOR FOR
SELECT
    s.name as schema_name,
    o.name as function_name,
    o.type_desc
FROM sys.objects o
JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE o.type IN ('FN', 'IF', 'TF')
ORDER BY s.name, o.name;

DECLARE @type_desc nvarchar(60);

OPEN func_cursor;
FETCH NEXT FROM func_cursor INTO @schema_name, @object_name, @type_desc;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Get function definition
    SELECT @definition = m.definition
    FROM sys.sql_modules m
    JOIN sys.objects o ON m.object_id = o.object_id
    WHERE o.name = @object_name AND SCHEMA_NAME(o.schema_id) = @schema_name;

    IF @definition IS NOT NULL
    BEGIN
        PRINT '-- ========================================';
        PRINT '-- Function: ' + @schema_name + '.' + @object_name + ' (' + @type_desc + ')';
        PRINT '-- ========================================';
        PRINT @definition;
        PRINT '';
        PRINT 'GO';
        PRINT '';
    END
    ELSE
    BEGIN
        PRINT '-- Function ' + @schema_name + '.' + @object_name + ' has no definition available';
        PRINT '';
    END

    FETCH NEXT FROM func_cursor INTO @schema_name, @object_name, @type_desc;
END

CLOSE func_cursor;
DEALLOCATE func_cursor;

-- 4. Extract critical view definitions with metadata
PRINT '=== CRITICAL ANALYTICS VIEWS METADATA ===';

WITH ViewMetadata AS (
    SELECT
        s.name as schema_name,
        v.name as view_name,
        v.create_date,
        v.modify_date,
        LEN(m.definition) as definition_length,
        CASE
            WHEN m.definition LIKE '%SELECT%COUNT%' THEN 'Contains Aggregation'
            WHEN m.definition LIKE '%JOIN%' THEN 'Contains Joins'
            WHEN m.definition LIKE '%UNION%' THEN 'Contains Union'
            ELSE 'Simple Select'
        END as complexity_indicator,
        CASE
            WHEN v.name LIKE '%export%' THEN 'Export View'
            WHEN v.name LIKE '%analytics%' THEN 'Analytics View'
            WHEN v.name LIKE '%flat%' THEN 'Flat View'
            WHEN v.name LIKE '%xtab%' THEN 'Cross-Tab View'
            ELSE 'Other'
        END as view_category
    FROM sys.views v
    JOIN sys.schemas s ON v.schema_id = s.schema_id
    LEFT JOIN sys.sql_modules m ON v.object_id = m.object_id
)
SELECT
    schema_name,
    view_name,
    view_category,
    complexity_indicator,
    create_date,
    modify_date,
    definition_length
FROM ViewMetadata
WHERE view_category IN ('Export View', 'Analytics View', 'Flat View', 'Cross-Tab View')
   OR schema_name IN ('dbo', 'gold', 'scout', 'ref')
ORDER BY
    CASE view_category
        WHEN 'Export View' THEN 1
        WHEN 'Analytics View' THEN 2
        WHEN 'Flat View' THEN 3
        WHEN 'Cross-Tab View' THEN 4
        ELSE 5
    END,
    schema_name,
    view_name;

PRINT '';
PRINT '=== DEFINITION EXTRACTION COMPLETE ===';