-- Export Single Concatenated DDL Script
-- Run this after executing the dump to get a complete portable schema

SET NOCOUNT ON;

PRINT '=== EXPORTING COMPLETE PRODUCTION DDL ===';
PRINT 'Generating single portable SQL script...';
PRINT '';

-- Method 1: Use STRING_AGG if available (SQL Server 2017+)
-- Uncomment if your Azure SQL supports STRING_AGG with WITHIN GROUP
/*
SELECT STRING_AGG(Script, CHAR(13)+CHAR(10))
       WITHIN GROUP (ORDER BY
         CASE ObjectType
           WHEN 'SCHEMA' THEN 1
           WHEN 'TABLE' THEN 2
           WHEN 'VIEW' THEN 3
           WHEN 'PROC' THEN 4
           WHEN 'FUNCTION' THEN 5
           WHEN 'TRIGGER' THEN 6
           ELSE 7
         END,
         SchemaName,
         ObjectName
       ) AS FullProductionScript
FROM ops.ObjectScripts;
*/

-- Method 2: Universal fallback using FOR XML PATH
SELECT (
  SELECT Script + CHAR(13) + CHAR(10)
  FROM ops.ObjectScripts
  ORDER BY
    CASE ObjectType
      WHEN 'SCHEMA' THEN 1
      WHEN 'TABLE' THEN 2
      WHEN 'VIEW' THEN 3
      WHEN 'PROC' THEN 4
      WHEN 'FUNCTION' THEN 5
      WHEN 'TRIGGER' THEN 6
      ELSE 7
    END,
    SchemaName,
    ObjectName
  FOR XML PATH(''), TYPE
).value('.','nvarchar(max)') AS FullProductionScript;