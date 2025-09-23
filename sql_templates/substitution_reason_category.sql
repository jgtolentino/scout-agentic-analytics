-- ===================================================================
-- SQL TEMPLATE: Substitution Events × Reason × Category Analysis
-- ID: substitution_reason_category
-- Version: 1.0
-- Purpose: Analyze substitution patterns by reason and product category
-- ===================================================================

-- Template Parameters:
-- @date_from (date): Start date for analysis (default: 30 days ago)
-- @date_to (date): End date for analysis (default: today)
-- @category (nvarchar): Specific category filter (optional)
-- @store_id (int): Specific store filter (optional)
-- @min_events (int): Minimum substitution events for inclusion (default: 3)

-- Business Question: "Why do customers substitute products and in which categories?"
-- Use Cases: Inventory management, product sourcing, customer satisfaction

WITH substitution_analysis AS (
    SELECT
        t.category,
        -- Extract substitution reason from transcript or edge data
        CASE
            WHEN t.transcript_audio LIKE '%out of stock%' OR t.transcript_audio LIKE '%wala%' THEN 'Out of Stock'
            WHEN t.transcript_audio LIKE '%expired%' OR t.transcript_audio LIKE '%sira%' THEN 'Quality Issue'
            WHEN t.transcript_audio LIKE '%expensive%' OR t.transcript_audio LIKE '%mahal%' THEN 'Price Concern'
            WHEN t.transcript_audio LIKE '%brand%' OR t.transcript_audio LIKE '%gusto%' THEN 'Brand Preference'
            WHEN t.transcript_audio LIKE '%size%' OR t.transcript_audio LIKE '%laki%' THEN 'Size Preference'
            WHEN t.bought_with_other_brands IS NOT NULL AND t.bought_with_other_brands != t.brand THEN 'Cross-Brand Bundle'
            ELSE 'Other/Unknown'
        END as substitution_reason,
        COUNT(*) as substitution_events,
        SUM(t.total_price) as substitution_revenue,
        AVG(t.total_price) as avg_substitution_value,
        COUNT(DISTINCT t.storeid) as stores_affected,
        COUNT(DISTINCT t.brand) as brands_involved,
        -- Calculate acceptance rate (successful substitutions vs total attempts)
        COUNT(CASE WHEN t.total_price > 0 THEN 1 END) as successful_substitutions,
        ROUND(100.0 * COUNT(CASE WHEN t.total_price > 0 THEN 1 END) / COUNT(*), 1) as acceptance_rate_pct
    FROM public.scout_gold_transactions_flat t
    WHERE t.transactiondate >= ISNULL(@date_from, DATEADD(day, -30, GETUTCDATE()))
      AND t.transactiondate <= ISNULL(@date_to, GETUTCDATE())
      AND t.location LIKE '%NCR%'
      AND (@category IS NULL OR t.category = @category)
      AND (@store_id IS NULL OR t.storeid = @store_id)
      AND t.category IS NOT NULL
      -- Identify substitution events
      AND (t.transcript_audio IS NOT NULL
           OR t.bought_with_other_brands IS NOT NULL
           OR t.transcript_audio LIKE '%substitute%'
           OR t.transcript_audio LIKE '%replace%'
           OR t.transcript_audio LIKE '%instead%')
    GROUP BY
        t.category,
        CASE
            WHEN t.transcript_audio LIKE '%out of stock%' OR t.transcript_audio LIKE '%wala%' THEN 'Out of Stock'
            WHEN t.transcript_audio LIKE '%expired%' OR t.transcript_audio LIKE '%sira%' THEN 'Quality Issue'
            WHEN t.transcript_audio LIKE '%expensive%' OR t.transcript_audio LIKE '%mahal%' THEN 'Price Concern'
            WHEN t.transcript_audio LIKE '%brand%' OR t.transcript_audio LIKE '%gusto%' THEN 'Brand Preference'
            WHEN t.transcript_audio LIKE '%size%' OR t.transcript_audio LIKE '%laki%' THEN 'Size Preference'
            WHEN t.bought_with_other_brands IS NOT NULL AND t.bought_with_other_brands != t.brand THEN 'Cross-Brand Bundle'
            ELSE 'Other/Unknown'
        END
),
category_totals AS (
    SELECT
        category,
        SUM(substitution_events) as total_category_substitutions
    FROM substitution_analysis
    GROUP BY category
),
reason_totals AS (
    SELECT
        substitution_reason,
        SUM(substitution_events) as total_reason_substitutions
    FROM substitution_analysis
    GROUP BY substitution_reason
)
SELECT
    sa.category,
    sa.substitution_reason,
    sa.substitution_events,
    ROUND(sa.substitution_revenue, 2) as substitution_revenue,
    ROUND(sa.avg_substitution_value, 2) as avg_substitution_value,
    sa.stores_affected,
    sa.brands_involved,
    sa.successful_substitutions,
    sa.acceptance_rate_pct,
    ROUND(100.0 * sa.substitution_events / ct.total_category_substitutions, 1) as category_share_pct,
    ROUND(100.0 * sa.substitution_events / rt.total_reason_substitutions, 1) as reason_share_pct,
    RANK() OVER (PARTITION BY sa.category ORDER BY sa.substitution_events DESC) as reason_rank_in_category,
    RANK() OVER (PARTITION BY sa.substitution_reason ORDER BY sa.substitution_events DESC) as category_rank_for_reason
FROM substitution_analysis sa
JOIN category_totals ct ON sa.category = ct.category
JOIN reason_totals rt ON sa.substitution_reason = rt.substitution_reason
WHERE sa.substitution_events >= ISNULL(@min_events, 3)
ORDER BY sa.substitution_events DESC, sa.acceptance_rate_pct DESC;

-- Template Metadata:
-- Expected Output: 15-50 rows (5-10 categories × 3-7 reasons)
-- Validation: acceptance_rate_pct should be between 0-100%
-- Validation: SUM(category_share_pct) per category should = 100%
-- Performance: ~300ms on 30 days of data
-- Dependencies: public.scout_gold_transactions_flat, transcript_audio field
-- Notes: Requires NLP enhancement for better reason extraction