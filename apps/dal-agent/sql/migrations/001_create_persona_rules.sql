-- ========================================================================
-- Scout Analytics - Persona Role Inference System
-- Migration: 001_create_persona_rules.sql
-- Purpose: Create reference schema and persona rules table
-- ========================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- ========================================================================
-- CREATE REFERENCE SCHEMA
-- ========================================================================

IF SCHEMA_ID('ref') IS NULL
BEGIN
    EXEC('CREATE SCHEMA ref');
    PRINT '✅ Created ref schema';
END
ELSE
BEGIN
    PRINT '✅ ref schema already exists';
END
GO

-- ========================================================================
-- CREATE PERSONA RULES TABLE
-- ========================================================================

IF OBJECT_ID('ref.persona_rules', 'U') IS NULL
BEGIN
    CREATE TABLE ref.persona_rules (
        rule_id int IDENTITY(1,1) PRIMARY KEY,
        role_name varchar(40) NOT NULL,
        priority tinyint NOT NULL,                    -- lower = stronger priority
        include_terms nvarchar(400) NULL,             -- pipe-separated keywords: 'school|class|student'
        exclude_terms nvarchar(400) NULL,             -- exclusion keywords: 'party|meeting'
        must_have_categories nvarchar(400) NULL,      -- required categories: 'Instant Noodles|Energy Drinks'
        must_have_brands nvarchar(400) NULL,          -- required brands: 'Red Bull|Monster'
        daypart_in varchar(60) NULL,                  -- allowed dayparts: 'Morning|Evening'
        hour_min tinyint NULL,                        -- minimum hour (0-23)
        hour_max tinyint NULL,                        -- maximum hour (0-23, handles wrap)
        min_items int NULL,                           -- minimum basket size
        min_age tinyint NULL,                         -- minimum age
        max_age tinyint NULL,                         -- maximum age
        gender_in varchar(20) NULL,                   -- allowed genders: 'Male|Female'
        notes nvarchar(200) NULL,                     -- documentation
        created_date datetime2 DEFAULT GETDATE(),
        is_active bit DEFAULT 1
    );

    PRINT '✅ Created ref.persona_rules table';
END
ELSE
BEGIN
    PRINT '✅ ref.persona_rules table already exists';
END
GO

-- ========================================================================
-- CREATE INDEXES FOR PERFORMANCE
-- ========================================================================

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('ref.persona_rules') AND name = 'IX_persona_rules_active_priority')
BEGIN
    CREATE INDEX IX_persona_rules_active_priority
    ON ref.persona_rules (is_active, priority, role_name);
    PRINT '✅ Created index on persona_rules';
END
GO

PRINT '✅ Migration 001_create_persona_rules completed successfully';
GO