-- ===================================================================
-- SQL TEMPLATE: Gender × Daypart Shopping Patterns Analysis
-- ID: gender_daypart
-- Version: 1.0
-- Purpose: Analyze shopping patterns by gender across different time periods
-- ===================================================================

-- Template Parameters:
-- @date_from (date): Start date for analysis (default: 30 days ago)
-- @date_to (date): End date for analysis (default: today)
-- @gender (nvarchar): Specific gender filter (optional: 'Male', 'Female')
-- @category (nvarchar): Specific category filter (optional)
-- @store_id (int): Specific store filter (optional)

-- Business Question: "When do different genders shop and what do they buy?"
-- Use Cases: Marketing timing, staffing decisions, product placement

WITH gender_daypart_analysis AS (
    SELECT
        COALESCE(t.gender, 'Unknown') as gender,
        CASE
            WHEN DATEPART(hour, t.transactiondate) BETWEEN 6 AND 11 THEN 'Morning (6-11 AM)'
            WHEN DATEPART(hour, t.transactiondate) BETWEEN 12 AND 17 THEN 'Afternoon (12-5 PM)'
            WHEN DATEPART(hour, t.transactiondate) BETWEEN 18 AND 21 THEN 'Evening (6-9 PM)'
            ELSE 'Night (10 PM-5 AM)'
        END as daypart,
        DATENAME(weekday, t.transactiondate) as day_of_week,
        CASE
            WHEN DATENAME(weekday, t.transactiondate) IN ('Saturday', 'Sunday') THEN 'Weekend'
            ELSE 'Weekday'
        END as weekday_weekend,
        t.category,
        t.brand,
        COUNT(*) as transaction_count,
        SUM(t.total_price) as total_revenue,
        AVG(t.total_price) as avg_transaction_value,
        COUNT(DISTINCT t.storeid) as store_count,
        COUNT(DISTINCT t.productid) as unique_products,
        COUNT(DISTINCT t.payment_method) as payment_methods_used,
        -- Customer engagement metrics
        COUNT(DISTINCT CONCAT(t.storeid, '-', t.facialid)) as unique_customers_estimated,
        AVG(CASE WHEN t.transcript_audio IS NOT NULL THEN LEN(t.transcript_audio) ELSE 0 END) as avg_interaction_length
    FROM public.scout_gold_transactions_flat t
    WHERE t.transactiondate >= ISNULL(@date_from, DATEADD(day, -30, GETUTCDATE()))
      AND t.transactiondate <= ISNULL(@date_to, GETUTCDATE())
      AND t.location LIKE '%NCR%'
      AND (@gender IS NULL OR t.gender = @gender)
      AND (@category IS NULL OR t.category = @category)
      AND (@store_id IS NULL OR t.storeid = @store_id)
      AND t.gender IS NOT NULL
    GROUP BY
        COALESCE(t.gender, 'Unknown'),
        CASE
            WHEN DATEPART(hour, t.transactiondate) BETWEEN 6 AND 11 THEN 'Morning (6-11 AM)'
            WHEN DATEPART(hour, t.transactiondate) BETWEEN 12 AND 17 THEN 'Afternoon (12-5 PM)'
            WHEN DATEPART(hour, t.transactiondate) BETWEEN 18 AND 21 THEN 'Evening (6-9 PM)'
            ELSE 'Night (10 PM-5 AM)'
        END,
        DATENAME(weekday, t.transactiondate),
        CASE
            WHEN DATENAME(weekday, t.transactiondate) IN ('Saturday', 'Sunday') THEN 'Weekend'
            ELSE 'Weekday'
        END,
        t.category,
        t.brand
),
gender_totals AS (
    SELECT
        gender,
        SUM(transaction_count) as total_gender_transactions
    FROM gender_daypart_analysis
    GROUP BY gender
),
daypart_totals AS (
    SELECT
        daypart,
        SUM(transaction_count) as total_daypart_transactions
    FROM gender_daypart_analysis
    GROUP BY daypart
),
category_gender_totals AS (
    SELECT
        gender,
        category,
        SUM(transaction_count) as total_gender_category_transactions
    FROM gender_daypart_analysis
    GROUP BY gender, category
)
SELECT
    gda.gender,
    gda.daypart,
    gda.day_of_week,
    gda.weekday_weekend,
    gda.category,
    gda.brand,
    gda.transaction_count,
    ROUND(gda.total_revenue, 2) as total_revenue,
    ROUND(gda.avg_transaction_value, 2) as avg_transaction_value,
    gda.store_count,
    gda.unique_products,
    gda.payment_methods_used,
    gda.unique_customers_estimated,
    ROUND(gda.avg_interaction_length, 0) as avg_interaction_length,
    ROUND(100.0 * gda.transaction_count / gt.total_gender_transactions, 1) as gender_daypart_share_pct,
    ROUND(100.0 * gda.transaction_count / dt.total_daypart_transactions, 1) as daypart_gender_share_pct,
    ROUND(100.0 * gda.transaction_count / cgt.total_gender_category_transactions, 1) as category_gender_share_pct,
    RANK() OVER (PARTITION BY gda.gender ORDER BY gda.transaction_count DESC) as daypart_rank_for_gender,
    RANK() OVER (PARTITION BY gda.daypart ORDER BY gda.transaction_count DESC) as gender_rank_for_daypart,
    -- Peak time indicator for each gender
    CASE
        WHEN RANK() OVER (PARTITION BY gda.gender ORDER BY gda.transaction_count DESC) = 1 THEN 'Peak Time'
        WHEN RANK() OVER (PARTITION BY gda.gender ORDER BY gda.transaction_count DESC) <= 3 THEN 'High Activity'
        ELSE 'Normal Activity'
    END as activity_level,
    -- Gender preference index
    ROUND(100.0 * (gda.transaction_count / dt.total_daypart_transactions) /
          (gt.total_gender_transactions / (SELECT SUM(transaction_count) FROM gender_daypart_analysis)), 1) as preference_index
FROM gender_daypart_analysis gda
JOIN gender_totals gt ON gda.gender = gt.gender
JOIN daypart_totals dt ON gda.daypart = dt.daypart
JOIN category_gender_totals cgt ON gda.gender = cgt.gender AND gda.category = cgt.category
WHERE gda.transaction_count >= 3 -- Statistical significance threshold
ORDER BY gda.gender, gda.transaction_count DESC, gda.daypart;

-- Template Metadata:
-- Expected Output: 40-120 rows (2-3 genders × 4 dayparts × 7 days × 3-8 categories)
-- Validation: SUM(gender_daypart_share_pct) per gender should = 100%
-- Validation: SUM(daypart_gender_share_pct) per daypart should = 100%
-- Validation: preference_index around 100 indicates average preference
-- Performance: ~350ms on 30 days of data
-- Dependencies: public.scout_gold_transactions_flat, gender field
-- Notes: preference_index >120 indicates strong time preference, <80 indicates avoidance