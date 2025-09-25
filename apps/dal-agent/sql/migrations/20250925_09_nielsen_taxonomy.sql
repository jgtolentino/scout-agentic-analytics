SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name=N'ref') EXEC('CREATE SCHEMA ref');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name=N'gold') EXEC('CREATE SCHEMA gold');
GO

IF OBJECT_ID('ref.NielsenTaxonomy','U') IS NULL
CREATE TABLE ref.NielsenTaxonomy (
  taxonomy_id   int IDENTITY(1,1) PRIMARY KEY,
  taxonomy_code varchar(64)  NOT NULL UNIQUE,
  taxonomy_name varchar(200) NOT NULL,
  level         tinyint      NOT NULL,   -- 1=Department, 2=Group, 3=Category/Module
  parent_id     int NULL REFERENCES ref.NielsenTaxonomy(taxonomy_id)
);
GO
CREATE INDEX IX_NielsenTaxonomy_Level ON ref.NielsenTaxonomy(level);
GO

IF OBJECT_ID('ref.ProductNielsenMap','U') IS NULL
CREATE TABLE ref.ProductNielsenMap (
  ProductID   int NOT NULL REFERENCES dbo.Products(ProductID),
  taxonomy_id int NOT NULL REFERENCES ref.NielsenTaxonomy(taxonomy_id),
  confidence  decimal(5,4) NULL,
  mapped_at   datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_ProductNielsenMap PRIMARY KEY (ProductID, taxonomy_id)
);
GO

IF OBJECT_ID('ref.BrandCategoryRules','U') IS NULL
CREATE TABLE ref.BrandCategoryRules (
  brand_name    nvarchar(200) NOT NULL,
  taxonomy_code varchar(64)   NOT NULL,      -- points to ref.NielsenTaxonomy.taxonomy_code (level=3)
  priority      tinyint       NOT NULL DEFAULT 10,
  rule_source   varchar(50)   NOT NULL DEFAULT 'seed',
  CONSTRAINT UQ_BrandRule UNIQUE (brand_name, taxonomy_code)
);
GO

