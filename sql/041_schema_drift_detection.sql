-- ================================================================
-- Scout v7 Schema Drift Detection Infrastructure
-- ================================================================
-- Purpose: Bi-directional auto-sync system for database schema
-- - Captures all DDL changes via triggers
-- - Enables documentation platform auto-generation
-- - Protects flatten.py and ETL components from breaking changes
-- ================================================================

-- Enable Change Tracking on Database (if not already enabled)
IF NOT EXISTS (SELECT 1 FROM sys.change_tracking_databases WHERE database_id = DB_ID())
BEGIN
    ALTER DATABASE CURRENT
    SET CHANGE_TRACKING = ON (CHANGE_RETENTION = 7 DAYS, AUTO_CLEANUP = ON);
    PRINT '✅ Change Tracking enabled for schema drift detection'
END

-- Schema Drift Log Table
-- Captures every DDL operation for bi-directional sync
CREATE TABLE system.schema_drift_log (
    drift_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    event_time DATETIME2(3) NOT NULL DEFAULT GETDATE(),
    event_type NVARCHAR(100) NOT NULL, -- CREATE_TABLE, ALTER_TABLE, DROP_TABLE, etc.
    database_name NVARCHAR(128) NOT NULL,
    schema_name NVARCHAR(128) NOT NULL,
    object_name NVARCHAR(128) NOT NULL,
    object_type NVARCHAR(60) NOT NULL, -- TABLE, VIEW, PROCEDURE, FUNCTION
    ddl_command NVARCHAR(MAX), -- Full DDL statement
    login_name NVARCHAR(128) NOT NULL,
    app_name NVARCHAR(128),
    host_name NVARCHAR(128),
    sync_status NVARCHAR(20) DEFAULT 'PENDING', -- PENDING, PR_CREATED, SYNCED, FAILED
    sync_pr_number INT NULL, -- GitHub PR number for tracking
    sync_error NVARCHAR(MAX) NULL,
    created_at DATETIME2(3) NOT NULL DEFAULT GETDATE(),
    updated_at DATETIME2(3) NOT NULL DEFAULT GETDATE()
);

-- Index for efficient querying by sync status and time
CREATE INDEX IX_schema_drift_log_sync_status
ON system.schema_drift_log (sync_status, event_time DESC);

CREATE INDEX IX_schema_drift_log_object
ON system.schema_drift_log (schema_name, object_name, event_time DESC);

-- Schema Object Hash Table
-- For computing precise deltas and detecting changes
CREATE TABLE system.schema_object_hash (
    hash_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    schema_name NVARCHAR(128) NOT NULL,
    object_name NVARCHAR(128) NOT NULL,
    object_type NVARCHAR(60) NOT NULL,
    definition_hash VARBINARY(32) NOT NULL, -- SHA-256 of object definition
    column_hash VARBINARY(32) NULL, -- SHA-256 of column structure (tables only)
    constraint_hash VARBINARY(32) NULL, -- SHA-256 of constraints (tables only)
    object_definition NVARCHAR(MAX), -- Full object definition
    snapshot_time DATETIME2(3) NOT NULL DEFAULT GETDATE(),
    is_current BIT NOT NULL DEFAULT 1,

    CONSTRAINT UQ_schema_object_hash_current
    UNIQUE (schema_name, object_name, object_type, is_current)
);

-- DDL Trigger for Schema Change Capture
-- Captures ALL DDL operations automatically
CREATE OR ALTER TRIGGER system.trg_capture_schema_drift
ON DATABASE
FOR DDL_TABLE_EVENTS, DDL_VIEW_EVENTS, DDL_PROCEDURE_EVENTS, DDL_FUNCTION_EVENTS
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @event_data XML = EVENTDATA();
    DECLARE @event_type NVARCHAR(100) = @event_data.value('(/EVENT_INSTANCE/EventType)[1]', 'NVARCHAR(100)');
    DECLARE @database_name NVARCHAR(128) = @event_data.value('(/EVENT_INSTANCE/DatabaseName)[1]', 'NVARCHAR(128)');
    DECLARE @schema_name NVARCHAR(128) = @event_data.value('(/EVENT_INSTANCE/SchemaName)[1]', 'NVARCHAR(128)');
    DECLARE @object_name NVARCHAR(128) = @event_data.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(128)');
    DECLARE @object_type NVARCHAR(60) = @event_data.value('(/EVENT_INSTANCE/ObjectType)[1]', 'NVARCHAR(60)');
    DECLARE @ddl_command NVARCHAR(MAX) = @event_data.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)');
    DECLARE @login_name NVARCHAR(128) = @event_data.value('(/EVENT_INSTANCE/LoginName)[1]', 'NVARCHAR(128)');

    -- Skip system-generated changes and our own sync operations
    IF @schema_name IN ('sys', 'INFORMATION_SCHEMA')
       OR @login_name = 'schema_sync_agent'
       OR @ddl_command LIKE '%-- SCHEMA_SYNC_GENERATED%'
        RETURN;

    -- Log the schema change
    INSERT INTO system.schema_drift_log (
        event_type, database_name, schema_name, object_name, object_type,
        ddl_command, login_name, app_name, host_name
    )
    VALUES (
        @event_type, @database_name, @schema_name, @object_name, @object_type,
        @ddl_command, @login_name, APP_NAME(), HOST_NAME()
    );

    -- Update schema hash for the affected object
    EXEC system.sp_update_schema_hash @schema_name, @object_name, @object_type;
