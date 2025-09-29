-- =============================================================================
-- Seed Nielsen SKU mapping to eliminate "Unknown" results
-- Creates initial mappings for existing brands with Nielsen categories
-- =============================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Create Nielsen SKU mapping table if not exists
IF OBJECT_ID('dbo.nielsen_sku_map','U') IS NULL
BEGIN
    CREATE TABLE dbo.nielsen_sku_map (
        sku_code              varchar(128) NOT NULL,
        brand_name            nvarchar(200) NULL,
        product_name          nvarchar(400) NULL,
        nielsen_category_code varchar(64) NOT NULL,
        confidence_score      decimal(3,2) DEFAULT 1.0,
        mapping_source        varchar(50) DEFAULT 'MANUAL',
        created_at            datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_nielsen_sku_map PRIMARY KEY (sku_code)
    );
    CREATE INDEX IX_nielsen_sku_map_cat ON dbo.nielsen_sku_map(nielsen_category_code);
    CREATE INDEX IX_nielsen_sku_map_brand ON dbo.nielsen_sku_map(brand_name);
END;

-- Seed with existing brands mapped to appropriate Nielsen categories
-- Using brands from the brand_sku_catalog and matching to Nielsen taxonomy
MERGE dbo.nielsen_sku_map AS t
USING (VALUES
    -- Food & Beverages
    ('SKU-ALASKA-MILK', N'Alaska', N'Evaporated Milk', 'DAIRY_MILK'),
    ('SKU-NIDO-POWDER', N'Nido', N'Powdered Milk', 'DAIRY_MILK'),
    ('SKU-BEAR-BRAND', N'Bear Brand', N'Sterilized Milk', 'DAIRY_MILK'),
    ('SKU-MAGNOLIA-ICE', N'Magnolia', N'Ice Cream', 'DAIRY_FROZEN'),

    -- Instant Foods
    ('SKU-LUCKY-ME-PANCIT', N'Lucky Me', N'Pancit Canton', 'INST_NOODLES'),
    ('SKU-NISSIN-CUP', N'Nissin', N'Cup Noodles', 'INST_NOODLES'),
    ('SKU-MAGGI-NOODLES', N'Maggi', N'Magic Sarap Noodles', 'INST_NOODLES'),

    -- Canned & Jarred Foods
    ('SKU-DEL-MONTE-CORNED', N'Del Monte', N'Corned Beef', 'CANNED_MEAT'),
    ('SKU-CENTURY-TUNA', N'Century Tuna', N'Tuna Flakes', 'CANNED_FISH'),
    ('SKU-CDO-CORNED', N'CDO', N'Corned Beef', 'CANNED_MEAT'),
    ('SKU-SAN-MARINO-TUNA', N'San Marino', N'Tuna', 'CANNED_FISH'),
    ('SKU-MARCA-LEON', N'Marca Leon', N'Sardines', 'CANNED_FISH'),

    -- Beverages
    ('SKU-COCA-COLA-REG', N'Coca-Cola', N'Regular Coke 330ml', 'SOFT_DRINKS'),
    ('SKU-PEPSI-REG', N'Pepsi', N'Regular Pepsi 330ml', 'SOFT_DRINKS'),
    ('SKU-SPRITE-REG', N'Sprite', N'Sprite 330ml', 'SOFT_DRINKS'),
    ('SKU-C2-GREEN-TEA', N'C2', N'Green Tea', 'TEA_RTD'),
    ('SKU-KOPIKO-COFFEE', N'Kopiko', N'Coffee Candy', 'COFFEE_RTD'),
    ('SKU-NESCAFE-3IN1', N'Nescafé', N'3-in-1 Coffee', 'COFFEE_INST'),
    ('SKU-GREAT-TASTE', N'Great Taste', N'Coffee', 'COFFEE_INST'),
    ('SKU-GATORADE-BLUE', N'Gatorade', N'Sports Drink', 'SPORTS_DRINKS'),
    ('SKU-RED-BULL', N'Red Bull', N'Energy Drink', 'ENERGY_DRINKS'),
    ('SKU-EXTRA-JOSS', N'Extra Joss', N'Energy Drink', 'ENERGY_DRINKS'),

    -- Snacks & Confectionery
    ('SKU-OISHI-PRAWN', N'Oishi', N'Prawn Crackers', 'SALTY_SNACKS'),
    ('SKU-PIATTOS-CHEESE', N'Piattos', N'Cheese Chips', 'SALTY_SNACKS'),
    ('SKU-CHIPPY-BBQ', N'Chippy', N'BBQ Chips', 'SALTY_SNACKS'),
    ('SKU-NOVA-MULTIGRAIN', N'Nova', N'Multigrain Chips', 'SALTY_SNACKS'),
    ('SKU-OREO-ORIGINAL', N'Oreo', N'Original Cookies', 'BISCUITS'),
    ('SKU-SKYFLAKES-PLAIN', N'SkyFlakes', N'Plain Crackers', 'BISCUITS'),
    ('SKU-FUDGEE-BAR', N'Fudgee Bar', N'Chocolate Cake', 'CHOCO_CONF'),

    -- Cooking Essentials
    ('SKU-DATU-PUTI-SOY', N'Datu Puti', N'Soy Sauce', 'CONDIMENTS'),
    ('SKU-SILVER-SWAN-SOY', N'Silver Swan', N'Soy Sauce', 'CONDIMENTS'),
    ('SKU-STAR-MARGARINE', N'Star Margarine', N'Margarine', 'COOKING_OILS'),

    -- Tobacco Products
    ('SKU-MARLBORO-RED', N'Marlboro', N'Red 20s', 'TOBACCO_CIG'),
    ('SKU-CAMEL-YELLOW', N'Camel', N'Yellow 20s', 'TOBACCO_CIG'),
    ('SKU-WINSTON-BLUE', N'Winston', N'Blue 20s', 'TOBACCO_CIG'),

    -- Personal Care & Hygiene
    ('SKU-COLGATE-TOTAL', N'Colgate', N'Total Toothpaste', 'ORAL_CARE'),
    ('SKU-CLOSE-UP-RED', N'Close Up', N'Red Hot Toothpaste', 'ORAL_CARE'),
    ('SKU-SAFEGUARD-WHITE', N'Safeguard', N'White Soap', 'BODY_SOAP'),
    ('SKU-DOVE-WHITE', N'Dove', N'White Beauty Bar', 'BODY_SOAP'),
    ('SKU-PANTENE-SHAMPOO', N'Pantene', N'Pro-V Shampoo', 'HAIR_CARE'),
    ('SKU-CREAM-SILK-CON', N'Cream Silk', N'Conditioner', 'HAIR_CARE'),
    ('SKU-HEAD-SHOULDERS', N'Head & Shoulders', N'Shampoo', 'HAIR_CARE'),

    -- Household & Cleaning
    ('SKU-SURF-POWDER', N'Surf', N'Laundry Powder', 'LAUNDRY'),
    ('SKU-TIDE-POWDER', N'Tide', N'Laundry Powder', 'LAUNDRY'),
    ('SKU-ARIEL-POWDER', N'Ariel', N'Laundry Powder', 'LAUNDRY'),
    ('SKU-DOWNY-FABRIC', N'Downy', N'Fabric Conditioner', 'FABRIC_CARE')

) AS s(sku_code, brand_name, product_name, nielsen_category_code)
ON (t.sku_code = s.sku_code)
WHEN NOT MATCHED THEN
    INSERT (sku_code, brand_name, product_name, nielsen_category_code, mapping_source)
    VALUES (s.sku_code, s.brand_name, s.product_name, s.nielsen_category_code, 'SEED_DATA');

