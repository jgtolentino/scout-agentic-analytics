-- Scout Store Performance Details - Last 7 Days
-- Drill-down with daily breakdown

WITH daily_store_performance AS (
  SELECT
    t.storeid,
    t.storename,
    t.date_ph,
    COUNT(*) as daily_transactions,
    SUM(t.total_price) as daily_revenue,
    AVG(t.total_price) as avg_daily_transaction,
    COUNT(DISTINCT t.category) as daily_categories,
    STRING_AGG(DISTINCT t.payment_method, ', ') as payment_methods_used
  FROM public.scout_gold_transactions_flat t
  WHERE t.transactiondate >= DATEADD(day, -7, GETUTCDATE())
    AND t.location LIKE '%NCR%'
  GROUP BY t.storeid, t.storename, t.date_ph
)
SELECT
  storename,
  date_ph,
  daily_transactions,
  ROUND(daily_revenue, 2) as daily_revenue,
  ROUND(avg_daily_transaction, 2) as avg_daily_transaction,
  daily_categories,
  payment_methods_used,
  LAG(daily_transactions) OVER (PARTITION BY storeid ORDER BY date_ph) as prev_day_txns,
  CASE
    WHEN LAG(daily_transactions) OVER (PARTITION BY storeid ORDER BY date_ph) IS NULL THEN 0
    ELSE ROUND(100.0 * (daily_transactions - LAG(daily_transactions) OVER (PARTITION BY storeid ORDER BY date_ph)) /
               NULLIF(LAG(daily_transactions) OVER (PARTITION BY storeid ORDER BY date_ph), 0), 1)
  END as day_over_day_change_pct
FROM daily_store_performance
ORDER BY storename, date_ph DESC;