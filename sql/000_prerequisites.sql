-- Prerequisites: Enable Change Tracking for Scout v7 Auto-Sync
-- Execute this manually with proper Azure SQL credentials

-- Enable Change Tracking if not already (7-day retention is sane)
IF NOT EXISTS (SELECT 1 FROM sys.change_tracking_databases WHERE database_id=DB_ID())
  ALTER DATABASE CURRENT
  SET CHANGE_TRACKING = ON (CHANGE_RETENTION = 7 DAYS, AUTO_CLEANUP = ON);

-- Ensure CT on key tables used by sync/parity
IF NOT EXISTS (SELECT 1 FROM sys.change_tracking_tables WHERE object_id=OBJECT_ID('silver.Transactions'))
  ALTER TABLE silver.Transactions ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);

-- Check status
SELECT
    'Change Tracking Database' AS check_type,
    CASE WHEN EXISTS(SELECT 1 FROM sys.change_tracking_databases WHERE database_id=DB_ID())
         THEN 'ENABLED' ELSE 'DISABLED' END AS status;

SELECT
    'Change Tracking Tables' AS check_type,
    OBJECT_NAME(object_id) AS table_name,
    'ENABLED' AS status
FROM sys.change_tracking_tables
WHERE object_id IN (OBJECT_ID('silver.Transactions'));

SELECT
    CHANGE_TRACKING_CURRENT_VERSION() AS current_version,
    CHANGE_TRACKING_MIN_VALID_VERSION(OBJECT_ID('silver.Transactions')) AS min_valid_version;