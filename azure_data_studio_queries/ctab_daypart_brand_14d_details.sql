-- Scout Cross-tab Detailed View: Daypart × Brand - Last 14 Days
-- Drill-down with transaction-level details

WITH daypart_mapping AS (
  SELECT
    t.*,
    CASE
      WHEN DATEPART(hour, t.transactiondate) BETWEEN 6 AND 11 THEN 'Morning'
      WHEN DATEPART(hour, t.transactiondate) BETWEEN 12 AND 17 THEN 'Afternoon'
      WHEN DATEPART(hour, t.transactiondate) BETWEEN 18 AND 21 THEN 'Evening'
      ELSE 'Night'
    END as daypart
  FROM public.scout_gold_transactions_flat t
  WHERE t.transactiondate >= DATEADD(day, -14, GETUTCDATE())
    AND t.location LIKE '%NCR%'
    AND t.brand IS NOT NULL
)
SELECT
  daypart,
  brand,
  date_ph,
  time_ph,
  storename,
  product,
  category,
  qty,
  unit_price,
  total_price,
  payment_method,
  gender,
  agebracket,
  location,
  RANK() OVER (PARTITION BY daypart, brand ORDER BY total_price DESC) as price_rank
FROM daypart_mapping
ORDER BY daypart, brand, total_price DESC;