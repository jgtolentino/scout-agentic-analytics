-- ========================================================================
-- Scout Platform Business Intelligence Views
-- Supports all required analytics: Demographics, Store Profiles, Category Analysis
-- ========================================================================

-- ==========================
-- 1. ENHANCED TRANSACTION INTELLIGENCE VIEW
-- ==========================

-- Master view combining all dimensions: WHO, WHAT, WHERE, WHEN, HOW
CREATE VIEW gold.v_scout_transaction_intelligence AS
WITH TransactionEnhanced AS (
    SELECT
        -- Transaction Identifiers
        ti.transaction_id,
        si.interaction_id,

        -- WHO: Customer Demographics (from Vision Analysis)
        si.customer_age,
        si.customer_gender,
        CASE
            WHEN si.customer_age < 18 THEN 'Teen'
            WHEN si.customer_age BETWEEN 18 AND 24 THEN 'Young Adult'
            WHEN si.customer_age BETWEEN 25 AND 34 THEN 'Millennial'
            WHEN si.customer_age BETWEEN 35 AND 44 THEN 'Gen X'
            WHEN si.customer_age BETWEEN 45 AND 54 THEN 'Boomer'
            WHEN si.customer_age >= 55 THEN 'Senior'
            ELSE 'Unknown'
        END as customer_segment,

        -- WHAT: Product Details
        ti.product_name,
        ti.brand_name,
        ti.generic_name,
        ti.local_name,
        ti.category,
        ti.subcategory,
        ti.sku,
        ti.quantity,
        ti.unit,
        ti.unit_price,
        ti.total_price as peso_value,

        -- HOW: Purchase Context
        si.payment_method,
        ti.detection_method,
        ti.brand_confidence,
        ti.is_substitution,
        ti.substitution_reason,

        -- WHERE: Location Context
        s.store_id,
        s.store_name,
        s.store_type,
        s.barangay,
        s.city,
        s.province,
        s.region,
        s.latitude,
        s.longitude,

        -- WHEN: Time Context
        si.interaction_timestamp,
        DATEPART(YEAR, si.interaction_timestamp) as year,
        DATEPART(MONTH, si.interaction_timestamp) as month,
        DATEPART(DAY, si.interaction_timestamp) as day_of_month,
        DATENAME(WEEKDAY, si.interaction_timestamp) as day_of_week,
        DATEPART(HOUR, si.interaction_timestamp) as hour_of_day,
        CASE
            WHEN DATEPART(HOUR, si.interaction_timestamp) BETWEEN 6 AND 11 THEN 'Morning'
            WHEN DATEPART(HOUR, si.interaction_timestamp) BETWEEN 12 AND 17 THEN 'Afternoon'
            WHEN DATEPART(HOUR, si.interaction_timestamp) BETWEEN 18 AND 23 THEN 'Evening'
            ELSE 'Night'
        END as day_part,
        CASE WHEN DATEPART(WEEKDAY, si.interaction_timestamp) IN (1,7) THEN 1 ELSE 0 END as is_weekend,

        -- Pecha de Peligro Analysis
        CASE
            WHEN DATEPART(DAY, si.interaction_timestamp) BETWEEN 13 AND 17 THEN 1
            WHEN DATEPART(DAY, si.interaction_timestamp) BETWEEN 28 AND 31 THEN 1
            ELSE 0
        END as is_payday_period,

        CASE
            WHEN DATEPART(DAY, si.interaction_timestamp) BETWEEN 1 AND 5 THEN 'Post-Payday'
            WHEN DATEPART(DAY, si.interaction_timestamp) BETWEEN 13 AND 17 THEN 'Mid-Month Payday'
            WHEN DATEPART(DAY, si.interaction_timestamp) BETWEEN 28 AND 31 THEN 'Month-End Payday'
            WHEN DATEPART(DAY, si.interaction_timestamp) BETWEEN 6 AND 12 THEN 'Pre-Mid-Month'
            ELSE 'Pre-Month-End'
        END as salary_period

    FROM dbo.SalesInteractions si
    INNER JOIN dbo.TransactionItems ti ON si.interaction_id = ti.interaction_id
    INNER JOIN dbo.Stores s ON si.store_id = s.store_id
);

-- ==========================
-- 2. STORE DEMOGRAPHICS & PROFILES
-- ==========================

