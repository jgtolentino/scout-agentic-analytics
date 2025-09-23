-- Scout Cross-tab: Daypart × Brand Analysis - Last 14 Days
-- For Azure Data Studio Dashboard

WITH daypart_mapping AS (
  SELECT
    t.time_of_day,
    CASE
      WHEN DATEPART(hour, t.transactiondate) BETWEEN 6 AND 11 THEN 'Morning'
      WHEN DATEPART(hour, t.transactiondate) BETWEEN 12 AND 17 THEN 'Afternoon'
      WHEN DATEPART(hour, t.transactiondate) BETWEEN 18 AND 21 THEN 'Evening'
      ELSE 'Night'
    END as daypart,
    t.brand,
    t.total_price,
    t.storeid
  FROM public.scout_gold_transactions_flat t
  WHERE t.transactiondate >= DATEADD(day, -14, GETUTCDATE())
    AND t.location LIKE '%NCR%'
    AND t.brand IS NOT NULL
),
crosstab_data AS (
  SELECT
    daypart,
    brand,
    COUNT(*) as txn_count,
    SUM(total_price) as total_revenue,
    COUNT(DISTINCT storeid) as store_count,
    AVG(total_price) as avg_transaction
  FROM daypart_mapping
  GROUP BY daypart, brand
)
SELECT
  daypart,
  brand,
  txn_count,
  ROUND(total_revenue, 2) as total_revenue,
  store_count,
  ROUND(avg_transaction, 2) as avg_transaction,
  ROUND(100.0 * txn_count / SUM(txn_count) OVER (PARTITION BY daypart), 1) as share_pct
FROM crosstab_data
WHERE txn_count >= 5 -- Filter for statistical significance
ORDER BY daypart, txn_count DESC;