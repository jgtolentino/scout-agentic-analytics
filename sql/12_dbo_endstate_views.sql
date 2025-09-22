IF OBJECT_ID('dbo.v_transactions_flat','V') IS NULL
EXEC('
CREATE VIEW dbo.v_transactions_flat AS
SELECT
  transactionId, storeId, StoreName,
  Region, ProvinceName, MunicipalityName, BarangayName,
  psgc_region, psgc_citymun, psgc_barangay,
  GeoLatitude, GeoLongitude, StorePolygon,
  AgeBracket, Gender, Role,
  WeekdayOrWeekend,
  TimeOfDay AS daypart,
  BasketFlag,
  category, brand, amount, basket_item_count, substitution_flag,
  payload_json, source_path,
  CAST(txn_ts AS datetime2(0)) AS txn_ts
FROM dbo.fact_transactions_location WITH (NOEXPAND)
WHERE Region = ''NCR''
  AND ProvinceName = N''Metro Manila''
  AND (StorePolygon IS NOT NULL OR (GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL));
');
GO

IF OBJECT_ID('dbo.v_transactions_crosstab','V') IS NULL
EXEC('
CREATE VIEW dbo.v_transactions_crosstab AS
WITH base AS (
  SELECT CONVERT(date, txn_ts) AS [date],
         storeId AS store_id,
         MunicipalityName AS municipality,
         category, brand,
         TimeOfDay AS daypart,
         amount, basket_item_count
  FROM dbo.v_transactions_flat
)
SELECT [date], store_id, municipality, daypart, brand, category,
       COUNT(*) AS txn_count,
       SUM(amount) AS total_amount,
       AVG(CAST(basket_item_count AS float)) AS avg_basket_items
FROM base
GROUP BY [date], store_id, municipality, daypart, brand, category;
');
GO