CREATE VIEW v_store_demographic_profiles AS
SELECT
    s.store_id,
    s.store_name,
    s.store_type,
    s.barangay,
    s.city,
    s.province,
    s.region,

    -- Customer Demographics
    COUNT(DISTINCT t.interaction_id) as unique_customers,
    AVG(CAST(t.customer_age AS FLOAT)) as avg_customer_age,
    SUM(CASE WHEN t.customer_gender = 'M' THEN 1 ELSE 0 END) * 100.0 /
        NULLIF(COUNT(*), 0) as male_percentage,
    SUM(CASE WHEN t.customer_gender = 'F' THEN 1 ELSE 0 END) * 100.0 /
        NULLIF(COUNT(*), 0) as female_percentage,

    -- Age Distribution
    SUM(CASE WHEN t.customer_age < 25 THEN 1 ELSE 0 END) * 100.0 /
        NULLIF(COUNT(*), 0) as young_adult_percentage,
    SUM(CASE WHEN t.customer_age BETWEEN 25 AND 44 THEN 1 ELSE 0 END) * 100.0 /
        NULLIF(COUNT(*), 0) as adult_percentage,
    SUM(CASE WHEN t.customer_age >= 45 THEN 1 ELSE 0 END) * 100.0 /
        NULLIF(COUNT(*), 0) as senior_percentage,

    -- Purchase Profile
    COUNT(*) as total_transactions,
    SUM(t.peso_value) as total_revenue,
    AVG(t.peso_value) as avg_transaction_value,
    COUNT(DISTINCT t.brand_name) as unique_brands,
    COUNT(DISTINCT t.category) as unique_categories,

    -- Payment Methods
    SUM(CASE WHEN t.payment_method = 'cash' THEN 1 ELSE 0 END) * 100.0 /
        NULLIF(COUNT(*), 0) as cash_percentage,
    SUM(CASE WHEN t.payment_method = 'gcash' THEN 1 ELSE 0 END) * 100.0 /
        NULLIF(COUNT(*), 0) as gcash_percentage,
    SUM(CASE WHEN t.payment_method = 'maya' THEN 1 ELSE 0 END) * 100.0 /
        NULLIF(COUNT(*), 0) as maya_percentage,

    -- Activity Patterns
    COUNT(DISTINCT CAST(t.interaction_timestamp AS DATE)) as active_days,
    MIN(t.interaction_timestamp) as first_transaction,
    MAX(t.interaction_timestamp) as last_transaction

FROM dbo.Stores s
LEFT JOIN gold.v_scout_transaction_intelligence t ON s.store_id = t.store_id
GROUP BY s.store_id, s.store_name, s.store_type, s.barangay, s.city, s.province, s.region;

-- ==========================
-- 3. TOBACCO CATEGORY ANALYTICS
-- ==========================

CREATE VIEW v_tobacco_demographics_analytics AS
SELECT
    -- Demographics
    customer_gender,
    CASE
        WHEN customer_age < 25 THEN '18-24'
        WHEN customer_age BETWEEN 25 AND 34 THEN '25-34'
        WHEN customer_age BETWEEN 35 AND 44 THEN '35-44'
        WHEN customer_age >= 45 THEN '45+'
        ELSE 'Unknown'
    END as age_group,

    -- Brand Analysis
    brand_name,

    -- Purchase Metrics
    COUNT(*) as purchase_count,
    SUM(peso_value) as total_spent,
    AVG(peso_value) as avg_purchase_value,
    SUM(quantity) as total_sticks_purchased,
    AVG(quantity) as avg_sticks_per_purchase,

    -- Timing Patterns
    AVG(CASE WHEN is_payday_period = 1 THEN peso_value END) as avg_payday_spend,
    AVG(CASE WHEN is_payday_period = 0 THEN peso_value END) as avg_regular_spend,

    -- Day Parting
    SUM(CASE WHEN day_part = 'Morning' THEN 1 ELSE 0 END) as morning_purchases,
    SUM(CASE WHEN day_part = 'Afternoon' THEN 1 ELSE 0 END) as afternoon_purchases,
    SUM(CASE WHEN day_part = 'Evening' THEN 1 ELSE 0 END) as evening_purchases,

    -- Weekly Patterns
    SUM(CASE WHEN is_weekend = 1 THEN 1 ELSE 0 END) as weekend_purchases,
    SUM(CASE WHEN is_weekend = 0 THEN 1 ELSE 0 END) as weekday_purchases,

    -- Store Distribution
    COUNT(DISTINCT store_id) as stores_purchased_from,
    COUNT(DISTINCT city) as cities_purchased_in

FROM gold.v_scout_transaction_intelligence
WHERE category IN ('Tobacco', 'Cigarettes', 'Smoking')
GROUP BY customer_gender, age_group, brand_name;

