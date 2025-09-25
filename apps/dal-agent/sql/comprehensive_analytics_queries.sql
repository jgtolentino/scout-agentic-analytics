-- ================================================================
-- SCOUT ANALYTICS PLATFORM - COMPREHENSIVE DATA INQUIRIES
-- Post Nielsen Taxonomy Clean-up Analytics
-- Generated: September 24, 2025
-- ================================================================

-- ================================================================
-- OVERALL STORE DEMOGRAPHICS & PROFILES
-- ================================================================

-- Store Demographic Profiles
SELECT
    s.StoreID,
    s.StoreName,
    s.MunicipalityName,
    s.Region,
    COUNT(DISTINCT pt.sessionId) as total_sessions,
    COUNT(*) as total_transactions,
    SUM(CAST(pt.amount AS decimal(18,2))) as total_revenue,
    AVG(CAST(pt.amount AS decimal(18,2))) as avg_transaction_value,

    -- Customer Demographics by Store
    COUNT(CASE WHEN JSON_VALUE(pt.payload_json, '$.customer.gender') = 'Male' THEN 1 END) as male_customers,
    COUNT(CASE WHEN JSON_VALUE(pt.payload_json, '$.customer.gender') = 'Female' THEN 1 END) as female_customers,

    -- Age Segments by Store
    COUNT(CASE WHEN CAST(JSON_VALUE(pt.payload_json, '$.customer.age') AS INT) BETWEEN 18 AND 25 THEN 1 END) as gen_z,
    COUNT(CASE WHEN CAST(JSON_VALUE(pt.payload_json, '$.customer.age') AS INT) BETWEEN 26 AND 41 THEN 1 END) as millennial,
    COUNT(CASE WHEN CAST(JSON_VALUE(pt.payload_json, '$.customer.age') AS INT) BETWEEN 42 AND 57 THEN 1 END) as gen_x,
    COUNT(CASE WHEN CAST(JSON_VALUE(pt.payload_json, '$.customer.age') AS INT) >= 58 THEN 1 END) as boomer

FROM PayloadTransactions pt
JOIN Stores s ON CAST(pt.storeId AS INT) = s.StoreID
WHERE s.IsActive = 1
GROUP BY s.StoreID, s.StoreName, s.MunicipalityName, s.Region
ORDER BY total_revenue DESC;

-- Purchase Demographics and Profile Info
SELECT
    -- Demographics
    JSON_VALUE(pt.payload_json, '$.customer.gender') as gender,
    CASE
        WHEN CAST(JSON_VALUE(pt.payload_json, '$.customer.age') AS INT) BETWEEN 18 AND 25 THEN 'Gen Z (18-25)'
        WHEN CAST(JSON_VALUE(pt.payload_json, '$.customer.age') AS INT) BETWEEN 26 AND 41 THEN 'Millennial (26-41)'
        WHEN CAST(JSON_VALUE(pt.payload_json, '$.customer.age') AS INT) BETWEEN 42 AND 57 THEN 'Gen X (42-57)'
        WHEN CAST(JSON_VALUE(pt.payload_json, '$.customer.age') AS INT) >= 58 THEN 'Boomer (58+)'
        ELSE 'Unknown'
    END as age_segment,

    -- Purchase Behavior
    COUNT(*) as transaction_count,
    SUM(CAST(pt.amount AS decimal(18,2))) as total_spent,
    AVG(CAST(pt.amount AS decimal(18,2))) as avg_spend_per_transaction,
    COUNT(DISTINCT CAST(pt.storeId AS INT)) as stores_visited,

    -- Top Categories by Demographics
    STRING_AGG(DISTINCT vn.category, ', ') as top_categories

FROM PayloadTransactions pt
JOIN v_nielsen_complete_analytics vn ON pt.canonical_tx_id = vn.canonical_tx_id
WHERE vn.category != 'Unknown Brand'
GROUP BY
    JSON_VALUE(pt.payload_json, '$.customer.gender'),
    CASE
        WHEN CAST(JSON_VALUE(pt.payload_json, '$.customer.age') AS INT) BETWEEN 18 AND 25 THEN 'Gen Z (18-25)'
        WHEN CAST(JSON_VALUE(pt.payload_json, '$.customer.age') AS INT) BETWEEN 26 AND 41 THEN 'Millennial (26-41)'
        WHEN CAST(JSON_VALUE(pt.payload_json, '$.customer.age') AS INT) BETWEEN 42 AND 57 THEN 'Gen X (42-57)'
        WHEN CAST(JSON_VALUE(pt.payload_json, '$.customer.age') AS INT) >= 58 THEN 'Boomer (58+)'
        ELSE 'Unknown'
    END
