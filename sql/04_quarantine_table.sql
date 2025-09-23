-- File: sql/04_quarantine_table.sql
-- Phase 2: Quarantine table for malformed JSON tracking
-- Purpose: Capture and analyze malformed JSON for upstream fixing

-- Batch 1: Create quarantine table
IF SCHEMA_ID('dbo') IS NULL THROW 50000,'dbo schema missing',1;
GO

-- Drop existing quarantine table if it exists
IF OBJECT_ID('dbo.BadPayloads', 'U') IS NOT NULL
BEGIN
    PRINT 'Dropping existing BadPayloads table...';
    DROP TABLE dbo.BadPayloads;
END
GO

-- Create quarantine table for malformed JSON
CREATE TABLE dbo.BadPayloads (
    id                  int IDENTITY(1,1) PRIMARY KEY,
    source_id           int NOT NULL,                    -- Original PayloadTransactions.id
    sessionId           nvarchar(128) NOT NULL,          -- Original sessionId
    deviceId            nvarchar(64) NULL,               -- Original deviceId
    storeId             nvarchar(32) NULL,               -- Original storeId
    payload_length      int NOT NULL,                    -- Length of original payload
    payload_sample      nvarchar(1200) NOT NULL,        -- First 1200 chars of malformed JSON
    error_pattern       nvarchar(100) NULL,             -- Detected error pattern
    source_created_at   datetime2 NOT NULL,             -- Original createdAt
    quarantined_at      datetime2 NOT NULL DEFAULT SYSDATETIME(), -- When captured

    INDEX IX_BadPayloads_DeviceStore (deviceId, storeId),
    INDEX IX_BadPayloads_Pattern (error_pattern),
    INDEX IX_BadPayloads_Date (source_created_at)
);
GO

-- Create procedure to populate quarantine table
CREATE OR ALTER PROCEDURE dbo.CaptureBadPayloads
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @captured_count int = 0;

    -- Insert new malformed JSON records not already quarantined
    INSERT INTO dbo.BadPayloads (
        source_id,
        sessionId,
        deviceId,
        storeId,
        payload_length,
        payload_sample,
        error_pattern,
        source_created_at
    )
    SELECT
        pt.id,
        pt.sessionId,
        pt.deviceId,
        pt.storeId,
        LEN(pt.payload_json) as payload_length,
        LEFT(pt.payload_json, 1200) as payload_sample,
        CASE
            WHEN pt.payload_json IS NULL THEN 'NULL'
            WHEN LEN(pt.payload_json) = 0 THEN 'EMPTY'
            WHEN LEFT(LTRIM(pt.payload_json), 1) != '{' THEN 'NOT_OBJECT'
            WHEN RIGHT(RTRIM(pt.payload_json), 1) != '}' THEN 'INCOMPLETE_OBJECT'
            WHEN LEN(pt.payload_json) = 1998 THEN 'TRUNCATED_1998'
            WHEN CHARINDEX('""', pt.payload_json) > 0 THEN 'DOUBLE_QUOTES'
            WHEN CHARINDEX(CHAR(13), pt.payload_json) > 0 OR CHARINDEX(CHAR(10), pt.payload_json) > 0 THEN 'CONTAINS_NEWLINES'
            WHEN CHARINDEX('\', pt.payload_json) > 0 THEN 'CONTAINS_BACKSLASH'
            ELSE 'OTHER_INVALID'
        END as error_pattern,
        pt.createdAt
    FROM dbo.PayloadTransactions pt
    WHERE ISJSON(pt.payload_json) = 0
      AND NOT EXISTS (
          SELECT 1 FROM dbo.BadPayloads bp
          WHERE bp.source_id = pt.id
      );

    SET @captured_count = @@ROWCOUNT;

    PRINT 'Captured ' + CAST(@captured_count AS nvarchar(10)) + ' new malformed JSON records.';

    -- Return summary statistics
    SELECT
        'Quarantine Summary' as report_type,
        COUNT(*) as total_quarantined,
        COUNT(DISTINCT deviceId) as affected_devices,
        COUNT(DISTINCT storeId) as affected_stores,
        MIN(source_created_at) as earliest_occurrence,
        MAX(source_created_at) as latest_occurrence
    FROM dbo.BadPayloads;

    -- Pattern breakdown
    SELECT
        'Pattern Analysis' as report_type,
        error_pattern,
        COUNT(*) as occurrence_count,
        COUNT(DISTINCT deviceId) as affected_devices,
        COUNT(DISTINCT storeId) as affected_stores,
        CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM dbo.BadPayloads) AS decimal(5,2)) as percentage
    FROM dbo.BadPayloads
    GROUP BY error_pattern
    ORDER BY occurrence_count DESC;
END
GO

-- Create nightly job procedure (can be scheduled via SQL Server Agent)
CREATE OR ALTER PROCEDURE dbo.NightlyBadPayloadCapture
AS
BEGIN
    SET NOCOUNT ON;

    PRINT 'Starting nightly bad payload capture: ' + CONVERT(nvarchar(20), SYSDATETIME(), 120);

    -- Capture new bad payloads
    EXEC dbo.CaptureBadPayloads;

    -- Clean up old quarantine records (keep last 90 days)
    DELETE FROM dbo.BadPayloads
    WHERE quarantined_at < DATEADD(day, -90, SYSDATETIME());

    DECLARE @deleted_count int = @@ROWCOUNT;
    PRINT 'Cleaned up ' + CAST(@deleted_count AS nvarchar(10)) + ' old quarantine records (>90 days).';

    PRINT 'Nightly bad payload capture completed: ' + CONVERT(nvarchar(20), SYSDATETIME(), 120);
END
GO

-- Initial population of quarantine table
PRINT 'Performing initial quarantine population...';
EXEC dbo.CaptureBADPayloads;

-- Create helpful views for monitoring
CREATE OR ALTER VIEW dbo.v_bad_payload_summary
AS
SELECT
    error_pattern,
    COUNT(*) as count,
    COUNT(DISTINCT deviceId) as devices,
    COUNT(DISTINCT storeId) as stores,
    AVG(payload_length) as avg_length,
    MIN(source_created_at) as first_seen,
    MAX(source_created_at) as last_seen
FROM dbo.BadPayloads
GROUP BY error_pattern;
GO

CREATE OR ALTER VIEW dbo.v_bad_payload_trends
AS
SELECT
    CAST(source_created_at AS date) as date,
    error_pattern,
    COUNT(*) as daily_count
FROM dbo.BadPayloads
WHERE source_created_at >= DATEADD(day, -30, SYSDATETIME())
GROUP BY CAST(source_created_at AS date), error_pattern;
GO

PRINT 'Phase 2 quarantine system deployed successfully.';
PRINT 'Use: EXEC dbo.CaptureBADPayloads to manually capture new bad payloads';
PRINT 'Use: SELECT * FROM dbo.v_bad_payload_summary for current status';
PRINT 'Use: SELECT * FROM dbo.v_bad_payload_trends for trend analysis';

GO