-- Tobacco purchase frequency and patterns
CREATE VIEW v_tobacco_purchase_patterns AS
WITH TobaccoCustomers AS (
    SELECT
        interaction_id,
        customer_age,
        customer_gender,
        COUNT(*) as tobacco_purchases,
        SUM(quantity) as total_sticks,
        AVG(quantity) as avg_sticks_per_visit,
        SUM(peso_value) as total_tobacco_spend,
        MIN(interaction_timestamp) as first_tobacco_purchase,
        MAX(interaction_timestamp) as last_tobacco_purchase,
        COUNT(DISTINCT CAST(interaction_timestamp AS DATE)) as days_purchased_tobacco
    FROM gold.v_scout_transaction_intelligence
    WHERE category IN ('Tobacco', 'Cigarettes')
    GROUP BY interaction_id, customer_age, customer_gender
)
SELECT
    customer_gender,
    CASE
        WHEN customer_age < 25 THEN '18-24'
        WHEN customer_age BETWEEN 25 AND 34 THEN '25-34'
        WHEN customer_age BETWEEN 35 AND 44 THEN '35-44'
        ELSE '45+'
    END as age_group,

    COUNT(*) as customer_count,
    AVG(tobacco_purchases) as avg_purchases_per_customer,
    AVG(total_sticks) as avg_sticks_per_customer,
    AVG(avg_sticks_per_visit) as avg_sticks_per_visit,
    AVG(total_tobacco_spend) as avg_spend_per_customer,
    AVG(days_purchased_tobacco) as avg_purchase_days,

    -- Purchase frequency categories
    SUM(CASE WHEN tobacco_purchases >= 10 THEN 1 ELSE 0 END) as heavy_buyers,
    SUM(CASE WHEN tobacco_purchases BETWEEN 5 AND 9 THEN 1 ELSE 0 END) as regular_buyers,
    SUM(CASE WHEN tobacco_purchases < 5 THEN 1 ELSE 0 END) as light_buyers

FROM TobaccoCustomers
GROUP BY customer_gender, age_group;

-- ==========================
-- 4. LAUNDRY SOAP ANALYTICS
-- ==========================

CREATE VIEW v_laundry_demographics_analytics AS
SELECT
    -- Demographics
    customer_gender,
    CASE
        WHEN customer_age < 25 THEN '18-24'
        WHEN customer_age BETWEEN 25 AND 34 THEN '25-34'
        WHEN customer_age BETWEEN 35 AND 44 THEN '35-44'
        WHEN customer_age >= 45 THEN '45+'
        ELSE 'Unknown'
    END as age_group,

    -- Brand Analysis
    brand_name,

    -- Product Type Analysis
    CASE
        WHEN product_name LIKE '%bar%' OR local_name LIKE '%baro%' THEN 'Bar Soap'
        WHEN product_name LIKE '%powder%' OR product_name LIKE '%pulbos%' THEN 'Powder'
        WHEN product_name LIKE '%liquid%' THEN 'Liquid'
        WHEN product_name LIKE '%fabric%' OR product_name LIKE '%fabcon%' THEN 'Fabric Softener'
        ELSE 'Other'
    END as product_type,

    -- Purchase Metrics
    COUNT(*) as purchase_count,
    SUM(peso_value) as total_spent,
    AVG(peso_value) as avg_purchase_value,

    -- Timing Patterns
    AVG(CASE WHEN is_payday_period = 1 THEN peso_value END) as avg_payday_spend,
    AVG(CASE WHEN is_payday_period = 0 THEN peso_value END) as avg_regular_spend,

    -- Day Parting
    SUM(CASE WHEN day_part = 'Morning' THEN 1 ELSE 0 END) as morning_purchases,
    SUM(CASE WHEN day_part = 'Afternoon' THEN 1 ELSE 0 END) as afternoon_purchases,
    SUM(CASE WHEN day_part = 'Evening' THEN 1 ELSE 0 END) as evening_purchases

FROM gold.v_scout_transaction_intelligence
WHERE category IN ('Laundry', 'Detergent', 'Home Care', 'Cleaning')
GROUP BY customer_gender, age_group, brand_name, product_type;

