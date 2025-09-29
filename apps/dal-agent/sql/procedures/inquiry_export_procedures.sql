-- Inquiry Export Stored Procedures
-- High-performance exports using optimized views
-- Created: 2025-09-26

-- 1. Overall Store Profiles Export
CREATE OR ALTER PROCEDURE sp_export_store_profiles
    @date_from date,
    @date_to date,
    @region nvarchar(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        store_id,
        store_name,
        region,
        COUNT(*) AS transactions,
        SUM(basket_size) AS total_items,
        CAST(SUM(transaction_value) AS decimal(18,2)) AS total_amount
    FROM gold.v_demographics_parsed
    WHERE transaction_date BETWEEN @date_from AND @date_to
        AND (@region IS NULL OR region = @region)
    GROUP BY store_id, store_name, region
    ORDER BY total_amount DESC;
END;

-- 2. Purchase Demographics Export
CREATE OR ALTER PROCEDURE sp_export_purchase_demographics
    @date_from date,
    @date_to date,
    @region nvarchar(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        payment_method,
        daypart,
        region,
        transactions,
        avg_amount,
        CAST(100.0 * transactions / SUM(transactions) OVER() AS decimal(5,2)) AS share_pct
    FROM gold.v_payment_demographics
    WHERE (@region IS NULL OR region = @region)
    ORDER BY transactions DESC;
END;

-- 3. Category Demographics Export
CREATE OR ALTER PROCEDURE sp_export_category_demographics
    @date_from date,
    @date_to date,
    @category nvarchar(50),
    @region nvarchar(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        gender,
        age_band,
        brand,
        COUNT(*) AS transactions,
        CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER() AS decimal(5,2)) AS share_pct
    FROM gold.v_demographics_parsed
    WHERE transaction_date BETWEEN @date_from AND @date_to
        AND category = @category
        AND (@region IS NULL OR region = @region)
    GROUP BY gender, age_band, brand
    ORDER BY transactions DESC;
END;

-- 4. Purchase Profile (Day-of-Month) Export
CREATE OR ALTER PROCEDURE sp_export_purchase_profile
    @date_from date,
    @date_to date,
    @category nvarchar(50),
    @region nvarchar(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        dom_bucket,
        COUNT(*) AS transactions,
        CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER() AS decimal(5,2)) AS share_pct
    FROM gold.v_demographics_parsed
    WHERE transaction_date BETWEEN @date_from AND @date_to
        AND category = @category
        AND (@region IS NULL OR region = @region)
    GROUP BY dom_bucket
    ORDER BY CASE dom_bucket
                WHEN N'01-07' THEN 1
                WHEN N'08-15' THEN 2
                WHEN N'16-22' THEN 3
                ELSE 4 END;
END;

-- 5. Daily Sales by Daypart Export
CREATE OR ALTER PROCEDURE sp_export_daily_sales
    @date_from date,
    @date_to date,
    @category nvarchar(50),
    @region nvarchar(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        CAST(transaction_date AS date) AS sale_date,
        daypart,
        COUNT(*) AS transactions,
        CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(PARTITION BY CAST(transaction_date AS date)) AS decimal(5,2)) AS share_pct
    FROM gold.v_demographics_parsed
    WHERE transaction_date BETWEEN @date_from AND @date_to
        AND category = @category
        AND (@region IS NULL OR region = @region)
    GROUP BY CAST(transaction_date AS date), daypart
    ORDER BY sale_date, transactions DESC;
END;

-- 6. Co-purchase Categories Export
CREATE OR ALTER PROCEDURE sp_export_copurchase_categories
    @date_from date,
    @date_to date,
    @target_category nvarchar(50),
    @region nvarchar(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    WITH target_transactions AS (
        SELECT DISTINCT transaction_id
        FROM gold.v_demographics_parsed
        WHERE transaction_date BETWEEN @date_from AND @date_to
            AND category = @target_category
            AND (@region IS NULL OR region = @region)
    )
    SELECT
        p.category,
        COUNT(*) AS transactions,
        CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER() AS decimal(5,2)) AS share_pct
    FROM target_transactions t
    JOIN gold.v_demographics_parsed p ON p.transaction_id = t.transaction_id
    WHERE p.category != @target_category
    GROUP BY p.category
    ORDER BY transactions DESC;
END;

-- 7. Frequent Terms Export (Audio Transcript Analysis)
CREATE OR ALTER PROCEDURE sp_export_frequent_terms
    @date_from date,
    @date_to date,
    @category nvarchar(50),
    @min_frequency int = 3,
    @region nvarchar(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    WITH transcript_words AS (
        SELECT
            value AS term,
            category
        FROM gold.v_demographics_parsed
        CROSS APPLY STRING_SPLIT(LOWER(COALESCE(audio_transcript, '')), ' ')
        WHERE transaction_date BETWEEN @date_from AND @date_to
            AND category = @category
            AND (@region IS NULL OR region = @region)
            AND LEN(value) > 2
            AND value NOT IN (
                'the','and','for','with','this','that','from','have','been',
                'they','were','said','each','what','will','when','your','how'
            )
    )
    SELECT
        term,
        COUNT(*) AS frequency,
        STRING_AGG(DISTINCT category, ', ') AS category_context
    FROM transcript_words
    WHERE term IS NOT NULL AND term != ''
    GROUP BY term
    HAVING COUNT(*) >= @min_frequency
    ORDER BY frequency DESC;
END;

-- 8. Laundry Detergent Type Analysis
CREATE OR ALTER PROCEDURE sp_export_detergent_types
    @date_from date,
    @date_to date,
    @region nvarchar(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    WITH laundry_analysis AS (
        SELECT
            CASE
                WHEN brand LIKE N'%Bar%' OR brand LIKE N'%bar%' THEN N'bar'
                WHEN brand LIKE N'%Powder%' OR brand LIKE N'%powder%' THEN N'powder'
                WHEN brand LIKE N'%Liquid%' OR brand LIKE N'%liquid%' THEN N'liquid'
                ELSE N'unknown'
            END AS detergent_type,
            transaction_id
        FROM gold.v_demographics_parsed
        WHERE transaction_date BETWEEN @date_from AND @date_to
            AND category = N'Laundry'
            AND (@region IS NULL OR region = @region)
    ),
    fabcon_check AS (
        SELECT DISTINCT
            la.detergent_type,
            la.transaction_id,
            CASE WHEN EXISTS (
                SELECT 1 FROM gold.v_demographics_parsed dp2
                WHERE dp2.transaction_id = la.transaction_id
                    AND (dp2.brand LIKE N'%Fabcon%' OR dp2.brand LIKE N'%Fabric%')
            ) THEN 1 ELSE 0 END AS with_fabcon
        FROM laundry_analysis la
    )
    SELECT
        detergent_type,
        with_fabcon,
        COUNT(*) AS transactions,
        CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(PARTITION BY detergent_type) AS decimal(5,2)) AS share_pct
    FROM fabcon_check
    GROUP BY detergent_type, with_fabcon
    ORDER BY detergent_type, transactions DESC;
END;