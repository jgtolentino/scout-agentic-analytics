SET NOCOUNT ON;
-- Seed Philippines sari-sari staples (expand to full 113+ brand list)
-- Beverages - Non-Alcoholic: Juice/Mix, RTD Coffee, Energy, Water
INSERT INTO ref.BrandCategoryRules (brand_name, taxonomy_code, priority, rule_source)
SELECT v.brand_name, v.taxonomy_code, 10, 'seed' FROM (VALUES
  (N'Zest-O',           'CAT_BEV_JUICE'),
  (N'Tang',             'CAT_BEV_JUICE'),
  (N'Great Taste',      'CAT_BEV_RTD_COFFEE'),
  (N'Nescafé',          'CAT_BEV_RTD_COFFEE'),
  (N'Nescafe',          'CAT_BEV_RTD_COFFEE'),
  (N'Kopiko',           'CAT_BEV_RTD_COFFEE'),
  (N'Sting',            'CAT_BEV_ENG'),
  (N'Gatorade',         'CAT_BEV_ENG'),
  (N'Red Bull',         'CAT_BEV_ENG'),
  (N'Monster',          'CAT_BEV_ENG'),
  (N'Wilkins',          'CAT_BEV_WATER'),
  (N'Nature''s Spring',  'CAT_BEV_WATER'),
  (N'Summit',           'CAT_BEV_WATER'),
  (N'Absolute',         'CAT_BEV_WATER'),
  (N'Coca-Cola',        'CAT_BEV_CSD'),
  (N'Coke',             'CAT_BEV_CSD'),
  (N'Pepsi',            'CAT_BEV_CSD'),
  (N'Sprite',           'CAT_BEV_CSD'),
  (N'Royal',            'CAT_BEV_CSD'),
  (N'Sarsi',            'CAT_BEV_CSD'),
  (N'C2',               'CAT_BEV_TEA'),
  (N'Nestea',           'CAT_BEV_TEA')
) v(brand_name, taxonomy_code)
WHERE NOT EXISTS (
  SELECT 1 FROM ref.BrandCategoryRules r WHERE r.brand_name = v.brand_name AND r.taxonomy_code = v.taxonomy_code
);

-- Alcoholic beverages
INSERT INTO ref.BrandCategoryRules (brand_name, taxonomy_code, priority, rule_source)
SELECT v.brand_name, v.taxonomy_code, 10, 'seed' FROM (VALUES
  (N'Red Horse',        'GRP_FNB_BEV_ALC'),
  (N'San Miguel Beer',  'GRP_FNB_BEV_ALC'),
  (N'Tanduay',          'GRP_FNB_BEV_ALC'),
  (N'Emperador',        'GRP_FNB_BEV_ALC')
) v(brand_name, taxonomy_code)
WHERE NOT EXISTS (
  SELECT 1 FROM ref.BrandCategoryRules r WHERE r.brand_name = v.brand_name AND r.taxonomy_code = v.taxonomy_code
);

-- Tobacco products (critical for sari-sari stores)
INSERT INTO ref.BrandCategoryRules (brand_name, taxonomy_code, priority, rule_source)
SELECT v.brand_name, v.taxonomy_code, 10, 'seed' FROM (VALUES
  (N'Marlboro',         'CAT_TOB_CIG_REGULAR'),
  (N'Philip Morris',    'CAT_TOB_CIG_REGULAR'),
  (N'Winston',          'CAT_TOB_CIG_REGULAR'),
  (N'Lucky Strike',     'CAT_TOB_CIG_REGULAR'),
  (N'Hope',             'CAT_TOB_CIG_REGULAR'),
  (N'Fortune',          'CAT_TOB_CIG_REGULAR'),
  (N'Mighty',           'CAT_TOB_CIG_REGULAR'),
  (N'Marlboro Ice',     'CAT_TOB_CIG_MENTHOL')
) v(brand_name, taxonomy_code)
WHERE NOT EXISTS (
  SELECT 1 FROM ref.BrandCategoryRules r WHERE r.brand_name = v.brand_name AND r.taxonomy_code = v.taxonomy_code
);