-- Laundry co-purchase analysis (Detergent + Fabric Softener)
CREATE VIEW v_laundry_basket_analysis AS
WITH LaundryBaskets AS (
    SELECT
        transaction_id,
        interaction_id,
        customer_age,
        customer_gender,
        store_type,
        -- Product flags
        MAX(CASE WHEN product_name LIKE '%detergent%' OR local_name LIKE '%sabon%' THEN 1 ELSE 0 END) as has_detergent,
        MAX(CASE WHEN product_name LIKE '%bar%' OR local_name LIKE '%baro%' THEN 1 ELSE 0 END) as has_bar_soap,
        MAX(CASE WHEN product_name LIKE '%fabric%' OR product_name LIKE '%fabcon%' OR product_name LIKE '%downy%' THEN 1 ELSE 0 END) as has_fabric_softener,
        MAX(CASE WHEN product_name LIKE '%bleach%' THEN 1 ELSE 0 END) as has_bleach,
        -- Totals
        COUNT(*) as laundry_items,
        SUM(peso_value) as total_laundry_spend
    FROM gold.v_scout_transaction_intelligence
    WHERE category IN ('Laundry', 'Detergent', 'Home Care', 'Cleaning')
    GROUP BY transaction_id, interaction_id, customer_age, customer_gender, store_type
)
SELECT
    customer_gender,
    CASE
        WHEN customer_age < 35 THEN 'Young Adults'
        ELSE 'Mature Adults'
    END as age_segment,
    store_type,

    COUNT(*) as total_laundry_transactions,

    -- Co-purchase patterns
    SUM(CASE WHEN has_detergent = 1 AND has_fabric_softener = 1 THEN 1 ELSE 0 END) as detergent_with_fabcon,
    SUM(CASE WHEN has_bar_soap = 1 AND has_fabric_softener = 1 THEN 1 ELSE 0 END) as bar_with_fabcon,
    SUM(CASE WHEN has_detergent = 1 AND has_bar_soap = 1 THEN 1 ELSE 0 END) as detergent_with_bar,
    SUM(CASE WHEN has_detergent = 1 AND has_bar_soap = 1 AND has_fabric_softener = 1 THEN 1 ELSE 0 END) as complete_laundry_bundle,

    -- Purchase patterns percentages
    SUM(CASE WHEN has_detergent = 1 AND has_fabric_softener = 1 THEN 1 ELSE 0 END) * 100.0 /
        NULLIF(SUM(has_detergent), 0) as detergent_fabcon_rate,
    SUM(CASE WHEN has_bar_soap = 1 AND has_fabric_softener = 1 THEN 1 ELSE 0 END) * 100.0 /
        NULLIF(SUM(has_bar_soap), 0) as bar_fabcon_rate,

    AVG(total_laundry_spend) as avg_basket_value

FROM LaundryBaskets
GROUP BY customer_gender, age_segment, store_type;

-- ==========================
-- 5. SALES SPREAD ANALYTICS
-- ==========================

-- Weekly and monthly sales distribution
CREATE VIEW v_sales_spread_analytics AS
SELECT
    year,
    month,
    DATEPART(WEEK, interaction_timestamp) as week_of_year,
    day_of_week,
    day_part,
    hour_of_day,
    category,

    -- Sales Metrics
    COUNT(*) as transaction_count,
    COUNT(DISTINCT interaction_id) as customer_count,
    SUM(peso_value) as total_sales,
    AVG(peso_value) as avg_transaction_value,

    -- Category Distribution
    COUNT(DISTINCT brand_name) as unique_brands,

    -- Geographic Distribution
    COUNT(DISTINCT store_id) as active_stores,
    COUNT(DISTINCT city) as active_cities

FROM gold.v_scout_transaction_intelligence
GROUP BY year, month, week_of_year, day_of_week, day_part, hour_of_day, category;

-- Pecha de peligro impact analysis
CREATE VIEW v_pecha_de_peligro_analysis AS
SELECT
    salary_period,
    category,
    customer_segment,

    COUNT(*) as transaction_count,
    SUM(peso_value) as total_sales,
    AVG(peso_value) as avg_transaction_value,

    -- Compare to regular periods
    AVG(CASE WHEN is_payday_period = 1 THEN peso_value END) as avg_payday_transaction,
    AVG(CASE WHEN is_payday_period = 0 THEN peso_value END) as avg_regular_transaction,

    -- Payment method preferences during different periods
    SUM(CASE WHEN payment_method = 'cash' THEN peso_value END) as cash_sales,
    SUM(CASE WHEN payment_method = 'gcash' THEN peso_value END) as gcash_sales

FROM gold.v_scout_transaction_intelligence
GROUP BY salary_period, category, customer_segment;

PRINT 'Business Intelligence views created successfully!';
PRINT 'Views: v_scout_transaction_intelligence, v_store_demographic_profiles, v_tobacco_demographics_analytics, v_tobacco_purchase_patterns, v_laundry_demographics_analytics, v_laundry_basket_analysis, v_sales_spread_analytics, v_pecha_de_peligro_analysis';