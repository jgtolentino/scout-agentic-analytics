-- Comprehensive Brand to Nielsen Category Mapping
-- All 113 Project Scout Brands + Industry Standard Extensions

-- Step 1: Insert Subcategories for granular classification
INSERT INTO dbo.nielsen_subcategories (subcategory_id, category_id, subcategory_code, subcategory_name, subcategory_desc, package_types, typical_sizes) VALUES
-- Coffee Subcategories
(2020101, 20201, '3IN1_ORIGINAL', '3-in-1 Coffee Original', 'Original flavor 3-in-1 coffee mixes', 'Sachet, Box', '20g, 25g, 30g'),
(2020102, 20201, '3IN1_FLAVORED', '3-in-1 Coffee Flavored', 'Flavored 3-in-1 coffee mixes', 'Sachet, Box', '20g, 25g, 30g'),
(2020103, 20201, '3IN1_PREMIUM', '3-in-1 Coffee Premium', 'Premium 3-in-1 coffee mixes', 'Sachet, Box', '25g, 30g, 35g'),

-- Soft Drinks Subcategories
(2010101, 20101, 'COLA_REGULAR', 'Regular Cola', 'Regular cola beverages', 'Can, Bottle, PET', '330ml, 500ml, 1L, 1.5L'),
(2010201, 20102, 'ORANGE_DRINKS', 'Orange Flavored Drinks', 'Orange flavored carbonated beverages', 'Can, Bottle, PET', '330ml, 500ml'),
(2010202, 20102, 'MIXED_FRUIT', 'Mixed Fruit Drinks', 'Mixed fruit flavored beverages', 'Can, Bottle, Tetrapack', '250ml, 330ml, 500ml'),

-- Powdered Drinks
(2040101, 20401, 'ORANGE_POWDER', 'Orange Powdered Drinks', 'Orange flavored drink mixes', 'Sachet, Pouch', '8g, 25g, 40g'),
(2040102, 20401, 'FOUR_SEASONS', 'Four Seasons Drinks', 'Multi-flavor drink mixes', 'Sachet, Pouch', '8g, 25g'),

-- Water Products
(2050101, 20501, 'PURIFIED_WATER', 'Purified Bottled Water', 'Purified drinking water', 'Bottle, Gallon', '350ml, 500ml, 1L, 5L'),

-- Energy Drinks
(2060101, 20601, 'ENERGY_REGULAR', 'Regular Energy Drinks', 'Standard energy drinks', 'Can, Bottle', '150ml, 250ml, 330ml'),
(2060102, 20601, 'ENERGY_PREMIUM', 'Premium Energy Drinks', 'Premium energy drinks', 'Can, Bottle', '250ml, 330ml'),

-- Sports Drinks
(2060201, 20602, 'ISOTONIC', 'Isotonic Sports Drinks', 'Electrolyte replacement drinks', 'Bottle, PET', '500ml, 750ml'),

-- Beer
(2070101, 20701, 'REGULAR_BEER', 'Regular Beer', 'Standard beer products', 'Can, Bottle', '330ml, 500ml'),
(2070102, 20701, 'PREMIUM_BEER', 'Premium Beer', 'Premium beer brands', 'Bottle', '330ml, 500ml'),

-- Instant Noodles
(1010101, 10101, 'CUP_NOODLES', 'Cup Noodles', 'Cup-style instant noodles', 'Cup', '60g, 75g'),
(1010102, 10101, 'POUCH_NOODLES', 'Pouch Noodles', 'Pouch-style instant noodles', 'Pouch', '55g, 70g, 80g'),

-- Canned Fish
(1020101, 10201, 'CANNED_TUNA', 'Canned Tuna', 'Tuna in various preparations', 'Can', '155g, 180g'),
(1020102, 10201, 'CANNED_SARDINES', 'Canned Sardines', 'Sardines in tomato sauce or oil', 'Can', '155g, 215g'),
(1020103, 10201, 'CANNED_SALMON', 'Canned Salmon', 'Canned salmon products', 'Can', '155g, 180g'),

-- Salty Snacks
(1030301, 10303, 'CORN_CHIPS', 'Corn-Based Chips', 'Corn chips and corn snacks', 'Pouch, Bag', '25g, 50g, 100g'),
(1030302, 10303, 'POTATO_CHIPS', 'Potato Chips', 'Potato-based snacks', 'Pouch, Bag', '25g, 50g, 85g'),
(1030303, 10303, 'EXTRUDED_SNACKS', 'Extruded Snacks', 'Processed extruded snacks', 'Pouch, Bag', '25g, 30g, 55g'),

