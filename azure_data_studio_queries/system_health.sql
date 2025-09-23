-- Scout System Health Check
-- For Azure Data Studio Server Dashboard

WITH data_freshness AS (
  SELECT
    'Data Freshness' as metric,
    DATEDIFF(minute, MAX(t.transactiondate), GETUTCDATE()) as minutes_behind,
    CASE
      WHEN DATEDIFF(minute, MAX(t.transactiondate), GETUTCDATE()) <= 60 THEN 'Healthy'
      WHEN DATEDIFF(minute, MAX(t.transactiondate), GETUTCDATE()) <= 240 THEN 'Warning'
      ELSE 'Critical'
    END as status
  FROM public.scout_gold_transactions_flat t
),
data_quality AS (
  SELECT
    'Data Quality' as metric,
    ROUND(100.0 * COUNT(CASE WHEN t.total_price > 0 AND t.storeid IS NOT NULL THEN 1 END) / COUNT(*), 1) as quality_score,
    CASE
      WHEN 100.0 * COUNT(CASE WHEN t.total_price > 0 AND t.storeid IS NOT NULL THEN 1 END) / COUNT(*) >= 95 THEN 'Healthy'
      WHEN 100.0 * COUNT(CASE WHEN t.total_price > 0 AND t.storeid IS NOT NULL THEN 1 END) / COUNT(*) >= 90 THEN 'Warning'
      ELSE 'Critical'
    END as status
  FROM public.scout_gold_transactions_flat t
  WHERE t.transactiondate >= DATEADD(hour, -24, GETUTCDATE())
),
store_coverage AS (
  SELECT
    'Store Coverage' as metric,
    COUNT(DISTINCT t.storeid) as active_stores_24h,
    CASE
      WHEN COUNT(DISTINCT t.storeid) >= 6 THEN 'Healthy'
      WHEN COUNT(DISTINCT t.storeid) >= 4 THEN 'Warning'
      ELSE 'Critical'
    END as status
  FROM public.scout_gold_transactions_flat t
  WHERE t.transactiondate >= DATEADD(hour, -24, GETUTCDATE())
),
transaction_volume AS (
  SELECT
    'Transaction Volume' as metric,
    COUNT(*) as txns_24h,
    CASE
      WHEN COUNT(*) >= 100 THEN 'Healthy'
      WHEN COUNT(*) >= 50 THEN 'Warning'
      ELSE 'Critical'
    END as status
  FROM public.scout_gold_transactions_flat t
  WHERE t.transactiondate >= DATEADD(hour, -24, GETUTCDATE())
)
SELECT
  metric,
  CASE
    WHEN metric = 'Data Freshness' THEN CAST(minutes_behind AS varchar)
    WHEN metric = 'Data Quality' THEN CAST(quality_score AS varchar) + '%'
    WHEN metric = 'Store Coverage' THEN CAST(active_stores_24h AS varchar) + ' stores'
    WHEN metric = 'Transaction Volume' THEN CAST(txns_24h AS varchar) + ' txns'
  END as value,
  status,
  CASE
    WHEN status = 'Healthy' THEN 1
    WHEN status = 'Warning' THEN 0.5
    ELSE 0
  END as health_score
FROM (
  SELECT metric, minutes_behind, NULL as quality_score, NULL as active_stores_24h, NULL as txns_24h, status FROM data_freshness
  UNION ALL
  SELECT metric, NULL, quality_score, NULL, NULL, status FROM data_quality
  UNION ALL
  SELECT metric, NULL, NULL, active_stores_24h, NULL, status FROM store_coverage
  UNION ALL
  SELECT metric, NULL, NULL, NULL, txns_24h, status FROM transaction_volume
) combined
ORDER BY health_score DESC;