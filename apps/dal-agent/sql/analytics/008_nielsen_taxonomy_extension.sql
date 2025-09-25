-- Nielsen Industry Standard Taxonomy (1,100+ Categories)
-- Philippine Sari-Sari Store Extension for Project Scout

-- Step 1: Create Nielsen Hierarchy Tables

-- Level 1: Departments (Nielsen Standard - 10 departments)
CREATE TABLE dbo.nielsen_departments (
    department_id TINYINT PRIMARY KEY,
    department_code VARCHAR(10) NOT NULL,
    department_name VARCHAR(100) NOT NULL,
    department_desc TEXT,
    created_date DATETIME2 DEFAULT GETDATE()
);

-- Level 2: Product Groups (Nielsen Standard - 125 groups)
CREATE TABLE dbo.nielsen_product_groups (
    group_id SMALLINT PRIMARY KEY,
    department_id TINYINT NOT NULL,
    group_code VARCHAR(20) NOT NULL,
    group_name VARCHAR(150) NOT NULL,
    group_desc TEXT,
    created_date DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (department_id) REFERENCES dbo.nielsen_departments(department_id)
);

-- Level 3: Product Categories (Nielsen Standard - 1,100 categories)
CREATE TABLE dbo.nielsen_product_categories (
    category_id SMALLINT PRIMARY KEY,
    group_id SMALLINT NOT NULL,
    category_code VARCHAR(30) NOT NULL,
    category_name VARCHAR(200) NOT NULL,
    category_desc TEXT,
    sari_sari_priority TINYINT DEFAULT 3, -- 1=Critical, 2=High, 3=Medium, 4=Low, 5=Rare
    ph_market_relevant BIT DEFAULT 1,
    created_date DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (group_id) REFERENCES dbo.nielsen_product_groups(group_id)
);

-- Level 4: Product Subcategories (Nielsen Extended)
CREATE TABLE dbo.nielsen_subcategories (
    subcategory_id INT PRIMARY KEY,
    category_id SMALLINT NOT NULL,
    subcategory_code VARCHAR(40) NOT NULL,
    subcategory_name VARCHAR(250) NOT NULL,
    subcategory_desc TEXT,
    package_types VARCHAR(500), -- Sachet, Bottle, Can, Pouch, etc.
    typical_sizes VARCHAR(500), -- 25g, 330ml, 1L, etc.
    created_date DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (category_id) REFERENCES dbo.nielsen_product_categories(category_id)
);

-- Level 5: Enhanced Brand Mapping
CREATE TABLE dbo.nielsen_brand_mapping (
    brand_id SMALLINT IDENTITY(1,1) PRIMARY KEY,
    brand_name VARCHAR(100) NOT NULL,
    subcategory_id INT NOT NULL,
    category_id SMALLINT NOT NULL,
    manufacturer VARCHAR(200),
    brand_owner VARCHAR(200),
    nielsen_brand_code VARCHAR(50),
    kantar_brand_code VARCHAR(50),
    is_global_brand BIT DEFAULT 0,
    is_local_brand BIT DEFAULT 1,
    ph_market_entry_year SMALLINT,
    market_position TINYINT, -- 1=Leader, 2=Challenger, 3=Follower, 4=Nicher
    distribution_tier TINYINT, -- 1=National, 2=Regional, 3=Urban, 4=Rural, 5=Sari-Sari
    created_date DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (subcategory_id) REFERENCES dbo.nielsen_subcategories(subcategory_id),
    FOREIGN KEY (category_id) REFERENCES dbo.nielsen_product_categories(category_id)
);

-- Step 2: Insert Nielsen Department Structure
INSERT INTO dbo.nielsen_departments (department_id, department_code, department_name, department_desc) VALUES
(1, 'FOOD', 'Food Products', 'All food items including packaged, canned, and fresh food products'),
(2, 'BEVERAGE', 'Beverages', 'All beverage products including non-alcoholic, alcoholic, and functional drinks'),
(3, 'PERSONAL', 'Personal Care', 'Personal hygiene, beauty, grooming, and health products'),
(4, 'HOUSEHOLD', 'Household Products', 'Cleaning, laundry, kitchen, and home maintenance products'),
(5, 'TOBACCO', 'Tobacco Products', 'Cigarettes, cigars, vaping products, and tobacco accessories'),
(6, 'TELECOM', 'Telecommunications', 'Prepaid load, data cards, SIM cards, and telecom accessories'),
(7, 'HEALTH', 'Health & Pharmacy', 'Over-the-counter medicines, supplements, and health products'),
(8, 'BABY', 'Baby Care', 'Infant formula, diapers, baby food, and child care products'),
(9, 'PET', 'Pet Care', 'Pet food, accessories, and pet care products'),
(10, 'GENERAL', 'General Merchandise', 'School supplies, batteries, hardware, and miscellaneous items');

