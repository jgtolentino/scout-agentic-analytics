SET NOCOUNT ON;
SET XACT_ABORT ON;

-------------------------------------------------------------------------------
-- Guards
-------------------------------------------------------------------------------
IF OBJECT_ID('dbo.PayloadTransactions','U') IS NULL
  THROW 51000, 'dbo.PayloadTransactions missing.', 1;

IF COL_LENGTH('dbo.PayloadTransactions','PayloadJson') IS NULL
  THROW 51001, 'PayloadTransactions.PayloadJson NVARCHAR(MAX) missing.', 1;

IF OBJECT_ID('dbo.TransactionItems','U') IS NULL
  THROW 51002, 'dbo.TransactionItems missing.', 1;

IF OBJECT_ID('ref.NielsenCategories','U') IS NULL
  THROW 51003, 'ref.NielsenCategories missing. Deploy taxonomy first.', 1;

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='ref') EXEC('CREATE SCHEMA ref;');

-------------------------------------------------------------------------------
-- SKU dimension (create/align)
-------------------------------------------------------------------------------
IF OBJECT_ID('ref.SkuDimensions','U') IS NULL
BEGIN
  CREATE TABLE ref.SkuDimensions(
    sku_id        INT IDENTITY(1,1) PRIMARY KEY,
    SkuCode       NVARCHAR(100) NOT NULL,
    SkuName       NVARCHAR(300) NOT NULL,
    BrandName     NVARCHAR(255) NOT NULL,
    BrandNameNorm AS LOWER(REPLACE(REPLACE(BrandName,' ',''),'-','')),
    CategoryCode  NVARCHAR(50)  NULL, -- FK -> ref.NielsenCategories.category_code
    PackSize      NVARCHAR(100) NULL,
    IsActive      BIT NOT NULL DEFAULT(1),
    CreatedUtc    DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedUtc    DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
  );
  CREATE INDEX IX_SkuDimensions_BrandCode ON ref.SkuDimensions(BrandNameNorm, SkuCode);
END
ELSE
BEGIN
  IF (SELECT CHARACTER_MAXIMUM_LENGTH
      FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_SCHEMA='ref' AND TABLE_NAME='SkuDimensions' AND COLUMN_NAME='CategoryCode') <> 50
  BEGIN
    ALTER TABLE ref.SkuDimensions ALTER COLUMN CategoryCode NVARCHAR(50) NULL;
  END
END

IF COL_LENGTH('dbo.TransactionItems','sku_id') IS NULL
  ALTER TABLE dbo.TransactionItems ADD sku_id INT NULL;

-------------------------------------------------------------------------------
-- Stage payload → SKUs
-------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#stg_SkuFromPayload','U') IS NOT NULL DROP TABLE #stg_SkuFromPayload;
CREATE TABLE #stg_SkuFromPayload(
  canonical_tx_id NVARCHAR(100),
  SkuCode         NVARCHAR(100),
  SkuName         NVARCHAR(300),
  BrandName       NVARCHAR(255),
  CategoryName    NVARCHAR(300),
  Qty             INT,
  PackSize        NVARCHAR(100)
);

INSERT INTO #stg_SkuFromPayload(canonical_tx_id,SkuCode,SkuName,BrandName,CategoryName,Qty,PackSize)
SELECT
  pt.canonical_tx_id,
  NULLIF(LTRIM(RTRIM(j.[sku])),'')                                 AS SkuCode,
  NULLIF(LTRIM(RTRIM(COALESCE(j.[productName], j.[itemName]))),'')  AS SkuName,
  NULLIF(LTRIM(RTRIM(j.[brandName])),'')                            AS BrandName,
  NULLIF(LTRIM(RTRIM(j.[category])),'')                             AS CategoryName,
  TRY_CONVERT(INT, j.[quantity])                                    AS Qty,
  NULLIF(LTRIM(RTRIM(COALESCE(j.[packSize], j.[size]))),'')         AS PackSize
FROM dbo.PayloadTransactions pt
CROSS APPLY OPENJSON(pt.PayloadJson, '$.items')
WITH (
  brandName   NVARCHAR(255)  '$.brandName',
  productName NVARCHAR(300)  '$.productName',
  itemName    NVARCHAR(300)  '$.itemName',
  sku         NVARCHAR(100)  '$.sku',
  category    NVARCHAR(300)  '$.category',
  quantity    NVARCHAR(50)   '$.quantity',
  packSize    NVARCHAR(100)  '$.packSize',
  size        NVARCHAR(100)  '$.size'
) AS j;

DELETE FROM #stg_SkuFromPayload
WHERE BrandName IS NULL OR SkuName IS NULL;

