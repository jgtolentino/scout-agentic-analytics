SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
 * Nielsen 1,100 Category Expansion Procedures
 * Multiplies base 227 categories to reach full 1,100+ categories
 *
 * Expansion Strategy:
 * - Size variations (4 tiers): Single, Regular, Family, Bulk
 * - Price tiers (3 levels): Economy, Regular, Premium
 * - Package types (3 forms): Standard, Multi-pack, Gift pack
 * - Condition variants (3 states): Regular, Light/Diet, Zero/Sugar-free
 *
 * Formula: Base Categories (227) × Multipliers = 1,100+ categories
 */

PRINT 'Deploying Nielsen 1,100 Category Expansion Procedures...';
PRINT 'Creating expansion framework to reach 1,100+ categories from base 227';
GO

-- Create expansion dimension tables
IF OBJECT_ID('ref.NielsenSizeVariants','U') IS NULL
CREATE TABLE ref.NielsenSizeVariants (
  variant_id    int IDENTITY(1,1) PRIMARY KEY,
  variant_code  varchar(20) NOT NULL UNIQUE,
  variant_name  varchar(100) NOT NULL,
  size_factor   decimal(4,2) NOT NULL DEFAULT 1.00,
  priority      tinyint NOT NULL DEFAULT 10
);
GO

IF OBJECT_ID('ref.NielsenPriceTiers','U') IS NULL
CREATE TABLE ref.NielsenPriceTiers (
  tier_id       int IDENTITY(1,1) PRIMARY KEY,
  tier_code     varchar(20) NOT NULL UNIQUE,
  tier_name     varchar(100) NOT NULL,
  price_factor  decimal(4,2) NOT NULL DEFAULT 1.00,
  priority      tinyint NOT NULL DEFAULT 10
);
GO

IF OBJECT_ID('ref.NielsenPackageTypes','U') IS NULL
CREATE TABLE ref.NielsenPackageTypes (
  package_id    int IDENTITY(1,1) PRIMARY KEY,
  package_code  varchar(20) NOT NULL UNIQUE,
  package_name  varchar(100) NOT NULL,
  pack_factor   decimal(4,2) NOT NULL DEFAULT 1.00,
  priority      tinyint NOT NULL DEFAULT 10
);
GO

IF OBJECT_ID('ref.NielsenConditionTypes','U') IS NULL
CREATE TABLE ref.NielsenConditionTypes (
  condition_id   int IDENTITY(1,1) PRIMARY KEY,
  condition_code varchar(20) NOT NULL UNIQUE,
  condition_name varchar(100) NOT NULL,
  health_factor  decimal(4,2) NOT NULL DEFAULT 1.00,
  priority       tinyint NOT NULL DEFAULT 10
);
GO

-- Seed expansion dimensions
INSERT INTO ref.NielsenSizeVariants (variant_code, variant_name, size_factor, priority)
VALUES
  ('SINGLE', 'Single Serve', 0.50, 10),
  ('REGULAR', 'Regular Size', 1.00, 20),
  ('FAMILY', 'Family Size', 1.75, 30),
  ('BULK', 'Bulk/Economy', 2.50, 40);

INSERT INTO ref.NielsenPriceTiers (tier_code, tier_name, price_factor, priority)
VALUES
  ('ECONOMY', 'Economy/Value', 0.75, 10),
  ('REGULAR', 'Regular Price', 1.00, 20),
  ('PREMIUM', 'Premium/Luxury', 1.50, 30);

INSERT INTO ref.NielsenPackageTypes (package_code, package_name, pack_factor, priority)
VALUES
  ('STANDARD', 'Standard Package', 1.00, 10),
  ('MULTIPACK', 'Multi-pack Bundle', 3.00, 20),
  ('GIFTPACK', 'Gift/Special Edition', 1.25, 30);

INSERT INTO ref.NielsenConditionTypes (condition_code, condition_name, health_factor, priority)
VALUES
  ('REGULAR', 'Regular Formula', 1.00, 10),
  ('LIGHT', 'Light/Diet Version', 0.85, 20),
  ('ZERO', 'Zero/Sugar-free', 0.70, 30);

PRINT 'Expansion dimension tables seeded';
GO