/* Minimal seed for Departments & Groups (extend later to full 1,100 modules) */
CREATE OR ALTER PROCEDURE etl.sp_seed_nielsen_taxonomy_min
AS
BEGIN
  SET NOCOUNT ON;

  -- Departments (Level 1) per reviewed standards
  -- Examples; extend according to your doc:
  MERGE ref.NielsenTaxonomy AS d
  USING (VALUES
    ('DEPT_FNB','FOOD & BEVERAGES',1,NULL),
    ('DEPT_PH','PERSONAL & HEALTH CARE',1,NULL),
    ('DEPT_HH','HOUSEHOLD PRODUCTS',1,NULL),
    ('DEPT_TOB','TOBACCO & VICES',1,NULL),
    ('DEPT_TEL','TELECOMMUNICATIONS',1,NULL),
    ('DEPT_GM','GENERAL MERCHANDISE',1,NULL)
  ) AS s(code,name,level,parent_id)
  ON d.taxonomy_code=s.code
  WHEN NOT MATCHED THEN
    INSERT (taxonomy_code,taxonomy_name,level,parent_id) VALUES (s.code,s.name,s.level,s.parent_id);

  -- Groups (Level 2) under Food & Beverages (examples)
  DECLARE @dept_fnb int = (SELECT taxonomy_id FROM ref.NielsenTaxonomy WHERE taxonomy_code='DEPT_FNB');
  MERGE ref.NielsenTaxonomy AS d
  USING (VALUES
    ('GRP_FNB_BEV_NA','Beverages - Non-Alcoholic',2,@dept_fnb),
    ('GRP_FNB_BEV_ALC','Beverages - Alcoholic',2,@dept_fnb),
    ('GRP_FNB_INSTANT','Instant Foods & Noodles',2,@dept_fnb),
    ('GRP_FNB_CANNED','Canned & Packaged Foods',2,@dept_fnb),
    ('GRP_FNB_SNACKS','Snacks & Confectionery',2,@dept_fnb),
    ('GRP_FNB_DAIRY','Dairy Products',2,@dept_fnb),
    ('GRP_FNB_COND','Condiments & Seasonings',2,@dept_fnb),
    ('GRP_FNB_BAKERY','Biscuits & Bakery',2,@dept_fnb)
  ) AS s(code,name,level,parent_id)
  ON d.taxonomy_code=s.code
  WHEN NOT MATCHED THEN
    INSERT (taxonomy_code,taxonomy_name,level,parent_id) VALUES (s.code,s.name,s.level,s.parent_id);

  -- Example Level 3 "modules" under non-alcoholic beverages (extend to 1,100 later)
  DECLARE @grp_na int = (SELECT taxonomy_id FROM ref.NielsenTaxonomy WHERE taxonomy_code='GRP_FNB_BEV_NA');
  MERGE ref.NielsenTaxonomy AS d
  USING (VALUES
    ('CAT_BEV_CSD','Carbonated Soft Drinks',3,@grp_na),
    ('CAT_BEV_JUICE','Juice & Drink Mixes',3,@grp_na),
    ('CAT_BEV_RTD_COFFEE','RTD Coffee',3,@grp_na),
    ('CAT_BEV_ENG','Energy Drinks',3,@grp_na),
    ('CAT_BEV_WATER','Bottled Water',3,@grp_na),
    ('CAT_BEV_TEA','Tea & RTD Tea',3,@grp_na)
  ) AS s(code,name,level,parent_id)
  ON d.taxonomy_code=s.code
  WHEN NOT MATCHED THEN
    INSERT (taxonomy_code,taxonomy_name,level,parent_id) VALUES (s.code,s.name,s.level,s.parent_id);

  -- Add Tobacco groups and categories (critical for sari-sari)
  DECLARE @dept_tob int = (SELECT taxonomy_id FROM ref.NielsenTaxonomy WHERE taxonomy_code='DEPT_TOB');
  MERGE ref.NielsenTaxonomy AS d
  USING (VALUES
    ('GRP_TOB_CIG','Cigarettes',2,@dept_tob),
    ('GRP_TOB_OTHER','Other Tobacco Products',2,@dept_tob)
  ) AS s(code,name,level,parent_id)
  ON d.taxonomy_code=s.code
  WHEN NOT MATCHED THEN
    INSERT (taxonomy_code,taxonomy_name,level,parent_id) VALUES (s.code,s.name,s.level,s.parent_id);

  DECLARE @grp_cig int = (SELECT taxonomy_id FROM ref.NielsenTaxonomy WHERE taxonomy_code='GRP_TOB_CIG');
  MERGE ref.NielsenTaxonomy AS d
  USING (VALUES
    ('CAT_TOB_CIG_REGULAR','Regular Cigarettes',3,@grp_cig),
    ('CAT_TOB_CIG_MENTHOL','Menthol Cigarettes',3,@grp_cig)
  ) AS s(code,name,level,parent_id)
  ON d.taxonomy_code=s.code
  WHEN NOT MATCHED THEN
    INSERT (taxonomy_code,taxonomy_name,level,parent_id) VALUES (s.code,s.name,s.level,s.parent_id);

  -- Add Telecommunications groups and categories (critical for sari-sari)
  DECLARE @dept_tel int = (SELECT taxonomy_id FROM ref.NielsenTaxonomy WHERE taxonomy_code='DEPT_TEL');
  MERGE ref.NielsenTaxonomy AS d
  USING (VALUES
    ('GRP_TEL_PREPAID','Prepaid Load & Cards',2,@dept_tel),
    ('GRP_TEL_ACC','Mobile Accessories',2,@dept_tel)
  ) AS s(code,name,level,parent_id)
  ON d.taxonomy_code=s.code
  WHEN NOT MATCHED THEN
    INSERT (taxonomy_code,taxonomy_name,level,parent_id) VALUES (s.code,s.name,s.level,s.parent_id);

  DECLARE @grp_prepaid int = (SELECT taxonomy_id FROM ref.NielsenTaxonomy WHERE taxonomy_code='GRP_TEL_PREPAID');
  MERGE ref.NielsenTaxonomy AS d
  USING (VALUES
    ('CAT_TEL_GLOBE','Globe Prepaid',3,@grp_prepaid),
    ('CAT_TEL_SMART','Smart Prepaid',3,@grp_prepaid),
    ('CAT_TEL_OTHER','Other Telecom Load',3,@grp_prepaid)
  ) AS s(code,name,level,parent_id)
  ON d.taxonomy_code=s.code
  WHEN NOT MATCHED THEN
    INSERT (taxonomy_code,taxonomy_name,level,parent_id) VALUES (s.code,s.name,s.level,s.parent_id);