-- Step 3: Insert Key Product Groups (Nielsen-Based)
INSERT INTO dbo.nielsen_product_groups (group_id, department_id, group_code, group_name, group_desc) VALUES
-- FOOD PRODUCTS (Department 1)
(101, 1, 'INSTANT', 'Instant Foods', 'Instant noodles, instant rice, ready-to-eat meals'),
(102, 1, 'CANNED', 'Canned & Jarred Foods', 'Canned goods, jarred products, preserved foods'),
(103, 1, 'SNACKS', 'Snacks & Confectionery', 'Sweet and savory snacks, chocolates, candies'),
(104, 1, 'BISCUITS', 'Biscuits & Crackers', 'Cookies, crackers, wafers, and baked snacks'),
(105, 1, 'CONDIMENTS', 'Condiments & Seasonings', 'Sauces, spices, seasonings, cooking aids'),
(106, 1, 'COOKING', 'Cooking Essentials', 'Cooking oil, margarine, flour, sugar'),
(107, 1, 'DAIRY', 'Dairy Products', 'Milk, cheese, yogurt, dairy-based products'),

-- BEVERAGES (Department 2)
(201, 2, 'SOFT', 'Soft Drinks', 'Carbonated beverages, colas, fruit drinks'),
(202, 2, 'COFFEE', 'Coffee Products', 'Instant coffee, coffee mixes, ground coffee'),
(203, 2, 'TEA', 'Tea Products', 'Tea bags, instant tea, traditional tea'),
(204, 2, 'JUICES', 'Juices & Drinks', 'Fruit juices, powdered drinks, concentrates'),
(205, 2, 'WATER', 'Water Products', 'Bottled water, flavored water, functional water'),
(206, 2, 'ENERGY', 'Energy & Sports Drinks', 'Energy drinks, sports drinks, functional beverages'),
(207, 2, 'ALCOHOLIC', 'Alcoholic Beverages', 'Beer, wine, spirits, alcoholic drinks'),

-- PERSONAL CARE (Department 3)
(301, 3, 'HAIR', 'Hair Care', 'Shampoo, conditioner, hair treatments, styling products'),
(302, 3, 'BODY', 'Body Care', 'Soap, body wash, lotion, deodorants'),
(303, 3, 'ORAL', 'Oral Care', 'Toothpaste, toothbrush, mouthwash, dental care'),
(304, 3, 'FEMININE', 'Feminine Care', 'Sanitary pads, tampons, feminine hygiene'),

-- HOUSEHOLD (Department 4)
(401, 4, 'LAUNDRY', 'Laundry Products', 'Detergent, fabric conditioner, laundry aids'),
(402, 4, 'CLEANING', 'Household Cleaning', 'All-purpose cleaners, disinfectants, floor care'),

-- TOBACCO (Department 5)
(501, 5, 'CIGARETTES', 'Cigarettes', 'Regular cigarettes, menthol, premium brands'),

-- TELECOM (Department 6)
(601, 6, 'PREPAID', 'Prepaid Services', 'Load cards, data packages, telecom services'),

-- HEALTH (Department 7)
(701, 7, 'OTC', 'Over-the-Counter', 'Pain relievers, vitamins, basic medicines'),

-- BABY CARE (Department 8)
(801, 8, 'FORMULA', 'Infant Formula', 'Baby milk, infant nutrition products'),

-- GENERAL (Department 10)
(1001, 10, 'ESSENTIALS', 'Essential Items', 'Batteries, school supplies, basic necessities');

-- Step 4: Insert Nielsen Categories (Top 50 Sari-Sari Relevant)
INSERT INTO dbo.nielsen_product_categories (category_id, group_id, category_code, category_name, sari_sari_priority, ph_market_relevant) VALUES
-- INSTANT FOODS (Critical for Sari-Sari)
(10101, 101, 'INST_NOODLES', 'Instant Noodles', 1, 1),
(10102, 101, 'INST_RICE', 'Instant Rice Products', 2, 1),
(10103, 101, 'INST_MEALS', 'Ready-to-Eat Meals', 3, 1),

-- CANNED FOODS
(10201, 102, 'CANNED_FISH', 'Canned Fish & Seafood', 1, 1),
(10202, 102, 'CANNED_MEAT', 'Canned Meat Products', 2, 1),
(10203, 102, 'CANNED_FRUITS', 'Canned Fruits', 3, 1),
(10204, 102, 'CANNED_VEGGIES', 'Canned Vegetables', 3, 1),

-- SNACKS (High Priority)
(10301, 103, 'CHOCO_CONF', 'Chocolate & Confectionery', 2, 1),
(10302, 103, 'HARD_CANDY', 'Hard Candies & Sweets', 2, 1),
(10303, 103, 'SALTY_SNACKS', 'Salty Snacks & Chips', 1, 1),
(10304, 103, 'NUTS_SEEDS', 'Nuts & Seeds', 3, 1),

