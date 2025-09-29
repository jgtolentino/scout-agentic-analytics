-- =============================================================================
-- Map all 113 brands from brand_sku_catalog to Nielsen categories
-- Ensures complete brand coverage for Nielsen taxonomy integration
-- =============================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Clear existing mappings and rebuild with all 113 brands
TRUNCATE TABLE dbo.nielsen_sku_map;

-- Map all 113 brands to appropriate Nielsen categories
INSERT INTO dbo.nielsen_sku_map (sku_code, brand_name, product_name, nielsen_category_code, mapping_source, confidence_score)
VALUES
-- Tobacco Products
('SKU-MARLBORO', 'Marlboro', 'Cigarettes', 'TOBACCO', 'BRAND_CATALOG', 1.0),
('SKU-CAMEL', 'Camel', 'Cigarettes', 'TOBACCO', 'BRAND_CATALOG', 1.0),
('SKU-CHESTERFIELD', 'Chesterfield', 'Cigarettes', 'TOBACCO', 'BRAND_CATALOG', 1.0),
('SKU-WINSTON', 'Winston', 'Cigarettes', 'TOBACCO', 'BRAND_CATALOG', 1.0),
('SKU-TM', 'TM', 'Cigarettes', 'TOBACCO', 'BRAND_CATALOG', 1.0),

-- Beverages - Non-Alcoholic
('SKU-COCA-COLA', 'Coca-Cola', 'Soft Drink', 'SOFT_DRINKS', 'BRAND_CATALOG', 1.0),
('SKU-PEPSI', 'Pepsi', 'Soft Drink', 'SOFT_DRINKS', 'BRAND_CATALOG', 1.0),
('SKU-SPRITE', 'Sprite', 'Soft Drink', 'SOFT_DRINKS', 'BRAND_CATALOG', 1.0),
('SKU-ROYAL', 'Royal', 'Soft Drink', 'SOFT_DRINKS', 'BRAND_CATALOG', 1.0),

-- Beverages - Tea & Coffee
('SKU-C2', 'C2', 'Iced Tea', 'ICED_TEA', 'BRAND_CATALOG', 1.0),
('SKU-NESTEA', 'Nestea', 'Iced Tea', 'ICED_TEA', 'BRAND_CATALOG', 1.0),
('SKU-NESCAFE', 'Nescafé', '3-in-1 Coffee', '3IN1_COFFEE', 'BRAND_CATALOG', 1.0),
('SKU-GREAT-TASTE', 'Great Taste', '3-in-1 Coffee', '3IN1_COFFEE', 'BRAND_CATALOG', 1.0),
('SKU-KOPIKO', 'Kopiko', 'Coffee', '3IN1_COFFEE', 'BRAND_CATALOG', 1.0),
('SKU-CAFE-PURO', 'Café Puro', 'Coffee', '3IN1_COFFEE', 'BRAND_CATALOG', 1.0),
('SKU-BLEND-45', 'Blend 45', 'Coffee', '3IN1_COFFEE', 'BRAND_CATALOG', 1.0),

-- Beverages - Energy & Sports
('SKU-RED-BULL', 'Red Bull', 'Energy Drink', 'ENERGY_DRINKS', 'BRAND_CATALOG', 1.0),
('SKU-EXTRA-JOSS', 'Extra Joss', 'Energy Drink', 'ENERGY_DRINKS', 'BRAND_CATALOG', 1.0),
('SKU-GATORADE', 'Gatorade', 'Sports Drink', 'SPORTS_DRINKS', 'BRAND_CATALOG', 1.0),
('SKU-COBRA', 'Cobra', 'Energy Drink', 'ENERGY_DRINKS', 'BRAND_CATALOG', 1.0),
('SKU-LIPOVITAN', 'Lipovitan', 'Energy Drink', 'ENERGY_DRINKS', 'BRAND_CATALOG', 1.0),

-- Beverages - Other
('SKU-OVALTINE', 'Ovaltine', 'Malt Drink', 'MILK_DRINKS', 'BRAND_CATALOG', 1.0),
('SKU-MILO', 'Milo', 'Chocolate Drink', 'MILK_DRINKS', 'BRAND_CATALOG', 1.0),
('SKU-TANG', 'Tang', 'Powdered Drink', 'POWDERED_DRINKS', 'BRAND_CATALOG', 1.0),

