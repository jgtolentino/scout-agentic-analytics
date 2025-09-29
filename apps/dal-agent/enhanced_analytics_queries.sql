/*
Enhanced Scout Analytics - Dan Ryan's Requirements
Deep dive into tobacco and laundry categories with comprehensive insights
*/

-- ==================================================================
-- OVERALL STORE DEMOGRAPHICS
-- ==================================================================

-- Store profiles with category performance
CREATE OR ALTER VIEW analytics.v_store_profiles AS
SELECT
    s.store_id,
    s.store_name,
    s.region,
    s.city,
    COUNT(DISTINCT t.canonical_tx_id) as total_transactions,
    COUNT(DISTINCT t.customer_key) as unique_customers,
    SUM(t.transaction_value) as total_revenue,
    AVG(t.transaction_value) as avg_transaction_value,
    AVG(t.basket_size) as avg_basket_size,
    -- Category breakdown
    SUM(CASE WHEN p.category = 'Tobacco Products' THEN t.transaction_value ELSE 0 END) as tobacco_revenue,
    SUM(CASE WHEN p.category LIKE '%Laundry%' THEN t.transaction_value ELSE 0 END) as laundry_revenue,
    COUNT(CASE WHEN p.category = 'Tobacco Products' THEN t.canonical_tx_id END) as tobacco_transactions,
    COUNT(CASE WHEN p.category LIKE '%Laundry%' THEN t.canonical_tx_id END) as laundry_transactions
FROM gold.v_export_projection t
LEFT JOIN gold.dim_stores s ON t.store_id = s.store_id
LEFT JOIN silver.transaction_products p ON t.canonical_tx_id = p.canonical_tx_id
WHERE t.transaction_date >= DATEADD(MONTH, -3, GETDATE())
GROUP BY s.store_id, s.store_name, s.region, s.city;

-- Purchase demographics with detailed profiles
CREATE OR ALTER VIEW analytics.v_purchase_demographics AS
SELECT
    t.store_id,
    t.store_name,
    t.region,
    -- Demographics parsing from Scout format
    CASE
        WHEN t.demographics LIKE '%Male%' THEN 'Male'
        WHEN t.demographics LIKE '%Female%' THEN 'Female'
        ELSE 'Unknown'
    END as gender,
    CASE
        WHEN t.demographics LIKE '%16-19%' THEN '16-19'
        WHEN t.demographics LIKE '%20-29%' THEN '20-29'
        WHEN t.demographics LIKE '%30-39%' THEN '30-39'
        WHEN t.demographics LIKE '%40-49%' THEN '40-49'
        WHEN t.demographics LIKE '%50-59%' THEN '50-59'
        ELSE 'Unknown'
    END as age_group,
    t.daypart,
    DATENAME(WEEKDAY, t.transaction_date) as day_of_week,
    CASE WHEN DATENAME(WEEKDAY, t.transaction_date) IN ('Saturday', 'Sunday') THEN 'Weekend' ELSE 'Weekday' END as week_type,
    COUNT(t.canonical_tx_id) as transaction_count,
    AVG(t.transaction_value) as avg_transaction_value,
    AVG(t.basket_size) as avg_basket_size,
    SUM(t.transaction_value) as total_revenue
FROM gold.v_export_projection t
WHERE t.transaction_date >= DATEADD(MONTH, -3, GETDATE())
GROUP BY t.store_id, t.store_name, t.region,
         CASE WHEN t.demographics LIKE '%Male%' THEN 'Male' WHEN t.demographics LIKE '%Female%' THEN 'Female' ELSE 'Unknown' END,
         CASE WHEN t.demographics LIKE '%16-19%' THEN '16-19' WHEN t.demographics LIKE '%20-29%' THEN '20-29' WHEN t.demographics LIKE '%30-39%' THEN '30-39' WHEN t.demographics LIKE '%40-49%' THEN '40-49' WHEN t.demographics LIKE '%50-59%' THEN '50-59' ELSE 'Unknown' END,
         t.daypart, DATENAME(WEEKDAY, t.transaction_date),
         CASE WHEN DATENAME(WEEKDAY, t.transaction_date) IN ('Saturday', 'Sunday') THEN 'Weekend' ELSE 'Weekday' END;

