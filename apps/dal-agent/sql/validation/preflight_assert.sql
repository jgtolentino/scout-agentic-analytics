-- ========================================================================
-- Scout Analytics Platform - Preflight Validation
-- Purpose: Fail-fast check that required schemas/objects exist
-- Usage: Run before executing migrations to ensure prerequisites
-- ========================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

SET NOCOUNT ON;
DECLARE @Missing TABLE(kind sysname, name sysname);

PRINT '🔍 Starting preflight validation checks...';

-- ========================================================================
-- SCHEMA CHECKS
-- ========================================================================
PRINT '📂 Checking required schemas...';

-- Schemas
IF SCHEMA_ID('dbo') IS NULL INSERT INTO @Missing VALUES ('schema','dbo');
IF SCHEMA_ID('ref') IS NULL INSERT INTO @Missing VALUES ('schema','ref');

-- ========================================================================
-- TABLE CHECKS
-- ========================================================================
PRINT '📋 Checking required tables...';

-- Tables
DECLARE @tables TABLE(name sysname);
INSERT INTO @tables(name) VALUES
 ('dbo.TransactionItems'),
 ('dbo.SalesInteractions');

INSERT INTO @Missing
SELECT 'table', t.name
FROM @tables t
WHERE OBJECT_ID(t.name,'U') IS NULL;

-- ========================================================================
-- VIEW CHECKS
-- ========================================================================
PRINT '👁️ Checking required views...';

-- Views
DECLARE @views TABLE(name sysname);
INSERT INTO @views(name) VALUES
 ('dbo.v_transactions_flat_production'),
 ('dbo.v_insight_base');

INSERT INTO @Missing
SELECT 'view', v.name
FROM @views v
WHERE OBJECT_ID(v.name,'V') IS NULL;

-- ========================================================================
-- STORED PROCEDURE CHECKS (optional but recommended)
-- ========================================================================
PRINT '⚙️ Checking recommended stored procedures...';

-- Procs (optional but recommended)
DECLARE @procs TABLE(name sysname);
INSERT INTO @procs(name) VALUES
 ('dbo.sp_refresh_analytics_views'),
 ('dbo.sp_ValidateNielsenCompleteAnalytics');

INSERT INTO @Missing
SELECT 'proc', p.name
FROM @procs p
WHERE OBJECT_ID(p.name,'P') IS NULL;

-- ========================================================================
-- INDEX RECOMMENDATIONS (informational, not fatal)
-- ========================================================================
PRINT '📈 Checking performance indexes...';

-- Suggested indexes (informational)
SELECT 'IX_SalesInteractions_canon' AS rec, 'dbo.SalesInteractions(canonical_tx_id)' AS target
WHERE NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_SalesInteractions_canon' AND object_id=OBJECT_ID('dbo.SalesInteractions'));

SELECT 'IX_TransactionItems_canon' AS rec, 'dbo.TransactionItems(canonical_tx_id)' AS target
WHERE NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_TransactionItems_canon' AND object_id=OBJECT_ID('dbo.TransactionItems'));

-- ========================================================================
-- DATA AVAILABILITY CHECKS (warn if empty, not fatal)
-- ========================================================================
PRINT '📊 Checking data availability...';

-- Non-empty signals (warn if zero)
DECLARE @base_count INT, @sales_count INT, @items_count INT, @insight_count INT;

SELECT @base_count = COUNT(*) FROM dbo.v_transactions_flat_production;
SELECT @sales_count = COUNT(*) FROM dbo.SalesInteractions;
SELECT @items_count = COUNT(*) FROM dbo.TransactionItems;
SELECT @insight_count = COUNT(*) FROM dbo.v_insight_base;

IF @base_count = 0
  PRINT '⚠️ v_transactions_flat_production is empty';
ELSE
  PRINT CONCAT('✅ v_transactions_flat_production has ', @base_count, ' rows');

IF @sales_count = 0
  PRINT '⚠️ SalesInteractions is empty';
ELSE
  PRINT CONCAT('✅ SalesInteractions has ', @sales_count, ' rows');

IF @items_count = 0
  PRINT '⚠️ TransactionItems is empty';
ELSE
  PRINT CONCAT('✅ TransactionItems has ', @items_count, ' rows');

IF @insight_count = 0
  PRINT '⚠️ v_insight_base is empty';
ELSE
  PRINT CONCAT('✅ v_insight_base has ', @insight_count, ' rows');

-- ========================================================================
-- PERMISSIONS CHECKS
-- ========================================================================
PRINT '🔐 Checking reporting roles...';

-- Check if reporting roles exist
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rpt_reader')
  PRINT '✅ rpt_reader role exists';
ELSE
  PRINT '⚠️ rpt_reader role not found (will skip permissions grant)';

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'scout_reader')
  PRINT '✅ scout_reader role exists';

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'analytics_reader')
  PRINT '✅ analytics_reader role exists';

-- ========================================================================
-- FINAL VALIDATION RESULT
-- ========================================================================

IF EXISTS (SELECT 1 FROM @Missing WHERE kind IN ('schema', 'table', 'view'))
BEGIN
  PRINT '❌ Preflight FAILED: Critical objects missing';
  SELECT kind AS [Kind], name AS [Object] FROM @Missing ORDER BY kind, name;
  THROW 50001, 'Preflight failed: required objects missing.', 1;
END
ELSE
BEGIN
  PRINT '✅ Preflight PASSED: All critical objects found';

  -- Show optional missing objects (non-fatal)
  IF EXISTS (SELECT 1 FROM @Missing WHERE kind = 'proc')
  BEGIN
    PRINT '📋 Optional objects missing (non-fatal):';
    SELECT kind AS [Kind], name AS [Object] FROM @Missing WHERE kind = 'proc';
  END;

  PRINT '🚀 Ready to proceed with flat export view creation';
END;

-- ========================================================================
-- SYSTEM INFORMATION
-- ========================================================================
PRINT '📋 System Information:';
SELECT
  'Database' as Info,
  DB_NAME() as Value
UNION ALL
SELECT
  'Server Version',
  @@VERSION
UNION ALL
SELECT
  'Current User',
  SYSTEM_USER
UNION ALL
SELECT
  'Execution Time',
  CONVERT(varchar(20), GETDATE(), 120);

PRINT '✅ Preflight validation completed';