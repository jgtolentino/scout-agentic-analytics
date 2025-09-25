-- =====================================================================================
-- Philippine Sari-Sari Store Product Dimensions Integration - Phase 1
-- Migration: 001_sari_sari_product_dimensions.sql
-- Created: 2025-09-25
-- Purpose: Create reference tables for Philippine FMCG and Tobacco products
-- =====================================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Drop existing tables if they exist (for clean recreation)
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'ref.sari_sari_product_dimensions') AND type in (N'U'))
    DROP TABLE ref.sari_sari_product_dimensions;

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'ref.regional_price_variations') AND type in (N'U'))
    DROP TABLE ref.regional_price_variations;

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'ref.manufacturer_directory') AND type in (N'U'))
    DROP TABLE ref.manufacturer_directory;

-- Create schema if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'ref')
    EXEC('CREATE SCHEMA ref');
GO

-- =====================================================================================
-- 1. MANUFACTURER DIRECTORY
-- Central registry of all manufacturers with standardized naming
-- =====================================================================================
CREATE TABLE ref.manufacturer_directory (
    manufacturer_id INT IDENTITY(1,1) PRIMARY KEY,
    manufacturer_name NVARCHAR(100) NOT NULL,
    manufacturer_code NVARCHAR(20) NOT NULL UNIQUE,
    manufacturer_type NVARCHAR(50) NOT NULL, -- 'Local', 'Multinational', 'Regional'
    country_origin NVARCHAR(50) NULL,
    is_active BIT DEFAULT 1,
    created_date DATETIME2 DEFAULT GETDATE(),
    updated_date DATETIME2 DEFAULT GETDATE(),

    INDEX IX_manufacturer_directory_code (manufacturer_code),
    INDEX IX_manufacturer_directory_name (manufacturer_name),
    INDEX IX_manufacturer_directory_active (is_active)
);

-- Insert manufacturer data
INSERT INTO ref.manufacturer_directory (manufacturer_name, manufacturer_code, manufacturer_type, country_origin) VALUES
('Universal Robina Corporation', 'URC', 'Local', 'Philippines'),
('Monde Nissin Corporation', 'MONDE', 'Local', 'Philippines'),
('Ricoa', 'RICOA', 'Local', 'Philippines'),
('Jack ''n Jill', 'JNJ', 'Local', 'Philippines'),
('Oishi', 'OISHI', 'Local', 'Philippines'),
('Regent', 'REGENT', 'Local', 'Philippines'),
('Rebisco', 'REBISCO', 'Local', 'Philippines'),
('Boy Bawang', 'BOYBAWANG', 'Local', 'Philippines'),
('Nova', 'NOVA', 'Local', 'Philippines'),
('Lala', 'LALA', 'Local', 'Philippines'),
('Nissin', 'NISSIN', 'Multinational', 'Japan'),
('Lucky Me!', 'LUCKYME', 'Local', 'Philippines'),
('Payless', 'PAYLESS', 'Local', 'Philippines'),
('Maggi', 'MAGGI', 'Multinational', 'Switzerland'),
('Knorr', 'KNORR', 'Multinational', 'Germany'),
('Nestle', 'NESTLE', 'Multinational', 'Switzerland'),
('Del Monte', 'DELMONTE', 'Multinational', 'USA'),
('Hunt''s', 'HUNTS', 'Multinational', 'USA'),
('UFC', 'UFC', 'Local', 'Philippines'),
('Datu Puti', 'DATUPUTI', 'Local', 'Philippines'),
('Silver Swan', 'SILVERSWAN', 'Local', 'Philippines'),
('Mama Sita''s', 'MAMASITAS', 'Local', 'Philippines'),
('Clara Ole', 'CLARAOLE', 'Local', 'Philippines'),
('Unilever', 'UNILEVER', 'Multinational', 'Netherlands'),
('Procter & Gamble', 'PG', 'Multinational', 'USA'),
('Colgate-Palmolive', 'COLGATE', 'Multinational', 'USA'),
('Johnson & Johnson', 'JJ', 'Multinational', 'USA'),
('Philip Morris', 'PM', 'Multinational', 'USA'),
('JTI (Japan Tobacco)', 'JTI', 'Multinational', 'Japan'),
('PMFTC', 'PMFTC', 'Local', 'Philippines'),
('Mighty Corporation', 'MIGHTY', 'Local', 'Philippines');