-- ==================================================================
-- ENHANCED TOBACCO ANALYTICS
-- ==================================================================

-- Tobacco demographics with brand breakdown
CREATE OR ALTER VIEW analytics.v_tobacco_demographics AS
SELECT
    t.store_id,
    t.store_name,
    t.region,
    p.brand,
    p.product_name,
    -- Demographics
    CASE
        WHEN t.demographics LIKE '%Male%' THEN 'Male'
        WHEN t.demographics LIKE '%Female%' THEN 'Female'
        ELSE 'Unknown'
    END as gender,
    CASE
        WHEN t.demographics LIKE '%16-19%' THEN '16-19'
        WHEN t.demographics LIKE '%20-29%' THEN '20-29'
        WHEN t.demographics LIKE '%30-39%' THEN '30-39'
        WHEN t.demographics LIKE '%40-49%' THEN '40-49'
        WHEN t.demographics LIKE '%50-59%' THEN '50-59'
        ELSE 'Unknown'
    END as age_group,
    -- Purchase patterns
    COUNT(DISTINCT t.canonical_tx_id) as transactions,
    COUNT(DISTINCT t.customer_key) as unique_customers,
    SUM(p.quantity) as total_sticks_sold,
    AVG(p.quantity) as avg_sticks_per_visit,
    SUM(p.line_total) as total_revenue,
    AVG(p.line_total) as avg_revenue_per_transaction,
    AVG(p.unit_price) as avg_unit_price
FROM gold.v_export_projection t
INNER JOIN silver.transaction_products p ON t.canonical_tx_id = p.canonical_tx_id
WHERE p.category = 'Tobacco Products'
    AND t.transaction_date >= DATEADD(MONTH, -3, GETDATE())
GROUP BY t.store_id, t.store_name, t.region, p.brand, p.product_name,
         CASE WHEN t.demographics LIKE '%Male%' THEN 'Male' WHEN t.demographics LIKE '%Female%' THEN 'Female' ELSE 'Unknown' END,
         CASE WHEN t.demographics LIKE '%16-19%' THEN '16-19' WHEN t.demographics LIKE '%20-29%' THEN '20-29' WHEN t.demographics LIKE '%30-39%' THEN '30-39' WHEN t.demographics LIKE '%40-49%' THEN '40-49' WHEN t.demographics LIKE '%50-59%' THEN '50-59' ELSE 'Unknown' END;

-- Tobacco purchase profile with "pecha de peligro" analysis
CREATE OR ALTER VIEW analytics.v_tobacco_purchase_profile AS
SELECT
    p.brand,
    DATENAME(WEEKDAY, t.transaction_date) as day_of_week,
    t.daypart,
    DAY(t.transaction_date) as day_of_month,
    CASE
        WHEN DAY(t.transaction_date) BETWEEN 15 AND 31 THEN 'Pecha de Peligro'
        ELSE 'First Half'
    END as month_period,
    COUNT(t.canonical_tx_id) as transaction_count,
    SUM(p.quantity) as total_sticks,
    AVG(p.quantity) as avg_sticks_per_visit,
    SUM(p.line_total) as total_sales,
    AVG(p.line_total) as avg_sales_per_transaction
FROM gold.v_export_projection t
INNER JOIN silver.transaction_products p ON t.canonical_tx_id = p.canonical_tx_id
WHERE p.category = 'Tobacco Products'
    AND t.transaction_date >= DATEADD(MONTH, -3, GETDATE())
GROUP BY p.brand, DATENAME(WEEKDAY, t.transaction_date), t.daypart,
         DAY(t.transaction_date),
         CASE WHEN DAY(t.transaction_date) BETWEEN 15 AND 31 THEN 'Pecha de Peligro' ELSE 'First Half' END;