ORDER BY transaction_count DESC;

-- Sales Spread Across Week and Month
SELECT
    DATEPART(WEEK, vn.date) as week_number,
    DATEPART(MONTH, vn.date) as month_number,
    DATENAME(WEEKDAY, vn.date) as day_of_week,
    COUNT(*) as transaction_count,
    SUM(vn.amount_sum) as total_sales,
    AVG(vn.amount_sum) as avg_transaction_value,
    COUNT(DISTINCT vn.brand) as unique_brands_sold
FROM v_nielsen_complete_analytics vn
WHERE vn.category != 'Unknown Brand'
GROUP BY DATEPART(WEEK, vn.date), DATEPART(MONTH, vn.date), DATENAME(WEEKDAY, vn.date), vn.date
ORDER BY week_number, month_number;

-- Sales Spread Day to Evening by Categories
SELECT
    vn.daypart,
    vn.category,
    COUNT(*) as transaction_count,
    SUM(vn.amount_sum) as total_sales,
    AVG(vn.amount_sum) as avg_transaction_value,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY vn.daypart) AS DECIMAL(5,1)) as category_share_by_daypart
FROM v_nielsen_complete_analytics vn
WHERE vn.category != 'Unknown Brand'
GROUP BY vn.daypart, vn.category
ORDER BY vn.daypart, total_sales DESC;

-- ================================================================
-- TOBACCO DEMOGRAPHICS & ANALYSIS
-- ================================================================

-- Tobacco Demographics (Gender x Age x Brand)
-- Note: Demographics require joining with transaction-level data
-- This query uses the existing demographics views for tobacco analysis
SELECT
    vn.brand as tobacco_brand,
    -- Use existing demographic breakdown from v_insight_base
    vib.age_bracket,
    vib.gender,

    COUNT(*) as purchase_count,
    SUM(vn.amount_sum) as total_spent,
    AVG(vn.amount_sum) as avg_spend,
    SUM(vn.items_sum) as total_items_purchased,
    AVG(vn.items_sum) as avg_items_per_purchase

FROM v_nielsen_complete_analytics vn
-- Join with insight base for demographics where available
LEFT JOIN v_insight_base vib ON vn.store_id = vib.store_id
    AND vn.date = CAST(vib.transaction_date AS DATE)
    AND vn.brand = vib.brand
WHERE vn.category = 'Cigarettes'
GROUP BY vn.brand, vib.age_bracket, vib.gender
ORDER BY purchase_count DESC;

-- Tobacco Purchase Profile (Day, Time, Monthly Patterns)
SELECT
    vn.brand as tobacco_brand,
    DATENAME(WEEKDAY, vn.date) as day_of_week,
    vn.daypart,
    DATEPART(DAY, vn.date) as day_of_month,

    -- Check for "pecha de peligro" pattern (end of month vs beginning)
    CASE
        WHEN DATEPART(DAY, vn.date) BETWEEN 1 AND 10 THEN 'Beginning'
        WHEN DATEPART(DAY, vn.date) BETWEEN 11 AND 20 THEN 'Middle'
        WHEN DATEPART(DAY, vn.date) >= 21 THEN 'End (Pecha de Peligro)'
    END as month_period,

    COUNT(*) as purchase_frequency,
    SUM(vn.amount_sum) as total_sales,
    AVG(vn.amount_sum) as avg_transaction,
    SUM(vn.items_sum) as total_sticks_sold,
    AVG(vn.items_sum) as avg_sticks_per_visit

FROM v_nielsen_complete_analytics vn
WHERE vn.category = 'Cigarettes'
GROUP BY
    vn.brand,
    DATENAME(WEEKDAY, vn.date),
    vn.daypart,
    DATEPART(DAY, vn.date),
    CASE
        WHEN DATEPART(DAY, vn.date) BETWEEN 1 AND 10 THEN 'Beginning'
        WHEN DATEPART(DAY, vn.date) BETWEEN 11 AND 20 THEN 'Middle'
        WHEN DATEPART(DAY, vn.date) >= 21 THEN 'End (Pecha de Peligro)'
    END
