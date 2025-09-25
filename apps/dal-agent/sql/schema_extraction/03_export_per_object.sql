-- Export Individual Object Scripts
-- Get detailed breakdown of each object with its script

SET NOCOUNT ON;

PRINT '=== EXPORTING PER-OBJECT SCRIPTS ===';
PRINT 'Individual scripts for each database object...';
PRINT '';

-- Export all objects with their individual scripts
-- This can be exported as CSV to get one row per object
SELECT
  SchemaName,
  ObjectName,
  ObjectType,
  LEN(Script) as ScriptLength,
  GeneratedAt,
  Script
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
  ObjectName;