-- Laundry Soap Analytics
-- Comprehensive laundry category analysis with detergent types and fabric conditioner analysis
-- Created: 2025-09-26

-- =====================================================
-- SECTION 1: LAUNDRY DEMOGRAPHICS ANALYSIS
-- =====================================================

WITH laundry_demographics AS (
    SELECT
        -- Demographics
        t.demographics_gender AS gender,
        CASE
            WHEN TRY_CAST(t.demographics_age AS INT) BETWEEN 18 AND 25 THEN '18-25'
            WHEN TRY_CAST(t.demographics_age AS INT) BETWEEN 26 AND 35 THEN '26-35'
            WHEN TRY_CAST(t.demographics_age AS INT) BETWEEN 36 AND 45 THEN '36-45'
            WHEN TRY_CAST(t.demographics_age AS INT) BETWEEN 46 AND 60 THEN '46-60'
            WHEN TRY_CAST(t.demographics_age AS INT) > 60 THEN '60+'
            ELSE 'Unknown'
        END AS age_band,
        t.brand,

        -- Location
        s.region,
        s.store_name,

        -- Product type detection from brand/product names
        CASE
            WHEN t.brand LIKE '%bar%' OR t.brand LIKE '%Bar%' OR
                 t.product_name LIKE '%bar%' OR t.product_name LIKE '%Bar%' THEN 'Bar'
            WHEN t.brand LIKE '%powder%' OR t.brand LIKE '%Powder%' OR
                 t.product_name LIKE '%powder%' OR t.product_name LIKE '%Powder%' THEN 'Powder'
            WHEN t.brand LIKE '%liquid%' OR t.brand LIKE '%Liquid%' OR
                 t.product_name LIKE '%liquid%' OR t.product_name LIKE '%Liquid%' THEN 'Liquid'
            WHEN t.brand LIKE '%sachet%' OR t.brand LIKE '%Sachet%' OR
                 t.product_name LIKE '%sachet%' OR t.product_name LIKE '%Sachet%' THEN 'Sachet'
            ELSE 'Unknown Type'
        END AS detergent_type,

        -- Metrics
        COUNT(DISTINCT t.transaction_id) AS transactions,
        SUM(t.quantity) AS total_items,
        CAST(AVG(t.quantity) AS DECIMAL(8,2)) AS avg_items_per_visit,
        SUM(t.transaction_value) AS total_value,
        CAST(AVG(t.transaction_value) AS DECIMAL(10,2)) AS avg_transaction_value,

        -- Brand confidence from AI detection
        CAST(AVG(CAST(t.brand_confidence AS FLOAT)) AS DECIMAL(5,3)) AS avg_brand_confidence

    FROM canonical.v_transactions_flat_enhanced t
        LEFT JOIN dim.stores s ON t.store_id = s.store_id
    WHERE t.category IN ('Laundry', 'Household & Cleaning Supplies')
        AND (t.brand LIKE '%detergent%' OR t.brand LIKE '%soap%' OR t.brand LIKE '%wash%' OR
             t.brand IN ('Tide', 'Ariel', 'Surf', 'Breeze', 'Pride', 'Champion'))
        AND t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
    GROUP BY t.demographics_gender, age_band, t.brand, s.region, s.store_name, detergent_type
),

-- =====================================================
-- SECTION 2: LAUNDRY PURCHASE PATTERNS
-- =====================================================

