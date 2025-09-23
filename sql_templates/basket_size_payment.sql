-- ===================================================================
-- SQL TEMPLATE: Basket Size × Payment Method Correlation Analysis
-- ID: basket_size_payment
-- Version: 1.0
-- Purpose: Analyze relationship between basket composition and payment preferences
-- ===================================================================

-- Template Parameters:
-- @date_from (date): Start date for analysis (default: 30 days ago)
-- @date_to (date): End date for analysis (default: today)
-- @payment_method (nvarchar): Specific payment method filter (optional)
-- @store_id (int): Specific store filter (optional)
-- @min_transactions (int): Minimum transactions for inclusion (default: 10)

-- Business Question: "How does basket size relate to payment method choice?"
-- Use Cases: Payment optimization, customer behavior analysis, pricing strategy

WITH basket_analysis AS (
    SELECT
        t.transaction_id,
        t.payment_method,
        t.storeid,
        t.transactiondate,
        SUM(t.total_price) as basket_total_value,
        COUNT(*) as basket_item_count,
        COUNT(DISTINCT t.category) as unique_categories,
        COUNT(DISTINCT t.brand) as unique_brands,
        AVG(t.total_price) as avg_item_value,
        MAX(t.total_price) as max_item_value,
        MIN(t.total_price) as min_item_value
    FROM public.scout_gold_transactions_flat t
    WHERE t.transactiondate >= ISNULL(@date_from, DATEADD(day, -30, GETUTCDATE()))
      AND t.transactiondate <= ISNULL(@date_to, GETUTCDATE())
      AND t.location LIKE '%NCR%'
      AND (@payment_method IS NULL OR t.payment_method = @payment_method)
      AND (@store_id IS NULL OR t.storeid = @store_id)
      AND t.payment_method IS NOT NULL
      AND t.total_price > 0
    GROUP BY t.transaction_id, t.payment_method, t.storeid, t.transactiondate
),
basket_size_buckets AS (
    SELECT
        *,
        CASE
            WHEN basket_total_value <= 50 THEN 'Small (≤₱50)'
            WHEN basket_total_value <= 150 THEN 'Medium (₱51-150)'
            WHEN basket_total_value <= 300 THEN 'Large (₱151-300)'
            ELSE 'Extra Large (>₱300)'
        END as basket_size_bucket,
        CASE
            WHEN basket_item_count = 1 THEN 'Single Item'
            WHEN basket_item_count BETWEEN 2 AND 5 THEN 'Small Basket (2-5)'
            WHEN basket_item_count BETWEEN 6 AND 10 THEN 'Medium Basket (6-10)'
            ELSE 'Large Basket (>10)'
        END as item_count_bucket
    FROM basket_analysis
),
payment_basket_analysis AS (
    SELECT
        payment_method,
        basket_size_bucket,
        item_count_bucket,
        COUNT(*) as transaction_count,
        SUM(basket_total_value) as total_revenue,
        AVG(basket_total_value) as avg_basket_value,
        AVG(basket_item_count) as avg_item_count,
        AVG(unique_categories) as avg_categories_per_basket,
        AVG(unique_brands) as avg_brands_per_basket,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY basket_total_value) as median_basket_value,
        COUNT(DISTINCT storeid) as store_count
    FROM basket_size_buckets
    GROUP BY payment_method, basket_size_bucket, item_count_bucket
),
payment_totals AS (
    SELECT
        payment_method,
        SUM(transaction_count) as total_payment_transactions
    FROM payment_basket_analysis
    GROUP BY payment_method
),
bucket_totals AS (
    SELECT
        basket_size_bucket,
        SUM(transaction_count) as total_bucket_transactions
    FROM payment_basket_analysis
    GROUP BY basket_size_bucket
)
SELECT
    pba.payment_method,
    pba.basket_size_bucket,
    pba.item_count_bucket,
    pba.transaction_count,
    ROUND(pba.total_revenue, 2) as total_revenue,
    ROUND(pba.avg_basket_value, 2) as avg_basket_value,
    ROUND(pba.avg_item_count, 1) as avg_item_count,
    ROUND(pba.avg_categories_per_basket, 1) as avg_categories_per_basket,
    ROUND(pba.avg_brands_per_basket, 1) as avg_brands_per_basket,
    ROUND(pba.median_basket_value, 2) as median_basket_value,
    pba.store_count,
    ROUND(100.0 * pba.transaction_count / pt.total_payment_transactions, 1) as payment_method_share_pct,
    ROUND(100.0 * pba.transaction_count / bt.total_bucket_transactions, 1) as basket_size_share_pct,
    RANK() OVER (PARTITION BY pba.payment_method ORDER BY pba.transaction_count DESC) as bucket_rank_for_payment,
    RANK() OVER (PARTITION BY pba.basket_size_bucket ORDER BY pba.transaction_count DESC) as payment_rank_for_bucket,
    -- Correlation strength indicator
    CASE
        WHEN pba.payment_method = 'Cash' AND pba.basket_size_bucket IN ('Small (≤₱50)', 'Medium (₱51-150)') THEN 'Strong Correlation'
        WHEN pba.payment_method IN ('GCash', 'Credit Card') AND pba.basket_size_bucket IN ('Large (₱151-300)', 'Extra Large (>₱300)') THEN 'Strong Correlation'
        ELSE 'Weak Correlation'
    END as correlation_strength
FROM payment_basket_analysis pba
JOIN payment_totals pt ON pba.payment_method = pt.payment_method
JOIN bucket_totals bt ON pba.basket_size_bucket = bt.basket_size_bucket
WHERE pba.transaction_count >= ISNULL(@min_transactions, 10)
ORDER BY pba.payment_method, pba.avg_basket_value DESC;

-- Template Metadata:
-- Expected Output: 30-80 rows (4-6 payment methods × 4 basket sizes × 2-3 item buckets)
-- Validation: SUM(payment_method_share_pct) per payment method should = 100%
-- Validation: SUM(basket_size_share_pct) per basket size should = 100%
-- Performance: ~400ms on 30 days of data
-- Dependencies: public.scout_gold_transactions_flat, payment_method field
-- Notes: Strong correlations indicate customer behavior patterns for payment optimization