-------------------------------------------------------------------------------
-- Upsert into ref.SkuDimensions (resolve CategoryCode by name if available)
-------------------------------------------------------------------------------
;WITH src AS (
  SELECT DISTINCT
    SkuCode = COALESCE(SkuCode, CONCAT(LOWER(REPLACE(REPLACE(BrandName,' ',''),'-','')),':',LOWER(REPLACE(REPLACE(SkuName,' ',''),'-','')))),
    SkuName, BrandName, PackSize,
    CategoryCode = (SELECT TOP 1 nc.category_code
                    FROM ref.NielsenCategories nc
                    WHERE nc.is_active=1 AND nc.category_name = CategoryName)
  FROM #stg_SkuFromPayload
)
MERGE ref.SkuDimensions AS T
USING src S
  ON T.SkuCode = S.SkuCode
WHEN MATCHED THEN UPDATE SET
  T.SkuName     = S.SkuName,
  T.BrandName   = S.BrandName,
  T.PackSize    = S.PackSize,
  T.CategoryCode= S.CategoryCode,
  T.IsActive    = 1,
  T.UpdatedUtc  = SYSUTCDATETIME()
WHEN NOT MATCHED BY TARGET THEN
  INSERT (SkuCode,SkuName,BrandName,CategoryCode,PackSize)
  VALUES (S.SkuCode,S.SkuName,S.BrandName,S.CategoryCode,S.PackSize);

-------------------------------------------------------------------------------
-- Backfill TransactionItems.sku_id (SKU code/name hits in item_desc preferred)
-------------------------------------------------------------------------------
;WITH ti AS (
  SELECT
    ti.TransactionItemId,
    BrandNameNorm = LOWER(REPLACE(REPLACE(ti.brand_name,' ',''),'-','')),
    item_desc = COALESCE(ti.item_desc,'')
  FROM dbo.TransactionItems ti
),
cand AS (
  SELECT
    ti.TransactionItemId,
    sd.sku_id,
    score = CASE
              WHEN ti.item_desc LIKE '%' + sd.SkuCode + '%' THEN 1000 + LEN(sd.SkuCode)
              WHEN ti.item_desc LIKE '%' + sd.SkuName + '%' THEN 500 + LEN(sd.SkuName)
              ELSE 0
            END,
    rn = ROW_NUMBER() OVER (
          PARTITION BY ti.TransactionItemId
          ORDER BY
            CASE
              WHEN ti.item_desc LIKE '%' + sd.SkuCode + '%' THEN 1
              WHEN ti.item_desc LIKE '%' + sd.SkuName + '%' THEN 2
              ELSE 9
            END,
            LEN(sd.SkuCode) DESC, sd.sku_id ASC)
  FROM ti
  JOIN ref.SkuDimensions sd
    ON sd.IsActive=1
   AND ti.BrandNameNorm = sd.BrandNameNorm
   AND (ti.item_desc LIKE '%' + sd.SkuCode + '%'
     OR  ti.item_desc LIKE '%' + sd.SkuName + '%')
)
UPDATE TI
  SET TI.sku_id = C.sku_id
FROM dbo.TransactionItems TI
JOIN cand C ON C.TransactionItemId = TI.TransactionItemId AND C.rn = 1
WHERE TI.sku_id IS NULL;

GO

-------------------------------------------------------------------------------
-- SKU-first category resolver view (brand fallback)
-------------------------------------------------------------------------------
CREATE OR ALTER VIEW ref.v_ItemCategoryResolved AS
SELECT
  ti.TransactionItemId,
  ti.canonical_tx_id,
  ti.brand_name,
  ti.item_desc,
  ti.sku_id,
  PreferredCategoryCode =
    COALESCE(sd.CategoryCode, bcm.CategoryCode),
  PreferredCategoryName =
    COALESCE(nc.category_name, bcm.NielsenCategory),
  PreferredDepartmentCode =
    COALESCE(nc.department_code, bcm.DepartmentCode)
FROM dbo.TransactionItems ti
LEFT JOIN ref.SkuDimensions sd
  ON sd.sku_id = ti.sku_id AND sd.IsActive=1
LEFT JOIN dbo.BrandCategoryMapping bcm
  ON bcm.BrandNameNorm = LOWER(REPLACE(REPLACE(ti.brand_name,' ',''),'-',''))
LEFT JOIN ref.NielsenCategories nc
  ON nc.category_code = COALESCE(sd.CategoryCode, bcm.CategoryCode)
 AND nc.is_active=1;

-------------------------------------------------------------------------------
-- Health snapshot
-------------------------------------------------------------------------------
SELECT 'sku_dim_total' AS metric, COUNT(*)             AS val FROM ref.SkuDimensions;
SELECT 'ti_with_sku'   AS metric, COUNT(*)             AS val FROM dbo.TransactionItems WHERE sku_id IS NOT NULL;
SELECT 'brands_113'    AS metric, COUNT(DISTINCT BrandNameNorm) AS val FROM dbo.BrandCategoryMapping;