IF OBJECT_ID('dbo.sp_upsert_enriched_stores','P') IS NOT NULL DROP PROCEDURE dbo.sp_upsert_enriched_stores;
GO
CREATE PROCEDURE dbo.sp_upsert_enriched_stores AS
BEGIN
  SET NOCOUNT ON;
  ;WITH norm AS (
    SELECT
      s.StoreID,
      NULLIF(LTRIM(RTRIM(s.StoreName)),N'') AS StoreName,
      COALESCE(NULLIF(s.Region,''),'NCR') AS Region,
      COALESCE(NULLIF(s.ProvinceName,''),N'Metro Manila') AS ProvinceName,
      CASE UPPER(LTRIM(RTRIM(s.MunicipalityName)))
        WHEN 'QC' THEN 'Quezon City'
        WHEN 'PARANAQUE' THEN N'Parañaque'
        ELSE s.MunicipalityName END AS MunicipalityName,
      NULLIF(s.BarangayName,'') AS BarangayName,
      s.psgc_region, s.psgc_citymun, s.psgc_barangay,
      s.GeoLatitude, s.GeoLongitude, s.StorePolygon,
      NULLIF(s.DeviceID,'') AS DeviceID, NULLIF(s.DeviceName,'') AS DeviceName
    FROM dbo.StoreLocationStaging s
  )
  MERGE dbo.Stores AS tgt
  USING norm AS src ON tgt.StoreID=src.StoreID
  WHEN MATCHED THEN UPDATE SET
    tgt.StoreName=COALESCE(src.StoreName,tgt.StoreName),
    tgt.Region=COALESCE(src.Region,tgt.Region),
    tgt.ProvinceName=COALESCE(src.ProvinceName,tgt.ProvinceName),
    tgt.MunicipalityName=COALESCE(src.MunicipalityName,tgt.MunicipalityName),
    tgt.BarangayName=COALESCE(src.BarangayName,tgt.BarangayName),
    tgt.psgc_region=COALESCE(src.psgc_region,tgt.psgc_region),
    tgt.psgc_citymun=COALESCE(src.psgc_citymun,tgt.psgc_citymun),
    tgt.psgc_barangay=COALESCE(src.psgc_barangay,tgt.psgc_barangay),
    tgt.GeoLatitude=COALESCE(src.GeoLatitude,tgt.GeoLatitude),
    tgt.GeoLongitude=COALESCE(src.GeoLongitude,tgt.GeoLongitude),
    tgt.StorePolygon=COALESCE(src.StorePolygon,tgt.StorePolygon),
    tgt.DeviceID=COALESCE(src.DeviceID,tgt.DeviceID),
    tgt.DeviceName=COALESCE(src.DeviceName,tgt.DeviceName),
    tgt.UpdatedAt=sysutcdatetime()
  WHEN NOT MATCHED BY TARGET THEN
    INSERT (StoreID,StoreName,Region,ProvinceName,MunicipalityName,BarangayName,
            psgc_region,psgc_citymun,psgc_barangay,
            GeoLatitude,GeoLongitude,StorePolygon,DeviceID,DeviceName,CreatedAt,UpdatedAt)
    VALUES (src.StoreID,src.StoreName,src.Region,src.ProvinceName,src.MunicipalityName,src.BarangayName,
            src.psgc_region,src.psgc_citymun,src.psgc_barangay,
            src.GeoLatitude,src.GeoLongitude,src.StorePolygon,src.DeviceID,src.DeviceName,sysutcdatetime(),sysutcdatetime());
END
GO