-- Cookies
(1040101, 10401, 'SANDWICH_COOKIES', 'Sandwich Cookies', 'Cream-filled sandwich cookies', 'Pack, Tray', '30g, 137g, 270g'),
(1040102, 10401, 'PLAIN_BISCUITS', 'Plain Biscuits', 'Plain sweet biscuits', 'Pack', '25g, 200g, 300g'),

-- Seasonings
(1050201, 10502, 'FLAVOR_ENHANCER', 'Flavor Enhancers', 'MSG and flavor enhancing products', 'Sachet, Pouch', '8g, 11g, 50g'),
(1050202, 10502, 'SEASONING_MIX', 'All-Purpose Seasonings', 'Multi-purpose seasoning mixes', 'Sachet, Bottle', '8g, 40g, 100g'),

-- Cooking Oil & Margarine
(1060101, 10601, 'COOKING_OIL_PALM', 'Palm Cooking Oil', 'Palm-based cooking oil', 'Sachet, Bottle', '10ml, 350ml, 1L'),
(1060201, 10602, 'TABLE_MARGARINE', 'Table Margarine', 'Margarine for spreading and cooking', 'Tub, Bar', '100g, 200g, 240g'),

-- Milk Products
(1070101, 10701, 'POWDERED_MILK', 'Powdered Milk', 'Powdered milk products', 'Sachet, Can', '25g, 400g, 900g'),
(1070102, 10701, 'LIQUID_MILK', 'Liquid Milk', 'Ready-to-drink milk', 'Tetrapack, Bottle', '200ml, 250ml, 1L'),
(1070103, 10701, 'CONDENSED_MILK', 'Condensed Milk', 'Sweetened condensed milk', 'Can, Sachet', '14g, 300ml, 400ml'),

-- Shampoo
(3010101, 30101, 'ANTI_DANDRUFF', 'Anti-Dandruff Shampoo', 'Specialized anti-dandruff formulations', 'Sachet, Bottle', '12ml, 170ml, 340ml'),
(3010102, 30101, 'REGULAR_SHAMPOO', 'Regular Shampoo', 'Standard hair cleansing shampoo', 'Sachet, Bottle', '12ml, 170ml, 340ml'),

-- Body Soap
(3020101, 30201, 'BEAUTY_SOAP', 'Beauty Soap', 'Beauty and moisturizing soap bars', 'Bar', '75g, 90g, 135g'),
(3020102, 30201, 'ANTIBAC_SOAP', 'Antibacterial Soap', 'Antibacterial soap products', 'Bar, Liquid', '75g, 90g, 250ml'),

-- Toothpaste
(3030101, 30301, 'FLUORIDE_TOOTHPASTE', 'Fluoride Toothpaste', 'Fluoride-containing toothpaste', 'Tube', '30g, 50g, 100g, 160g'),

-- Detergent Powder
(4010101, 40101, 'REGULAR_POWDER', 'Regular Detergent Powder', 'Standard laundry detergent powder', 'Sachet, Box, Bag', '35g, 550g, 1kg'),

-- Fabric Conditioner
(4010201, 40102, 'LIQUID_CONDITIONER', 'Liquid Fabric Conditioner', 'Liquid fabric softener', 'Sachet, Bottle', '45ml, 500ml, 1L'),
(4010202, 40102, 'CONCENTRATED_CONDITIONER', 'Concentrated Fabric Conditioner', 'Concentrated fabric softener', 'Sachet, Bottle', '32ml, 400ml'),

-- Cigarettes
(5010101, 50101, 'FULL_FLAVOR', 'Full Flavor Cigarettes', 'Regular full-flavor cigarettes', 'Pack', '20 sticks'),
(5010102, 50101, 'LIGHTS', 'Light Cigarettes', 'Light/mild cigarettes', 'Pack', '20 sticks'),
(5010201, 50102, 'MENTHOL_REGULAR', 'Menthol Cigarettes', 'Menthol-flavored cigarettes', 'Pack', '20 sticks'),

