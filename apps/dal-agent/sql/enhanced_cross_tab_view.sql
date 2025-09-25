-- ================================================================
-- ENHANCED CROSS-TABULATION VIEW - Based on Actual Schema
-- Supports all cross-tabulation analytics with Nielsen taxonomy
-- Uses existing v_insight_base + v_transactions_flat_production
-- Generated: September 24, 2025
-- ================================================================

-- Create reference tables for normalization
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ref_pack_size_rules]') AND type in (N'U'))
BEGIN
    CREATE TABLE dbo.ref_pack_size_rules (
        rule_id int IDENTITY(1,1) PRIMARY KEY,
        size_value_min decimal(10,2),
        size_value_max decimal(10,2),
        size_unit varchar(12),
        pack_size_bucket varchar(16),
        created_date datetime DEFAULT GETDATE()
    );

    -- Insert standard pack size rules
    INSERT INTO dbo.ref_pack_size_rules (size_value_min, size_value_max, size_unit, pack_size_bucket) VALUES
    -- Liquid volumes (ml)
    (0, 249, 'ml', 'Single-serve'),
    (250, 499, 'ml', 'Small'),
    (500, 999, 'ml', 'Medium'),
    (1000, 1999, 'ml', 'Family'),
    (2000, 99999, 'ml', 'Bulk'),
    -- Weights (grams)
    (0, 99, 'g', 'Single-serve'),
    (100, 249, 'g', 'Small'),
    (250, 499, 'g', 'Medium'),
    (500, 999, 'g', 'Family'),
    (1000, 99999, 'g', 'Bulk'),
    -- Pieces
    (1, 1, 'pc', '1 pc'),
    (2, 3, 'pc', '2-3 pc'),
    (4, 6, 'pc', '4-6 pc'),
    (7, 999, 'pc', '>6 pc');
END;

-- Create payment method normalization
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ref_payment_method_map]') AND type in (N'U'))
BEGIN
    CREATE TABLE dbo.ref_payment_method_map (
        method_raw varchar(50) PRIMARY KEY,
        method_norm varchar(20),
        created_date datetime DEFAULT GETDATE()
    );

    -- Insert payment method mappings
    INSERT INTO dbo.ref_payment_method_map (method_raw, method_norm) VALUES
    ('cash', 'Cash'),
    ('Cash', 'Cash'),
    ('CASH', 'Cash'),
    ('credit', 'Card'),
    ('Credit', 'Card'),
    ('debit', 'Card'),
    ('Debit', 'Card'),
    ('card', 'Card'),
    ('Card', 'Card'),
    ('gcash', 'E-wallet'),
    ('GCash', 'E-wallet'),
    ('paymaya', 'E-wallet'),
    ('PayMaya', 'E-wallet'),
    ('maya', 'E-wallet'),
    ('Maya', 'E-wallet'),
    ('grabpay', 'E-wallet'),
    ('GrabPay', 'E-wallet'),
    ('digital', 'E-wallet'),
    ('Digital', 'E-wallet'),
    ('unknown', 'Other'),
    ('Unknown', 'Other'),
    ('other', 'Other'),
    ('Other', 'Other');
END;

