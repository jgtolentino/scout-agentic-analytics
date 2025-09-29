-- ========================================================================
-- Canonical Flat Export Schema Definition
-- Purpose: Define the official 13-column contract for all flat exports
-- ========================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Create schema if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'canonical')
BEGIN
    EXEC('CREATE SCHEMA canonical');
END;
GO

-- Create canonical schema definition table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE name = 'flat_schema_definition' AND schema_id = SCHEMA_ID('canonical'))
BEGIN
    CREATE TABLE canonical.flat_schema_definition (
        column_ord int PRIMARY KEY,
        column_name nvarchar(128) NOT NULL,
        data_type nvarchar(64) NOT NULL,
        max_length int NULL,
        precision_val tinyint NULL,
        scale_val tinyint NULL,
        is_nullable bit NOT NULL,
        description nvarchar(500) NULL,
        business_rule nvarchar(1000) NULL,
        created_at datetime2 NOT NULL DEFAULT(SYSUTCDATETIME()),
        updated_at datetime2 NOT NULL DEFAULT(SYSUTCDATETIME())
    );
END;
GO

-- Clear and insert the official 13-column canonical contract
DELETE FROM canonical.flat_schema_definition;

INSERT INTO canonical.flat_schema_definition (
    column_ord, column_name, data_type, max_length, precision_val, scale_val,
    is_nullable, description, business_rule
) VALUES
(1, 'Transaction_ID', 'nvarchar', 64, NULL, NULL, 0,
    'Unique transaction identifier from canonical_tx_id',
    'Must be unique across all transactions'),

(2, 'Transaction_Value', 'decimal', NULL, 18, 2, 0,
    'Total transaction value in PHP',
    'Must be > 0 for valid transactions'),

(3, 'Basket_Size', 'int', NULL, NULL, NULL, 0,
    'Number of items in basket',
    'Must be >= 1 for completed transactions'),

(4, 'Category', 'nvarchar', 256, NULL, NULL, 0,
    'Primary product category',
    'Use Nielsen standard categories when available'),

(5, 'Brand', 'nvarchar', 256, NULL, NULL, 0,
    'Primary brand name',
    'Use standardized brand names from ref.brands'),

(6, 'Daypart', 'nvarchar', 32, NULL, NULL, 0,
    'Time of day segment',
    'Values: Morning, Afternoon, Evening, Night'),

(7, 'Demographics_Age_Gender_Role', 'nvarchar', 256, NULL, NULL, 0,
    'Combined demographic information',
    'Format: Age Gender Role (e.g., "25-30 Female Customer")'),

(8, 'Weekday_vs_Weekend', 'nvarchar', 32, NULL, NULL, 0,
    'Week type classification',
    'Values: Weekday, Weekend'),

(9, 'Time_of_Transaction', 'time', NULL, NULL, NULL, 1,
    'Exact transaction time (HH:MM:SS)',
    'NULL allowed if precise time unavailable'),

(10, 'Location', 'nvarchar', 256, NULL, NULL, 1,
    'Store location or region',
    'Prefer barangay > city > region hierarchy'),

(11, 'Other_Products', 'nvarchar', -1, NULL, NULL, 1,
    'Co-purchase items in basket',
    'JSON array or comma-separated list, NULL if unavailable'),

(12, 'Was_Substitution', 'bit', NULL, NULL, NULL, 1,
    'Flag indicating substitution occurred',
    '1=substitution, 0=no substitution, NULL=unknown'),

(13, 'Export_Timestamp', 'datetime2', NULL, NULL, NULL, 0,
    'Export generation timestamp',
    'UTC timestamp when export was generated');

PRINT '✅ Canonical schema definition created with 13 columns';

-- Create index for performance
CREATE UNIQUE INDEX UX_canonical_flat_schema_column_ord
    ON canonical.flat_schema_definition(column_ord);

CREATE INDEX IX_canonical_flat_schema_name
    ON canonical.flat_schema_definition(column_name);

-- Create audit trail table for schema changes
IF NOT EXISTS (SELECT * FROM sys.objects WHERE name = 'flat_schema_audit' AND schema_id = SCHEMA_ID('canonical'))
BEGIN
    CREATE TABLE canonical.flat_schema_audit (
        audit_id bigint IDENTITY(1,1) PRIMARY KEY,
        action nvarchar(32) NOT NULL,
        column_name nvarchar(128) NOT NULL,
        old_definition nvarchar(max) NULL,
        new_definition nvarchar(max) NULL,
        changed_by nvarchar(128) NOT NULL DEFAULT(SUSER_SNAME()),
        changed_at datetime2 NOT NULL DEFAULT(SYSUTCDATETIME())
    );
END;
GO

-- Create trigger to track schema changes
CREATE OR ALTER TRIGGER canonical.tr_flat_schema_audit
ON canonical.flat_schema_definition
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Handle inserts
    INSERT INTO canonical.flat_schema_audit (action, column_name, new_definition)
    SELECT 'INSERT', column_name,
           CONCAT('ord:', column_ord, ' type:', data_type, ' nullable:', is_nullable)
    FROM inserted;

    -- Handle updates
    INSERT INTO canonical.flat_schema_audit (action, column_name, old_definition, new_definition)
    SELECT 'UPDATE', i.column_name,
           CONCAT('ord:', d.column_ord, ' type:', d.data_type, ' nullable:', d.is_nullable),
           CONCAT('ord:', i.column_ord, ' type:', i.data_type, ' nullable:', i.is_nullable)
    FROM inserted i
    INNER JOIN deleted d ON d.column_ord = i.column_ord;

    -- Handle deletes
    INSERT INTO canonical.flat_schema_audit (action, column_name, old_definition)
    SELECT 'DELETE', column_name,
           CONCAT('ord:', column_ord, ' type:', data_type, ' nullable:', is_nullable)
    FROM deleted
    WHERE NOT EXISTS (SELECT 1 FROM inserted WHERE inserted.column_ord = deleted.column_ord);
END;
GO

-- Create view for easy schema inspection
CREATE OR ALTER VIEW canonical.v_flat_schema AS
SELECT
    column_ord,
    column_name,
    data_type +
        CASE
            WHEN data_type IN ('nvarchar', 'varchar') AND max_length > 0
                THEN '(' + CAST(max_length AS nvarchar) + ')'
            WHEN data_type IN ('nvarchar', 'varchar') AND max_length = -1
                THEN '(max)'
            WHEN data_type IN ('decimal', 'numeric')
                THEN '(' + CAST(precision_val AS nvarchar) + ',' + CAST(scale_val AS nvarchar) + ')'
            ELSE ''
        END as full_data_type,
    is_nullable,
    CASE WHEN is_nullable = 1 THEN 'NULL' ELSE 'NOT NULL' END as nullability,
    description,
    business_rule
FROM canonical.flat_schema_definition
ORDER BY column_ord;
GO

-- Test the schema definition
SELECT 'Schema Definition Test:' as test_type, COUNT(*) as column_count
FROM canonical.flat_schema_definition;

SELECT 'Column Details:' as test_type;
SELECT column_ord, column_name, full_data_type, nullability
FROM canonical.v_flat_schema
ORDER BY column_ord;

PRINT 'Canonical schema definition deployment complete.';