-- Create synthetic SKU codes for existing tx_sku_mapping entries
INSERT INTO dbo.nielsen_sku_map (sku_code, brand_name, product_name, nielsen_category_code, mapping_source)
SELECT DISTINCT
    CONCAT('TX-', UPPER(REPLACE(REPLACE(sku.brand_name, ' ', ''), '''', '')), '-', ROW_NUMBER() OVER (PARTITION BY sku.brand_name ORDER BY sku.canonical_tx_id)) AS sku_code,
    sku.brand_name,
    COALESCE(sku.product_name, sku.brand_name + ' Product') AS product_name,
    CASE
        WHEN sku.category LIKE '%Beverage%' OR sku.category LIKE '%Drink%' THEN 'SOFT_DRINKS'
        WHEN sku.category LIKE '%Food%' OR sku.category LIKE '%Meal%' THEN 'INST_MEALS'
        WHEN sku.category LIKE '%Tobacco%' OR sku.category LIKE '%Cigarette%' THEN 'TOBACCO_CIG'
        WHEN sku.category LIKE '%Personal%' OR sku.category LIKE '%Care%' THEN 'BODY_SOAP'
        WHEN sku.category LIKE '%Laundry%' OR sku.category LIKE '%Clean%' THEN 'LAUNDRY'
        WHEN sku.category LIKE '%Snack%' OR sku.category LIKE '%Chip%' THEN 'SALTY_SNACKS'
        ELSE 'GENERAL_MERCH'
    END AS nielsen_category_code,
    'AUTO_MAPPED' AS mapping_source
FROM dbo.tx_sku_mapping sku
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.nielsen_sku_map nsm
    WHERE nsm.brand_name = sku.brand_name
);

PRINT 'Nielsen SKU seed mapping created successfully. Mapped ' + CAST(@@ROWCOUNT AS varchar(10)) + ' SKUs.';

-- Show mapping summary
SELECT
    mapping_source,
    COUNT(*) AS sku_count,
    COUNT(DISTINCT brand_name) AS unique_brands,
    COUNT(DISTINCT nielsen_category_code) AS unique_categories
FROM dbo.nielsen_sku_map
GROUP BY mapping_source
ORDER BY sku_count DESC;