-- Telecommunications (critical for sari-sari stores)
INSERT INTO ref.BrandCategoryRules (brand_name, taxonomy_code, priority, rule_source)
SELECT v.brand_name, v.taxonomy_code, 10, 'seed' FROM (VALUES
  (N'Globe',            'CAT_TEL_GLOBE'),
  (N'Globe Load',       'CAT_TEL_GLOBE'),
  (N'SMART',            'CAT_TEL_SMART'),
  (N'Smart Load',       'CAT_TEL_SMART'),
  (N'Sun Cellular',     'CAT_TEL_OTHER'),
  (N'TNT',              'CAT_TEL_SMART'),
  (N'TM',               'CAT_TEL_GLOBE')
) v(brand_name, taxonomy_code)
WHERE NOT EXISTS (
  SELECT 1 FROM ref.BrandCategoryRules r WHERE r.brand_name = v.brand_name AND r.taxonomy_code = v.taxonomy_code
);

-- Instant foods and noodles (high-frequency sari-sari items)
INSERT INTO ref.BrandCategoryRules (brand_name, taxonomy_code, priority, rule_source)
SELECT v.brand_name, v.taxonomy_code, 10, 'seed' FROM (VALUES
  (N'Lucky Me',         'GRP_FNB_INSTANT'),
  (N'Pancit Canton',    'GRP_FNB_INSTANT'),
  (N'Nissin',           'GRP_FNB_INSTANT'),
  (N'Payless',          'GRP_FNB_INSTANT'),
  (N'Maggi',            'GRP_FNB_INSTANT')
) v(brand_name, taxonomy_code)
WHERE NOT EXISTS (
  SELECT 1 FROM ref.BrandCategoryRules r WHERE r.brand_name = v.brand_name AND r.taxonomy_code = v.taxonomy_code
);

-- Snacks and confectionery
INSERT INTO ref.BrandCategoryRules (brand_name, taxonomy_code, priority, rule_source)
SELECT v.brand_name, v.taxonomy_code, 10, 'seed' FROM (VALUES
  (N'Pringles',         'GRP_FNB_SNACKS'),
  (N'Lay''s',           'GRP_FNB_SNACKS'),
  (N'Chippy',           'GRP_FNB_SNACKS'),
  (N'Nova',             'GRP_FNB_SNACKS'),
  (N'Ricoa',            'GRP_FNB_SNACKS'),
  (N'Choc Nut',         'GRP_FNB_SNACKS')
) v(brand_name, taxonomy_code)
WHERE NOT EXISTS (
  SELECT 1 FROM ref.BrandCategoryRules r WHERE r.brand_name = v.brand_name AND r.taxonomy_code = v.taxonomy_code
);

-- Personal & Health Care (household staples)
INSERT INTO ref.BrandCategoryRules (brand_name, taxonomy_code, priority, rule_source)
SELECT v.brand_name, v.taxonomy_code, 10, 'seed' FROM (VALUES
  (N'Colgate',          'DEPT_PH'),
  (N'Close Up',         'DEPT_PH'),
  (N'Safeguard',        'DEPT_PH'),
  (N'Palmolive',        'DEPT_PH'),
  (N'Head & Shoulders', 'DEPT_PH'),
  (N'Pantene',          'DEPT_PH'),
  (N'Johnson''s',       'DEPT_PH'),
  (N'Biogesic',         'DEPT_PH'),
  (N'Paracetamol',      'DEPT_PH')
) v(brand_name, taxonomy_code)
WHERE NOT EXISTS (
  SELECT 1 FROM ref.BrandCategoryRules r WHERE r.brand_name = v.brand_name AND r.taxonomy_code = v.taxonomy_code
);

-- Household products (cleaning supplies)
INSERT INTO ref.BrandCategoryRules (brand_name, taxonomy_code, priority, rule_source)
SELECT v.brand_name, v.taxonomy_code, 10, 'seed' FROM (VALUES
  (N'Surf',             'DEPT_HH'),
  (N'Tide',             'DEPT_HH'),
  (N'Ariel',            'DEPT_HH'),
  (N'Downy',            'DEPT_HH'),
  (N'Joy',              'DEPT_HH'),
  (N'Zonrox',           'DEPT_HH'),
  (N'Axion',            'DEPT_HH'),
  (N'Mr. Clean',        'DEPT_HH')
) v(brand_name, taxonomy_code)
WHERE NOT EXISTS (
  SELECT 1 FROM ref.BrandCategoryRules r WHERE r.brand_name = v.brand_name AND r.taxonomy_code = v.taxonomy_code
);

PRINT 'Seeded Nielsen brand classification rules for Philippines sari-sari store staples';
PRINT 'Coverage: Beverages, Tobacco, Telecom, Instant Foods, Snacks, Personal Care, Household Products';
PRINT 'Next: Extend to full 113+ brand list and add remaining categories (Dairy, OTC, Baby Care)';