laundry_purchase_patterns AS (
    SELECT
        t.brand,

        -- Product type
        CASE
            WHEN t.brand LIKE '%bar%' OR t.brand LIKE '%Bar%' OR
                 t.product_name LIKE '%bar%' OR t.product_name LIKE '%Bar%' THEN 'Bar'
            WHEN t.brand LIKE '%powder%' OR t.brand LIKE '%Powder%' OR
                 t.product_name LIKE '%powder%' OR t.product_name LIKE '%Powder%' THEN 'Powder'
            WHEN t.brand LIKE '%liquid%' OR t.brand LIKE '%Liquid%' OR
                 t.product_name LIKE '%liquid%' OR t.product_name LIKE '%Liquid%' THEN 'Liquid'
            WHEN t.brand LIKE '%sachet%' OR t.brand LIKE '%Sachet%' OR
                 t.product_name LIKE '%sachet%' OR t.product_name LIKE '%Sachet%' THEN 'Sachet'
            ELSE 'Unknown Type'
        END AS detergent_type,

        -- Time patterns
        DATEPART(HOUR, t.transaction_datetime) AS hour_of_day,
        CASE
            WHEN DATEPART(HOUR, t.transaction_datetime) BETWEEN 6 AND 11 THEN 'Morning'
            WHEN DATEPART(HOUR, t.transaction_datetime) BETWEEN 12 AND 17 THEN 'Afternoon'
            WHEN DATEPART(HOUR, t.transaction_datetime) BETWEEN 18 AND 23 THEN 'Evening'
            ELSE 'Night'
        END AS daypart,

        DATENAME(WEEKDAY, t.transaction_date) AS day_of_week,
        DATEPART(WEEKDAY, t.transaction_date) AS day_of_week_num,

        -- Pecha de peligro analysis (salary period impact)
        CASE
            WHEN DAY(t.transaction_date) BETWEEN 23 AND 30 THEN 'Pecha de Peligro (23-30)'
            WHEN DAY(t.transaction_date) BETWEEN 1 AND 7 THEN 'Start of Month (1-7)'
            WHEN DAY(t.transaction_date) BETWEEN 8 AND 15 THEN 'Mid Month Early (8-15)'
            ELSE 'Mid Month Late (16-22)'
        END AS salary_period,

        -- Month patterns
        MONTH(t.transaction_date) AS month_number,
        DATENAME(MONTH, t.transaction_date) AS month_name,

        -- Demographics
        t.demographics_gender,
        t.demographics_age,

        -- Metrics
        COUNT(DISTINCT t.transaction_id) AS transactions,
        SUM(t.quantity) AS total_items,
        CAST(AVG(t.quantity) AS DECIMAL(8,2)) AS avg_items_per_transaction,
        SUM(t.transaction_value) AS total_revenue,
        CAST(AVG(t.transaction_value) AS DECIMAL(10,2)) AS avg_revenue_per_transaction

    FROM canonical.v_transactions_flat_enhanced t
    WHERE t.category IN ('Laundry', 'Household & Cleaning Supplies')
        AND (t.brand LIKE '%detergent%' OR t.brand LIKE '%soap%' OR t.brand LIKE '%wash%' OR
             t.brand IN ('Tide', 'Ariel', 'Surf', 'Breeze', 'Pride', 'Champion'))
        AND t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
    GROUP BY t.brand, detergent_type, hour_of_day, daypart, day_of_week, day_of_week_num,
             salary_period, month_number, month_name, t.demographics_gender, t.demographics_age
),

-- =====================================================
-- SECTION 3: FABRIC CONDITIONER CO-PURCHASE ANALYSIS
-- =====================================================