END
GO

/* Automap using Brand→Category rules (Level 3) */
CREATE OR ALTER PROCEDURE etl.sp_automap_products_to_nielsen
AS
BEGIN
  SET NOCOUNT ON;

  ;WITH brand_tax AS (
    SELECT r.brand_name,
           n.taxonomy_id
    FROM ref.BrandCategoryRules r
    JOIN ref.NielsenTaxonomy n
      ON n.taxonomy_code = r.taxonomy_code AND n.level = 3
  )
  INSERT INTO ref.ProductNielsenMap (ProductID, taxonomy_id, confidence)
  SELECT p.ProductID, bt.taxonomy_id, 1.000
  FROM dbo.Products p
  LEFT JOIN ref.ProductNielsenMap existing ON existing.ProductID = p.ProductID
  CROSS APPLY (
    SELECT TOP 1 bt.taxonomy_id
    FROM brand_tax bt
    WHERE p.Category LIKE '%' + REPLACE(bt.brand_name, ' ', '%') + '%'
       OR p.ProductName LIKE '%' + REPLACE(bt.brand_name, ' ', '%') + '%'
  ) bt
  WHERE existing.ProductID IS NULL;
END
GO

/* Coverage report */
CREATE OR ALTER PROCEDURE etl.sp_report_nielsen_coverage
AS
BEGIN
  SET NOCOUNT ON;
  SELECT
    total_products   = (SELECT COUNT(*) FROM dbo.Products),
    mapped_products  = (SELECT COUNT(DISTINCT ProductID) FROM ref.ProductNielsenMap),
    coverage_pct     = CAST(100.0 * (SELECT COUNT(DISTINCT ProductID) FROM ref.ProductNielsenMap) / NULLIF((SELECT COUNT(*) FROM dbo.Products),0) AS decimal(5,2));

  SELECT TOP 25 p.ProductName, p.Category
  FROM dbo.Products p
  LEFT JOIN ref.ProductNielsenMap m ON m.ProductID = p.ProductID
  WHERE m.ProductID IS NULL
  ORDER BY p.Category, p.ProductName;
END
GO

/* Nielsen-aware transaction view (transaction × SKU × Nielsen) */
CREATE OR ALTER VIEW gold.v_transactions_nielsen
AS
SELECT
  si.canonical_tx_id,
  si.TransactionDate,
  si.StoreID,
  i.ProductID,
  p.ProductName,
  p.Category AS product_category,
  n.taxonomy_code,
  n.taxonomy_name,
  n.level,
  CASE n.level
    WHEN 1 THEN n.taxonomy_name
    ELSE dept.taxonomy_name
  END AS department,
  CASE n.level
    WHEN 1 THEN NULL
    WHEN 2 THEN n.taxonomy_name
    ELSE grp.taxonomy_name
  END AS group_name,
  CASE n.level
    WHEN 3 THEN n.taxonomy_name
    ELSE NULL
  END AS category,
  i.Quantity,
  i.UnitPrice
FROM dbo.TransactionItems i
JOIN dbo.SalesInteractions si ON si.InteractionID = i.InteractionID
LEFT JOIN dbo.Products p ON p.ProductID = i.ProductID
LEFT JOIN ref.ProductNielsenMap m ON m.ProductID = p.ProductID
LEFT JOIN ref.NielsenTaxonomy n ON n.taxonomy_id = m.taxonomy_id
LEFT JOIN ref.NielsenTaxonomy grp ON grp.taxonomy_id = n.parent_id AND n.level = 3
LEFT JOIN ref.NielsenTaxonomy dept ON dept.taxonomy_id = COALESCE(grp.parent_id, n.parent_id) AND dept.level = 1;
GO