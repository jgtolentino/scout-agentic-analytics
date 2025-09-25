SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'dim') EXEC('CREATE SCHEMA dim');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'fact') EXEC('CREATE SCHEMA fact');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'bridge') EXEC('CREATE SCHEMA bridge');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'ops') EXEC('CREATE SCHEMA ops');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'analytics') EXEC('CREATE SCHEMA analytics');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'etl') EXEC('CREATE SCHEMA etl');
GO