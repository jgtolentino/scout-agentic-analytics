SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER VIEW dbo.v_transactions_flat_v24
AS
/* 24-column compatibility view
   - Source of truth: dbo.v_transactions_flat (already enforces NCR + geom guards)
   - DeviceID is picked from fact via key (transactionId, storeId)
*/
SELECT
  t.transactionId                         AS CanonicalTxID,
  t.transactionId                         AS TransactionID,
  f.deviceId                              AS DeviceID,            -- may be NULL if not present
  t.storeId                               AS StoreID,
  t.StoreName                             AS StoreName,
  t.Region                                AS Region,
  t.ProvinceName                          AS ProvinceName,
  t.MunicipalityName                      AS MunicipalityName,
  t.BarangayName                          AS BarangayName,
  t.psgc_region                           AS psgc_region,
  t.psgc_citymun                          AS psgc_citymun,
  t.psgc_barangay                         AS psgc_barangay,
  t.GeoLatitude                           AS GeoLatitude,
  t.GeoLongitude                          AS GeoLongitude,
  t.StorePolygon                          AS StorePolygon,
  t.amount                                AS Amount,
  t.basket_item_count                     AS Basket_Item_Count,
  t.WeekdayOrWeekend                      AS WeekdayOrWeekend,
  /* Spec column name: TimeOfDay (char(4)). Our flat view exposes daypart already. */
  t.daypart                               AS TimeOfDay,
  t.AgeBracket                            AS AgeBracket,
  t.Gender                                AS Gender,
  t.Role                                  AS Role,
  t.substitution_flag                     AS Substitution_Flag,
  t.txn_ts                                AS Txn_TS
FROM dbo.v_transactions_flat AS t
LEFT JOIN dbo.fact_transactions_location AS f
  ON f.transactionId = t.transactionId
 AND f.storeId       = t.storeId;
GO

/* Optional: make sure the reader can select (usually covered by db_datareader) */
GRANT SELECT ON OBJECT::dbo.v_transactions_flat_v24 TO [scout_reader];
GO