END;

-- Schema Snapshot Procedure
-- Creates comprehensive snapshot of current schema state
CREATE OR ALTER PROCEDURE system.sp_schema_snapshot
    @output_format NVARCHAR(20) = 'JSON' -- JSON, MARKDOWN, YAML
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @snapshot TABLE (
        schema_name NVARCHAR(128),
        object_name NVARCHAR(128),
        object_type NVARCHAR(60),
        column_count INT,
        definition_preview NVARCHAR(500)
    );

    -- Tables
    INSERT INTO @snapshot
    SELECT
        s.name AS schema_name,
        t.name AS object_name,
        'TABLE' AS object_type,
        COUNT(c.column_id) AS column_count,
        CONCAT('Columns: ', STRING_AGG(c.name, ', ')) AS definition_preview
    FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    LEFT JOIN sys.columns c ON t.object_id = c.object_id
    WHERE s.name NOT IN ('sys', 'INFORMATION_SCHEMA')
    GROUP BY s.name, t.name;

    -- Views
    INSERT INTO @snapshot
    SELECT
        s.name AS schema_name,
        v.name AS object_name,
        'VIEW' AS object_type,
        0 AS column_count,
        LEFT(m.definition, 500) AS definition_preview
    FROM sys.views v
    JOIN sys.schemas s ON v.schema_id = s.schema_id
    LEFT JOIN sys.sql_modules m ON v.object_id = m.object_id
    WHERE s.name NOT IN ('sys', 'INFORMATION_SCHEMA');

    -- Procedures
    INSERT INTO @snapshot
    SELECT
        s.name AS schema_name,
        p.name AS object_name,
        'PROCEDURE' AS object_type,
        0 AS column_count,
        LEFT(m.definition, 500) AS definition_preview
    FROM sys.procedures p
    JOIN sys.schemas s ON p.schema_id = s.schema_id
    LEFT JOIN sys.sql_modules m ON p.object_id = m.object_id
    WHERE s.name NOT IN ('sys', 'INFORMATION_SCHEMA');

    IF @output_format = 'JSON'
    BEGIN
        SELECT
            schema_name,
            object_name,
            object_type,
            column_count,
            definition_preview
        FROM @snapshot
        ORDER BY schema_name, object_type, object_name
        FOR JSON AUTO;
    END
    ELSE IF @output_format = 'MARKDOWN'
    BEGIN
        -- Markdown table format for documentation
        SELECT
            CONCAT('| ', schema_name, ' | ', object_name, ' | ', object_type, ' | ',
                   CAST(column_count AS NVARCHAR), ' | ', definition_preview, ' |') AS markdown_row
        FROM @snapshot
        ORDER BY schema_name, object_type, object_name;
    END
    ELSE
    BEGIN
        -- Default tabular output
        SELECT * FROM @snapshot
        ORDER BY schema_name, object_type, object_name;
    END
END;