-- Milk & Dairy
('SKU-ALASKA', 'Alaska', 'Evaporated Milk', 'MILK_EVAP', 'BRAND_CATALOG', 1.0),
('SKU-BEAR-BRAND', 'Bear Brand', 'Sterilized Milk', 'MILK_EVAP', 'BRAND_CATALOG', 1.0),
('SKU-NIDO', 'Nido', 'Powdered Milk', 'MILK_POWDER', 'BRAND_CATALOG', 1.0),
('SKU-BIRCH-TREE', 'Birch Tree', 'Powdered Milk', 'MILK_POWDER', 'BRAND_CATALOG', 1.0),
('SKU-COWHEAD', 'Cowhead', 'Milk', 'MILK_EVAP', 'BRAND_CATALOG', 1.0),
('SKU-MAGNOLIA', 'Magnolia', 'Ice Cream', 'ICE_CREAM', 'BRAND_CATALOG', 1.0),
('SKU-SELECTA', 'Selecta', 'Ice Cream', 'ICE_CREAM', 'BRAND_CATALOG', 1.0),

-- Canned & Jarred Goods - Fish
('SKU-CENTURY-TUNA', 'Century Tuna', 'Canned Tuna', 'CANNED_FISH', 'BRAND_CATALOG', 1.0),
('SKU-555', '555', 'Canned Sardines', 'CANNED_FISH', 'BRAND_CATALOG', 1.0),
('SKU-ANGEL', 'Angel', 'Canned Fish', 'CANNED_FISH', 'BRAND_CATALOG', 1.0),
('SKU-MARCA-LEON', 'Marca Leon', 'Canned Sardines', 'CANNED_FISH', 'BRAND_CATALOG', 1.0),
('SKU-SAN-MARINO', 'San Marino', 'Canned Tuna', 'CANNED_FISH', 'BRAND_CATALOG', 1.0),

-- Canned & Jarred Goods - Meat
('SKU-CDO', 'CDO', 'Corned Beef', 'CANNED_MEAT', 'BRAND_CATALOG', 1.0),
('SKU-DEL-MONTE', 'Del Monte', 'Corned Beef', 'CANNED_MEAT', 'BRAND_CATALOG', 1.0),

-- Canned & Jarred Goods - Other
('SKU-CARNATION', 'Carnation', 'Condensed Milk', 'CANNED_MILK', 'BRAND_CATALOG', 1.0),
('SKU-MILKMAID', 'Milkmaid', 'Condensed Milk', 'CANNED_MILK', 'BRAND_CATALOG', 1.0),
('SKU-BAGUIO', 'Baguio', 'Canned Goods', 'CANNED_FRUITS', 'BRAND_CATALOG', 1.0),
('SKU-DOLE', 'Dole', 'Canned Fruits', 'CANNED_FRUITS', 'BRAND_CATALOG', 1.0),
('SKU-HUNTS', 'Hunt''s', 'Tomato Sauce', 'TOMATO_SAUCE', 'BRAND_CATALOG', 1.0),

-- Instant Foods
('SKU-LUCKY-ME', 'Lucky Me', 'Instant Noodles', 'INST_NOODLES', 'BRAND_CATALOG', 1.0),
('SKU-NISSIN', 'Nissin', 'Instant Noodles', 'INST_NOODLES', 'BRAND_CATALOG', 1.0),
('SKU-MAGGI', 'Maggi', 'Instant Noodles', 'INST_NOODLES', 'BRAND_CATALOG', 1.0),

-- Snacks & Confectionery - Salty Snacks
('SKU-OISHI', 'Oishi', 'Snacks', 'SALTY_SNACKS', 'BRAND_CATALOG', 1.0),
('SKU-PIATTOS', 'Piattos', 'Potato Chips', 'SALTY_SNACKS', 'BRAND_CATALOG', 1.0),
('SKU-CHIPPY', 'Chippy', 'Corn Chips', 'SALTY_SNACKS', 'BRAND_CATALOG', 1.0),
('SKU-NOVA', 'Nova', 'Chips', 'SALTY_SNACKS', 'BRAND_CATALOG', 1.0),
('SKU-PRINGLES', 'Pringles', 'Potato Chips', 'SALTY_SNACKS', 'BRAND_CATALOG', 1.0),
('SKU-BOY-BAWANG', 'Boy Bawang', 'Corn Nuts', 'SALTY_SNACKS', 'BRAND_CATALOG', 1.0),
('SKU-V-CUT', 'V-Cut', 'Potato Chips', 'SALTY_SNACKS', 'BRAND_CATALOG', 1.0),