IF OBJECT_ID('dbo.sp_build_fact_from_staging','P') IS NOT NULL DROP PROCEDURE dbo.sp_build_fact_from_staging;
GO
CREATE PROCEDURE dbo.sp_build_fact_from_staging AS
BEGIN
  SET NOCOUNT ON;
  MERGE dbo.fact_transactions_location AS tgt
  USING (
    SELECT
      t.transactionId, t.storeId, t.deviceId,
      s.StoreName, s.Region, s.ProvinceName, s.MunicipalityName, s.BarangayName,
      s.psgc_region, s.psgc_citymun, s.psgc_barangay,
      s.GeoLatitude, s.GeoLongitude, s.StorePolygon,
      t.AgeBracket, t.Gender, t.Role,
      t.WeekdayOrWeekend, t.TimeOfDay, t.BasketFlag,
      t.category, t.brand, t.amount, t.basket_item_count, t.substitution_flag,
      t.payload_json, t.source_path, t.txn_ts
    FROM staging.TransactionsStaging t
    JOIN dbo.Stores s ON s.StoreID = t.storeId
  ) AS src
  ON (tgt.transactionId=src.transactionId AND tgt.storeId=src.storeId)
  WHEN MATCHED THEN UPDATE SET
    tgt.deviceId=COALESCE(src.deviceId,tgt.deviceId),
    tgt.StoreName=COALESCE(src.StoreName,tgt.StoreName),
    tgt.Region=src.Region, tgt.ProvinceName=src.ProvinceName,
    tgt.MunicipalityName=src.MunicipalityName, tgt.BarangayName=COALESCE(src.BarangayName,tgt.BarangayName),
    tgt.psgc_region=COALESCE(src.psgc_region,tgt.psgc_region),
    tgt.psgc_citymun=COALESCE(src.psgc_citymun,tgt.psgc_citymun),
    tgt.psgc_barangay=COALESCE(src.psgc_barangay,tgt.psgc_barangay),
    tgt.GeoLatitude=COALESCE(src.GeoLatitude,tgt.GeoLatitude),
    tgt.GeoLongitude=COALESCE(src.GeoLongitude,tgt.GeoLongitude),
    tgt.StorePolygon=COALESCE(src.StorePolygon,tgt.StorePolygon),
    tgt.AgeBracket=COALESCE(src.AgeBracket,tgt.AgeBracket),
    tgt.Gender=COALESCE(src.Gender,tgt.Gender),
    tgt.Role=COALESCE(src.Role,tgt.Role),
    tgt.WeekdayOrWeekend=COALESCE(src.WeekdayOrWeekend,tgt.WeekdayOrWeekend),
    tgt.TimeOfDay=COALESCE(src.TimeOfDay,tgt.TimeOfDay),
    tgt.BasketFlag=COALESCE(src.BasketFlag,tgt.BasketFlag),
    tgt.category=COALESCE(src.category,tgt.category),
    tgt.brand=COALESCE(src.brand,tgt.brand),
    tgt.amount=COALESCE(src.amount,tgt.amount),
    tgt.basket_item_count=COALESCE(src.basket_item_count,tgt.basket_item_count),
    tgt.substitution_flag=COALESCE(src.substitution_flag,tgt.substitution_flag),
    tgt.payload_json=COALESCE(src.payload_json,tgt.payload_json),
    tgt.source_path=COALESCE(src.source_path,tgt.source_path),
    tgt.txn_ts=COALESCE(src.txn_ts,tgt.txn_ts)
  WHEN NOT MATCHED BY TARGET THEN
    INSERT (transactionId,storeId,deviceId,StoreName,Region,ProvinceName,MunicipalityName,BarangayName,
            psgc_region,psgc_citymun,psgc_barangay,
            GeoLatitude,GeoLongitude,StorePolygon,
            AgeBracket,Gender,Role,WeekdayOrWeekend,TimeOfDay,BasketFlag,
            category,brand,amount,basket_item_count,substitution_flag,
            payload_json,source_path,txn_ts)
    VALUES (src.transactionId,src.storeId,src.deviceId,src.StoreName,
            src.Region,src.ProvinceName,src.MunicipalityName,src.BarangayName,
            src.psgc_region,src.psgc_citymun,src.psgc_barangay,
            src.GeoLatitude,src.GeoLongitude,src.StorePolygon,
            src.AgeBracket,src.Gender,src.Role,src.WeekdayOrWeekend,src.TimeOfDay,src.BasketFlag,
            src.category,src.brand,src.amount,src.basket_item_count,src.substitution_flag,
            src.payload_json,src.source_path,src.txn_ts);
END
GO

IF OBJECT_ID('dbo.sp_health_dbo_endstate','P') IS NOT NULL DROP PROCEDURE dbo.sp_health_dbo_endstate;
GO
CREATE PROCEDURE dbo.sp_health_dbo_endstate AS
BEGIN
  SET NOCOUNT ON;
  SELECT COUNT(*) AS stores,
         SUM(CASE WHEN StorePolygon IS NULL AND (GeoLatitude IS NULL OR GeoLongitude IS NULL) THEN 1 ELSE 0 END) AS stores_missing_geom
  FROM dbo.Stores;

  SELECT COUNT(*) AS fact_rows, MIN(txn_ts) AS min_ts, MAX(txn_ts) AS max_ts
  FROM dbo.fact_transactions_location;

  SELECT
    SUM(CASE WHEN Region <> 'NCR' THEN 1 ELSE 0 END) AS bad_region,
    SUM(CASE WHEN ProvinceName <> N'Metro Manila' THEN 1 ELSE 0 END) AS bad_prov,
    SUM(CASE WHEN MunicipalityName IS NULL THEN 1 ELSE 0 END) AS missing_muni,
    SUM(CASE WHEN (StorePolygon IS NULL AND (GeoLatitude IS NULL OR GeoLongitude IS NULL)) THEN 1 ELSE 0 END) AS missing_geom
  FROM dbo.fact_transactions_location;
END
GO