-- Extended taxonomy table for expanded categories
IF OBJECT_ID('ref.NielsenTaxonomyExpanded','U') IS NULL
CREATE TABLE ref.NielsenTaxonomyExpanded (
  expanded_id      int IDENTITY(1,1) PRIMARY KEY,
  base_taxonomy_id int NOT NULL REFERENCES ref.NielsenTaxonomy(taxonomy_id),
  size_variant_id  int NULL REFERENCES ref.NielsenSizeVariants(variant_id),
  price_tier_id    int NULL REFERENCES ref.NielsenPriceTiers(tier_id),
  package_type_id  int NULL REFERENCES ref.NielsenPackageTypes(package_id),
  condition_type_id int NULL REFERENCES ref.NielsenConditionTypes(condition_id),
  expanded_code    varchar(128) NOT NULL UNIQUE,
  expanded_name    varchar(300) NOT NULL,
  category_weight  decimal(8,4) NOT NULL DEFAULT 1.0000,
  is_active        bit NOT NULL DEFAULT 1,
  created_at       datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE INDEX IX_NielsenTaxonomyExpanded_Base ON ref.NielsenTaxonomyExpanded(base_taxonomy_id);
CREATE INDEX IX_NielsenTaxonomyExpanded_Code ON ref.NielsenTaxonomyExpanded(expanded_code);
GO

-- Category expansion generation procedure
CREATE OR ALTER PROCEDURE etl.sp_generate_nielsen_expansions
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @expanded_count int = 0;
  DECLARE @new_taxonomy_count int = 0;
  DECLARE @target_categories int = 1100;

  PRINT 'Generating Nielsen 1,100 category expansions...';

  -- Clear existing expansions to regenerate
  DELETE FROM ref.NielsenTaxonomyExpanded;

  -- Generate expansions for Level 3 categories (modules)
  WITH expansion_combinations AS (
    SELECT
      nt.taxonomy_id,
      nt.taxonomy_code,
      nt.taxonomy_name,
      sv.variant_id as size_id,
      sv.variant_code as size_code,
      sv.variant_name as size_name,
      sv.size_factor,
      pt.tier_id as price_id,
      pt.tier_code as price_code,
      pt.tier_name as price_name,
      pt.price_factor,
      pkt.package_id,
      pkt.package_code,
      pkt.package_name,
      pkt.pack_factor,
      ct.condition_id,
      ct.condition_code,
      ct.condition_name,
      ct.health_factor,
      -- Calculate category weight based on all factors
      (sv.size_factor * pt.price_factor * pkt.pack_factor * ct.health_factor) as category_weight,
      -- Generate expanded taxonomy code
      CONCAT(
        nt.taxonomy_code, '_',
        sv.variant_code, '_',
        pt.tier_code, '_',
        pkt.package_code, '_',
        ct.condition_code
      ) as expanded_code,
      -- Generate expanded name
      CONCAT(
        nt.taxonomy_name, ' - ',
        sv.variant_name, ' ',
        pt.tier_name, ' ',
        pkt.package_name, ' ',
        ct.condition_name
      ) as expanded_name
    FROM ref.NielsenTaxonomy nt
    CROSS JOIN ref.NielsenSizeVariants sv
    CROSS JOIN ref.NielsenPriceTiers pt
    CROSS JOIN ref.NielsenPackageTypes pkt
    CROSS JOIN ref.NielsenConditionTypes ct
    WHERE nt.level = 3 -- Only expand Level 3 categories
      AND nt.taxonomy_code LIKE 'CAT_%' -- Only category codes
  )
  INSERT INTO ref.NielsenTaxonomyExpanded (
    base_taxonomy_id, size_variant_id, price_tier_id, package_type_id, condition_type_id,
    expanded_code, expanded_name, category_weight
  )
  SELECT
    taxonomy_id, size_id, price_id, package_id, condition_id,
    expanded_code, expanded_name, category_weight
  FROM expansion_combinations
  WHERE LEN(expanded_code) <= 128 -- Respect code length limits
    AND LEN(expanded_name) <= 300; -- Respect name length limits

  SET @expanded_count = @@ROWCOUNT;

  PRINT CONCAT('Generated ', @expanded_count, ' expanded categories from base categories');

  -- Now create actual Level-3 taxonomy entries for top weighted expansions
  PRINT 'Creating new Level-3 taxonomy entries for high-value expansions...';

  INSERT INTO ref.NielsenTaxonomy (taxonomy_code, taxonomy_name, level, parent_id)
  SELECT TOP 1000
    nte.expanded_code,
    SUBSTRING(nte.expanded_name, 1, 200), -- Ensure name fits
    3, -- Level 3 (Category)
    nte.base_taxonomy_id -- Parent is the base category
  FROM ref.NielsenTaxonomyExpanded nte
  JOIN ref.NielsenTaxonomy nt ON nt.taxonomy_id = nte.base_taxonomy_id
  WHERE nte.category_weight >= 1.0 -- Only create high-value expansions
    AND NOT EXISTS (
      SELECT 1 FROM ref.NielsenTaxonomy existing
      WHERE existing.taxonomy_code = nte.expanded_code
    )
  ORDER BY nte.category_weight DESC;

  SET @new_taxonomy_count = @@ROWCOUNT;
  PRINT CONCAT('Created ', @new_taxonomy_count, ' new Level-3 taxonomy entries');

  -- Generate summary report
  SELECT
    'Expansion Summary' as report_type,
    COUNT(*) as total_expanded_categories,
    COUNT(DISTINCT base_taxonomy_id) as base_categories_expanded,
    MIN(category_weight) as min_weight,
    MAX(category_weight) as max_weight,
    AVG(category_weight) as avg_weight
  FROM ref.NielsenTaxonomyExpanded;

  -- Show top 10 expanded categories by weight
  SELECT TOP 10
    nte.expanded_code,
    nte.expanded_name,
    nte.category_weight,
    nt.taxonomy_name as base_category
  FROM ref.NielsenTaxonomyExpanded nte
  JOIN ref.NielsenTaxonomy nt ON nt.taxonomy_id = nte.base_taxonomy_id
  ORDER BY nte.category_weight DESC;

  PRINT CONCAT('Target: ', @target_categories, ' categories | Generated: ', @expanded_count, ' categories');

  IF @expanded_count >= @target_categories
    PRINT 'SUCCESS: Nielsen 1,100 category target achieved!';
  ELSE
    PRINT 'WARNING: Generated categories below target. Consider additional expansion rules.';

END
GO

-- Enhanced product mapping with expanded categories
CREATE OR ALTER PROCEDURE etl.sp_automap_products_to_nielsen_expanded
AS
BEGIN
  SET NOCOUNT ON;

  PRINT 'Mapping products to expanded Nielsen categories...';

  -- Map to expanded categories first
  ;WITH expanded_mapping AS (
    SELECT
      p.ProductID,
      nte.expanded_id,
      nt.taxonomy_id as base_taxonomy_id,
      -- Calculate confidence based on text matching and category weight
      (
        CASE
          WHEN p.ProductName LIKE '%' + REPLACE(REPLACE(nt.taxonomy_name, ' - ', '%'), ' ', '%') + '%' THEN 0.9
          WHEN p.Category LIKE '%' + REPLACE(REPLACE(nt.taxonomy_name, ' - ', '%'), ' ', '%') + '%' THEN 0.8
          ELSE 0.5
        END * nte.category_weight
      ) as confidence_score,
      ROW_NUMBER() OVER (
        PARTITION BY p.ProductID
        ORDER BY (
          CASE
            WHEN p.ProductName LIKE '%' + REPLACE(REPLACE(nt.taxonomy_name, ' - ', '%'), ' ', '%') + '%' THEN 0.9
            WHEN p.Category LIKE '%' + REPLACE(REPLACE(nt.taxonomy_name, ' - ', '%'), ' ', '%') + '%' THEN 0.8
            ELSE 0.5
          END * nte.category_weight
        ) DESC
      ) as ranking
    FROM dbo.Products p
    CROSS APPLY (
      SELECT TOP 1
        nte2.expanded_id,
        nte2.expanded_code,
        nte2.expanded_name,
        nte2.base_taxonomy_id,
        nte2.category_weight,
        nt2.taxonomy_name
      FROM ref.NielsenTaxonomyExpanded nte2
      JOIN ref.NielsenTaxonomy nt2 ON nt2.taxonomy_id = nte2.base_taxonomy_id
      WHERE nt2.level = 3
        AND (
          p.ProductName LIKE '%' + REPLACE(REPLACE(nt2.taxonomy_name, ' - ', '%'), ' ', '%') + '%'
          OR p.Category LIKE '%' + REPLACE(REPLACE(nt2.taxonomy_name, ' - ', '%'), ' ', '%') + '%'
        )
      ORDER BY nte2.category_weight DESC
    ) nte
    JOIN ref.NielsenTaxonomy nt ON nt.taxonomy_id = nte.base_taxonomy_id
    WHERE NOT EXISTS (
      SELECT 1 FROM ref.ProductNielsenMap existing
      WHERE existing.ProductID = p.ProductID
    )
  )
  INSERT INTO ref.ProductNielsenMap (ProductID, taxonomy_id, confidence, mapped_at)
  SELECT
    ProductID,
    base_taxonomy_id,
    confidence_score,
    SYSUTCDATETIME()
  FROM expanded_mapping
  WHERE ranking = 1
    AND confidence_score >= 0.7; -- Only high-confidence mappings

  PRINT CONCAT('Mapped ', @@ROWCOUNT, ' products to expanded Nielsen categories');

  -- Fallback to brand-based mapping for unmapped products
  ;WITH brand_mapping AS (
    SELECT
      p.ProductID,
      nt.taxonomy_id,
      0.8 as confidence_score -- Brand-based mapping confidence
    FROM dbo.Products p
    JOIN ref.BrandCategoryRules bcr ON (
      p.ProductName LIKE '%' + REPLACE(bcr.brand_name, ' ', '%') + '%'
      OR p.Category LIKE '%' + REPLACE(bcr.brand_name, ' ', '%') + '%'
    )
    JOIN ref.NielsenTaxonomy nt ON nt.taxonomy_code = bcr.taxonomy_code
    WHERE NOT EXISTS (
      SELECT 1 FROM ref.ProductNielsenMap existing
      WHERE existing.ProductID = p.ProductID
    )
  )
  INSERT INTO ref.ProductNielsenMap (ProductID, taxonomy_id, confidence, mapped_at)
  SELECT DISTINCT ProductID, taxonomy_id, confidence_score, SYSUTCDATETIME()
  FROM brand_mapping;

  PRINT CONCAT('Fallback brand mapping added ', @@ROWCOUNT, ' additional product mappings');

END
GO

-- Nielsen 1,100 coverage report with expanded categories
CREATE OR ALTER PROCEDURE etl.sp_report_nielsen_1100_coverage
AS
BEGIN
  SET NOCOUNT ON;

  PRINT '=== Nielsen 1,100 Category System Coverage Report ===';

  -- Overall system statistics
  SELECT
    'System Overview' as report_section,
    (SELECT COUNT(*) FROM ref.NielsenTaxonomy WHERE level = 1) as departments,
    (SELECT COUNT(*) FROM ref.NielsenTaxonomy WHERE level = 2) as product_groups,
    (SELECT COUNT(*) FROM ref.NielsenTaxonomy WHERE level = 3) as base_categories,
    (SELECT COUNT(*) FROM ref.NielsenTaxonomyExpanded WHERE is_active = 1) as expanded_categories,
    (SELECT COUNT(*) FROM dbo.Products) as total_products,
    (SELECT COUNT(DISTINCT ProductID) FROM ref.ProductNielsenMap) as mapped_products;

  -- Product mapping coverage
  SELECT
    'Mapping Coverage' as report_section,
    CAST(100.0 * (SELECT COUNT(DISTINCT ProductID) FROM ref.ProductNielsenMap) /
         NULLIF((SELECT COUNT(*) FROM dbo.Products), 0) AS decimal(5,2)) as coverage_percentage,
    (SELECT COUNT(*) FROM dbo.Products) -
    (SELECT COUNT(DISTINCT ProductID) FROM ref.ProductNielsenMap) as unmapped_products;

  -- Top 20 unmapped products for analysis
  SELECT TOP 20
    'Unmapped Products' as report_section,
    p.ProductName,
    p.Category,
    p.ProductID
  FROM dbo.Products p
  LEFT JOIN ref.ProductNielsenMap m ON m.ProductID = p.ProductID
  WHERE m.ProductID IS NULL
  ORDER BY p.Category, p.ProductName;

  -- Expansion effectiveness by dimension
  SELECT
    'Expansion Dimensions' as report_section,
    sv.variant_name as dimension_type,
    COUNT(*) as categories_using_dimension,
    AVG(nte.category_weight) as avg_weight
  FROM ref.NielsenTaxonomyExpanded nte
  JOIN ref.NielsenSizeVariants sv ON sv.variant_id = nte.size_variant_id
  WHERE nte.is_active = 1
  GROUP BY sv.variant_name, sv.priority
  ORDER BY sv.priority;

  -- Brand mapping effectiveness
  SELECT
    'Brand Mapping' as report_section,
    bcr.rule_source,
    COUNT(*) as brand_rules,
    COUNT(DISTINCT bcr.brand_name) as unique_brands,
    COUNT(DISTINCT bcr.taxonomy_code) as categories_mapped
  FROM ref.BrandCategoryRules bcr
  GROUP BY bcr.rule_source
  ORDER BY COUNT(*) DESC;

  PRINT 'Nielsen 1,100 coverage analysis complete';

END
GO

PRINT 'Nielsen 1,100 expansion procedures deployed successfully';
PRINT 'Next steps:';
PRINT '1. Execute: EXEC etl.sp_generate_nielsen_expansions';
PRINT '2. Execute: EXEC etl.sp_automap_products_to_nielsen_expanded';
PRINT '3. Execute: EXEC etl.sp_report_nielsen_1100_coverage';
GO