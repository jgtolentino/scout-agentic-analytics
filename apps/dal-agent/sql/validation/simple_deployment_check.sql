-- Simple deployment validation for SARI-SARI Expert v2.0
SET NOCOUNT ON;

-- Check basic schema and table existence
DECLARE @schemas_ok INT = 0;
DECLARE @gold_tables INT = 0;
DECLARE @platinum_tables INT = 0;

-- Count schemas
SELECT @schemas_ok = COUNT(*)
FROM sys.schemas
WHERE name IN ('dbo', 'gold', 'platinum');

-- Count Gold layer tables/views
SELECT @gold_tables = COUNT(*)
FROM sys.objects o
JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE s.name = 'gold'
AND o.type IN ('U', 'V');

-- Count Platinum layer tables/views
SELECT @platinum_tables = COUNT(*)
FROM sys.objects o
JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE s.name = 'platinum'
AND o.type IN ('U', 'V');

-- Return results as JSON
SELECT
    @schemas_ok AS schemas_found,
    @gold_tables AS gold_objects,
    @platinum_tables AS platinum_objects,
    CASE
        WHEN @schemas_ok >= 3 AND @gold_tables > 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS deployment_status
FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;