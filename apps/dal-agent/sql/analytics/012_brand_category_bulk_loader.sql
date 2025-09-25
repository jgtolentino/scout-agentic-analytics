/* ============================================================
   SCOUT — Brand→Nielsen CategoryCode Bulk Loader
   Input: ref.stg_BrandCategoryMap (BrandName, CategoryCode, DepartmentCode?)
   Behavior: Upsert FK codes on dbo.BrandCategoryMapping; purge 'unspecified' dupes.
   Idempotent & JSON-safe.
   ============================================================ */
SET NOCOUNT ON;
SET XACT_ABORT ON;

/* 0) Staging table (truncate+load via CSV import or INSERTs) */
IF OBJECT_ID('ref.stg_BrandCategoryMap','U') IS NULL
BEGIN
  CREATE TABLE ref.stg_BrandCategoryMap(
    BrandName       nvarchar(255) NOT NULL,
    CategoryCode    nvarchar(100) NOT NULL,
    DepartmentCode  nvarchar(50)  NULL
  );
END

/* Guard: ensure target dims exist */
IF OBJECT_ID('ref.NielsenCategories','U') IS NULL
  THROW 51000, 'ref.NielsenCategories not found. Run 011_nielsen_1100_migration.sql first.', 1;

/* 1) Normalize stage + resolve department by CategoryCode if NULL */
;WITH s AS (
  SELECT
    BrandName,
    LOWER(REPLACE(REPLACE(BrandName,' ',''),'-','')) AS BrandNameNorm,
    CategoryCode,
    COALESCE(DepartmentCode, nc.department_code) AS DepartmentCode
  FROM ref.stg_BrandCategoryMap m
  LEFT JOIN ref.NielsenCategories nc ON nc.category_code = m.CategoryCode AND nc.is_active = 1
)
SELECT * INTO #stg_norm FROM s;

IF NOT EXISTS (SELECT 1 FROM #stg_norm)
  THROW 51001, 'ref.stg_BrandCategoryMap is empty. Load rows before running.', 1;

/* 2) Ensure mapping columns exist on target */
IF COL_LENGTH('dbo.BrandCategoryMapping','CategoryCode') IS NULL
  ALTER TABLE dbo.BrandCategoryMapping ADD CategoryCode nvarchar(100) NULL;
IF COL_LENGTH('dbo.BrandCategoryMapping','DepartmentCode') IS NULL
  ALTER TABLE dbo.BrandCategoryMapping ADD DepartmentCode nvarchar(50) NULL;
IF COL_LENGTH('dbo.BrandCategoryMapping','BrandNameNorm') IS NULL
  ALTER TABLE dbo.BrandCategoryMapping ADD BrandNameNorm AS LOWER(REPLACE(REPLACE(BrandName,' ',''),'-',''));

/* 3) Upsert on (BrandNameNorm) — single canonical slot per brand */
MERGE dbo.BrandCategoryMapping AS T
USING (
  SELECT BrandName, BrandNameNorm, CategoryCode, DepartmentCode
  FROM #stg_norm
) S
ON (T.BrandNameNorm = S.BrandNameNorm)
WHEN MATCHED THEN
  UPDATE SET
    T.CategoryCode   = S.CategoryCode,
    T.DepartmentCode = S.DepartmentCode
WHEN NOT MATCHED BY TARGET THEN
  INSERT (BrandName, CategoryCode, DepartmentCode)
  VALUES (S.BrandName, S.CategoryCode, S.DepartmentCode);

/* 4) Purge 'unspecified' duplicates where a real mapping exists for same brand */
;WITH dup AS (
  SELECT BrandNameNorm
  FROM dbo.BrandCategoryMapping
  GROUP BY BrandNameNorm
  HAVING SUM(CASE WHEN LOWER(LTRIM(RTRIM(NielsenCategory)))='unspecified' THEN 1 ELSE 0 END) > 0
     AND SUM(CASE WHEN CategoryCode IS NOT NULL THEN 1 ELSE 0 END) > 0
)
DELETE bcm
FROM dbo.BrandCategoryMapping bcm
JOIN dup d ON d.BrandNameNorm = bcm.BrandNameNorm
WHERE LOWER(LTRIM(RTRIM(bcm.NielsenCategory)))='unspecified';

/* 5) Final coverage report (3 single-row sets, JSON-safe) */
SELECT mapped_brands = COUNT(*)
FROM dbo.BrandCategoryMapping
WHERE CategoryCode IS NOT NULL;

SELECT unmapped_brands = COUNT(*)
FROM dbo.BrandCategoryMapping
WHERE CategoryCode IS NULL;

SELECT sample_unmapped_brand = TOP(1) BrandName
FROM dbo.BrandCategoryMapping
WHERE CategoryCode IS NULL
ORDER BY BrandName;