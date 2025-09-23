-- Scout Store Performance - Last 7 Days
-- For Azure Data Studio Dashboard

WITH store_metrics AS (
  SELECT
    t.storeid,
    t.storename,
    t.location,
    COUNT(*) as total_transactions,
    SUM(t.total_price) as total_revenue,
    AVG(t.total_price) as avg_transaction,
    COUNT(DISTINCT t.category) as categories_sold,
    COUNT(DISTINCT t.brand) as brands_sold,
    MIN(t.transactiondate) as first_transaction,
    MAX(t.transactiondate) as last_transaction
  FROM public.scout_gold_transactions_flat t
  WHERE t.transactiondate >= DATEADD(day, -7, GETUTCDATE())
    AND t.location LIKE '%NCR%'
  GROUP BY t.storeid, t.storename, t.location
),
performance_ranked AS (
  SELECT
    *,
    RANK() OVER (ORDER BY total_transactions DESC) as txn_rank,
    RANK() OVER (ORDER BY total_revenue DESC) as revenue_rank,
    ROUND(100.0 * total_transactions / SUM(total_transactions) OVER (), 1) as txn_share_pct
  FROM store_metrics
)
SELECT
  storename as store_name,
  total_transactions,
  ROUND(total_revenue, 2) as total_revenue,
  ROUND(avg_transaction, 2) as avg_transaction,
  categories_sold,
  brands_sold,
  txn_share_pct,
  CASE
    WHEN txn_rank <= 3 THEN 'Top Performer'
    WHEN txn_rank <= CEILING(COUNT(*) OVER () * 0.5) THEN 'Above Average'
    ELSE 'Below Average'
  END as performance_tier
FROM performance_ranked
ORDER BY total_transactions DESC;