fabcon_copurchase_analysis AS (
    SELECT
        detergent.transaction_id,
        detergent.brand AS detergent_brand,
        detergent.detergent_type,
        detergent.demographics_gender,
        detergent.demographics_age,

        -- Check for fabric conditioner in same transaction
        MAX(CASE WHEN fabcon.brand IS NOT NULL THEN 1 ELSE 0 END) AS has_fabcon,
        STRING_AGG(fabcon.brand, ', ') AS fabcon_brands,
        COUNT(fabcon.transaction_id) AS fabcon_items_count,
        SUM(fabcon.transaction_value) AS fabcon_total_value

    FROM (
        SELECT
            t.transaction_id,
            t.brand,
            t.demographics_gender,
            t.demographics_age,
            t.transaction_value,
            CASE
                WHEN t.brand LIKE '%bar%' OR t.brand LIKE '%Bar%' OR
                     t.product_name LIKE '%bar%' OR t.product_name LIKE '%Bar%' THEN 'Bar'
                WHEN t.brand LIKE '%powder%' OR t.brand LIKE '%Powder%' OR
                     t.product_name LIKE '%powder%' OR t.product_name LIKE '%Powder%' THEN 'Powder'
                WHEN t.brand LIKE '%liquid%' OR t.brand LIKE '%Liquid%' OR
                     t.product_name LIKE '%liquid%' OR t.product_name LIKE '%Liquid%' THEN 'Liquid'
                WHEN t.brand LIKE '%sachet%' OR t.brand LIKE '%Sachet%' OR
                     t.product_name LIKE '%sachet%' OR t.product_name LIKE '%Sachet%' THEN 'Sachet'
                ELSE 'Unknown Type'
            END AS detergent_type
        FROM canonical.v_transactions_flat_enhanced t
        WHERE t.category IN ('Laundry', 'Household & Cleaning Supplies')
            AND (t.brand LIKE '%detergent%' OR t.brand LIKE '%soap%' OR t.brand LIKE '%wash%' OR
                 t.brand IN ('Tide', 'Ariel', 'Surf', 'Breeze', 'Pride', 'Champion'))
            AND t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
    ) detergent

    LEFT JOIN (
        SELECT
            t.transaction_id,
            t.brand,
            t.transaction_value
        FROM canonical.v_transactions_flat_enhanced t
        WHERE (t.brand LIKE '%Downy%' OR t.brand LIKE '%Fabcon%' OR t.brand LIKE '%fabric%' OR
               t.brand LIKE '%conditioner%' OR t.brand LIKE '%softener%' OR
               t.product_name LIKE '%conditioner%' OR t.product_name LIKE '%softener%')
            AND t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
    ) fabcon ON detergent.transaction_id = fabcon.transaction_id

    GROUP BY detergent.transaction_id, detergent.brand, detergent.detergent_type,
             detergent.demographics_gender, detergent.demographics_age
),

-- =====================================================
-- SECTION 4: LAUNDRY CO-PURCHASE CATEGORIES
-- =====================================================