-- Schema Hash Update Procedure
-- Computes and stores hash for schema object
CREATE OR ALTER PROCEDURE system.sp_update_schema_hash
    @schema_name NVARCHAR(128),
    @object_name NVARCHAR(128),
    @object_type NVARCHAR(60)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @object_definition NVARCHAR(MAX);
    DECLARE @definition_hash VARBINARY(32);
    DECLARE @column_hash VARBINARY(32) = NULL;
    DECLARE @constraint_hash VARBINARY(32) = NULL;

    -- Get object definition based on type
    IF @object_type = 'TABLE'
    BEGIN
        -- For tables, get CREATE TABLE statement
        DECLARE @table_def NVARCHAR(MAX);
        SELECT @table_def = CONCAT(
            'CREATE TABLE [', @schema_name, '].[', @object_name, '] (',
            STRING_AGG(
                CONCAT(
                    '[', c.name, '] ',
                    UPPER(t.name),
                    CASE
                        WHEN t.name IN ('varchar', 'char', 'nvarchar', 'nchar')
                        THEN CONCAT('(', CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length AS VARCHAR) END, ')')
                        WHEN t.name IN ('decimal', 'numeric')
                        THEN CONCAT('(', c.precision, ',', c.scale, ')')
                        ELSE ''
                    END,
                    CASE WHEN c.is_nullable = 0 THEN ' NOT NULL' ELSE '' END
                ),
                ', '
            ),
            ')'
        )
        FROM sys.columns c
        JOIN sys.types t ON c.user_type_id = t.user_type_id
        WHERE c.object_id = OBJECT_ID(@schema_name + '.' + @object_name);

        SET @object_definition = @table_def;

        -- Column structure hash
        SELECT @column_hash = HASHBYTES('SHA2_256', STRING_AGG(
            CONCAT(c.name, ':', t.name, ':', c.max_length, ':', c.is_nullable), '|'
        ))
        FROM sys.columns c
        JOIN sys.types t ON c.user_type_id = t.user_type_id
        WHERE c.object_id = OBJECT_ID(@schema_name + '.' + @object_name);

    END
    ELSE
    BEGIN
        -- For views, procedures, functions - get definition from sys.sql_modules
        SELECT @object_definition = definition
        FROM sys.sql_modules m
        JOIN sys.objects o ON m.object_id = o.object_id
        JOIN sys.schemas s ON o.schema_id = s.schema_id
        WHERE s.name = @schema_name AND o.name = @object_name;
    END

    -- Compute definition hash
    SET @definition_hash = HASHBYTES('SHA2_256', ISNULL(@object_definition, ''));

    -- Mark previous hash as not current
    UPDATE system.schema_object_hash
    SET is_current = 0, updated_at = GETDATE()
    WHERE schema_name = @schema_name
      AND object_name = @object_name
      AND object_type = @object_type
      AND is_current = 1;

    -- Insert new hash record
    INSERT INTO system.schema_object_hash (
        schema_name, object_name, object_type,
        definition_hash, column_hash, constraint_hash,
        object_definition, is_current
    )
    VALUES (
        @schema_name, @object_name, @object_type,
        @definition_hash, @column_hash, @constraint_hash,
        @object_definition, 1
    );
END;

-- Schema Drift Detection Function
-- Identifies objects that have changed since last sync
CREATE OR ALTER FUNCTION system.fn_get_pending_schema_drift()
RETURNS TABLE
AS
RETURN (
    SELECT
        drift_id,
        event_time,
        event_type,
        schema_name,
        object_name,
        object_type,
        ddl_command,
        login_name,
        DATEDIFF(HOUR, event_time, GETDATE()) AS hours_since_change
    FROM system.schema_drift_log
    WHERE sync_status = 'PENDING'
      AND event_time >= DATEADD(DAY, -7, GETDATE()) -- Only last 7 days
);

-- Documentation Generation View
-- Provides structured data for MkDocs auto-generation
CREATE OR ALTER VIEW system.vw_schema_documentation AS
SELECT
    s.name AS schema_name,
    t.name AS table_name,
    'TABLE' AS object_type,
    c.name AS column_name,
    tp.name AS data_type,
    CASE
        WHEN tp.name IN ('varchar', 'char', 'nvarchar', 'nchar')
        THEN CAST(c.max_length AS VARCHAR)
        WHEN tp.name IN ('decimal', 'numeric')
        THEN CONCAT(c.precision, ',', c.scale)
        ELSE NULL
    END AS data_length,
    c.is_nullable,
    c.is_identity,
    ISNULL(ep.value, '') AS description,
    c.column_id AS ordinal_position
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
JOIN sys.columns c ON t.object_id = c.object_id
JOIN sys.types tp ON c.user_type_id = tp.user_type_id
LEFT JOIN sys.extended_properties ep ON c.object_id = ep.major_id
    AND c.column_id = ep.minor_id
    AND ep.name = 'MS_Description'
WHERE s.name NOT IN ('sys', 'INFORMATION_SCHEMA')

UNION ALL

