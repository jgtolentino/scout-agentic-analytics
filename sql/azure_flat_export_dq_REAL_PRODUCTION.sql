-- Azure SQL Flat CSV Export DQ Framework - REAL PRODUCTION DATA
-- Updated with actual brand/category patterns from production
-- Date: 2025-09-22

-- ============================================
-- DQ-03: Business Rules Validation (REAL PRODUCTION)
-- ============================================

IF OBJECT_ID('dq.v_flat_business_rules_real') IS NOT NULL
    DROP VIEW dq.v_flat_business_rules_real;
GO

CREATE VIEW dq.v_flat_business_rules_real AS
SELECT
    'Real Production Business Rules' as check_type,
    COUNT(*) as total_records,

    -- REAL Category validation from production data
    SUM(CASE WHEN Category NOT IN (
        'Snacks & Confectionery', 'Salty Snacks (Chichirya)', 'Candies & Sweets',
        'Body Care', 'Hair Care', 'Oral Care', 'Beverages', 'Non-Alcoholic',
        'Other Essentials', 'unspecified', 'Unknown'
    ) THEN 1 ELSE 0 END) as invalid_categories,

    -- TEST/PLACEHOLDER Brand detection (real production has hundreds of brands)
    SUM(CASE WHEN Brand IN ('Brand A', 'Brand B', 'Brand C', 'Local Brand') THEN 1 ELSE 0 END) as test_placeholder_brands,

    -- Real Filipino brands sample validation
    SUM(CASE WHEN Brand IN (
        'Safeguard', 'Jack ''n Jill', 'Piattos', 'Combi', 'Pantene',
        'Head & Shoulders', 'Close Up', 'Cream Silk', 'Gatorade',
        'C2', 'Coca-Cola'
    ) THEN 1 ELSE 0 END) as known_real_brands,

    -- Location validation (still valid for stores)
    SUM(CASE WHEN Location NOT IN ('Los Baños', 'Quezon City', 'Manila', 'Pateros', 'Metro Manila') THEN 1 ELSE 0 END) as invalid_locations,

    -- StoreID validation (Scout stores)
    SUM(CASE WHEN StoreID NOT IN (102, 103, 104, 109, 110, 112) THEN 1 ELSE 0 END) as invalid_store_ids,

    -- Substitution validation
    SUM(CASE WHEN Was_there_substitution NOT IN ('Yes', 'No') THEN 1 ELSE 0 END) as invalid_substitution_values,

    -- Negative amounts (critical error)
    SUM(CASE WHEN Transaction_Value < 0 THEN 1 ELSE 0 END) as negative_amounts,

    -- Very high amounts (outlier detection)
    SUM(CASE WHEN Transaction_Value > 5000 THEN 1 ELSE 0 END) as very_high_amounts,

    -- Quality scoring
    (100.0 -
        (CAST(SUM(CASE WHEN Category NOT IN (
            'Snacks & Confectionery', 'Salty Snacks (Chichirya)', 'Candies & Sweets',
            'Body Care', 'Hair Care', 'Oral Care', 'Beverages', 'Non-Alcoholic',
            'Other Essentials', 'unspecified', 'Unknown'
        ) THEN 1 ELSE 0 END) AS float) / COUNT(*) * 100) -
        (CAST(SUM(CASE WHEN Brand IN ('Brand A', 'Brand B', 'Brand C', 'Local Brand') THEN 1 ELSE 0 END) AS float) / COUNT(*) * 100) -
        (CAST(SUM(CASE WHEN Transaction_Value < 0 THEN 1 ELSE 0 END) AS float) / COUNT(*) * 100)
    ) as real_production_quality_score,

    -- Data authenticity assessment
    CASE
        WHEN SUM(CASE WHEN Brand IN ('Brand A', 'Brand B', 'Brand C', 'Local Brand') THEN 1 ELSE 0 END) > 0
        THEN 'TEST_DATA_DETECTED'
        WHEN SUM(CASE WHEN Brand IN (
            'Safeguard', 'Jack ''n Jill', 'Piattos', 'Combi', 'Pantene',
            'Head & Shoulders', 'Close Up', 'Cream Silk', 'Gatorade', 'C2', 'Coca-Cola'
        ) THEN 1 ELSE 0 END) > 0
        THEN 'REAL_PRODUCTION_DATA'
        ELSE 'UNKNOWN_DATA_SOURCE'
    END as data_authenticity

FROM gold.v_flat_export_ready;
GO

-- ============================================
-- REAL PRODUCTION BRANDS REFERENCE
-- ============================================

IF OBJECT_ID('dq.v_real_production_brands') IS NOT NULL
    DROP VIEW dq.v_real_production_brands;
GO

CREATE VIEW dq.v_real_production_brands AS
SELECT
    'Real Production Brands Sample' as reference_type,
    brand_name,
    category,
    'From actual Scout production data 2025-09-21' as source
FROM (VALUES
    ('Safeguard', 'Body Care'),
    ('Jack ''n Jill', 'Snacks & Confectionery'),
    ('Piattos', 'Salty Snacks (Chichirya)'),
    ('Combi', 'Candies & Sweets'),
    ('Pantene', 'Hair Care'),
    ('Head & Shoulders', 'Hair Care'),
    ('Close Up', 'Oral Care'),
    ('Cream Silk', 'Hair Care'),
    ('Gatorade', 'Beverages'),
    ('C2', 'Non-Alcoholic'),
    ('Coca-Cola', 'Non-Alcoholic')
) AS brands(brand_name, category);
GO

-- ============================================
-- REAL PRODUCTION CATEGORIES REFERENCE
-- ============================================

IF OBJECT_ID('dq.v_real_production_categories') IS NOT NULL
    DROP VIEW dq.v_real_production_categories;
GO

CREATE VIEW dq.v_real_production_categories AS
SELECT
    'Real Production Categories' as reference_type,
    category_name,
    'Filipino retail categories from production' as description
FROM (VALUES
    ('Snacks & Confectionery'),
    ('Salty Snacks (Chichirya)'),
    ('Candies & Sweets'),
    ('Body Care'),
    ('Hair Care'),
    ('Oral Care'),
    ('Beverages'),
    ('Non-Alcoholic'),
    ('Other Essentials'),
    ('unspecified')
) AS categories(category_name);
GO

-- Summary: Real production data shows authentic Filipino brands like Safeguard,
-- Jack 'n Jill, Piattos, etc. NOT generic "Brand A/B/C" placeholders!