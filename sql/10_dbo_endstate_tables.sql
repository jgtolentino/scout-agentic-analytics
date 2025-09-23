IF SCHEMA_ID('dbo') IS NULL THROW 50000, 'dbo schema missing', 1;
GO
IF OBJECT_ID('dbo.Stores','U') IS NULL
CREATE TABLE dbo.Stores(
  StoreID int NOT NULL PRIMARY KEY,
  StoreName nvarchar(200) NOT NULL,
  Location nvarchar(400) NULL,
  Size nvarchar(50) NULL,
  Region varchar(16) NOT NULL DEFAULT('NCR'),
  ProvinceName nvarchar(60) NOT NULL DEFAULT(N'Metro Manila'),
  MunicipalityName nvarchar(100) NOT NULL,
  BarangayName nvarchar(120) NULL,
  psgc_region char(9) NULL, psgc_citymun char(9) NULL, psgc_barangay char(9) NULL,
  GeoLatitude float NULL, GeoLongitude float NULL, StorePolygon nvarchar(max) NULL,
  DeviceID nvarchar(64) NULL, DeviceName nvarchar(100) NULL,
  CreatedAt datetime2(0) NOT NULL DEFAULT (sysutcdatetime()),
  UpdatedAt datetime2(0) NOT NULL DEFAULT (sysutcdatetime())
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name='CK_dboStores_NCRBounds')
ALTER TABLE dbo.Stores WITH NOCHECK ADD CONSTRAINT CK_dboStores_NCRBounds
CHECK (GeoLatitude IS NULL OR (GeoLatitude BETWEEN 14.20 AND 14.90));
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name='CK_dboStores_LonBounds')
ALTER TABLE dbo.Stores WITH NOCHECK ADD CONSTRAINT CK_dboStores_LonBounds
CHECK (GeoLongitude IS NULL OR (GeoLongitude BETWEEN 120.90 AND 121.20));
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name='CK_dboStores_GeomPresence')
ALTER TABLE dbo.Stores WITH NOCHECK ADD CONSTRAINT CK_dboStores_GeomPresence
CHECK (StorePolygon IS NOT NULL OR (GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL));
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Stores_Muni')
CREATE INDEX IX_Stores_Muni ON dbo.Stores (MunicipalityName) INCLUDE (GeoLatitude,GeoLongitude,StorePolygon);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Stores_Device')
CREATE INDEX IX_Stores_Device ON dbo.Stores (DeviceID);
GO

IF OBJECT_ID('dbo.StoreLocationStaging','U') IS NULL
CREATE TABLE dbo.StoreLocationStaging(
  StoreID int NOT NULL,
  StoreName nvarchar(200) NULL,
  Region varchar(16) NULL, ProvinceName nvarchar(60) NULL,
  MunicipalityName nvarchar(100) NULL, BarangayName nvarchar(120) NULL,
  psgc_region char(9) NULL, psgc_citymun char(9) NULL, psgc_barangay char(9) NULL,
  GeoLatitude float NULL, GeoLongitude float NULL, StorePolygon nvarchar(max) NULL,
  DeviceID nvarchar(64) NULL, DeviceName nvarchar(100) NULL,
  _source_path nvarchar(400) NULL, _load_ts datetime2(0) NOT NULL DEFAULT (sysutcdatetime())
);
GO

IF OBJECT_ID('dbo.fact_transactions_location','U') IS NULL
CREATE TABLE dbo.fact_transactions_location(
  transactionId varchar(64) NOT NULL,
  storeId int NOT NULL,
  deviceId varchar(64) NULL,
  StoreName nvarchar(200) NULL,
  Region varchar(8) NOT NULL,
  ProvinceName nvarchar(50) NOT NULL,
  MunicipalityName nvarchar(80) NOT NULL,
  BarangayName nvarchar(120) NULL,
  psgc_region char(9) NULL, psgc_citymun char(9) NULL, psgc_barangay char(9) NULL,
  GeoLatitude float NULL, GeoLongitude float NULL, StorePolygon nvarchar(max) NULL,
  AgeBracket nvarchar(50) NULL, Gender nvarchar(20) NULL, Role nvarchar(50) NULL,
  WeekdayOrWeekend varchar(8) NULL, TimeOfDay char(4) NULL, BasketFlag bit NOT NULL DEFAULT(0),
  category nvarchar(100) NULL, brand nvarchar(120) NULL,
  amount decimal(12,2) NULL, basket_item_count int NULL, substitution_flag bit NULL,
  payload_json nvarchar(max) NULL, source_path nvarchar(400) NULL, txn_ts datetime2(0) NULL,
  CONSTRAINT PK_fact_txn_loc PRIMARY KEY CLUSTERED(transactionId, storeId),
  CONSTRAINT CK_Fact_Region CHECK (Region='NCR'),
  CONSTRAINT CK_Fact_Prov CHECK (ProvinceName=N'Metro Manila'),
  CONSTRAINT CK_Fact_Geom CHECK (StorePolygon IS NOT NULL OR (GeoLatitude IS NOT NULL AND GeoLongitude IS NOT NULL)),
  CONSTRAINT FK_Fact_Store FOREIGN KEY (storeId) REFERENCES dbo.Stores(StoreID)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Fact_txn_ts')
CREATE INDEX IX_Fact_txn_ts ON dbo.fact_transactions_location (txn_ts)
INCLUDE (storeId,category,brand,amount,TimeOfDay,WeekdayOrWeekend);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Fact_store')
CREATE INDEX IX_Fact_store ON dbo.fact_transactions_location (storeId)
INCLUDE (MunicipalityName,category,brand,amount);
GO