-- What is purchased with cigarettes (basket analysis)
CREATE OR ALTER VIEW analytics.v_tobacco_basket_analysis AS
SELECT
    tobacco.brand as tobacco_brand,
    other.category as companion_category,
    other.product_name as companion_product,
    COUNT(DISTINCT tobacco.canonical_tx_id) as co_purchase_transactions,
    COUNT(tobacco.canonical_tx_id) * 100.0 /
        (SELECT COUNT(DISTINCT canonical_tx_id) FROM silver.transaction_products WHERE category = 'Tobacco Products') as co_purchase_rate,
    AVG(other.quantity) as avg_companion_quantity,
    SUM(other.line_total) as total_companion_revenue
FROM silver.transaction_products tobacco
INNER JOIN silver.transaction_products other ON tobacco.canonical_tx_id = other.canonical_tx_id
WHERE tobacco.category = 'Tobacco Products'
    AND other.category != 'Tobacco Products'
    AND tobacco.transaction_id IN (
        SELECT transaction_id FROM silver.transactions
        WHERE transaction_timestamp >= DATEADD(MONTH, -3, GETDATE())
    )
GROUP BY tobacco.brand, other.category, other.product_name
HAVING COUNT(DISTINCT tobacco.canonical_tx_id) >= 5  -- Minimum 5 co-occurrences
ORDER BY co_purchase_rate DESC;

-- Frequently used terms for tobacco purchases
CREATE OR ALTER VIEW analytics.v_tobacco_purchase_terms AS
SELECT
    p.brand,
    p.product_name,
    t.audio_transcript,
    -- Extract common tobacco terms
    CASE
        WHEN t.audio_transcript LIKE '%yosi%' THEN 'yosi'
        WHEN t.audio_transcript LIKE '%sigarilyo%' THEN 'sigarilyo'
        WHEN t.audio_transcript LIKE '%cigarette%' THEN 'cigarette'
        WHEN t.audio_transcript LIKE '%stick%' THEN 'stick'
        WHEN t.audio_transcript LIKE '%pack%' THEN 'pack'
        ELSE 'other_term'
    END as purchase_term,
    COUNT(t.canonical_tx_id) as usage_count,
    COUNT(t.canonical_tx_id) * 100.0 /
        (SELECT COUNT(*) FROM gold.v_export_projection WHERE audio_transcript IS NOT NULL) as usage_percentage
FROM gold.v_export_projection t
INNER JOIN silver.transaction_products p ON t.canonical_tx_id = p.canonical_tx_id
WHERE p.category = 'Tobacco Products'
    AND t.audio_transcript IS NOT NULL
    AND t.transaction_date >= DATEADD(MONTH, -3, GETDATE())
GROUP BY p.brand, p.product_name,
         CASE WHEN t.audio_transcript LIKE '%yosi%' THEN 'yosi' WHEN t.audio_transcript LIKE '%sigarilyo%' THEN 'sigarilyo' WHEN t.audio_transcript LIKE '%cigarette%' THEN 'cigarette' WHEN t.audio_transcript LIKE '%stick%' THEN 'stick' WHEN t.audio_transcript LIKE '%pack%' THEN 'pack' ELSE 'other_term' END,
         t.audio_transcript;

-- ==================================================================
-- ENHANCED LAUNDRY ANALYTICS
-- ==================================================================

-- Laundry demographics with brand breakdown
CREATE OR ALTER VIEW analytics.v_laundry_demographics AS
SELECT
    t.store_id,
    t.store_name,
    t.region,
    p.brand,
    p.product_name,
    -- Product type classification
    CASE
        WHEN p.product_name LIKE '%bar%' OR p.product_name LIKE '%soap%' THEN 'Bar Soap'
        WHEN p.product_name LIKE '%powder%' OR p.product_name LIKE '%detergent%' THEN 'Powder Detergent'
        WHEN p.product_name LIKE '%liquid%' THEN 'Liquid Detergent'
        ELSE 'Other Laundry'
    END as product_type,
    -- Demographics
    CASE
        WHEN t.demographics LIKE '%Male%' THEN 'Male'
        WHEN t.demographics LIKE '%Female%' THEN 'Female'
        ELSE 'Unknown'
    END as gender,
    CASE
        WHEN t.demographics LIKE '%16-19%' THEN '16-19'
        WHEN t.demographics LIKE '%20-29%' THEN '20-29'
        WHEN t.demographics LIKE '%30-39%' THEN '30-39'
        WHEN t.demographics LIKE '%40-49%' THEN '40-49'
        WHEN t.demographics LIKE '%50-59%' THEN '50-59'
        ELSE 'Unknown'
    END as age_group,
    -- Purchase patterns
    COUNT(DISTINCT t.canonical_tx_id) as transactions,
    COUNT(DISTINCT t.customer_key) as unique_customers,
    SUM(p.quantity) as total_units_sold,
    AVG(p.quantity) as avg_units_per_visit,
    SUM(p.line_total) as total_revenue,
    AVG(p.line_total) as avg_revenue_per_transaction
