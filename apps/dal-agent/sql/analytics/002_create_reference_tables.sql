-- ========================================================================
-- Scout Analytics - Create Reference Tables and Mart Schema
-- File: 002_create_reference_tables.sql
-- Purpose: Create reference tables for tobacco, laundry, and transcript mining
-- ========================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

SET NOCOUNT ON;

PRINT '🏗️ Creating reference tables and mart schema...';
PRINT '📅 Started: ' + CONVERT(varchar(20), GETDATE(), 120);
PRINT '';

-- ========================================================================
-- CREATE SCHEMAS
-- ========================================================================

-- Create ref schema if not exists
IF SCHEMA_ID('ref') IS NULL
BEGIN
    EXEC('CREATE SCHEMA ref');
    PRINT '✅ Created ref schema';
END
ELSE
BEGIN
    PRINT '✅ ref schema already exists';
END

-- Create mart schema if not exists
IF SCHEMA_ID('mart') IS NULL
BEGIN
    EXEC('CREATE SCHEMA mart');
    PRINT '✅ Created mart schema';
END
ELSE
BEGIN
    PRINT '✅ mart schema already exists';
END

-- ========================================================================
-- REFERENCE TABLE 1: TOBACCO PACK SPECIFICATIONS
-- ========================================================================

PRINT '';
PRINT '🚬 Creating tobacco pack specifications table...';

IF OBJECT_ID('ref.tobacco_pack_specs', 'U') IS NOT NULL
BEGIN
    DROP TABLE ref.tobacco_pack_specs;
    PRINT '🗑️ Dropped existing tobacco_pack_specs table';
END

CREATE TABLE ref.tobacco_pack_specs(
    brand           varchar(80) NOT NULL,
    sku             varchar(120) NULL,
    pack_type       varchar(40) NULL,         -- stick, softpack, hardpack, carton
    sticks_per_pack int NULL,
    created_date    datetime2 DEFAULT GETDATE(),
    updated_date    datetime2 DEFAULT GETDATE(),
    CONSTRAINT PK_tobacco_pack_specs PRIMARY KEY (brand, ISNULL(sku, ''))
);

PRINT '✅ Created ref.tobacco_pack_specs table';

-- ========================================================================
-- REFERENCE TABLE 2: LAUNDRY DETERGENT SPECIFICATIONS
-- ========================================================================

PRINT '';
PRINT '🧼 Creating detergent specifications table...';

IF OBJECT_ID('ref.detergent_specs', 'U') IS NOT NULL
BEGIN
    DROP TABLE ref.detergent_specs;
    PRINT '🗑️ Dropped existing detergent_specs table';
END

CREATE TABLE ref.detergent_specs(
    brand           varchar(80) NOT NULL,
    sku             varchar(120) NULL,
    detergent_form  varchar(16) NOT NULL CHECK (detergent_form IN ('bar', 'powder', 'liquid')),
    created_date    datetime2 DEFAULT GETDATE(),
    updated_date    datetime2 DEFAULT GETDATE(),
    CONSTRAINT PK_detergent_specs PRIMARY KEY (brand, ISNULL(sku, ''))
);

PRINT '✅ Created ref.detergent_specs table';

-- ========================================================================
-- REFERENCE TABLE 3: TRANSCRIPT TERM DICTIONARY
-- ========================================================================

PRINT '';
PRINT '📝 Creating transcript term dictionary table...';

IF OBJECT_ID('ref.term_dictionary', 'U') IS NOT NULL
BEGIN
    DROP TABLE ref.term_dictionary;
    PRINT '🗑️ Dropped existing term_dictionary table';
END

CREATE TABLE ref.term_dictionary(
    term_type       varchar(32) NOT NULL,     -- 'tobacco_intent', 'laundry_intent', 'brand_alias', etc.
    phrase          nvarchar(128) NOT NULL,
    weight          float NULL DEFAULT 1.0,
    created_date    datetime2 DEFAULT GETDATE(),
    updated_date    datetime2 DEFAULT GETDATE(),
    CONSTRAINT PK_term_dictionary PRIMARY KEY (term_type, phrase)
);

PRINT '✅ Created ref.term_dictionary table';

-- ========================================================================
-- CREATE INDEXES FOR PERFORMANCE
-- ========================================================================

PRINT '';
PRINT '🔍 Creating performance indexes...';

-- Index for tobacco lookup by brand
CREATE NONCLUSTERED INDEX IX_tobacco_pack_specs_brand
ON ref.tobacco_pack_specs (brand) INCLUDE (sticks_per_pack);

-- Index for detergent lookup by brand
CREATE NONCLUSTERED INDEX IX_detergent_specs_brand
ON ref.detergent_specs (brand) INCLUDE (detergent_form);

-- Index for term dictionary lookup by type
CREATE NONCLUSTERED INDEX IX_term_dictionary_type
ON ref.term_dictionary (term_type) INCLUDE (phrase, weight);

PRINT '✅ Created performance indexes';

-- ========================================================================
-- GRANT PERMISSIONS
-- ========================================================================

PRINT '';
PRINT '🔐 Setting up permissions...';

-- Grant permissions to rpt_reader role if it exists
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rpt_reader')
BEGIN
    GRANT SELECT ON ref.tobacco_pack_specs TO rpt_reader;
    GRANT SELECT ON ref.detergent_specs TO rpt_reader;
    GRANT SELECT ON ref.term_dictionary TO rpt_reader;
    PRINT '✅ Granted SELECT permissions to rpt_reader';
END
ELSE
BEGIN
    PRINT '⚠️ rpt_reader role not found - permissions not granted';
END

-- ========================================================================
-- VALIDATION
-- ========================================================================

PRINT '';
PRINT '🔍 Validating reference table creation...';

DECLARE @tobacco_exists bit = 0, @detergent_exists bit = 0, @term_exists bit = 0;

IF OBJECT_ID('ref.tobacco_pack_specs', 'U') IS NOT NULL SET @tobacco_exists = 1;
IF OBJECT_ID('ref.detergent_specs', 'U') IS NOT NULL SET @detergent_exists = 1;
IF OBJECT_ID('ref.term_dictionary', 'U') IS NOT NULL SET @term_exists = 1;

IF @tobacco_exists = 1 AND @detergent_exists = 1 AND @term_exists = 1
BEGIN
    PRINT '✅ All reference tables created successfully:';
    PRINT '   - ref.tobacco_pack_specs';
    PRINT '   - ref.detergent_specs';
    PRINT '   - ref.term_dictionary';

    -- Check schemas
    IF SCHEMA_ID('ref') IS NOT NULL AND SCHEMA_ID('mart') IS NOT NULL
    BEGIN
        PRINT '✅ Both ref and mart schemas are ready';
    END

    PRINT '✅ Reference table creation validation PASSED';
END
ELSE
BEGIN
    PRINT '❌ Reference table creation validation FAILED';
    PRINT '   tobacco_pack_specs: ' + CASE WHEN @tobacco_exists = 1 THEN 'EXISTS' ELSE 'MISSING' END;
    PRINT '   detergent_specs: ' + CASE WHEN @detergent_exists = 1 THEN 'EXISTS' ELSE 'MISSING' END;
    PRINT '   term_dictionary: ' + CASE WHEN @term_exists = 1 THEN 'EXISTS' ELSE 'MISSING' END;
    THROW 50002, 'Reference table creation validation failed', 1;
END

PRINT '';
PRINT '🎉 Reference tables and schemas ready for analytics!';
PRINT '📅 Finished: ' + CONVERT(varchar(20), GETDATE(), 120);

GO