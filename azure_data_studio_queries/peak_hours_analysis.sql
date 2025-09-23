-- Scout Peak Hours Analysis
-- For Azure Data Studio Dashboard

WITH hourly_transactions AS (
  SELECT
    DATEPART(hour, t.transactiondate) as hour_ph,
    COUNT(*) as hourly_count,
    SUM(t.total_price) as hourly_revenue,
    AVG(t.total_price) as avg_hourly_transaction,
    COUNT(DISTINCT t.storeid) as active_stores
  FROM public.scout_gold_transactions_flat t
  WHERE t.transactiondate >= DATEADD(day, -14, GETUTCDATE())
    AND t.location LIKE '%NCR%'
  GROUP BY DATEPART(hour, t.transactiondate)
),
peak_analysis AS (
  SELECT
    *,
    AVG(hourly_count) OVER () as avg_transactions,
    RANK() OVER (ORDER BY hourly_count DESC) as peak_rank,
    ROUND(100.0 * hourly_count / SUM(hourly_count) OVER (), 1) as hour_share_pct
  FROM hourly_transactions
)
SELECT
  hour_ph,
  hourly_count,
  ROUND(avg_transactions, 1) as avg_transactions,
  ROUND(hourly_revenue, 2) as hourly_revenue,
  ROUND(avg_hourly_transaction, 2) as avg_hourly_transaction,
  active_stores,
  hour_share_pct,
  CASE
    WHEN peak_rank <= 3 THEN 'Peak Hour'
    WHEN hourly_count >= avg_transactions THEN 'Above Average'
    ELSE 'Below Average'
  END as hour_category,
  CASE
    WHEN hour_ph BETWEEN 6 AND 11 THEN 'Morning'
    WHEN hour_ph BETWEEN 12 AND 17 THEN 'Afternoon'
    WHEN hour_ph BETWEEN 18 AND 21 THEN 'Evening'
    ELSE 'Night'
  END as daypart
FROM peak_analysis
ORDER BY hour_ph;