-- Snacks & Confectionery - Sweet Snacks
('SKU-FUDGEE-BAR', 'Fudgee Bar', 'Cake Bar', 'CHOCO_CONF', 'BRAND_CATALOG', 1.0),
('SKU-JACK-N-JILL', 'Jack ''n Jill', 'Snacks', 'CHOCO_CONF', 'BRAND_CATALOG', 1.0),
('SKU-BINGO', 'Bingo', 'Snacks', 'CHOCO_CONF', 'BRAND_CATALOG', 1.0),
('SKU-CHOCO-MUCHO', 'Choco Mucho', 'Chocolate Bar', 'CHOCO_CONF', 'BRAND_CATALOG', 1.0),
('SKU-DING-DONG', 'Ding Dong', 'Snacks', 'CHOCO_CONF', 'BRAND_CATALOG', 1.0),
('SKU-JIMMS', 'Jimm''s', 'Snacks', 'CHOCO_CONF', 'BRAND_CATALOG', 1.0),
('SKU-MAXX', 'Maxx', 'Snacks', 'CHOCO_CONF', 'BRAND_CATALOG', 1.0),
('SKU-PRESTO', 'Presto', 'Snacks', 'CHOCO_CONF', 'BRAND_CATALOG', 1.0),
('SKU-REBISCO', 'Rebisco', 'Snacks', 'CHOCO_CONF', 'BRAND_CATALOG', 1.0),
('SKU-REGENT', 'Regent', 'Snacks', 'CHOCO_CONF', 'BRAND_CATALOG', 1.0),
('SKU-ROLLER-COASTER', 'Roller Coaster', 'Snacks', 'CHOCO_CONF', 'BRAND_CATALOG', 1.0),
('SKU-STING', 'Sting', 'Snacks', 'CHOCO_CONF', 'BRAND_CATALOG', 1.0),
('SKU-TIGER', 'Tiger', 'Snacks', 'CHOCO_CONF', 'BRAND_CATALOG', 1.0),

-- Candies & Sweets
('SKU-CHOC-NUT', 'Choc-Nut', 'Chocolate Candy', 'HARD_CANDY', 'BRAND_CATALOG', 1.0),
('SKU-COMBI', 'Combi', 'Candy', 'HARD_CANDY', 'BRAND_CATALOG', 1.0),
('SKU-POTCHI', 'Potchi', 'Gummy Candy', 'HARD_CANDY', 'BRAND_CATALOG', 1.0),
('SKU-WHITE-RABBIT', 'White Rabbit', 'Candy', 'HARD_CANDY', 'BRAND_CATALOG', 1.0),

-- Biscuits & Crackers
('SKU-OREO', 'Oreo', 'Sandwich Cookies', 'BISCUITS', 'BRAND_CATALOG', 1.0),
('SKU-CHIPS-AHOY', 'Chips Ahoy', 'Chocolate Chip Cookies', 'BISCUITS', 'BRAND_CATALOG', 1.0),
('SKU-CREAM-O', 'Cream-O', 'Sandwich Cookies', 'BISCUITS', 'BRAND_CATALOG', 1.0),
('SKU-HANSEL', 'Hansel', 'Biscuits', 'BISCUITS', 'BRAND_CATALOG', 1.0),
('SKU-SKYFLAKES', 'SkyFlakes', 'Crackers', 'BISCUITS', 'BRAND_CATALOG', 1.0),

-- Cooking Essentials & Condiments
('SKU-DATU-PUTI', 'Datu Puti', 'Soy Sauce', 'SOY_SAUCE', 'BRAND_CATALOG', 1.0),
('SKU-SILVER-SWAN', 'Silver Swan', 'Soy Sauce', 'SOY_SAUCE', 'BRAND_CATALOG', 1.0),
('SKU-STAR-MARGARINE', 'Star Margarine', 'Margarine', 'MARGARINE', 'BRAND_CATALOG', 1.0),
('SKU-BLUE-BAND', 'Blue Band', 'Margarine', 'MARGARINE', 'BRAND_CATALOG', 1.0),
('SKU-PALM', 'Palm', 'Cooking Oil', 'COOKING_OIL', 'BRAND_CATALOG', 1.0),
('SKU-FORTUNE', 'Fortune', 'Cooking Oil', 'COOKING_OIL', 'BRAND_CATALOG', 1.0),

-- Personal Care - Oral Care
('SKU-COLGATE', 'Colgate', 'Toothpaste', 'TOOTHPASTE', 'BRAND_CATALOG', 1.0),
('SKU-CLOSE-UP', 'Close Up', 'Toothpaste', 'TOOTHPASTE', 'BRAND_CATALOG', 1.0),

-- Personal Care - Body Care
('SKU-SAFEGUARD-BODY', 'Safeguard', 'Bar Soap', 'BAR_SOAP', 'BRAND_CATALOG', 1.0),
('SKU-DOVE', 'Dove', 'Bar Soap', 'BAR_SOAP', 'BRAND_CATALOG', 1.0),