-- Create the comprehensive cross-tabulation view
CREATE OR ALTER VIEW dbo.v_insight_cross_tabs AS
WITH base_transactions AS (
    -- Get transaction-level data from v_transactions_flat_production
    SELECT
        p.canonical_tx_id,
        p.transaction_id,
        p.txn_ts,
        DATEPART(HOUR, p.txn_ts) as hour_of_day,
        p.daypart,
        p.weekday_weekend,
        p.device_id,
        p.store_id,
        p.store_name,
        p.brand,
        p.product_name,
        p.category,
        p.total_amount as transaction_value,
        p.total_items as basket_size,
        COALESCE(pm.method_norm, p.payment_method, 'Other') as payment_method,
        p.transaction_date
    FROM dbo.v_transactions_flat_production p
    LEFT JOIN dbo.ref_payment_method_map pm ON pm.method_raw = p.payment_method
),
insights_enriched AS (
    -- Get demographics and behavioral data from v_insight_base
    SELECT
        vib.sessionId as canonical_tx_id,
        vib.age_bracket,
        vib.gender,
        vib.customer_type,
        vib.emotions as emotion,
        vib.pack_size,
        vib.substitution_event,
        vib.substitution_reason,
        vib.suggestion_accepted,
        -- Parse pack size into value and unit
        CASE
            WHEN vib.pack_size LIKE '%ml%' OR vib.pack_size LIKE '%ML%'
            THEN TRY_CAST(REPLACE(REPLACE(REPLACE(vib.pack_size, 'ml', ''), 'ML', ''), ' ', '') AS decimal(10,2))
            WHEN vib.pack_size LIKE '%g%' OR vib.pack_size LIKE '%G%'
            THEN TRY_CAST(REPLACE(REPLACE(REPLACE(vib.pack_size, 'g', ''), 'G', ''), ' ', '') AS decimal(10,2))
            WHEN vib.pack_size LIKE '%pc%' OR vib.pack_size LIKE '%PC%'
            THEN TRY_CAST(REPLACE(REPLACE(REPLACE(vib.pack_size, 'pc', ''), 'PC', ''), ' ', '') AS decimal(10,2))
            ELSE NULL
        END as pack_size_value,
        CASE
            WHEN vib.pack_size LIKE '%ml%' OR vib.pack_size LIKE '%ML%' THEN 'ml'
            WHEN vib.pack_size LIKE '%g%' OR vib.pack_size LIKE '%G%' THEN 'g'
            WHEN vib.pack_size LIKE '%pc%' OR vib.pack_size LIKE '%PC%' THEN 'pc'
            ELSE 'unknown'
        END as pack_size_unit
    FROM dbo.v_insight_base vib
),
pack_buckets AS (
    -- Apply pack size bucketing rules
    SELECT
        ie.*,
        COALESCE(psr.pack_size_bucket, 'Unknown') as pack_size_bucket
    FROM insights_enriched ie
    LEFT JOIN dbo.ref_pack_size_rules psr
        ON ie.pack_size_value BETWEEN psr.size_value_min AND psr.size_value_max
        AND ie.pack_size_unit = psr.size_unit
),
nielsen_enhanced AS (
    -- Add Nielsen taxonomy mapping
    SELECT
        bt.*,
        pb.age_bracket,
        pb.gender,
        pb.customer_type,
        pb.emotion,
        pb.pack_size,
        pb.pack_size_value,
        pb.pack_size_unit,
        pb.pack_size_bucket,
        pb.substitution_event,
        pb.substitution_reason,
        pb.suggestion_accepted,
        -- Add Nielsen department from BrandCategoryMapping
        COALESCE(td.department_name, 'Unspecified') as nielsen_department,
        -- Add region/location info
        s.MunicipalityName,
        s.Region,
        s.ProvinceName
    FROM base_transactions bt
    LEFT JOIN pack_buckets pb ON bt.canonical_tx_id = pb.canonical_tx_id
    LEFT JOIN dbo.BrandCategoryMapping bcm ON bt.brand = bcm.brand_name
    LEFT JOIN dbo.TaxonomyCategories tc ON bcm.category_id = tc.category_id
    LEFT JOIN dbo.TaxonomyCategoryGroups tcg ON tc.category_group_id = tcg.category_group_id
    LEFT JOIN dbo.TaxonomyDepartments td ON tcg.department_id = td.department_id
    LEFT JOIN dbo.Stores s ON bt.store_id = s.StoreID
)
SELECT
    -- Transaction identifiers
    canonical_tx_id,
    transaction_id,
    device_id,
    store_id,
    store_name,

    -- Time dimensions
    txn_ts,
    hour_of_day,
    daypart,
    weekday_weekend,
    transaction_date,

    -- Product dimensions
    brand as purchased_brand,
    brand, -- Keep both for clarity
    product_name,
    category,
    nielsen_department,

    -- Pack size dimensions
    pack_size,
    pack_size_value,
    pack_size_unit,
    pack_size_bucket,

    -- Transaction dimensions
    transaction_value,
    basket_size,
    payment_method,

    -- Customer dimensions
    age_bracket,
    gender,
    customer_type,
    emotion,

    -- Behavioral dimensions
    substitution_event,
    substitution_reason,
    suggestion_accepted,

    -- Location dimensions
    MunicipalityName as municipality,
    Region as region,
    ProvinceName as province

FROM nielsen_enhanced;

-- ================================================================
-- CROSS-TABULATION HELPER VIEWS
-- ================================================================

-- Cross-tab: Time of Day × Category
CREATE OR ALTER VIEW dbo.ct_time_category_enhanced AS
SELECT
    hour_of_day,
    daypart,
    weekday_weekend,
    category,
    nielsen_department,
    COUNT(*) as txn_count,
    SUM(transaction_value) as total_sales,
    AVG(transaction_value) as avg_transaction,
    COUNT(DISTINCT purchased_brand) as unique_brands
FROM dbo.v_insight_cross_tabs
GROUP BY hour_of_day, daypart, weekday_weekend, category, nielsen_department;

-- Cross-tab: Demographics × Brand
CREATE OR ALTER VIEW dbo.ct_demographics_brand_enhanced AS
SELECT
    age_bracket,
    gender,
    purchased_brand,
    category,
    nielsen_department,
    COUNT(*) as txn_count,
    SUM(transaction_value) as total_sales,
    AVG(transaction_value) as avg_spend,
    COUNT(DISTINCT store_id) as stores_visited
FROM dbo.v_insight_cross_tabs
GROUP BY age_bracket, gender, purchased_brand, category, nielsen_department;

-- Cross-tab: Basket Size × Category × Payment
CREATE OR ALTER VIEW dbo.ct_basket_category_payment AS
SELECT
    CASE
        WHEN basket_size = 1 THEN '1 item'
        WHEN basket_size BETWEEN 2 AND 3 THEN '2-3 items'
        WHEN basket_size BETWEEN 4 AND 6 THEN '4-6 items'
        WHEN basket_size > 6 THEN '7+ items'
    END as basket_size_bucket,
    category,
    payment_method,
    COUNT(*) as txn_count,
    SUM(transaction_value) as total_sales,
    AVG(transaction_value) as avg_transaction