-- =====================================================================================
-- 2. SARI-SARI PRODUCT DIMENSIONS
-- Core product catalog with Philippine-specific attributes
-- =====================================================================================
CREATE TABLE ref.sari_sari_product_dimensions (
    product_id INT IDENTITY(1,1) PRIMARY KEY,
    product_name NVARCHAR(200) NOT NULL,
    brand_name NVARCHAR(100) NOT NULL,
    category_name NVARCHAR(100) NOT NULL,
    subcategory_name NVARCHAR(100) NULL,
    manufacturer_id INT NOT NULL,

    -- Product specifications
    package_size NVARCHAR(50) NULL, -- e.g., "25g", "1 piece", "sachet"
    package_type NVARCHAR(50) NULL, -- "sachet", "piece", "pack", "bottle"
    unit_weight_grams DECIMAL(10,2) NULL,
    is_sachet_economy BIT DEFAULT 0,
    pieces_per_pack INT NULL,

    -- Pricing information (baseline)
    suggested_retail_price DECIMAL(10,2) NULL,
    typical_sari_sari_price DECIMAL(10,2) NULL,
    bulk_wholesale_price DECIMAL(10,2) NULL,
    price_currency NVARCHAR(10) DEFAULT 'PHP',

    -- Product attributes
    flavor_variant NVARCHAR(100) NULL,
    is_premium_tier BIT DEFAULT 0,
    target_age_group NVARCHAR(50) NULL, -- "Kids", "Teen", "Adult", "All Ages"
    consumption_occasion NVARCHAR(100) NULL, -- "Snack", "Meal", "Breakfast", etc.

    -- Nielsen/Kantar alignment
    nielsen_category_code NVARCHAR(20) NULL,
    kantar_brand_code NVARCHAR(20) NULL,

    -- Metadata
    source_id NVARCHAR(50) NOT NULL DEFAULT 'SARI_SARI_CATALOG_2025',
    is_active BIT DEFAULT 1,
    created_date DATETIME2 DEFAULT GETDATE(),
    updated_date DATETIME2 DEFAULT GETDATE(),

    -- Foreign keys
    FOREIGN KEY (manufacturer_id) REFERENCES ref.manufacturer_directory(manufacturer_id),

    -- Indexes
    INDEX IX_product_brand (brand_name),
    INDEX IX_product_category (category_name),
    INDEX IX_product_manufacturer (manufacturer_id),
    INDEX IX_product_sachet (is_sachet_economy),
    INDEX IX_product_active (is_active),
    INDEX IX_product_source (source_id)
);

-- =====================================================================================
-- 3. REGIONAL PRICE VARIATIONS
-- Captures regional pricing differences across Philippines
-- =====================================================================================
CREATE TABLE ref.regional_price_variations (
    price_variation_id INT IDENTITY(1,1) PRIMARY KEY,
    product_id INT NOT NULL,
    region_name NVARCHAR(100) NOT NULL, -- "NCR", "Luzon", "Visayas", "Mindanao", etc.
    province_name NVARCHAR(100) NULL,
    city_municipality NVARCHAR(100) NULL,

    -- Pricing data
    local_retail_price DECIMAL(10,2) NOT NULL,
    wholesale_price DECIMAL(10,2) NULL,
    price_variance_percentage DECIMAL(5,2) NULL, -- vs. national average
    price_source NVARCHAR(100) NULL, -- "Market Survey", "Retailer Report", etc.

    -- Market conditions
    availability_score DECIMAL(3,2) NULL, -- 0.0-1.0 scale
    market_penetration DECIMAL(5,2) NULL, -- percentage
    competition_intensity NVARCHAR(50) NULL, -- "Low", "Medium", "High"

    -- Metadata
    price_date DATE NOT NULL DEFAULT GETDATE(),
    source_id NVARCHAR(50) NOT NULL DEFAULT 'REGIONAL_PRICE_SURVEY_2025',
    is_active BIT DEFAULT 1,
    created_date DATETIME2 DEFAULT GETDATE(),
    updated_date DATETIME2 DEFAULT GETDATE(),

    -- Foreign keys
    FOREIGN KEY (product_id) REFERENCES ref.sari_sari_product_dimensions(product_id),

    -- Indexes
    INDEX IX_price_product (product_id),
    INDEX IX_price_region (region_name),
    INDEX IX_price_date (price_date),
    INDEX IX_price_active (is_active),
    INDEX IX_price_source (source_id)
);

-- =====================================================================================
-- Add source_id column to TransactionItems table
-- =====================================================================================
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('dbo.TransactionItems') AND name = 'source_id')
BEGIN
    ALTER TABLE dbo.TransactionItems
    ADD source_id NVARCHAR(50) NULL;

    CREATE INDEX IX_TransactionItems_source_id ON dbo.TransactionItems(source_id);
END;

-- Update existing records with default source_id
UPDATE dbo.TransactionItems
SET source_id = 'SCOUT_LEGACY_TRANSACTIONS'
WHERE source_id IS NULL;

-- =====================================================================================
-- Add source_id column to other key tables
-- =====================================================================================
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('dbo.SalesInteractions') AND name = 'source_id')
BEGIN
    ALTER TABLE dbo.SalesInteractions
    ADD source_id NVARCHAR(50) NULL;

    CREATE INDEX IX_SalesInteractions_source_id ON dbo.SalesInteractions(source_id);

    UPDATE dbo.SalesInteractions
    SET source_id = 'SCOUT_LEGACY_SALES'
    WHERE source_id IS NULL;