FROM gold.v_export_projection t
INNER JOIN silver.transaction_products p ON t.canonical_tx_id = p.canonical_tx_id
WHERE p.category LIKE '%Laundry%' OR p.category LIKE '%Detergent%' OR p.category LIKE '%Soap%'
    AND t.transaction_date >= DATEADD(MONTH, -3, GETDATE())
GROUP BY t.store_id, t.store_name, t.region, p.brand, p.product_name,
         CASE WHEN p.product_name LIKE '%bar%' OR p.product_name LIKE '%soap%' THEN 'Bar Soap' WHEN p.product_name LIKE '%powder%' OR p.product_name LIKE '%detergent%' THEN 'Powder Detergent' WHEN p.product_name LIKE '%liquid%' THEN 'Liquid Detergent' ELSE 'Other Laundry' END,
         CASE WHEN t.demographics LIKE '%Male%' THEN 'Male' WHEN t.demographics LIKE '%Female%' THEN 'Female' ELSE 'Unknown' END,
         CASE WHEN t.demographics LIKE '%16-19%' THEN '16-19' WHEN t.demographics LIKE '%20-29%' THEN '20-29' WHEN t.demographics LIKE '%30-39%' THEN '30-39' WHEN t.demographics LIKE '%40-49%' THEN '40-49' WHEN t.demographics LIKE '%50-59%' THEN '50-59' ELSE 'Unknown' END;

-- Laundry purchase profile with "pecha de peligro" analysis
CREATE OR ALTER VIEW analytics.v_laundry_purchase_profile AS
SELECT
    p.brand,
    CASE
        WHEN p.product_name LIKE '%bar%' OR p.product_name LIKE '%soap%' THEN 'Bar Soap'
        WHEN p.product_name LIKE '%powder%' OR p.product_name LIKE '%detergent%' THEN 'Powder Detergent'
        WHEN p.product_name LIKE '%liquid%' THEN 'Liquid Detergent'
        ELSE 'Other Laundry'
    END as product_type,
    DATENAME(WEEKDAY, t.transaction_date) as day_of_week,
    t.daypart,
    DAY(t.transaction_date) as day_of_month,
    CASE
        WHEN DAY(t.transaction_date) BETWEEN 15 AND 31 THEN 'Pecha de Peligro'
        ELSE 'First Half'
    END as month_period,
    COUNT(t.canonical_tx_id) as transaction_count,
    SUM(p.quantity) as total_units,
    AVG(p.quantity) as avg_units_per_visit,
    SUM(p.line_total) as total_sales,
    AVG(p.line_total) as avg_sales_per_transaction
FROM gold.v_export_projection t
INNER JOIN silver.transaction_products p ON t.canonical_tx_id = p.canonical_tx_id
WHERE (p.category LIKE '%Laundry%' OR p.category LIKE '%Detergent%' OR p.category LIKE '%Soap%')
    AND t.transaction_date >= DATEADD(MONTH, -3, GETDATE())
GROUP BY p.brand,
         CASE WHEN p.product_name LIKE '%bar%' OR p.product_name LIKE '%soap%' THEN 'Bar Soap' WHEN p.product_name LIKE '%powder%' OR p.product_name LIKE '%detergent%' THEN 'Powder Detergent' WHEN p.product_name LIKE '%liquid%' THEN 'Liquid Detergent' ELSE 'Other Laundry' END,
         DATENAME(WEEKDAY, t.transaction_date), t.daypart,
         DAY(t.transaction_date),
         CASE WHEN DAY(t.transaction_date) BETWEEN 15 AND 31 THEN 'Pecha de Peligro' ELSE 'First Half' END;

