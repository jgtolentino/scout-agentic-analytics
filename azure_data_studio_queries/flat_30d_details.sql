-- Scout Flat Transactions - Last 30 Days Detailed View
-- Drill-down query for ADS dashboard

SELECT TOP 200
  t.date_ph,
  t.storename,
  t.category,
  t.brand,
  t.product,
  t.qty,
  t.total_price,
  t.payment_method,
  t.time_of_day,
  t.gender,
  t.agebracket,
  t.location
FROM public.scout_gold_transactions_flat t
WHERE t.transactiondate >= DATEADD(day, -30, GETUTCDATE())
  AND t.location LIKE '%NCR%'
ORDER BY t.transactiondate DESC, t.total_price DESC;