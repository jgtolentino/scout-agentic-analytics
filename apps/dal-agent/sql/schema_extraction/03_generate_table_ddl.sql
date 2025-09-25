-- Schema Extraction Script 3: Generate Table DDL
-- Purpose: Extract complete CREATE TABLE statements for all tables
-- Usage: Run in Azure SQL Query Editor or via sqlcmd

SET NOCOUNT ON;

PRINT '=== TABLE DDL GENERATION ===';
PRINT 'Server: sqltbwaprojectscoutserver.database.windows.net';
PRINT 'Database: SQL-TBWA-ProjectScout-Reporting-Prod';
PRINT 'Generated: ' + CONVERT(varchar(20), GETDATE(), 120);
PRINT '';

-- Variables for dynamic DDL generation
DECLARE @TableSchema nvarchar(128);
DECLARE @TableName nvarchar(128);
DECLARE @DDL nvarchar(max);
DECLARE @ColumnDefinitions nvarchar(max);
DECLARE @PrimaryKeyDef nvarchar(max);
DECLARE @ForeignKeyDefs nvarchar(max);
DECLARE @IndexDefs nvarchar(max);

-- Cursor for all user tables
DECLARE table_cursor CURSOR FOR
SELECT
    s.name as schema_name,
    t.name as table_name
FROM sys.tables t
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
ORDER BY s.name, t.name;