-- BISCUITS
(10401, 104, 'COOKIES', 'Cookies & Sweet Biscuits', 1, 1),
(10402, 104, 'CRACKERS', 'Crackers & Savory Biscuits', 2, 1),
(10403, 104, 'WAFERS', 'Wafers & Filled Biscuits', 2, 1),

-- CONDIMENTS (Critical)
(10501, 105, 'SAUCES', 'Cooking Sauces', 1, 1),
(10502, 105, 'SEASONINGS', 'Seasonings & Flavor Enhancers', 1, 1),
(10503, 105, 'VINEGAR', 'Vinegar & Acidulants', 2, 1),

-- COOKING ESSENTIALS
(10601, 106, 'COOKING_OIL', 'Cooking Oil', 1, 1),
(10602, 106, 'MARGARINE', 'Margarine & Spreads', 1, 1),
(10603, 106, 'SUGAR', 'Sugar & Sweeteners', 2, 1),

-- SOFT DRINKS (Critical)
(20101, 201, 'COLA', 'Cola Drinks', 1, 1),
(20102, 201, 'FRUIT_DRINKS', 'Fruit-Flavored Drinks', 1, 1),
(20103, 201, 'LEMON_LIME', 'Lemon-Lime Sodas', 2, 1),

-- COFFEE (Critical for Sari-Sari)
(20201, 202, 'INST_COFFEE_3IN1', '3-in-1 Coffee Mixes', 1, 1),
(20202, 202, 'INST_COFFEE_BLACK', 'Black Instant Coffee', 2, 1),
(20203, 202, 'COFFEE_CREAMER', 'Coffee Creamers', 2, 1),

-- JUICES
(20401, 204, 'POWDERED_DRINKS', 'Powdered Drink Mixes', 1, 1),
(20402, 204, 'FRUIT_JUICES', 'Ready-to-Drink Fruit Juices', 2, 1),

-- WATER
(20501, 205, 'BOTTLED_WATER', 'Bottled Water', 1, 1),

-- ENERGY DRINKS
(20601, 206, 'ENERGY_DRINKS', 'Energy Drinks', 2, 1),
(20602, 206, 'SPORTS_DRINKS', 'Sports & Isotonic Drinks', 2, 1),

-- ALCOHOLIC
(20701, 207, 'BEER', 'Beer Products', 1, 1),
(20702, 207, 'SPIRITS', 'Spirits & Hard Liquor', 2, 1),

-- HAIR CARE
(30101, 301, 'SHAMPOO', 'Shampoo Products', 1, 1),
(30102, 301, 'HAIR_CONDITIONER', 'Hair Conditioners', 2, 1),

-- BODY CARE
(30201, 302, 'BODY_SOAP', 'Body Soap & Cleansers', 1, 1),
(30202, 302, 'DEODORANT', 'Deodorants & Antiperspirants', 2, 1),

-- ORAL CARE
(30301, 303, 'TOOTHPASTE', 'Toothpaste', 1, 1),
(30302, 303, 'MOUTHWASH', 'Mouthwash & Oral Rinse', 3, 1),

-- FEMININE CARE
(30401, 304, 'SANITARY_PADS', 'Sanitary Pads', 1, 1),

-- LAUNDRY (Critical)
(40101, 401, 'DETERGENT_POWDER', 'Laundry Detergent Powder', 1, 1),
(40102, 401, 'FABRIC_CONDITIONER', 'Fabric Conditioners', 1, 1),
(40103, 401, 'DETERGENT_LIQUID', 'Liquid Laundry Detergent', 2, 1),
(40104, 401, 'DETERGENT_BAR', 'Laundry Soap Bars', 2, 1),

-- CLEANING
(40201, 402, 'ALL_PURPOSE', 'All-Purpose Cleaners', 2, 1),
(40202, 402, 'FLOOR_CARE', 'Floor Care Products', 3, 1),

-- CIGARETTES (Critical - Top Sari-Sari Category)
(50101, 501, 'REG_CIGARETTES', 'Regular Cigarettes', 1, 1),
(50102, 501, 'MENTHOL_CIGARETTES', 'Menthol Cigarettes', 1, 1),

-- PREPAID (Critical Revenue Source)
(60101, 601, 'LOAD_CARDS', 'Prepaid Load Cards', 1, 1),
(60102, 601, 'DATA_PACKAGES', 'Internet Data Packages', 1, 1),

-- OTC MEDICINE
(70101, 701, 'PAIN_RELIEF', 'Pain Relief Medication', 2, 1),
(70102, 701, 'VITAMINS', 'Vitamins & Supplements', 3, 1),

-- ESSENTIALS
(100101, 1001, 'BATTERIES', 'Batteries', 2, 1),
(100102, 1001, 'SCHOOL_SUPPLIES', 'School & Office Supplies', 3, 1);