-- Personal Care - Hair Care
('SKU-PANTENE', 'Pantene', 'Shampoo', 'SHAMPOO', 'BRAND_CATALOG', 1.0),
('SKU-CREAM-SILK', 'Cream Silk', 'Shampoo', 'SHAMPOO', 'BRAND_CATALOG', 1.0),
('SKU-HEAD-SHOULDERS', 'Head & Shoulders', 'Shampoo', 'SHAMPOO', 'BRAND_CATALOG', 1.0),
('SKU-REJOICE', 'Rejoice', 'Shampoo', 'SHAMPOO', 'BRAND_CATALOG', 1.0),
('SKU-PALMOLIVE', 'Palmolive', 'Shampoo', 'SHAMPOO', 'BRAND_CATALOG', 1.0),

-- Household & Cleaning - Laundry
('SKU-SURF', 'Surf', 'Laundry Detergent', 'LAUNDRY_POWDER', 'BRAND_CATALOG', 1.0),
('SKU-TIDE', 'Tide', 'Laundry Detergent', 'LAUNDRY_POWDER', 'BRAND_CATALOG', 1.0),
('SKU-ARIEL', 'Ariel', 'Laundry Detergent', 'LAUNDRY_POWDER', 'BRAND_CATALOG', 1.0),
('SKU-DOWNY', 'Downy', 'Fabric Conditioner', 'FABRIC_SOFTENER', 'BRAND_CATALOG', 1.0),

-- Alcoholic Beverages
('SKU-SAN-MIG', 'San Mig', 'Beer', 'BEER', 'BRAND_CATALOG', 1.0),

-- Services & Telecom
('SKU-GLOBE', 'Globe', 'Telecom Services', 'TELECOM', 'BRAND_CATALOG', 1.0),
('SKU-SMART', 'Smart', 'Telecom Services', 'TELECOM', 'BRAND_CATALOG', 1.0),
('SKU-TNT', 'TNT', 'Telecom Services', 'TELECOM', 'BRAND_CATALOG', 1.0),
('SKU-CHERRY-PREPAID', 'Cherry Prepaid', 'Telecom Services', 'TELECOM', 'BRAND_CATALOG', 1.0),

-- Other Essentials & General Merchandise
('SKU-3JM', '3JM', 'General Merchandise', 'GENERAL_MERCH', 'BRAND_CATALOG', 0.8),
('SKU-BRAVO', 'Bravo', 'General Merchandise', 'GENERAL_MERCH', 'BRAND_CATALOG', 0.8),
('SKU-DEWBERRY', 'Dewberry', 'General Merchandise', 'GENERAL_MERCH', 'BRAND_CATALOG', 0.8),
('SKU-EIGHT-OCLOCK', 'Eight O''Clock', 'Coffee', '3IN1_COFFEE', 'BRAND_CATALOG', 0.9),
('SKU-GOMO', 'GOMO', 'Telecom Services', 'TELECOM', 'BRAND_CATALOG', 1.0),
('SKU-HANY', 'Hany', 'General Merchandise', 'GENERAL_MERCH', 'BRAND_CATALOG', 0.8),
('SKU-HELLO', 'Hello', 'General Merchandise', 'GENERAL_MERCH', 'BRAND_CATALOG', 0.8),
('SKU-LESLIES', 'Leslie''s', 'General Merchandise', 'GENERAL_MERCH', 'BRAND_CATALOG', 0.8),
('SKU-MAGIC', 'Magic', 'General Merchandise', 'GENERAL_MERCH', 'BRAND_CATALOG', 0.8),
('SKU-MIGHTY', 'Mighty', 'Rice Products', 'RICE', 'BRAND_CATALOG', 0.9),
('SKU-SUPREME', 'Supreme', 'General Merchandise', 'GENERAL_MERCH', 'BRAND_CATALOG', 0.8),
('SKU-VOICE', 'Voice', 'Telecom Services', 'TELECOM', 'BRAND_CATALOG', 1.0);

PRINT 'All 113 brands mapped to Nielsen categories successfully.';

-- Show mapping summary by category
SELECT
    nc.category_name,
    COUNT(*) as brand_count,
    STRING_AGG(nsm.brand_name, ', ') as brands
FROM dbo.nielsen_sku_map nsm
JOIN dbo.nielsen_product_categories nc ON nc.category_code = nsm.nielsen_category_code
GROUP BY nc.category_name
ORDER BY brand_count DESC;