-- Detergent + Fabcon co-purchase analysis
CREATE OR ALTER VIEW analytics.v_laundry_fabcon_analysis AS
SELECT
    detergent.brand as detergent_brand,
    detergent.product_name as detergent_product,
    CASE
        WHEN detergent.product_name LIKE '%bar%' OR detergent.product_name LIKE '%soap%' THEN 'Bar Soap'
        WHEN detergent.product_name LIKE '%powder%' OR detergent.product_name LIKE '%detergent%' THEN 'Powder Detergent'
        WHEN detergent.product_name LIKE '%liquid%' THEN 'Liquid Detergent'
        ELSE 'Other Laundry'
    END as detergent_type,
    fabcon.brand as fabcon_brand,
    fabcon.product_name as fabcon_product,
    COUNT(DISTINCT detergent.canonical_tx_id) as co_purchase_transactions,
    COUNT(detergent.canonical_tx_id) * 100.0 /
        (SELECT COUNT(DISTINCT canonical_tx_id) FROM silver.transaction_products WHERE category LIKE '%Laundry%') as co_purchase_rate,
    AVG(fabcon.quantity) as avg_fabcon_quantity,
    SUM(fabcon.line_total) as total_fabcon_revenue
FROM silver.transaction_products detergent
INNER JOIN silver.transaction_products fabcon ON detergent.canonical_tx_id = fabcon.canonical_tx_id
WHERE (detergent.category LIKE '%Laundry%' OR detergent.category LIKE '%Detergent%' OR detergent.category LIKE '%Soap%')
    AND (fabcon.product_name LIKE '%fabcon%' OR fabcon.product_name LIKE '%fabric%' OR fabcon.product_name LIKE '%conditioner%')
    AND detergent.transaction_id IN (
        SELECT transaction_id FROM silver.transactions
        WHERE transaction_timestamp >= DATEADD(MONTH, -3, GETDATE())
    )
GROUP BY detergent.brand, detergent.product_name,
         CASE WHEN detergent.product_name LIKE '%bar%' OR detergent.product_name LIKE '%soap%' THEN 'Bar Soap' WHEN detergent.product_name LIKE '%powder%' OR detergent.product_name LIKE '%detergent%' THEN 'Powder Detergent' WHEN detergent.product_name LIKE '%liquid%' THEN 'Liquid Detergent' ELSE 'Other Laundry' END,
         fabcon.brand, fabcon.product_name
HAVING COUNT(DISTINCT detergent.canonical_tx_id) >= 3  -- Minimum 3 co-occurrences
ORDER BY co_purchase_rate DESC;

-- What else is purchased with detergent
CREATE OR ALTER VIEW analytics.v_laundry_basket_analysis AS
SELECT
    laundry.brand as laundry_brand,
    CASE
        WHEN laundry.product_name LIKE '%bar%' OR laundry.product_name LIKE '%soap%' THEN 'Bar Soap'
        WHEN laundry.product_name LIKE '%powder%' OR laundry.product_name LIKE '%detergent%' THEN 'Powder Detergent'
        WHEN laundry.product_name LIKE '%liquid%' THEN 'Liquid Detergent'
        ELSE 'Other Laundry'
    END as laundry_type,
    other.category as companion_category,
    other.product_name as companion_product,
    COUNT(DISTINCT laundry.canonical_tx_id) as co_purchase_transactions,
    COUNT(laundry.canonical_tx_id) * 100.0 /
        (SELECT COUNT(DISTINCT canonical_tx_id) FROM silver.transaction_products WHERE category LIKE '%Laundry%') as co_purchase_rate,
    AVG(other.quantity) as avg_companion_quantity,
    SUM(other.line_total) as total_companion_revenue
