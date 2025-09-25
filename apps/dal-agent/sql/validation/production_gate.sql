-- ========================================================================
-- Scout Analytics - Production Database Gate
-- Purpose: Hard gate to ensure we're connected to production DB
-- ========================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];

-- Hard gate: Ensure we're connected to the correct production database
DECLARE @db_name NVARCHAR(128) = DB_NAME();
DECLARE @expected_db NVARCHAR(128) = 'SQL-TBWA-ProjectScout-Reporting-Prod';

IF @db_name != @expected_db
BEGIN
  DECLARE @error_msg NVARCHAR(200) = CONCAT('Production gate failed: connected to [', @db_name, '] but expected [', @expected_db, ']');
  PRINT CONCAT('❌ PRODUCTION GATE FAILED: ', @error_msg);
  THROW 50030, @error_msg, 1;
END
ELSE
BEGIN
  PRINT '✅ Production gate PASSED: Connected to correct database';
END;

-- Output production confirmation for Bruno
SELECT
  'production_validation' AS gate_type,
  @db_name AS connected_database,
  ORIGINAL_LOGIN() AS login_user,
  SUSER_SNAME() AS effective_user,
  'PASS' AS status,
  'Connected to production database' AS message;