-- Prepaid Load
(6010101, 60101, 'SMART_LOAD', 'Smart Load Cards', 'Smart Communications load cards', 'Card, Digital', 'Various amounts'),
(6010102, 60101, 'GLOBE_LOAD', 'Globe Load Cards', 'Globe Telecom load cards', 'Card, Digital', 'Various amounts'),
(6010103, 60101, 'TM_LOAD', 'TM Load Cards', 'Touch Mobile load cards', 'Card, Digital', 'Various amounts'),
(6010104, 60101, 'TNT_LOAD', 'TNT Load Cards', 'Talk N Text load cards', 'Card, Digital', 'Various amounts');

-- Step 2: Insert Comprehensive Brand Mapping (All 113 Brands)
INSERT INTO dbo.nielsen_brand_mapping (brand_name, subcategory_id, category_id, manufacturer, brand_owner, is_global_brand, is_local_brand, market_position, distribution_tier) VALUES
-- BEVERAGES - Coffee (Critical Sari-Sari Category)
('Great Taste', 2020101, 20201, 'Nestlé Philippines', 'Nestlé', 1, 0, 1, 5),
('Nescafé', 2020102, 20201, 'Nestlé Philippines', 'Nestlé', 1, 0, 1, 5),
('Kopiko', 2020103, 20201, 'Mayora Indah', 'Mayora Group', 1, 0, 2, 5),
('Blend 45', 2020101, 20201, 'URC', 'Universal Robina Corporation', 0, 1, 3, 5),
('Eight O''Clock', 2020201, 20202, 'Tata Coffee', 'Tata Consumer Products', 1, 0, 4, 4),

-- BEVERAGES - Soft Drinks
('Coca-Cola', 2010101, 20101, 'Coca-Cola FEMSA Philippines', 'The Coca-Cola Company', 1, 0, 1, 5),
('Pepsi', 2010101, 20101, 'PepsiCo Philippines', 'PepsiCo', 1, 0, 2, 4),
('Sprite', 2010102, 20102, 'Coca-Cola FEMSA Philippines', 'The Coca-Cola Company', 1, 0, 1, 5),
('Royal', 2040101, 20401, 'ARC Refreshments Corporation', 'Asia Brewery Inc.', 0, 1, 1, 5),
('C2', 2040102, 20401, 'URC', 'Universal Robina Corporation', 0, 1, 2, 5),
('Tang', 2040101, 20401, 'Mondelez Philippines', 'Mondelez International', 1, 0, 1, 5),
('Nestea', 2040102, 20401, 'Nestlé Philippines', 'Nestlé', 1, 0, 2, 4),

-- BEVERAGES - Water
('Wilkins', 2050101, 20501, 'Coca-Cola FEMSA Philippines', 'The Coca-Cola Company', 1, 0, 2, 5),

-- BEVERAGES - Energy/Sports
('Gatorade', 2060201, 20602, 'PepsiCo Philippines', 'PepsiCo', 1, 0, 1, 4),
('Red Bull', 2060101, 20601, 'Red Bull Philippines', 'Red Bull GmbH', 1, 0, 1, 4),
('Extra Joss', 2060102, 20601, 'Bintang Toedjoe', 'Kalbe Farma', 1, 0, 3, 5),
('Cobra', 2060101, 20601, 'Asia Brewery Inc.', 'Asia Brewery Inc.', 0, 1, 2, 5),

-- BEVERAGES - Alcoholic
('San Mig', 2070101, 20701, 'San Miguel Brewery', 'San Miguel Corporation', 0, 1, 1, 5),

-- BEVERAGES - Milk Products
('Alaska', 1070102, 10701, 'Alaska Milk Corporation', 'FrieslandCampina', 1, 0, 1, 5),
('Bear Brand', 1070101, 10701, 'Nestlé Philippines', 'Nestlé', 1, 0, 1, 5),
('Nido', 1070101, 10701, 'Nestlé Philippines', 'Nestlé', 1, 0, 1, 5),
('Cowhead', 1070102, 10701, 'Nutri-Asia Inc.', 'Nutri-Asia', 0, 1, 3, 4),
('Birch Tree', 1070101, 10701, 'Alaska Milk Corporation', 'FrieslandCampina', 1, 0, 2, 4),
('Magnolia', 1070102, 10701, 'Magnolia Inc.', 'San Miguel Corporation', 0, 1, 2, 4),
('Selecta', 1070102, 10701, 'RFM Corporation', 'RFM Corporation', 0, 1, 3, 4),
('Ovaltine', 2020102, 20201, 'Nestlé Philippines', 'Nestlé', 1, 0, 3, 4),
('Milo', 2020102, 20201, 'Nestlé Philippines', 'Nestlé', 1, 0, 1, 5),
('Carnation', 1070103, 10701, 'Nestlé Philippines', 'Nestlé', 1, 0, 2, 4),
('Milkmaid', 1070103, 10701, 'Nestlé Philippines', 'Nestlé', 1, 0, 3, 4),

