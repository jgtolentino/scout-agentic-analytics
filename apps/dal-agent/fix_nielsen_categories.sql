-- Fix Nielsen Categories with correct SMALLINT values
-- Replace large category IDs with smaller ones that fit in SMALLINT

-- Insert Nielsen Categories (Top 50 Sari-Sari Relevant) - Fixed IDs
INSERT INTO dbo.nielsen_product_categories (category_id, group_id, category_code, category_name, sari_sari_priority, ph_market_relevant) VALUES
-- INSTANT FOODS (Critical for Sari-Sari)
(1001, 101, 'INST_NOODLES', 'Instant Noodles', 1, 1),
(1002, 101, 'INST_RICE', 'Instant Rice Products', 2, 1),
(1003, 101, 'INST_MEALS', 'Ready-to-Eat Meals', 3, 1),

-- CANNED FOODS
(1101, 102, 'CANNED_FISH', 'Canned Fish & Seafood', 1, 1),
(1102, 102, 'CANNED_MEAT', 'Canned Meat Products', 2, 1),
(1103, 102, 'CANNED_FRUITS', 'Canned Fruits', 3, 1),
(1104, 102, 'CANNED_VEGGIES', 'Canned Vegetables', 3, 1),

-- SNACKS (High Priority)
(1201, 103, 'CHOCO_CONF', 'Chocolate & Confectionery', 2, 1),
(1202, 103, 'HARD_CANDY', 'Hard Candies & Sweets', 2, 1),
(1203, 103, 'SALTY_SNACKS', 'Salty Snacks & Chips', 1, 1),
(1204, 103, 'NUTS_SEEDS', 'Nuts & Seeds', 3, 1),

-- BISCUITS & CRACKERS
(1301, 104, 'COOKIES', 'Cookies & Sweet Biscuits', 2, 1),
(1302, 104, 'CRACKERS', 'Crackers & Savory Biscuits', 2, 1),
(1303, 104, 'WAFERS', 'Wafers & Cream Biscuits', 2, 1),

-- CONDIMENTS & SEASONINGS (Critical)
(1401, 105, 'SAUCES', 'Cooking Sauces & Condiments', 1, 1),
(1402, 105, 'SPICES', 'Spices & Seasonings', 1, 1),
(1403, 105, 'VINEGAR', 'Vinegar Products', 2, 1),
(1404, 105, 'SOY_SAUCE', 'Soy Sauce & Fish Sauce', 1, 1),

-- COOKING ESSENTIALS (Critical)
(1501, 106, 'COOKING_OIL', 'Cooking Oil', 1, 1),
(1502, 106, 'MARGARINE', 'Margarine & Butter', 2, 1),
(1503, 106, 'FLOUR', 'Flour & Baking Ingredients', 2, 1),
(1504, 106, 'SUGAR', 'Sugar & Sweeteners', 1, 1),

-- SOFT DRINKS (Critical)
(2001, 201, 'COLA', 'Cola Drinks', 1, 1),
(2002, 201, 'CITRUS_SODA', 'Citrus & Lemon-Lime Sodas', 1, 1),
(2003, 201, 'FRUIT_SODAS', 'Fruit Flavored Sodas', 2, 1),
(2004, 201, 'ENERGY_DRINKS', 'Energy Drinks', 2, 1),

-- COFFEE PRODUCTS (Critical for Filipino Market)
(2101, 202, '3IN1_COFFEE', '3-in-1 Coffee Mixes', 1, 1),
(2102, 202, 'INSTANT_COFFEE', 'Pure Instant Coffee', 1, 1),
(2103, 202, 'COFFEE_CREAMER', 'Coffee Creamers', 2, 1),

-- JUICES & DRINKS
(2201, 204, 'FRUIT_JUICE', 'Packaged Fruit Juices', 2, 1),
(2202, 204, 'POWDERED_JUICE', 'Powdered Juice Drinks', 1, 1),
(2203, 204, 'ICED_TEA', 'Ready-to-Drink Iced Tea', 2, 1),

-- PERSONAL CARE (Critical)
(3001, 301, 'SHAMPOO', 'Shampoo Products', 1, 1),
(3002, 301, 'CONDITIONER', 'Hair Conditioner', 2, 1),
(3003, 301, 'HAIR_TREATMENT', 'Hair Treatment Products', 3, 1),

-- ORAL CARE
(3101, 302, 'TOOTHPASTE', 'Toothpaste', 1, 1),
(3102, 302, 'TOOTHBRUSH', 'Toothbrushes', 2, 1),
(3103, 302, 'MOUTHWASH', 'Mouthwash', 3, 1),

-- BODY CARE
(3201, 303, 'BAR_SOAP', 'Bar Soap', 1, 1),
(3202, 303, 'BODY_WASH', 'Body Wash & Shower Gel', 2, 1),
(3203, 303, 'DEODORANT', 'Deodorants & Antiperspirants', 2, 1),

-- LAUNDRY PRODUCTS (Critical for Sari-Sari)
(4001, 401, 'DETERGENT_POWDER', 'Laundry Detergent Powder', 1, 1),
(4002, 401, 'DETERGENT_BAR', 'Laundry Bar Soap', 1, 1),
(4003, 401, 'LIQUID_DETERGENT', 'Liquid Laundry Detergent', 2, 1),

-- FABRIC CARE
(4101, 402, 'FABRIC_CONDITIONER', 'Fabric Conditioner & Softener', 1, 1),
(4102, 402, 'BLEACH', 'Bleach & Whiteners', 2, 1),

-- TOBACCO PRODUCTS (Critical Revenue)
(5001, 501, 'REGULAR_CIGARETTES', 'Regular Cigarettes', 1, 1),
(5002, 501, 'MENTHOL_CIGARETTES', 'Menthol Cigarettes', 1, 1),
(5003, 501, 'PREMIUM_CIGARETTES', 'Premium Cigarettes', 2, 1),

-- TELECOMMUNICATIONS (High Revenue)
(6001, 601, 'PREPAID_LOAD', 'Prepaid Load Cards', 1, 1),
(6002, 601, 'DATA_CARDS', 'Internet Data Cards', 1, 1),
(6003, 601, 'SIM_CARDS', 'SIM Cards & Starter Kits', 2, 1);

PRINT 'Nielsen categories inserted successfully with corrected IDs';