ORDER BY purchase_frequency DESC;

-- What is Purchased with Cigarettes (Basket Analysis)
SELECT
    tobacco.brand as tobacco_brand,
    other.category as co_purchased_category,
    other.brand as co_purchased_brand,
    COUNT(*) as co_purchase_frequency,
    AVG(other.amount_sum) as avg_co_purchase_amount,
    CAST(COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM v_nielsen_complete_analytics WHERE category = 'Cigarettes')
        AS DECIMAL(5,1)) as co_purchase_rate

FROM v_nielsen_complete_analytics tobacco
JOIN v_nielsen_complete_analytics other ON tobacco.date = other.date
    AND tobacco.store_id = other.store_id
    AND tobacco.daypart = other.daypart
WHERE tobacco.category = 'Cigarettes'
AND other.category != 'Cigarettes'
AND other.brand != 'Unknown Brand'
GROUP BY tobacco.brand, other.category, other.brand
ORDER BY co_purchase_frequency DESC;

-- ================================================================
-- LAUNDRY SOAP DEMOGRAPHICS & ANALYSIS
-- ================================================================

-- Laundry Soap Demographics (Gender x Age x Brand)
SELECT
    vn.brand as detergent_brand,
    vn.category as detergent_type, -- Bar Soap vs Detergent Powder
    JSON_VALUE(pt.payload_json, '$.customer.gender') as gender,
    CASE
        WHEN CAST(JSON_VALUE(pt.payload_json, '$.customer.age') AS INT) BETWEEN 18 AND 30 THEN '18-30'
        WHEN CAST(JSON_VALUE(pt.payload_json, '$.customer.age') AS INT) BETWEEN 31 AND 45 THEN '31-45'
        WHEN CAST(JSON_VALUE(pt.payload_json, '$.customer.age') AS INT) BETWEEN 46 AND 60 THEN '46-60'
        WHEN CAST(JSON_VALUE(pt.payload_json, '$.customer.age') AS INT) >= 61 THEN '61+'
        ELSE 'Unknown'
    END as age_bracket,

    COUNT(*) as purchase_count,
    SUM(vn.amount_sum) as total_spent,
    AVG(vn.amount_sum) as avg_spend,
    SUM(vn.items_sum) as total_items_purchased

FROM v_nielsen_complete_analytics vn
JOIN PayloadTransactions pt ON pt.canonical_tx_id = vn.canonical_tx_id
WHERE vn.category IN ('Detergent Powder', 'Laundry Bar Soap')
GROUP BY
    vn.brand,
    vn.category,
    JSON_VALUE(pt.payload_json, '$.customer.gender'),
    CASE
        WHEN CAST(JSON_VALUE(pt.payload_json, '$.customer.age') AS INT) BETWEEN 18 AND 30 THEN '18-30'
        WHEN CAST(JSON_VALUE(pt.payload_json, '$.customer.age') AS INT) BETWEEN 31 AND 45 THEN '31-45'
        WHEN CAST(JSON_VALUE(pt.payload_json, '$.customer.age') AS INT) BETWEEN 46 AND 60 THEN '46-60'
        WHEN CAST(JSON_VALUE(pt.payload_json, '$.customer.age') AS INT) >= 61 THEN '61+'
        ELSE 'Unknown'
    END
ORDER BY purchase_count DESC;

-- Laundry Purchase Profile with Monthly Patterns
SELECT
    vn.brand as detergent_brand,
    vn.category as product_type,
    DATENAME(WEEKDAY, vn.date) as day_of_week,
    vn.daypart,

    -- Monthly spending pattern analysis
    CASE
        WHEN DATEPART(DAY, vn.date) BETWEEN 1 AND 10 THEN 'Beginning'
        WHEN DATEPART(DAY, vn.date) BETWEEN 11 AND 20 THEN 'Middle'
        WHEN DATEPART(DAY, vn.date) >= 21 THEN 'End (Pecha de Peligro)'
    END as month_period,

    COUNT(*) as purchase_frequency,
    SUM(vn.amount_sum) as total_sales,
    AVG(vn.amount_sum) as avg_transaction,
    SUM(vn.items_sum) as total_items_sold