FROM silver.transaction_products laundry
INNER JOIN silver.transaction_products other ON laundry.canonical_tx_id = other.canonical_tx_id
WHERE (laundry.category LIKE '%Laundry%' OR laundry.category LIKE '%Detergent%' OR laundry.category LIKE '%Soap%')
    AND NOT (other.category LIKE '%Laundry%' OR other.category LIKE '%Detergent%' OR other.category LIKE '%Soap%')
    AND laundry.transaction_id IN (
        SELECT transaction_id FROM silver.transactions
        WHERE transaction_timestamp >= DATEADD(MONTH, -3, GETDATE())
    )
GROUP BY laundry.brand,
         CASE WHEN laundry.product_name LIKE '%bar%' OR laundry.product_name LIKE '%soap%' THEN 'Bar Soap' WHEN laundry.product_name LIKE '%powder%' OR laundry.product_name LIKE '%detergent%' THEN 'Powder Detergent' WHEN laundry.product_name LIKE '%liquid%' THEN 'Liquid Detergent' ELSE 'Other Laundry' END,
         other.category, other.product_name
HAVING COUNT(DISTINCT laundry.canonical_tx_id) >= 5  -- Minimum 5 co-occurrences
ORDER BY co_purchase_rate DESC;

-- Frequently used terms for laundry soap purchases
CREATE OR ALTER VIEW analytics.v_laundry_purchase_terms AS
SELECT
    p.brand,
    p.product_name,
    CASE
        WHEN p.product_name LIKE '%bar%' OR p.product_name LIKE '%soap%' THEN 'Bar Soap'
        WHEN p.product_name LIKE '%powder%' OR p.product_name LIKE '%detergent%' THEN 'Powder Detergent'
        WHEN p.product_name LIKE '%liquid%' THEN 'Liquid Detergent'
        ELSE 'Other Laundry'
    END as product_type,
    -- Extract common laundry terms
    CASE
        WHEN t.audio_transcript LIKE '%sabon%' THEN 'sabon'
        WHEN t.audio_transcript LIKE '%detergent%' THEN 'detergent'
        WHEN t.audio_transcript LIKE '%labada%' THEN 'labada'
        WHEN t.audio_transcript LIKE '%washing%' THEN 'washing'
        WHEN t.audio_transcript LIKE '%powder%' THEN 'powder'
        WHEN t.audio_transcript LIKE '%bar%' THEN 'bar'
        WHEN t.audio_transcript LIKE '%fabcon%' THEN 'fabcon'
        ELSE 'other_term'
    END as purchase_term,
    t.audio_transcript,
    COUNT(t.canonical_tx_id) as usage_count,
    COUNT(t.canonical_tx_id) * 100.0 /
        (SELECT COUNT(*) FROM gold.v_export_projection WHERE audio_transcript IS NOT NULL) as usage_percentage
FROM gold.v_export_projection t
INNER JOIN silver.transaction_products p ON t.canonical_tx_id = p.canonical_tx_id
WHERE (p.category LIKE '%Laundry%' OR p.category LIKE '%Detergent%' OR p.category LIKE '%Soap%')
    AND t.audio_transcript IS NOT NULL
    AND t.transaction_date >= DATEADD(MONTH, -3, GETDATE())
GROUP BY p.brand, p.product_name,
         CASE WHEN p.product_name LIKE '%bar%' OR p.product_name LIKE '%soap%' THEN 'Bar Soap' WHEN p.product_name LIKE '%powder%' OR p.product_name LIKE '%detergent%' THEN 'Powder Detergent' WHEN p.product_name LIKE '%liquid%' THEN 'Liquid Detergent' ELSE 'Other Laundry' END,
         CASE WHEN t.audio_transcript LIKE '%sabon%' THEN 'sabon' WHEN t.audio_transcript LIKE '%detergent%' THEN 'detergent' WHEN t.audio_transcript LIKE '%labada%' THEN 'labada' WHEN t.audio_transcript LIKE '%washing%' THEN 'washing' WHEN t.audio_transcript LIKE '%powder%' THEN 'powder' WHEN t.audio_transcript LIKE '%bar%' THEN 'bar' WHEN t.audio_transcript LIKE '%fabcon%' THEN 'fabcon' ELSE 'other_term' END,
         t.audio_transcript;