-- Inquiry Analytics Views
-- Optimized views for business intelligence exports
-- Created: 2025-09-26

-- 1. Demographics parsing view (pre-computed for performance)
CREATE OR ALTER VIEW gold.v_demographics_parsed AS
SELECT
    transaction_id,
    transaction_date,
    store_id,
    store_name,
    region,
    category,
    brand,
    product_name,
    basket_size,
    transaction_value,
    payment_method,
    daypart,
    audio_transcript,
    -- Parse demographics efficiently
    COALESCE(
        TRY_CAST(PARSENAME(REPLACE(REPLACE(demographics,'''',''), ' ', '.'), 2) AS nvarchar(32)),
        N'Unknown'
    ) AS gender,
    COALESCE(
        TRY_CAST(PARSENAME(REPLACE(REPLACE(demographics,'''',''), ' ', '.'), 3) AS nvarchar(32)),
        N'Unknown'
    ) AS age_band,
    -- Day-of-month buckets (pre-computed)
    CASE
        WHEN DATEPART(DAY, transaction_date) BETWEEN 23 AND 30 THEN N'23-30'
        WHEN DATEPART(DAY, transaction_date) BETWEEN 1  AND 7  THEN N'01-07'
        WHEN DATEPART(DAY, transaction_date) BETWEEN 8  AND 15 THEN N'08-15'
        ELSE N'16-22'
    END AS dom_bucket
FROM gold.v_export_projection;
GO

-- 2. Category-specific views for performance
CREATE OR ALTER VIEW gold.v_tobacco_transactions AS
SELECT *
FROM gold.v_demographics_parsed
WHERE category = N'Tobacco Products';
GO

CREATE OR ALTER VIEW gold.v_laundry_transactions AS
SELECT *
FROM gold.v_demographics_parsed
WHERE category = N'Laundry';
GO

-- 3. Store profiles view (aggregated)
CREATE OR ALTER VIEW gold.v_store_profiles AS
SELECT
    store_id,
    store_name,
    region,
    COUNT(*) AS total_transactions,
    SUM(basket_size) AS total_items,
    CAST(SUM(transaction_value) AS decimal(18,2)) AS total_amount,
    CAST(AVG(transaction_value) AS decimal(18,2)) AS avg_transaction_value
FROM gold.v_demographics_parsed
GROUP BY store_id, store_name, region;
GO

-- 4. Payment demographics view (pre-aggregated)
CREATE OR ALTER VIEW gold.v_payment_demographics AS
SELECT
    COALESCE(payment_method, N'Unknown') AS payment_method,
    daypart,
    COALESCE(region, N'Unknown') AS region,
    COUNT(*) AS transactions,
    CAST(AVG(transaction_value) AS decimal(18,2)) AS avg_amount
FROM gold.v_demographics_parsed
GROUP BY payment_method, daypart, region;
GO

-- 5. Brand demographics view (category-agnostic)
CREATE OR ALTER VIEW gold.v_brand_demographics AS
SELECT
    category,
    gender,
    age_band,
    brand,
    COUNT(*) AS transactions
FROM gold.v_demographics_parsed
GROUP BY category, gender, age_band, brand;
GO

-- 6. Purchase patterns by day-of-month
CREATE OR ALTER VIEW gold.v_purchase_patterns AS
SELECT
    category,
    dom_bucket,
    COUNT(*) AS transactions
FROM gold.v_demographics_parsed
GROUP BY category, dom_bucket;
GO

-- 7. Sales by day and daypart
CREATE OR ALTER VIEW gold.v_daily_sales AS
SELECT
    category,
    CAST(transaction_date AS date) AS sale_date,
    daypart,
    COUNT(*) AS transactions
FROM gold.v_demographics_parsed
GROUP BY category, CAST(transaction_date AS date), daypart;