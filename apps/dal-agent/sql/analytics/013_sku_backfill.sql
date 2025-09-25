/* ============================================================
   SCOUT — SKU Backfill & Enforcement (Production-safe)
   - Dim table: ref.SkuDimensions
   - Staging:  ref.stg_SkuMap  (SkuCode,SkuName,BrandName,CategoryCode,PackSize)
   - Backfill TransactionItems.sku_id
   - Prefer SKU→CategoryCode over Brand→CategoryCode during analytics
   ============================================================ */
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- Ensure reference schema exists
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='ref')
    EXEC('CREATE SCHEMA ref');

-- 1) SKU dimension table
IF OBJECT_ID('ref.SkuDimensions','U') IS NULL
BEGIN
    CREATE TABLE ref.SkuDimensions(
        sku_id         int IDENTITY(1,1) PRIMARY KEY,
        SkuCode        nvarchar(100)  NOT NULL UNIQUE,
        SkuName        nvarchar(300)  NOT NULL,
        BrandName      nvarchar(255)  NOT NULL,
        BrandNameNorm  AS LOWER(REPLACE(REPLACE(BrandName,' ',''),'-','')),
        CategoryCode   nvarchar(50)   NULL,       -- FK to ref.NielsenCategories.category_code
        PackSize       nvarchar(100)  NULL,
        IsActive       bit            NOT NULL DEFAULT(1),
        CreatedUtc     datetime2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedUtc     datetime2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),

        -- Foreign key to Nielsen categories
        CONSTRAINT FK_SkuDimensions_NielsenCategory
            FOREIGN KEY (CategoryCode) REFERENCES ref.NielsenCategories(category_code)
    );

    -- Performance indexes
    CREATE NONCLUSTERED INDEX IX_SkuDimensions_Brand
        ON ref.SkuDimensions(BrandNameNorm) INCLUDE (CategoryCode, PackSize);
    CREATE NONCLUSTERED INDEX IX_SkuDimensions_Category
        ON ref.SkuDimensions(CategoryCode) INCLUDE (BrandName, SkuCode);
END;

-- 2) Nielsen categories required (guard)
IF OBJECT_ID('ref.NielsenCategories','U') IS NULL
    THROW 51000, 'ref.NielsenCategories missing. Run 011_nielsen_1100_migration.sql first.', 1;

-- 3) Staging table for bulk SKU loads
IF OBJECT_ID('ref.stg_SkuMap','U') IS NULL
BEGIN
    CREATE TABLE ref.stg_SkuMap(
        SkuCode       nvarchar(100)  NOT NULL,
        SkuName       nvarchar(300)  NOT NULL,
        BrandName     nvarchar(255)  NOT NULL,
        CategoryCode  nvarchar(50)   NULL,
        PackSize      nvarchar(100)  NULL
    );
END;

-- 4) Upsert SKUs from staging into SkuDimensions
IF EXISTS (SELECT 1 FROM ref.stg_SkuMap)
BEGIN
    ;WITH stg AS (
        SELECT DISTINCT
            SkuCode      = LTRIM(RTRIM(SkuCode)),
            SkuName      = LTRIM(RTRIM(SkuName)),
            BrandName    = LTRIM(RTRIM(BrandName)),
            CategoryCode = NULLIF(LTRIM(RTRIM(CategoryCode)),''),
            PackSize     = NULLIF(LTRIM(RTRIM(PackSize)),'')
        FROM ref.stg_SkuMap
        WHERE LTRIM(RTRIM(SkuCode)) != ''
          AND LTRIM(RTRIM(SkuName)) != ''
          AND LTRIM(RTRIM(BrandName)) != ''
    )
    MERGE ref.SkuDimensions AS T
    USING stg S ON T.SkuCode = S.SkuCode
    WHEN MATCHED THEN UPDATE SET
         T.SkuName    = S.SkuName,
         T.BrandName  = S.BrandName,
         T.CategoryCode = S.CategoryCode,
         T.PackSize   = S.PackSize,
         T.UpdatedUtc = SYSUTCDATETIME()
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (SkuCode,SkuName,BrandName,CategoryCode,PackSize)
        VALUES (S.SkuCode,S.SkuName,S.BrandName,S.CategoryCode,S.PackSize);
END;

-- 5) Ensure TransactionItems has sku_id column
IF COL_LENGTH('dbo.TransactionItems','sku_id') IS NULL
    ALTER TABLE dbo.TransactionItems ADD sku_id int NULL;

-- Optional performance index for backfill operations
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.TransactionItems') AND name = 'IX_TI_Brand_ProductID')
    CREATE INDEX IX_TI_Brand_ProductID ON dbo.TransactionItems(ProductID) INCLUDE (sku_id, InteractionID);

