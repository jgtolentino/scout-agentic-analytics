-- Scout Peak Hours Analysis Details
-- Hourly breakdown with store-level granularity

WITH hourly_store_breakdown AS (
  SELECT
    DATEPART(hour, t.transactiondate) as hour_ph,
    t.storeid,
    t.storename,
    COUNT(*) as store_hourly_count,
    SUM(t.total_price) as store_hourly_revenue,
    AVG(t.total_price) as store_avg_transaction,
    STRING_AGG(DISTINCT t.category, ', ') as categories_sold,
    STRING_AGG(DISTINCT t.payment_method, ', ') as payment_methods
  FROM public.scout_gold_transactions_flat t
  WHERE t.transactiondate >= DATEADD(day, -14, GETUTCDATE())
    AND t.location LIKE '%NCR%'
  GROUP BY DATEPART(hour, t.transactiondate), t.storeid, t.storename
),
store_rankings AS (
  SELECT
    *,
    RANK() OVER (PARTITION BY hour_ph ORDER BY store_hourly_count DESC) as store_rank_by_hour,
    ROUND(100.0 * store_hourly_count / SUM(store_hourly_count) OVER (PARTITION BY hour_ph), 1) as store_share_pct
  FROM hourly_store_breakdown
)
SELECT
  hour_ph,
  storename,
  store_hourly_count,
  ROUND(store_hourly_revenue, 2) as store_hourly_revenue,
  ROUND(store_avg_transaction, 2) as store_avg_transaction,
  categories_sold,
  payment_methods,
  store_share_pct,
  store_rank_by_hour,
  CASE
    WHEN hour_ph BETWEEN 6 AND 11 THEN 'Morning'
    WHEN hour_ph BETWEEN 12 AND 17 THEN 'Afternoon'
    WHEN hour_ph BETWEEN 18 AND 21 THEN 'Evening'
    ELSE 'Night'
  END as daypart
FROM store_rankings
WHERE store_rank_by_hour <= 5 -- Top 5 stores per hour
ORDER BY hour_ph, store_rank_by_hour;