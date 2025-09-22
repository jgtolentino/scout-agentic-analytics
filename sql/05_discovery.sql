-- File: sql/05_discovery.sql
-- "Show me everything in dbo" - use when ADS throws "invalid object name"

-- Tables
SELECT name AS object_name FROM sys.tables WHERE schema_id=SCHEMA_ID('dbo') ORDER BY name;

-- Views
SELECT name AS object_name FROM sys.views  WHERE schema_id=SCHEMA_ID('dbo') ORDER BY name;

-- Stored procedures
SELECT name AS object_name FROM sys.procedures WHERE schema_id=SCHEMA_ID('dbo') ORDER BY name;