laundry_copurchase_categories AS (
    SELECT
        t1.brand AS laundry_brand,
        t1.detergent_type,
        t2.category AS copurchase_category,
        t2.brand AS copurchase_brand,

        COUNT(DISTINCT t1.transaction_id) AS co_occurrence_count,
        COUNT(DISTINCT t1.canonical_tx_id) AS unique_customers,

        -- Calculate support and lift
        CAST(COUNT(DISTINCT t1.transaction_id) AS FLOAT) /
            (SELECT COUNT(DISTINCT transaction_id) FROM canonical.v_transactions_flat_enhanced
             WHERE category IN ('Laundry', 'Household & Cleaning Supplies')
               AND transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')) AS laundry_support,

        CAST(COUNT(DISTINCT t1.transaction_id) AS FLOAT) /
            (SELECT COUNT(DISTINCT transaction_id) FROM canonical.v_transactions_flat_enhanced
             WHERE category = t2.category
               AND transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')) AS copurchase_support

    FROM (
        SELECT
            t.transaction_id,
            t.canonical_tx_id,
            t.brand,
            CASE
                WHEN t.brand LIKE '%bar%' OR t.brand LIKE '%Bar%' OR
                     t.product_name LIKE '%bar%' OR t.product_name LIKE '%Bar%' THEN 'Bar'
                WHEN t.brand LIKE '%powder%' OR t.brand LIKE '%Powder%' OR
                     t.product_name LIKE '%powder%' OR t.product_name LIKE '%Powder%' THEN 'Powder'
                WHEN t.brand LIKE '%liquid%' OR t.brand LIKE '%Liquid%' OR
                     t.product_name LIKE '%liquid%' OR t.product_name LIKE '%Liquid%' THEN 'Liquid'
                WHEN t.brand LIKE '%sachet%' OR t.brand LIKE '%Sachet%' OR
                     t.product_name LIKE '%sachet%' OR t.product_name LIKE '%Sachet%' THEN 'Sachet'
                ELSE 'Unknown Type'
            END AS detergent_type
        FROM canonical.v_transactions_flat_enhanced t
        WHERE t.category IN ('Laundry', 'Household & Cleaning Supplies')
            AND (t.brand LIKE '%detergent%' OR t.brand LIKE '%soap%' OR t.brand LIKE '%wash%' OR
                 t.brand IN ('Tide', 'Ariel', 'Surf', 'Breeze', 'Pride', 'Champion'))
            AND t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
    ) t1

    INNER JOIN canonical.v_transactions_flat_enhanced t2
        ON t1.transaction_id = t2.transaction_id
        AND t2.category NOT IN ('Laundry', 'Household & Cleaning Supplies')

    GROUP BY t1.brand, t1.detergent_type, t2.category, t2.brand
),

-- =====================================================
-- SECTION 5: LAUNDRY FREQUENT TERMS
-- =====================================================

laundry_frequent_terms AS (
    SELECT
        value AS term,
        COUNT(*) AS frequency,
        STRING_AGG(DISTINCT t.brand, ', ') AS associated_brands,
        STRING_AGG(DISTINCT t.demographics_gender, ', ') AS user_genders,

        -- Product type association
        STRING_AGG(DISTINCT
            CASE
                WHEN t.brand LIKE '%bar%' OR t.brand LIKE '%Bar%' OR
                     t.product_name LIKE '%bar%' OR t.product_name LIKE '%Bar%' THEN 'Bar'
                WHEN t.brand LIKE '%powder%' OR t.brand LIKE '%Powder%' OR
                     t.product_name LIKE '%powder%' OR t.product_name LIKE '%Powder%' THEN 'Powder'
                WHEN t.brand LIKE '%liquid%' OR t.brand LIKE '%Liquid%' OR
                     t.product_name LIKE '%liquid%' OR t.product_name LIKE '%Liquid%' THEN 'Liquid'
                ELSE 'Unknown'
            END, ', ') AS associated_types,

        -- Calculate term confidence
        CAST(AVG(CAST(t.brand_confidence AS FLOAT)) AS DECIMAL(5,3)) AS avg_term_confidence

    FROM canonical.v_transactions_flat_enhanced t
        CROSS APPLY STRING_SPLIT(LOWER(COALESCE(t.transaction_context, '')), ' ')
    WHERE t.category IN ('Laundry', 'Household & Cleaning Supplies')
        AND (t.brand LIKE '%detergent%' OR t.brand LIKE '%soap%' OR t.brand LIKE '%wash%' OR
             t.brand IN ('Tide', 'Ariel', 'Surf', 'Breeze', 'Pride', 'Champion'))
        AND t.transaction_date BETWEEN ISNULL(@date_from, '2025-06-28') AND ISNULL(@date_to, '2025-09-26')
        AND LEN(value) > 2
        AND value NOT IN (
            'the', 'and', 'for', 'with', 'this', 'that', 'from', 'have', 'been',
            'they', 'were', 'said', 'each', 'what', 'will', 'when', 'your', 'how',
            'mga', 'ang', 'ng', 'sa', 'na', 'at', 'ay', 'ni', 'ka', 'pa', 'po'
        )
        AND value IS NOT NULL
        AND value != ''
    GROUP BY value
    HAVING COUNT(*) >= 3
)

-- =====================================================
-- SECTION 6: EXPORT QUERIES
-- =====================================================

-- Export 1: Laundry Demographics
SELECT
    'Laundry Demographics' AS export_type,
    gender,
    age_band,
    brand,
    detergent_type,
    region,
    transactions,
    total_items,
    avg_items_per_visit,
    CAST(total_value AS DECIMAL(18,2)) AS total_value,
    avg_transaction_value,
    avg_brand_confidence,
    CAST(transactions * 100.0 / SUM(transactions) OVER(PARTITION BY gender, age_band) AS DECIMAL(5,2)) AS brand_share_within_demographic
FROM laundry_demographics
ORDER BY gender, age_band, transactions DESC;

-- Export 2: Purchase Profile (Day, Time, Pecha de Peligro)
SELECT
    'Laundry Purchase Profiles' AS export_type,
    brand,
    detergent_type,
    hour_of_day,
    daypart,
    day_of_week,
    salary_period,
    month_name,
    demographics_gender,
    transactions,
    total_items,
    avg_items_per_transaction,
    CAST(total_revenue AS DECIMAL(18,2)) AS total_revenue,
    avg_revenue_per_transaction,

    -- Calculate percentage within each period type
    CAST(transactions * 100.0 / SUM(transactions) OVER(PARTITION BY salary_period) AS DECIMAL(5,2)) AS pct_within_salary_period,
    CAST(transactions * 100.0 / SUM(transactions) OVER(PARTITION BY daypart) AS DECIMAL(5,2)) AS pct_within_daypart

FROM laundry_purchase_patterns
ORDER BY brand, hour_of_day;

-- Export 3: Sales × Days × Day Parting
SELECT
    'Laundry Sales Daypart Analysis' AS export_type,
    brand,
    detergent_type,
    day_of_week,
    daypart,
    hour_of_day,
    COUNT(DISTINCT month_name) AS months_with_sales,
    SUM(transactions) AS total_transactions,
    SUM(total_items) AS total_items_sold,
    CAST(SUM(total_revenue) AS DECIMAL(18,2)) AS total_revenue,
    CAST(AVG(avg_items_per_transaction) AS DECIMAL(8,2)) AS overall_avg_items
FROM laundry_purchase_patterns
GROUP BY brand, detergent_type, day_of_week, daypart, hour_of_day, day_of_week_num
ORDER BY brand, day_of_week_num, hour_of_day;

-- Export 4: Detergent Type Analysis (Bar vs Powder)
SELECT
    'Detergent Types Analysis' AS export_type,
    detergent_type,
    gender,
    age_band,
    COUNT(DISTINCT transaction_id) AS transactions,
    COUNT(DISTINCT detergent_brand) AS brands_available,
    STRING_AGG(detergent_brand, ', ') AS popular_brands,
    CAST(AVG(CASE WHEN has_fabcon = 1 THEN 1.0 ELSE 0.0 END) * 100 AS DECIMAL(5,2)) AS fabcon_attachment_rate,
    CAST(COUNT(DISTINCT transaction_id) * 100.0 / SUM(COUNT(DISTINCT transaction_id)) OVER() AS DECIMAL(5,2)) AS type_market_share
FROM fabcon_copurchase_analysis
GROUP BY detergent_type, gender, age_band
ORDER BY transactions DESC;

-- Export 5: Fabric Conditioner Co-Purchase
SELECT
    'Fabcon Co-Purchase Analysis' AS export_type,
    detergent_brand,
    detergent_type,
    demographics_gender,
    demographics_age,
    COUNT(*) AS detergent_purchases,
    SUM(has_fabcon) AS purchases_with_fabcon,
    CAST(SUM(has_fabcon) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS fabcon_attachment_rate,
    STRING_AGG(fabcon_brands, '; ') AS common_fabcon_brands,
    CAST(AVG(fabcon_total_value) AS DECIMAL(10,2)) AS avg_fabcon_spend
FROM fabcon_copurchase_analysis
GROUP BY detergent_brand, detergent_type, demographics_gender, demographics_age
HAVING COUNT(*) >= 3
ORDER BY fabcon_attachment_rate DESC;

-- Export 6: What Else is Purchased with Detergent
SELECT
    'Laundry Co-Purchase Categories' AS export_type,
    laundry_brand,
    detergent_type,
    copurchase_category,
    copurchase_brand,
    co_occurrence_count,
    unique_customers,
    CAST(laundry_support * 100 AS DECIMAL(5,2)) AS laundry_support_pct,
    CAST(copurchase_support * 100 AS DECIMAL(5,2)) AS copurchase_support_pct,

    -- Calculate lift
    CAST((laundry_support / copurchase_support) AS DECIMAL(8,2)) AS lift_score,

    CASE
        WHEN (laundry_support / copurchase_support) > 1.2 THEN 'Strong Association'
        WHEN (laundry_support / copurchase_support) > 1.0 THEN 'Weak Association'
        ELSE 'No Association'
    END AS association_strength

FROM laundry_copurchase_categories
WHERE co_occurrence_count >= 3
ORDER BY co_occurrence_count DESC, laundry_brand;

-- Export 7: Frequently Used Terms for Laundry Soap
SELECT
    'Laundry Frequent Terms' AS export_type,
    term,
    frequency,
    associated_brands,
    associated_types,
    user_genders,
    avg_term_confidence,
    CAST(frequency * 100.0 / SUM(frequency) OVER() AS DECIMAL(5,2)) AS term_share_pct
FROM laundry_frequent_terms
ORDER BY frequency DESC;

PRINT 'Laundry analytics completed successfully';