END;

-- =====================================================================================
-- CREATE VIEWS FOR ANALYTICS
-- =====================================================================================

-- View: Product dimension analytics with manufacturer information
CREATE OR ALTER VIEW ref.v_product_analytics AS
SELECT
    spd.product_id,
    spd.product_name,
    spd.brand_name,
    spd.category_name,
    spd.subcategory_name,
    md.manufacturer_name,
    md.manufacturer_type,
    md.country_origin,
    spd.package_size,
    spd.package_type,
    spd.is_sachet_economy,
    spd.suggested_retail_price,
    spd.typical_sari_sari_price,
    spd.flavor_variant,
    spd.target_age_group,
    spd.consumption_occasion,
    spd.nielsen_category_code,
    spd.kantar_brand_code,
    spd.source_id,
    -- Price analytics
    CASE
        WHEN spd.suggested_retail_price > 0 AND spd.typical_sari_sari_price > 0
        THEN ((spd.typical_sari_sari_price - spd.suggested_retail_price) / spd.suggested_retail_price) * 100
        ELSE NULL
    END as retail_markup_percentage,
    -- Sachet economy flag
    CASE
        WHEN spd.is_sachet_economy = 1 THEN 'Sachet Economy'
        WHEN spd.package_size LIKE '%g' AND CAST(REPLACE(spd.package_size, 'g', '') AS INT) <= 50 THEN 'Small Pack'
        ELSE 'Regular Pack'
    END as economy_segment
FROM ref.sari_sari_product_dimensions spd
JOIN ref.manufacturer_directory md ON spd.manufacturer_id = md.manufacturer_id
WHERE spd.is_active = 1;

-- View: Regional pricing analytics
CREATE OR ALTER VIEW ref.v_regional_pricing_analytics AS
SELECT
    rpv.product_id,
    spd.product_name,
    spd.brand_name,
    spd.category_name,
    rpv.region_name,
    rpv.province_name,
    rpv.local_retail_price,
    rpv.wholesale_price,
    rpv.price_variance_percentage,
    rpv.availability_score,
    rpv.market_penetration,
    rpv.competition_intensity,
    spd.typical_sari_sari_price as national_average_price,
    -- Price comparison analytics
    CASE
        WHEN rpv.price_variance_percentage > 10 THEN 'Premium Market'
        WHEN rpv.price_variance_percentage < -10 THEN 'Value Market'
        ELSE 'Average Market'
    END as market_positioning,
    -- Regional accessibility
    CASE
        WHEN rpv.availability_score >= 0.8 THEN 'High Availability'
        WHEN rpv.availability_score >= 0.5 THEN 'Moderate Availability'
        ELSE 'Low Availability'
    END as availability_tier
FROM ref.regional_price_variations rpv
JOIN ref.sari_sari_product_dimensions spd ON rpv.product_id = spd.product_id
WHERE rpv.is_active = 1 AND spd.is_active = 1;

-- =====================================================================================
-- REFERENCE DATA POPULATION
-- Create stored procedure for bulk data loading
-- =====================================================================================
CREATE OR ALTER PROCEDURE ref.sp_load_sari_sari_products
AS
BEGIN
    SET NOCOUNT ON;

    -- This procedure will be used to load the 195+ SKUs
    -- For now, creating a sample to validate structure

    INSERT INTO ref.sari_sari_product_dimensions
    (product_name, brand_name, category_name, subcategory_name, manufacturer_id,
     package_size, package_type, is_sachet_economy, suggested_retail_price, typical_sari_sari_price,
     flavor_variant, target_age_group, consumption_occasion)
    VALUES
    ('SkyFlakes Crackers', 'SkyFlakes', 'Biscuits & Crackers', 'Crackers', 1, '25g', 'pack', 1, 8.00, 10.00, 'Original', 'All Ages', 'Snack'),
    ('Lucky Me! Instant Pancit Canton', 'Lucky Me!', 'Instant Noodles', 'Pancit Canton', 12, '60g', 'pack', 0, 12.00, 15.00, 'Original', 'All Ages', 'Meal'),
    ('Boy Bawang Cornick', 'Boy Bawang', 'Snacks', 'Corn Snacks', 8, '40g', 'pack', 0, 15.00, 18.00, 'Garlic', 'Teen', 'Snack');

    SELECT 'Sample products loaded successfully' as status;
END;
GO

-- Execute the sample load
EXEC ref.sp_load_sari_sari_products;

PRINT '✅ Phase 1 Complete: Philippine Sari-Sari Store dimensions tables created successfully';
PRINT '📊 Tables created: ref.manufacturer_directory, ref.sari_sari_product_dimensions, ref.regional_price_variations';
PRINT '🔗 Added source_id columns to TransactionItems and SalesInteractions tables';
PRINT '📈 Created analytics views: ref.v_product_analytics, ref.v_regional_pricing_analytics';
PRINT '📋 Ready for Phase 2: Load complete 195+ SKU dataset';