OPEN table_cursor;
FETCH NEXT FROM table_cursor INTO @TableSchema, @TableName;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT '-- ========================================';
    PRINT '-- Table: ' + @TableSchema + '.' + @TableName;
    PRINT '-- ========================================';

    -- Build column definitions
    SET @ColumnDefinitions = '';

    SELECT @ColumnDefinitions = @ColumnDefinitions +
        '    [' + c.name + '] ' +
        -- Data type with precision/scale
        CASE
            WHEN t.name IN ('char', 'varchar', 'nchar', 'nvarchar') THEN
                t.name + '(' +
                CASE WHEN c.max_length = -1 THEN 'max'
                     WHEN t.name IN ('nchar', 'nvarchar') THEN CAST(c.max_length/2 AS varchar(10))
                     ELSE CAST(c.max_length AS varchar(10))
                END + ')'
            WHEN t.name IN ('decimal', 'numeric') THEN
                t.name + '(' + CAST(c.precision AS varchar(10)) + ',' + CAST(c.scale AS varchar(10)) + ')'
            WHEN t.name IN ('float') THEN
                t.name + '(' + CAST(c.precision AS varchar(10)) + ')'
            WHEN t.name IN ('datetime2', 'datetimeoffset', 'time') THEN
                t.name + '(' + CAST(c.scale AS varchar(10)) + ')'
            ELSE t.name
        END +
        -- Identity specification
        CASE WHEN c.is_identity = 1 THEN ' IDENTITY(' + CAST(IDENT_SEED(SCHEMA_NAME(c.object_id) + '.' + OBJECT_NAME(c.object_id)) AS varchar(10)) + ',' + CAST(IDENT_INCR(SCHEMA_NAME(c.object_id) + '.' + OBJECT_NAME(c.object_id)) AS varchar(10)) + ')' ELSE '' END +
        -- Nullable
        CASE WHEN c.is_nullable = 1 THEN ' NULL' ELSE ' NOT NULL' END +
        -- Default constraint
        CASE WHEN dc.definition IS NOT NULL THEN ' DEFAULT ' + dc.definition ELSE '' END +
        ',' + CHAR(13) + CHAR(10)
    FROM sys.columns c
    INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
    LEFT JOIN sys.default_constraints dc ON c.default_object_id = dc.object_id
    WHERE c.object_id = OBJECT_ID(@TableSchema + '.' + @TableName)
    ORDER BY c.column_id;

    -- Remove trailing comma and newline
    SET @ColumnDefinitions = LEFT(@ColumnDefinitions, LEN(@ColumnDefinitions) - 3);

    -- Get Primary Key definition
    SET @PrimaryKeyDef = '';
    SELECT @PrimaryKeyDef =
        '    CONSTRAINT [' + kc.name + '] PRIMARY KEY ' +
        CASE WHEN i.type_desc = 'CLUSTERED' THEN 'CLUSTERED' ELSE 'NONCLUSTERED' END +
        ' (' +
        STUFF((SELECT ', [' + c.name + ']' + CASE WHEN ic.is_descending_key = 1 THEN ' DESC' ELSE ' ASC' END
               FROM sys.index_columns ic
               INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
               WHERE ic.object_id = kc.parent_object_id AND ic.index_id = i.index_id
               ORDER BY ic.key_ordinal
               FOR XML PATH('')), 1, 2, '') +
        ')'
    FROM sys.key_constraints kc
    INNER JOIN sys.indexes i ON kc.parent_object_id = i.object_id AND kc.unique_index_id = i.index_id
    WHERE kc.parent_object_id = OBJECT_ID(@TableSchema + '.' + @TableName)
      AND kc.type = 'PK';

    -- Generate CREATE TABLE statement
    SET @DDL = 'CREATE TABLE [' + @TableSchema + '].[' + @TableName + '] (' + CHAR(13) + CHAR(10) +
               @ColumnDefinitions;

    -- Add primary key if exists
    IF @PrimaryKeyDef != ''
        SET @DDL = @DDL + ',' + CHAR(13) + CHAR(10) + @PrimaryKeyDef;

    SET @DDL = @DDL + CHAR(13) + CHAR(10) + ');';

    PRINT @DDL;
    PRINT '';

    -- Get Foreign Key constraints
    SET @ForeignKeyDefs = '';

    DECLARE fk_cursor CURSOR FOR
    SELECT DISTINCT
        'ALTER TABLE [' + @TableSchema + '].[' + @TableName + '] ADD CONSTRAINT [' + fk.name + '] FOREIGN KEY (' +
        STUFF((SELECT ', [' + c.name + ']'
               FROM sys.foreign_key_columns fkc
               INNER JOIN sys.columns c ON fkc.parent_object_id = c.object_id AND fkc.parent_column_id = c.column_id
               WHERE fkc.constraint_object_id = fk.object_id
               ORDER BY fkc.constraint_column_id
               FOR XML PATH('')), 1, 2, '') +
        ') REFERENCES [' + rs.name + '].[' + rt.name + '] (' +
        STUFF((SELECT ', [' + c.name + ']'
               FROM sys.foreign_key_columns fkc
               INNER JOIN sys.columns c ON fkc.referenced_object_id = c.object_id AND fkc.referenced_column_id = c.column_id
               WHERE fkc.constraint_object_id = fk.object_id
               ORDER BY fkc.constraint_column_id
               FOR XML PATH('')), 1, 2, '') +
        ')' +
        CASE WHEN fk.update_referential_action_desc != 'NO_ACTION' THEN ' ON UPDATE ' + fk.update_referential_action_desc ELSE '' END +
        CASE WHEN fk.delete_referential_action_desc != 'NO_ACTION' THEN ' ON DELETE ' + fk.delete_referential_action_desc ELSE '' END +
        ';' as fk_definition
    FROM sys.foreign_keys fk
    INNER JOIN sys.tables rt ON fk.referenced_object_id = rt.object_id
    INNER JOIN sys.schemas rs ON rt.schema_id = rs.schema_id
    WHERE fk.parent_object_id = OBJECT_ID(@TableSchema + '.' + @TableName);

    DECLARE @FKDef nvarchar(max);
    OPEN fk_cursor;
    FETCH NEXT FROM fk_cursor INTO @FKDef;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        PRINT @FKDef;
        FETCH NEXT FROM fk_cursor INTO @FKDef;
    END

    CLOSE fk_cursor;
    DEALLOCATE fk_cursor;

    -- Get non-clustered indexes
    DECLARE index_cursor CURSOR FOR
    SELECT DISTINCT
        'CREATE ' +
        CASE WHEN i.is_unique = 1 THEN 'UNIQUE ' ELSE '' END +
        i.type_desc + ' INDEX [' + i.name + '] ON [' + @TableSchema + '].[' + @TableName + '] (' +
        STUFF((SELECT ', [' + c.name + ']' + CASE WHEN ic.is_descending_key = 1 THEN ' DESC' ELSE ' ASC' END
               FROM sys.index_columns ic
               INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
               WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
               ORDER BY ic.key_ordinal
               FOR XML PATH('')), 1, 2, '') +
        ')' +
        CASE WHEN EXISTS (SELECT 1 FROM sys.index_columns ic WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1) THEN
            ' INCLUDE (' +
            STUFF((SELECT ', [' + c.name + ']'
                   FROM sys.index_columns ic
                   INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
                   WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1
                   ORDER BY ic.index_column_id
                   FOR XML PATH('')), 1, 2, '') +
            ')'
        ELSE ''
        END +
        ';' as index_definition
    FROM sys.indexes i
    WHERE i.object_id = OBJECT_ID(@TableSchema + '.' + @TableName)
      AND i.is_primary_key = 0
      AND i.type > 0  -- Exclude heaps
      AND i.name IS NOT NULL;

    DECLARE @IndexDef nvarchar(max);
    OPEN index_cursor;
    FETCH NEXT FROM index_cursor INTO @IndexDef;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        PRINT @IndexDef;
        FETCH NEXT FROM index_cursor INTO @IndexDef;
    END

    CLOSE index_cursor;
    DEALLOCATE index_cursor;

    PRINT 'GO';
    PRINT '';

    FETCH NEXT FROM table_cursor INTO @TableSchema, @TableName;
END

CLOSE table_cursor;
DEALLOCATE table_cursor;

-- Generate table statistics
PRINT '-- ========================================';
PRINT '-- TABLE STATISTICS SUMMARY';
PRINT '-- ========================================';

SELECT
    s.name as schema_name,
    t.name as table_name,
    (SELECT COUNT(*) FROM sys.columns c WHERE c.object_id = t.object_id) as column_count,
    (SELECT COUNT(*) FROM sys.indexes i WHERE i.object_id = t.object_id AND i.type > 0) as index_count,
    (SELECT COUNT(*) FROM sys.foreign_keys fk WHERE fk.parent_object_id = t.object_id) as fk_count,
    t.create_date,
    t.modify_date
FROM sys.tables t
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
ORDER BY s.name, t.name;

PRINT '';
PRINT '=== TABLE DDL GENERATION COMPLETE ===';