FROM v_nielsen_complete_analytics vn
WHERE vn.category IN ('Detergent Powder', 'Laundry Bar Soap')
GROUP BY
    vn.brand,
    vn.category,
    DATENAME(WEEKDAY, vn.date),
    vn.daypart,
    CASE
        WHEN DATEPART(DAY, vn.date) BETWEEN 1 AND 10 THEN 'Beginning'
        WHEN DATEPART(DAY, vn.date) BETWEEN 11 AND 20 THEN 'Middle'
        WHEN DATEPART(DAY, vn.date) >= 21 THEN 'End (Pecha de Peligro)'
    END
ORDER BY purchase_frequency DESC;

-- Fabric Softener + Detergent Purchase Analysis
SELECT
    detergent.brand as detergent_brand,
    detergent.category as detergent_type,
    fabcon.brand as fabcon_brand,
    COUNT(*) as combo_purchase_count,
    AVG(detergent.amount_sum + fabcon.amount_sum) as avg_combo_spend,
    CAST(COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM v_nielsen_complete_analytics WHERE category IN ('Detergent Powder', 'Laundry Bar Soap'))
        AS DECIMAL(5,1)) as combo_purchase_rate

FROM v_nielsen_complete_analytics detergent
JOIN v_nielsen_complete_analytics fabcon ON detergent.date = fabcon.date
    AND detergent.store_id = fabcon.store_id
    AND detergent.daypart = fabcon.daypart
WHERE detergent.category IN ('Detergent Powder', 'Laundry Bar Soap')
AND fabcon.category = 'Fabric Softener'
GROUP BY detergent.brand, detergent.category, fabcon.brand
ORDER BY combo_purchase_count DESC;

-- What Else is Purchased with Detergent
SELECT
    detergent.brand as detergent_brand,
    other.category as co_purchased_category,
    other.brand as co_purchased_brand,
    COUNT(*) as co_purchase_frequency,
    AVG(other.amount_sum) as avg_co_purchase_amount,
    CAST(COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM v_nielsen_complete_analytics WHERE category IN ('Detergent Powder', 'Laundry Bar Soap'))
        AS DECIMAL(5,1)) as co_purchase_rate

FROM v_nielsen_complete_analytics detergent
JOIN v_nielsen_complete_analytics other ON detergent.date = other.date
    AND detergent.store_id = other.store_id
    AND detergent.daypart = other.daypart
WHERE detergent.category IN ('Detergent Powder', 'Laundry Bar Soap')
AND other.category NOT IN ('Detergent Powder', 'Laundry Bar Soap')
AND other.brand != 'Unknown Brand'
GROUP BY detergent.brand, other.category, other.brand
ORDER BY co_purchase_frequency DESC;

-- ================================================================
-- TRANSCRIPT ANALYSIS FOR PURCHASE TERMS
-- ================================================================

-- Frequently Used Terms to Purchase Tobacco (from transcripts)
SELECT
    'Tobacco Purchase Terms' as analysis_type,
    COUNT(*) as transcript_mentions
-- Note: This requires transcript data analysis
-- Would need to join with transcript tables when available
FROM v_nielsen_complete_analytics
WHERE category = 'Cigarettes';

-- Frequently Used Terms to Purchase Laundry Soap (from transcripts)
SELECT
    'Laundry Soap Purchase Terms' as analysis_type,
    COUNT(*) as transcript_mentions
-- Note: This requires transcript data analysis
-- Would need to join with transcript tables when available
FROM v_nielsen_complete_analytics
WHERE category IN ('Detergent Powder', 'Laundry Bar Soap', 'Fabric Softener');

-- ================================================================
-- SUMMARY ANALYTICS
-- ================================================================

-- Overall Category Performance Summary
SELECT
    vn.category,
    COUNT(DISTINCT vn.brand) as unique_brands,
    COUNT(*) as total_transactions,
    SUM(vn.amount_sum) as total_revenue,
    AVG(vn.amount_sum) as avg_transaction_value,
    SUM(vn.items_sum) as total_items_sold,
    COUNT(DISTINCT vn.store_id) as stores_available,
    CAST(SUM(vn.amount_sum) * 100.0 /
        (SELECT SUM(amount_sum) FROM v_nielsen_complete_analytics WHERE brand != 'Unknown Brand')
        AS DECIMAL(5,1)) as revenue_share

FROM v_nielsen_complete_analytics vn
WHERE vn.brand != 'Unknown Brand'
GROUP BY vn.category
ORDER BY total_revenue DESC;