-- INSTANT FOODS
('Lucky Me', 1010102, 10101, 'Monde Nissin Corporation', 'JG Summit Holdings', 0, 1, 1, 5),
('Nissin', 1010101, 10101, 'Nissin Foods Philippines', 'Nissin Foods Holdings', 1, 0, 2, 4),
('Maggi', 1050202, 10502, 'Nestlé Philippines', 'Nestlé', 1, 0, 1, 5),

-- CANNED GOODS
('Del Monte', 1020103, 10201, 'Del Monte Philippines', 'Del Monte Foods', 1, 0, 1, 4),
('Century Tuna', 1020101, 10201, 'Century Pacific Food', 'Century Pacific Group', 0, 1, 1, 5),
('555', 1020102, 10201, 'Century Pacific Food', 'Century Pacific Group', 0, 1, 2, 4),
('CDO', 1020102, 10201, 'CDO Foodsphere', 'JG Summit Holdings', 0, 1, 1, 4),
('Marca Leon', 1020102, 10201, 'Century Pacific Food', 'Century Pacific Group', 0, 1, 3, 4),
('Dole', 1020103, 10201, 'Dole Philippines', 'Dole plc', 1, 0, 2, 4),
('Angel', 1020103, 10201, 'Century Pacific Food', 'Century Pacific Group', 0, 1, 4, 4),
('Baguio', 1020103, 10201, 'Local Producer', 'Local', 0, 1, 5, 5),
('Hunt''s', 1020103, 10201, 'Del Monte Philippines', 'Conagra Brands', 1, 0, 3, 4),
('San Marino', 1020101, 10201, 'Century Pacific Food', 'Century Pacific Group', 0, 1, 3, 4),

-- SNACKS & CONFECTIONERY
('Oishi', 1030301, 10303, 'Liwayway Marketing Corporation', 'Rickmers Group', 0, 1, 1, 5),
('Piattos', 1030302, 10303, 'Jack ''n Jill', 'URC', 0, 1, 1, 5),
('Chippy', 1030303, 10303, 'Jack ''n Jill', 'URC', 0, 1, 2, 5),
('V-Cut', 1030302, 10303, 'Jack ''n Jill', 'URC', 0, 1, 3, 5),
('Nova', 1030303, 10303, 'Jack ''n Jill', 'URC', 0, 1, 4, 5),
('Boy Bawang', 1030301, 10303, 'KSK Food Products', 'KSK Food', 0, 1, 2, 5),
('Pringles', 1030302, 10303, 'Kellogg Philippines', 'Kellogg Company', 1, 0, 1, 4),
('Jack ''n Jill', 1030303, 10303, 'Jack ''n Jill', 'URC', 0, 1, 1, 5),
('Fudgee Bar', 1040101, 10401, 'Ricoa', 'Rickmers Group', 0, 1, 1, 5),
('Regent', 1030303, 10303, 'Ricoa', 'Rickmers Group', 0, 1, 3, 5),
('Bingo', 1030303, 10303, 'Ricoa', 'Rickmers Group', 0, 1, 4, 5),
('Tiger', 1040102, 10401, 'Ricoa', 'Rickmers Group', 0, 1, 4, 5),
('Rebisco', 1040101, 10401, 'Republic Biscuit Corporation', 'Rebisco', 0, 1, 2, 4),
('Roller Coaster', 1040101, 10401, 'Ricoa', 'Rickmers Group', 0, 1, 4, 5),
('Sting', 1030303, 10303, 'Ricoa', 'Rickmers Group', 0, 1, 5, 5),
('Jimm''s', 1030303, 10303, 'Local Producer', 'Local', 0, 1, 5, 5),
('Presto', 1030303, 10303, 'Jack ''n Jill', 'URC', 0, 1, 4, 5),
('Ding Dong', 1040101, 10401, 'Ricoa', 'Rickmers Group', 0, 1, 5, 5),
('Maxx', 1030303, 10303, 'Local Producer', 'Local', 0, 1, 5, 5),
('Choco Mucho', 1040101, 10401, 'Ricoa', 'Rickmers Group', 0, 1, 3, 5),

