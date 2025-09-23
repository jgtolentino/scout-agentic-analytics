-- Scout Flat Transactions - Last 30 Days Summary
-- For Azure Data Studio Dashboard Tile

WITH flat_30d AS (
  SELECT
    t.*
  FROM public.scout_gold_transactions_flat t
  WHERE t.transactiondate >= DATEADD(day, -30, GETUTCDATE())
    AND s.location LIKE '%NCR%' -- NCR bounds compliance
),
metrics AS (
  SELECT
    'Total Transactions' as metric,
    COUNT(*) as value,
    1 as sort_order
  FROM flat_30d

  UNION ALL

  SELECT
    'Total Revenue',
    ROUND(SUM(total_price), 2),
    2
  FROM flat_30d

  UNION ALL

  SELECT
    'Unique Stores',
    COUNT(DISTINCT storeid),
    3
  FROM flat_30d

  UNION ALL

  SELECT
    'Avg Basket Size',
    ROUND(AVG(total_price), 2),
    4
  FROM flat_30d

  UNION ALL

  SELECT
    'Peak Hour',
    (SELECT TOP 1 DATEPART(hour, transactiondate)
     FROM flat_30d
     GROUP BY DATEPART(hour, transactiondate)
     ORDER BY COUNT(*) DESC),
    5
  FROM flat_30d
  WHERE 1=1 -- Dummy condition for UNION ALL
)
SELECT
  metric,
  value
FROM metrics
ORDER BY sort_order;