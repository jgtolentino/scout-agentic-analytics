-- Execute One-Click Production DDL Dump
-- Run this after installing the sp_DumpSchema procedure

SET NOCOUNT ON;

PRINT '=== EXECUTING ONE-CLICK DDL DUMP ===';
PRINT 'Server: sqltbwaprojectscoutserver.database.windows.net';
PRINT 'Database: SQL-TBWA-ProjectScout-Reporting-Prod';
PRINT 'Timestamp: ' + CONVERT(varchar(20), GETDATE(), 120);
PRINT '';

-- Execute the dump for all production schemas
EXEC dbo.sp_DumpSchema
  @Schemas = N'dbo,gold,ref,scout,bronze,ces,staging,silver,ops,cdc',
  @Purge = 1;

PRINT '';
PRINT '=== DUMP EXECUTION COMPLETE ===';
PRINT 'Scripts stored in ops.ObjectScripts table';
PRINT '';