-- BISCUITS & CRACKERS
('Chips Ahoy', 1040101, 10401, 'Mondelez Philippines', 'Mondelez International', 1, 0, 1, 4),
('Oreo', 1040101, 10401, 'Mondelez Philippines', 'Mondelez International', 1, 0, 1, 4),
('Cream-O', 1040101, 10401, 'Ricoa', 'Rickmers Group', 0, 1, 2, 5),
('SkyFlakes', 1040102, 10401, 'Monde Nissin Corporation', 'JG Summit Holdings', 0, 1, 1, 5),
('Hansel', 1040102, 10401, 'Ricoa', 'Rickmers Group', 0, 1, 3, 5),

-- CANDIES & SWEETS
('Combi', 1030201, 10302, 'Ricoa', 'Rickmers Group', 0, 1, 3, 5),
('Potchi', 1030201, 10302, 'Ricoa', 'Rickmers Group', 0, 1, 4, 5),
('White Rabbit', 1030201, 10302, 'Guanshengyuan', 'Shanghai Guanshengyuan', 1, 0, 4, 4),
('Choc-Nut', 1030201, 10302, 'Ricoa', 'Rickmers Group', 0, 1, 2, 5),

-- COOKING ESSENTIALS
('Datu Puti', 1050301, 10503, 'NutriAsia', 'NutriAsia', 0, 1, 1, 5),
('Silver Swan', 1050301, 10503, 'NutriAsia', 'NutriAsia', 0, 1, 2, 4),
('Star Margarine', 1060201, 10602, 'Unilever Philippines', 'Unilever', 1, 0, 1, 5),
('Palm', 1060101, 10601, 'Palmolive Philippines', 'Colgate-Palmolive', 1, 0, 3, 4),
('Blue Band', 1060201, 10602, 'Unilever Philippines', 'Unilever', 1, 0, 2, 4),
('Fortune', 1060101, 10601, 'Fortune Brands', 'Local', 0, 1, 4, 4),

-- PERSONAL CARE - Hair Care
('Cream Silk', 3010101, 30101, 'Unilever Philippines', 'Unilever', 1, 0, 1, 5),
('Rejoice', 3010102, 30101, 'Procter & Gamble Philippines', 'Procter & Gamble', 1, 0, 2, 5),
('Pantene', 3010101, 30101, 'Procter & Gamble Philippines', 'Procter & Gamble', 1, 0, 1, 4),
('Head & Shoulders', 3010101, 30101, 'Procter & Gamble Philippines', 'Procter & Gamble', 1, 0, 1, 4),
('Palmolive', 3010102, 30101, 'Colgate-Palmolive Philippines', 'Colgate-Palmolive', 1, 0, 3, 4),

-- PERSONAL CARE - Body Care
('Safeguard', 3020102, 30201, 'Procter & Gamble Philippines', 'Procter & Gamble', 1, 0, 1, 5),
('Dove', 3020101, 30201, 'Unilever Philippines', 'Unilever', 1, 0, 1, 4),

-- PERSONAL CARE - Oral Care
('Colgate', 3030101, 30301, 'Colgate-Palmolive Philippines', 'Colgate-Palmolive', 1, 0, 1, 5),
('Close Up', 3030101, 30301, 'Unilever Philippines', 'Unilever', 1, 0, 2, 5),

-- HOUSEHOLD - Laundry
('Surf', 4010101, 40101, 'Unilever Philippines', 'Unilever', 1, 0, 1, 5),
('Tide', 4010101, 40101, 'Procter & Gamble Philippines', 'Procter & Gamble', 1, 0, 1, 4),
('Ariel', 4010101, 40101, 'Procter & Gamble Philippines', 'Procter & Gamble', 1, 0, 2, 4),
('Downy', 4010201, 40102, 'Procter & Gamble Philippines', 'Procter & Gamble', 1, 0, 1, 5),

