-- CSV-Safe Text Sanitizer Function
-- Strips control characters and escapes quotes for RFC4180 compliance
-- Fixes "JSON text not properly formatted" errors in large CSV exports

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

CREATE OR ALTER FUNCTION dbo.csv_safe(@s NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
BEGIN
  IF @s IS NULL RETURN NULL;

  -- Strip problematic characters and escape quotes for RFC4180-style CSV
  -- CR (13), LF (10), TAB (9) → space; double quotes → double-double quotes
  RETURN REPLACE(REPLACE(REPLACE(REPLACE(@s, CHAR(13),' '), CHAR(10),' '), CHAR(9),' '), '"','""');
END;
GO

PRINT 'CSV-safe text sanitizer function created successfully';
PRINT 'Usage: SELECT dbo.csv_safe(''text with "quotes" and'+CHAR(13)+CHAR(10)+'newlines'') AS clean_text';