SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name=N'etl') EXEC('CREATE SCHEMA etl');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name=N'gold') EXEC('CREATE SCHEMA gold');
GO

/* ========================================================================
 * Scout Analytics - Conversation Intelligence Tables
 * Migration: 20250926_15_conversation_intelligence_tables.sql
 * Purpose: Create core tables for conversation segments and signal facts
 * ======================================================================== */

-- Table: Conversation segments (SQL-only heuristic split)
-- Stores tokenized transcript segments with speaker attribution
IF OBJECT_ID('etl.conversation_segments','U') IS NULL
CREATE TABLE etl.conversation_segments (
    canonical_tx_id   varchar(64) NOT NULL,
    seg_id            int NOT NULL,
    speaker           varchar(16) NULL,      -- 'customer'|'owner'|NULL
    utterance         nvarchar(max) NOT NULL,
    ts_inferred       datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_conversation_segments PRIMARY KEY (canonical_tx_id, seg_id)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_convseg_tx' AND object_id=OBJECT_ID('etl.conversation_segments'))
    CREATE INDEX IX_convseg_tx ON etl.conversation_segments(canonical_tx_id);
GO

-- Table: Persona signal facts
-- Optional facts extracted from basket/time/category for persona inference
IF OBJECT_ID('etl.persona_signal_facts','U') IS NULL
CREATE TABLE etl.persona_signal_facts (
    canonical_tx_id   varchar(64) NOT NULL,
    signal_type       varchar(32) NOT NULL,  -- 'hour','nielsen_group','basket_size', etc.
    signal_value      varchar(128) NOT NULL,
    weight            decimal(5,2) NOT NULL DEFAULT 1.00,
    ts_inferred       datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_persona_signal_facts PRIMARY KEY (canonical_tx_id, signal_type, signal_value)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_psig_tx' AND object_id=OBJECT_ID('etl.persona_signal_facts'))
    CREATE INDEX IX_psig_tx ON etl.persona_signal_facts(canonical_tx_id);
GO

-- Ensure ref.persona_rules has required columns for enhanced matching
IF COL_LENGTH('ref.persona_rules', 'active_hours') IS NULL
    ALTER TABLE ref.persona_rules ADD active_hours varchar(128) NULL;
GO

IF COL_LENGTH('ref.persona_rules', 'required_groups') IS NULL
    ALTER TABLE ref.persona_rules ADD required_groups varchar(256) NULL;
GO

-- Update existing persona rules with constraints
UPDATE ref.persona_rules SET
    active_hours = CASE
        WHEN role_name = 'Student' THEN 'morning|afternoon'
        WHEN role_name = 'Office Worker' THEN 'morning|afternoon'
        WHEN role_name = 'Night-Shift Worker' THEN 'night'
        WHEN role_name = 'Teen Gamer' THEN 'afternoon|evening|night'
        WHEN role_name = 'Blue-Collar Worker' THEN 'afternoon|evening'
        WHEN role_name = 'Senior Citizen' THEN 'morning|afternoon'
        WHEN role_name = 'Farmer' THEN 'morning'
        ELSE '*'
    END,
    required_groups = CASE
        WHEN role_name = 'Delivery Rider' THEN 'Energy Drinks|Beverages|Tobacco Products'
        WHEN role_name = 'Parent' THEN 'Milk|Personal Care|Condiments'
        WHEN role_name = 'Health-Conscious' THEN 'Personal Care|Health Products|Soap|Shampoo'
        WHEN role_name = 'Teen Gamer' THEN 'Soft Drinks|Snacks|Chips'
        WHEN role_name = 'Night-Shift Worker' THEN 'Energy Drinks|Instant Coffee|Instant Noodles|Tobacco Products'
        WHEN role_name = 'Blue-Collar Worker' THEN 'Energy Drinks|Instant Noodles|Beverages'
        WHEN role_name = 'Office Worker' THEN 'Beverages|Biscuits|Instant Coffee'
        WHEN role_name = 'Party Buyer' THEN 'Soft Drinks|Snacks|Chips'
        WHEN role_name = 'Farmer' THEN 'Canned Goods|Rice|Condiments'
        WHEN role_name = 'Reseller' THEN 'Personal Care|Condiments|Instant Noodles|Snacks'
        ELSE '*'
    END
WHERE active_hours IS NULL OR required_groups IS NULL;
GO

PRINT '✅ Conversation intelligence tables created successfully';
PRINT '📊 Enhanced ref.persona_rules with active_hours and required_groups constraints';
PRINT '🔍 Ready for transcript parsing and signal extraction';
GO