SELECT
    s.name AS schema_name,
    v.name AS table_name,
    'VIEW' AS object_type,
    NULL AS column_name,
    NULL AS data_type,
    NULL AS data_length,
    NULL AS is_nullable,
    NULL AS is_identity,
    ISNULL(ep.value, LEFT(m.definition, 200)) AS description,
    1 AS ordinal_position
FROM sys.views v
JOIN sys.schemas s ON v.schema_id = s.schema_id
LEFT JOIN sys.sql_modules m ON v.object_id = m.object_id
LEFT JOIN sys.extended_properties ep ON v.object_id = ep.major_id
    AND ep.minor_id = 0
    AND ep.name = 'MS_Description'
WHERE s.name NOT IN ('sys', 'INFORMATION_SCHEMA');

-- ETL Contract Validation View
-- Ensures flatten.py and other ETL components don't break
CREATE OR ALTER VIEW system.vw_etl_contract_validation AS
SELECT
    'PayloadTransactions' AS source_table,
    'canonical_tx_id_norm' AS required_column,
    CASE WHEN EXISTS (
        SELECT 1 FROM sys.columns c
        JOIN sys.tables t ON c.object_id = t.object_id
        JOIN sys.schemas s ON t.schema_id = s.schema_id
        WHERE s.name = 'dbo' AND t.name = 'PayloadTransactions' AND c.name = 'canonical_tx_id_norm'
    ) THEN 'EXISTS' ELSE 'MISSING' END AS column_status,
    'Critical for ETL canonical ID normalization' AS impact_description

UNION ALL

SELECT
    'SalesInteractions',
    'canonical_tx_id_norm',
    CASE WHEN EXISTS (
        SELECT 1 FROM sys.columns c
        JOIN sys.tables t ON c.object_id = t.object_id
        JOIN sys.schemas s ON t.schema_id = s.schema_id
        WHERE s.name = 'dbo' AND t.name = 'SalesInteractions' AND c.name = 'canonical_tx_id_norm'
    ) THEN 'EXISTS' ELSE 'MISSING' END,
    'Critical for ETL join operations'

UNION ALL

SELECT
    'TransactionItems',
    'CanonicalTxID',
    CASE WHEN EXISTS (
        SELECT 1 FROM sys.columns c
        JOIN sys.tables t ON c.object_id = t.object_id
        JOIN sys.schemas s ON t.schema_id = s.schema_id
        WHERE s.name = 'dbo' AND t.name = 'TransactionItems' AND c.name = 'CanonicalTxID'
    ) THEN 'EXISTS' ELSE 'MISSING' END,
    'Critical for ETL product analysis';

-- Initial Schema Snapshot
-- Populate hash table with current state
DECLARE @schema_cursor CURSOR;
DECLARE @schema_name NVARCHAR(128), @object_name NVARCHAR(128), @object_type NVARCHAR(60);

SET @schema_cursor = CURSOR FOR
    SELECT s.name, o.name, o.type_desc
    FROM sys.objects o
    JOIN sys.schemas s ON o.schema_id = s.schema_id
    WHERE s.name NOT IN ('sys', 'INFORMATION_SCHEMA')
      AND o.type IN ('U', 'V', 'P', 'FN', 'TF');

OPEN @schema_cursor;
FETCH NEXT FROM @schema_cursor INTO @schema_name, @object_name, @object_type;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC system.sp_update_schema_hash @schema_name, @object_name, @object_type;
    FETCH NEXT FROM @schema_cursor INTO @schema_name, @object_name, @object_type;
END

CLOSE @schema_cursor;
DEALLOCATE @schema_cursor;

-- Grant permissions for schema sync agent
CREATE USER [schema_sync_agent] WITHOUT LOGIN;
GRANT SELECT, INSERT, UPDATE ON system.schema_drift_log TO [schema_sync_agent];
GRANT SELECT ON system.schema_object_hash TO [schema_sync_agent];
GRANT SELECT ON system.vw_schema_documentation TO [schema_sync_agent];
GRANT SELECT ON system.vw_etl_contract_validation TO [schema_sync_agent];
GRANT EXECUTE ON system.sp_schema_snapshot TO [schema_sync_agent];

PRINT '✅ Schema drift detection infrastructure created successfully';
PRINT '📊 Initial schema snapshot completed';
PRINT '🔄 DDL trigger active - all schema changes will be tracked';
PRINT '📚 Ready for documentation auto-generation';
PRINT '🛡️ ETL contract validation enabled';