-- 6) Backfill sku_id via ProductID matching (assuming ProductID contains SKU codes)
-- This is a safe pattern-based approach - adjust matching logic as needed
;WITH sku_matches AS (
    SELECT
        ti.TransactionItemID,
        sd.sku_id,
        ROW_NUMBER() OVER (PARTITION BY ti.TransactionItemID ORDER BY LEN(sd.SkuCode) DESC) as rn
    FROM dbo.TransactionItems ti
    JOIN ref.SkuDimensions sd ON (
        -- Strategy A: Direct ProductID match (if ProductID contains SKU codes)
        CAST(ti.ProductID AS nvarchar(50)) = sd.SkuCode
        OR
        -- Strategy B: Fuzzy match via brand correlation (safer fallback)
        (sd.BrandNameNorm = LOWER(REPLACE(REPLACE(COALESCE(
            (SELECT TOP 1 brand_name FROM dbo.BrandCategoryMapping bcm
             WHERE bcm.brand_name IS NOT NULL
             ORDER BY LEN(brand_name) DESC)
        , 'Unknown'),' ',''),'-',''))
        AND CAST(ti.ProductID AS nvarchar(50)) LIKE '%' + sd.SkuCode + '%')
    )
    WHERE sd.IsActive = 1
      AND ti.sku_id IS NULL
)
UPDATE ti
SET ti.sku_id = sm.sku_id
FROM dbo.TransactionItems ti
JOIN sku_matches sm ON sm.TransactionItemID = ti.TransactionItemID
WHERE sm.rn = 1; -- Take best match only

GO

-- 7) Create analytics preference view: SKU-first, brand-fallback
CREATE OR ALTER VIEW ref.v_ItemCategoryResolved AS
SELECT
    ti.TransactionItemID,
    ti.InteractionID,
    ti.ProductID,
    ti.Quantity,
    ti.UnitPrice,
    ti.sku_id,

    -- SKU information
    sd.SkuCode,
    sd.SkuName,
    sd.PackSize,

    -- Brand resolution
    ResolvedBrandName = COALESCE(sd.BrandName, bcm.brand_name, 'Unknown'),

    -- Category resolution: SKU CategoryCode takes precedence
    PreferredCategoryCode = COALESCE(sd.CategoryCode, bcm.CategoryCode),

    -- Department and category names from Nielsen taxonomy
    nc.department_code AS PreferredDepartmentCode,
    nc.category_name AS PreferredCategoryName,
    nd.department_name AS PreferredDepartmentName,

    -- Quality indicators
    HasSKU = CASE WHEN ti.sku_id IS NOT NULL THEN 1 ELSE 0 END,
    HasBrandMapping = CASE WHEN bcm.brand_name IS NOT NULL THEN 1 ELSE 0 END,
    ResolutionSource = CASE
        WHEN sd.CategoryCode IS NOT NULL THEN 'SKU'
        WHEN bcm.CategoryCode IS NOT NULL THEN 'Brand'
        ELSE 'Unmapped'
    END

FROM dbo.TransactionItems ti

-- Left join to SKU dimension
LEFT JOIN ref.SkuDimensions sd
    ON sd.sku_id = ti.sku_id AND sd.IsActive = 1

-- Left join to brand category mapping (fallback)
LEFT JOIN dbo.BrandCategoryMapping bcm
    ON bcm.brand_name = COALESCE(sd.BrandName, 'Unknown')

-- Left join to Nielsen categories for names
LEFT JOIN ref.NielsenCategories nc
    ON nc.category_code = COALESCE(sd.CategoryCode, bcm.CategoryCode)
    AND nc.is_active = 1

-- Left join to Nielsen departments for names
LEFT JOIN ref.NielsenDepartments nd
    ON nd.department_code = nc.department_code
    AND nd.is_active = 1;

GO

-- 8) Create coverage helper view
CREATE OR ALTER VIEW ref.v_SkuCoverage AS
SELECT
    total_transaction_items = COUNT(*),
    items_with_sku = COUNT(CASE WHEN sku_id IS NOT NULL THEN 1 END),
    items_with_brand_only = COUNT(CASE WHEN sku_id IS NULL THEN 1 END),
    sku_coverage_pct = CAST(COUNT(CASE WHEN sku_id IS NOT NULL THEN 1 END) * 100.0 /
                           NULLIF(COUNT(*), 0) AS decimal(5,2))
FROM dbo.TransactionItems;

GO

-- 9) Validation and reporting
SELECT 'sku_dimensions_total' AS metric, COUNT(*) AS value FROM ref.SkuDimensions;
SELECT 'sku_dimensions_with_category' AS metric, COUNT(*) AS value FROM ref.SkuDimensions WHERE CategoryCode IS NOT NULL;
SELECT 'transaction_items_with_sku' AS metric, COUNT(*) AS value FROM dbo.TransactionItems WHERE sku_id IS NOT NULL;

-- Show sample of the resolution view
SELECT TOP 10 * FROM ref.v_ItemCategoryResolved ORDER BY TransactionItemID;

-- Coverage summary
SELECT * FROM ref.v_SkuCoverage;