-- OTHER ESSENTIALS (Need to be recategorized)
('Magic', 4020101, 40201, 'Colgate-Palmolive Philippines', 'Colgate-Palmolive', 1, 0, 2, 5),
('Leslie''s', 1030201, 10302, 'Ricoa', 'Rickmers Group', 0, 1, 4, 5),
('Dewberry', 7010101, 70101, 'Local Producer', 'Local', 0, 1, 5, 5),
('Supreme', 1001010, 100101, 'Local Producer', 'Local', 0, 1, 4, 5),
('Bravo', 1001010, 100101, 'Local Producer', 'Local', 0, 1, 4, 5),
('Lipovitan', 2060101, 20601, 'Taisho Pharmaceutical', 'Taisho Holdings', 1, 0, 3, 4),
('3JM', 1001010, 100101, 'Local Producer', 'Local', 0, 1, 5, 5),
('Hello', 1001010, 100101, 'Local Producer', 'Local', 0, 1, 5, 5),
('Voice', 1001010, 100101, 'Local Producer', 'Local', 0, 1, 5, 5),
('Mighty', 1070101, 10701, 'Local Producer', 'Local', 0, 1, 5, 5),
('Hany', 1001010, 100101, 'Local Producer', 'Local', 0, 1, 5, 5),

-- TELECOMMUNICATIONS
('GOMO', 6010102, 60101, 'Globe Telecom', 'Globe Telecom', 0, 1, 2, 5),
('Smart', 6010101, 60101, 'Smart Communications', 'PLDT', 0, 1, 1, 5),
('Globe', 6010102, 60101, 'Globe Telecom', 'Globe Telecom', 0, 1, 1, 5),
('TNT', 6010104, 60101, 'Smart Communications', 'PLDT', 0, 1, 2, 5),
('TM', 6010103, 60101, 'Globe Telecom', 'Globe Telecom', 0, 1, 3, 5),
('Cherry Prepaid', 6010102, 60101, 'Cherry Mobile', 'Cherry Mobile', 0, 1, 4, 4),

-- TOBACCO PRODUCTS
('Marlboro', 5010101, 50101, 'Philip Morris Philippines', 'Philip Morris International', 1, 0, 1, 5),
('Camel', 5010101, 50101, 'JTI Philippines', 'Japan Tobacco International', 1, 0, 2, 4),
('Winston', 5010101, 50101, 'JTI Philippines', 'Japan Tobacco International', 1, 0, 3, 4),
('Chesterfield', 5010101, 50101, 'Philip Morris Philippines', 'Philip Morris International', 1, 0, 4, 4);

-- Step 3: Create Views for Easy Access
CREATE OR ALTER VIEW dbo.v_nielsen_brand_hierarchy AS
SELECT
    bm.brand_name,
    bm.manufacturer,
    bm.brand_owner,

    -- Full Nielsen Hierarchy
    nd.department_name,
    nd.department_code,

    npg.group_name,
    npg.group_code,

    npc.category_name,
    npc.category_code,
    npc.sari_sari_priority,

    nsc.subcategory_name,
    nsc.subcategory_code,
    nsc.package_types,
    nsc.typical_sizes,

    -- Brand Characteristics
    bm.market_position,
    bm.distribution_tier,
    CASE bm.market_position
        WHEN 1 THEN 'Market Leader'
        WHEN 2 THEN 'Challenger'
        WHEN 3 THEN 'Follower'
        WHEN 4 THEN 'Nicher'
        ELSE 'Unclassified'
    END as position_desc,

    CASE bm.distribution_tier
        WHEN 1 THEN 'National'
        WHEN 2 THEN 'Regional'
        WHEN 3 THEN 'Urban'
        WHEN 4 THEN 'Rural'
        WHEN 5 THEN 'Sari-Sari Focus'
        ELSE 'Unknown'
    END as distribution_desc,

    CASE npc.sari_sari_priority
        WHEN 1 THEN 'Critical'
        WHEN 2 THEN 'High Priority'
        WHEN 3 THEN 'Medium Priority'
        WHEN 4 THEN 'Low Priority'
        WHEN 5 THEN 'Rare'
        ELSE 'Unclassified'
    END as sari_sari_importance

FROM dbo.nielsen_brand_mapping bm
JOIN dbo.nielsen_subcategories nsc ON bm.subcategory_id = nsc.subcategory_id
JOIN dbo.nielsen_product_categories npc ON nsc.category_id = npc.category_id
JOIN dbo.nielsen_product_groups npg ON npc.group_id = npg.group_id
JOIN dbo.nielsen_departments nd ON npg.department_id = nd.department_id;