FROM dbo.v_insight_cross_tabs
GROUP BY
    CASE
        WHEN basket_size = 1 THEN '1 item'
        WHEN basket_size BETWEEN 2 AND 3 THEN '2-3 items'
        WHEN basket_size BETWEEN 4 AND 6 THEN '4-6 items'
        WHEN basket_size > 6 THEN '7+ items'
    END,
    category,
    payment_method;

-- Cross-tab: Substitution × Category × Reason
CREATE OR ALTER VIEW dbo.ct_substitution_analysis AS
SELECT
    category,
    nielsen_department,
    substitution_event,
    substitution_reason,
    suggestion_accepted,
    COUNT(*) as event_count,
    SUM(transaction_value) as total_sales,
    COUNT(DISTINCT purchased_brand) as brands_involved
FROM dbo.v_insight_cross_tabs
GROUP BY category, nielsen_department, substitution_event, substitution_reason, suggestion_accepted;

-- Cross-tab: Pack Size × Demographics
CREATE OR ALTER VIEW dbo.ct_packsize_demographics AS
SELECT
    pack_size_bucket,
    age_bracket,
    gender,
    category,
    COUNT(*) as txn_count,
    SUM(transaction_value) as total_sales,
    AVG(pack_size_value) as avg_pack_size
FROM dbo.v_insight_cross_tabs
WHERE pack_size_bucket != 'Unknown'
GROUP BY pack_size_bucket, age_bracket, gender, category;

-- ================================================================
-- EXPORT VIEWS FOR EXCEL
-- ================================================================

-- Export: All cross-tab data for Excel
CREATE OR ALTER VIEW dbo.v_excel_cross_tabs_export AS
SELECT
    'Cross Tab Data' as sheet_name,
    *
FROM dbo.v_insight_cross_tabs;

-- Export: Summary by Nielsen Department
CREATE OR ALTER VIEW dbo.v_excel_nielsen_summary AS
SELECT
    'Nielsen Summary' as sheet_name,
    nielsen_department,
    category,
    COUNT(*) as transactions,
    COUNT(DISTINCT purchased_brand) as brands,
    SUM(transaction_value) as revenue,
    AVG(transaction_value) as avg_transaction,
    COUNT(DISTINCT store_id) as stores,
    COUNT(DISTINCT CONCAT(age_bracket, gender)) as demographic_segments
FROM dbo.v_insight_cross_tabs
GROUP BY nielsen_department, category
ORDER BY revenue DESC;

-- Export: Customer Segmentation Analysis
CREATE OR ALTER VIEW dbo.v_excel_customer_segments AS
SELECT
    'Customer Segments' as sheet_name,
    age_bracket,
    gender,
    customer_type,
    COUNT(*) as transactions,
    COUNT(DISTINCT purchased_brand) as brands_purchased,
    SUM(transaction_value) as total_spent,
    AVG(transaction_value) as avg_transaction,
    AVG(basket_size) as avg_basket_size,
    COUNT(DISTINCT category) as categories_shopped
FROM dbo.v_insight_cross_tabs
GROUP BY age_bracket, gender, customer_type
ORDER BY total_spent DESC;

-- ================================================================
-- VALIDATION QUERIES
-- ================================================================

-- Validate data completeness
SELECT
    'Data Completeness Check' as validation_type,
    COUNT(*) as total_records,
    COUNT(CASE WHEN age_bracket IS NOT NULL THEN 1 END) as has_age_bracket,
    COUNT(CASE WHEN gender IS NOT NULL THEN 1 END) as has_gender,
    COUNT(CASE WHEN pack_size_bucket != 'Unknown' THEN 1 END) as has_pack_size,
    COUNT(CASE WHEN payment_method != 'Other' THEN 1 END) as has_payment_method,
    CAST(COUNT(CASE WHEN age_bracket IS NOT NULL THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,1)) as age_completeness_pct,
    CAST(COUNT(CASE WHEN pack_size_bucket != 'Unknown' THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,1)) as packsize_completeness_pct
FROM dbo.v_insight_cross_tabs;

PRINT 'Enhanced Cross-Tabulation View Created Successfully!';
PRINT 'Available Views:';
PRINT '- v_insight_cross_tabs (main comprehensive view)';
PRINT '- ct_time_category_enhanced (time × category cross-tabs)';
PRINT '- ct_demographics_brand_enhanced (demographics × brand cross-tabs)';
PRINT '- ct_basket_category_payment (basket × category × payment cross-tabs)';
PRINT '- ct_substitution_analysis (substitution behavior analysis)';
PRINT '- ct_packsize_demographics (pack size × demographics cross-tabs)';
PRINT '- v_excel_* views for Excel export';
PRINT '';
PRINT 'Reference Tables Created:';
PRINT '- ref_pack_size_rules (pack size bucketing rules)';
PRINT '- ref_payment_method_map (payment method normalization)';
PRINT '';
PRINT 'Ready for comprehensive cross-tabulation analytics!';