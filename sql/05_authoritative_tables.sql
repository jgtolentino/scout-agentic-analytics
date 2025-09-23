-- File: sql/05_authoritative_tables.sql
-- Authoritative tables for end-state Scout analytics
-- Purpose: DB-driven device mapping and store registry (no file sentinels)

-- Device→Store mapping (DB-driven; versioned)
IF OBJECT_ID('dbo.DeviceStoreMap','U') IS NULL
BEGIN
  CREATE TABLE dbo.DeviceStoreMap
  (
    DeviceID        nvarchar(64)  NOT NULL,
    StoreID         int           NOT NULL,
    EffectiveFrom   datetime2(0)  NOT NULL DEFAULT (SYSUTCDATETIME()),
    EffectiveTo     datetime2(0)  NULL,   -- NULL = open ended
    UpdatedBy       sysname       NOT NULL DEFAULT (SUSER_SNAME()),
    UpdatedAt       datetime2(0)  NOT NULL DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_DeviceStoreMap PRIMARY KEY CLUSTERED (DeviceID, EffectiveFrom)
  );

  CREATE INDEX IX_DeviceStoreMap_Current ON dbo.DeviceStoreMap(DeviceID, EffectiveTo) WHERE EffectiveTo IS NULL;
END

-- Stores (minimal, real DB mapping; no STORE-xxx.txt)
IF OBJECT_ID('dbo.Stores','U') IS NULL
BEGIN
  CREATE TABLE dbo.Stores
  (
    StoreID           int           NOT NULL PRIMARY KEY,
    StoreName         nvarchar(200) NOT NULL,
    MunicipalityName  nvarchar(100) NULL,
    BarangayName      nvarchar(120) NULL,
    GeoLatitude       float         NULL,
    GeoLongitude      float         NULL,
    CreatedAt         datetime2(0)  NOT NULL DEFAULT (SYSUTCDATETIME()),
    UpdatedAt         datetime2(0)  NOT NULL DEFAULT (SYSUTCDATETIME())
  );

  CREATE INDEX IX_Stores_Muni ON dbo.Stores (MunicipalityName);
END

-- Seed current device mappings based on existing PayloadTransactions data
IF NOT EXISTS (SELECT 1 FROM dbo.DeviceStoreMap)
BEGIN
  INSERT INTO dbo.DeviceStoreMap (DeviceID, StoreID)
  SELECT DISTINCT deviceId, TRY_CAST(storeId AS int)
  FROM dbo.PayloadTransactions
  WHERE deviceId IS NOT NULL AND TRY_CAST(storeId AS int) IS NOT NULL;

  PRINT 'Seeded DeviceStoreMap with ' + CAST(@@ROWCOUNT AS varchar(10)) + ' device-store mappings';
END

-- Seed stores based on existing data
IF NOT EXISTS (SELECT 1 FROM dbo.Stores)
BEGIN
  INSERT INTO dbo.Stores (StoreID, StoreName)
  SELECT DISTINCT TRY_CAST(storeId AS int), CONCAT('Store_', storeId)
  FROM dbo.PayloadTransactions
  WHERE TRY_CAST(storeId AS int) IS NOT NULL;

  PRINT 'Seeded Stores with ' + CAST(@@ROWCOUNT AS varchar(10)) + ' store records';
END