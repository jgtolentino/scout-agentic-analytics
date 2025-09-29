-- =====================================================
-- COMPLETE FLATTENED DATASET: All Fact + Dimension Tables
-- Combines SalesInteractions + PayloadTransactions + Store Hierarchy + Nielsen Taxonomy + SKU-Level Data
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

CREATE OR ALTER VIEW dbo.v_complete_flattened_dataset AS
WITH sku_items AS (
    -- Extract SKU-level data from JSON payload
    SELECT
        pt.canonical_tx_id,
        JSON_VALUE(item.value, '$.sku') AS sku_code,
        JSON_VALUE(item.value, '$.brand') AS item_brand,
        JSON_VALUE(item.value, '$.category') AS item_category,
        TRY_CONVERT(INT, JSON_VALUE(item.value, '$.quantity')) AS item_quantity,
        TRY_CONVERT(DECIMAL(10,2), JSON_VALUE(item.value, '$.unitPrice')) AS item_unit_price,
        TRY_CONVERT(DECIMAL(10,2), JSON_VALUE(item.value, '$.total')) AS item_total,
        ROW_NUMBER() OVER (PARTITION BY pt.canonical_tx_id ORDER BY JSON_VALUE(item.value, '$.total') DESC) AS item_rank
    FROM dbo.PayloadTransactions pt
    CROSS APPLY OPENJSON(pt.payload_json, '$.items') AS item
    WHERE pt.payload_json IS NOT NULL
      AND ISJSON(pt.payload_json) = 1
)
SELECT
    -- =====================================================
    -- CORE TRANSACTION IDENTITY
    -- =====================================================
    si.canonical_tx_id AS transaction_id,
    si.InteractionID AS interaction_id,
    pt.sessionId AS session_id,
    pt.deviceId AS device_id,

    -- =====================================================
    -- TEMPORAL DIMENSIONS (Complete Time Hierarchy)
    -- =====================================================
    si.TransactionDate AS transaction_date,
    CAST(si.CreatedDate AS TIME) AS transaction_time,

    -- Date Hierarchy
    YEAR(si.TransactionDate) AS year_number,
    MONTH(si.TransactionDate) AS month_number,
    DATENAME(month, si.TransactionDate) AS month_name,
    DATEPART(quarter, si.TransactionDate) AS quarter_number,
    DATEPART(week, si.TransactionDate) AS week_number,
    DATEPART(dayofyear, si.TransactionDate) AS day_of_year,
    DATENAME(weekday, si.TransactionDate) AS day_name,
    DATEPART(weekday, si.TransactionDate) AS day_of_week_number,
    CASE
        WHEN DATEPART(weekday, si.TransactionDate) IN (1,7) THEN 'Weekend'
        ELSE 'Weekday'
    END AS weekday_vs_weekend,

    -- Time Hierarchy (from CreatedDate timestamp)
    DATEPART(hour, si.CreatedDate) AS hour_24,
    CASE
        WHEN DATEPART(hour, si.CreatedDate) = 0 THEN 12
        WHEN DATEPART(hour, si.CreatedDate) <= 12 THEN DATEPART(hour, si.CreatedDate)
        ELSE DATEPART(hour, si.CreatedDate) - 12
    END AS hour_12,
    DATEPART(minute, si.CreatedDate) AS minute_number,
    CASE
        WHEN DATEPART(hour, si.CreatedDate) < 12 THEN 'AM'
        ELSE 'PM'
    END AS am_pm,

    -- Time of Day Categories (Business Intelligence)
    CASE
        WHEN DATEPART(hour, si.CreatedDate) BETWEEN 6 AND 8 THEN 'Early-Morning'
        WHEN DATEPART(hour, si.CreatedDate) BETWEEN 9 AND 11 THEN 'Late-Morning'
        WHEN DATEPART(hour, si.CreatedDate) BETWEEN 12 AND 14 THEN 'Lunch-Time'
        WHEN DATEPART(hour, si.CreatedDate) BETWEEN 15 AND 17 THEN 'Afternoon'
        WHEN DATEPART(hour, si.CreatedDate) BETWEEN 18 AND 20 THEN 'Evening'
        WHEN DATEPART(hour, si.CreatedDate) BETWEEN 21 AND 23 THEN 'Night'
        ELSE 'Late-Night'
    END AS time_of_day_category,

    -- Business Time Periods
    CASE
        WHEN DATEPART(hour, si.CreatedDate) BETWEEN 7 AND 9 THEN 'Rush-Hour-Morning'
        WHEN DATEPART(hour, si.CreatedDate) BETWEEN 10 AND 16 THEN 'Business-Hours'
        WHEN DATEPART(hour, si.CreatedDate) BETWEEN 17 AND 19 THEN 'Rush-Hour-Evening'
        WHEN DATEPART(hour, si.CreatedDate) BETWEEN 20 AND 22 THEN 'Prime-Time'
        ELSE 'Off-Peak'
    END AS business_time_period,

    -- =====================================================
    -- STORE HIERARCHY (Complete Geographic Mapping)
    -- =====================================================
    s.StoreID AS store_id,
    s.StoreName AS store_name,

    -- Region Level
    r.RegionID AS region_id,
    r.RegionName AS region_name,
    r.RegionCode AS region_code,

    -- Province Level
    p.ProvinceID AS province_id,
    p.ProvinceName AS province_name,

    -- Municipality Level
    m.MunicipalityID AS municipality_id,
    m.MunicipalityName AS municipality_name,

    -- Barangay Level
    b.BarangayID AS barangay_id,
    b.BarangayName AS barangay_name,

    -- =====================================================
    -- CUSTOMER DEMOGRAPHICS (From SalesInteractions)
    -- =====================================================
    si.FacialID AS customer_facial_id,
    si.Age AS customer_age,
    si.Gender AS customer_gender,
    si.EmotionalState AS customer_emotion,
    CASE
        WHEN si.Age BETWEEN 18 AND 24 THEN '18-24'
        WHEN si.Age BETWEEN 25 AND 34 THEN '25-34'
        WHEN si.Age BETWEEN 35 AND 44 THEN '35-44'
        WHEN si.Age BETWEEN 45 AND 54 THEN '45-54'
        WHEN si.Age BETWEEN 55 AND 64 THEN '55-64'
        WHEN si.Age >= 65 THEN '65+'
        ELSE 'Unknown'
    END AS age_bracket,

    -- =====================================================
    -- TRANSACTION MEASURES
    -- =====================================================
    COALESCE(si.TransactionValue, pt.amount) AS transaction_amount,
    si.BasketSize AS basket_size,
    si.WasSubstitution AS was_substitution,
    pt.amount AS payload_amount,

    -- =====================================================
    -- SKU-LEVEL DATA (From JSON Payload)
    -- =====================================================
    -- Primary Item (highest value)
    sku1.sku_code AS primary_sku,
    sku1.item_brand AS primary_item_brand,
    sku1.item_category AS primary_item_category,
    sku1.item_quantity AS primary_item_quantity,
    sku1.item_unit_price AS primary_item_unit_price,
    sku1.item_total AS primary_item_total,

    -- Secondary Item
    sku2.sku_code AS secondary_sku,
    sku2.item_brand AS secondary_item_brand,
    sku2.item_category AS secondary_item_category,
    sku2.item_quantity AS secondary_item_quantity,
    sku2.item_unit_price AS secondary_item_unit_price,
    sku2.item_total AS secondary_item_total,

    -- All SKUs in basket (aggregated)
    stuff((
        SELECT '; ' + sku_items.sku_code
        FROM sku_items
        WHERE sku_items.canonical_tx_id = si.canonical_tx_id
        FOR XML PATH('')
    ), 1, 2, '') AS all_skus,

    -- =====================================================
    -- MARKET BASKET ANALYSIS (Items Bought Together)
    -- =====================================================
    -- Item affinity patterns
    stuff((
        SELECT '; ' + sku_items.item_brand + ':' + sku_items.item_category
        FROM sku_items
        WHERE sku_items.canonical_tx_id = si.canonical_tx_id
        ORDER BY sku_items.item_total DESC
        FOR XML PATH('')
    ), 1, 2, '') AS brand_category_combinations,

    -- Cross-category basket indicator
    (SELECT COUNT(DISTINCT sku_items.item_category)
     FROM sku_items
     WHERE sku_items.canonical_tx_id = si.canonical_tx_id) AS unique_categories_in_basket,

    -- Cross-brand basket indicator
    (SELECT COUNT(DISTINCT sku_items.item_brand)
     FROM sku_items
     WHERE sku_items.canonical_tx_id = si.canonical_tx_id) AS unique_brands_in_basket,

    -- Basket value distribution
    CASE
        WHEN (SELECT COUNT(*)
              FROM sku_items
              WHERE sku_items.canonical_tx_id = si.canonical_tx_id
                AND sku_items.item_total > (SELECT AVG(item_total) FROM sku_items WHERE canonical_tx_id = si.canonical_tx_id)) > 1
        THEN 'High-Value-Multi-Item'
        WHEN (SELECT COUNT(*) FROM sku_items WHERE sku_items.canonical_tx_id = si.canonical_tx_id) = 1
        THEN 'Single-Item'
        ELSE 'Mixed-Value-Basket'
    END AS basket_value_pattern,

    -- Complementary product indicator (food + beverage, personal care + health, etc.)
    CASE
        WHEN EXISTS (
            SELECT 1 FROM sku_items s1
            JOIN sku_items s2 ON s1.canonical_tx_id = s2.canonical_tx_id
            WHERE s1.canonical_tx_id = si.canonical_tx_id
              AND s1.item_category IN ('food', 'snacks', 'instant_noodles')
              AND s2.item_category IN ('beverages', 'soft_drinks', 'water')
        ) THEN 'Food-Beverage-Combo'
        WHEN EXISTS (
            SELECT 1 FROM sku_items s1
            JOIN sku_items s2 ON s1.canonical_tx_id = s2.canonical_tx_id
            WHERE s1.canonical_tx_id = si.canonical_tx_id
              AND s1.item_category IN ('personal_care', 'hygiene')
              AND s2.item_category IN ('health', 'medicine', 'vitamins')
        ) THEN 'Health-Care-Combo'
        ELSE 'No-Complementary-Pattern'
    END AS complementary_product_pattern,

    -- =====================================================
    -- BRAND ANALYTICS (Nielsen Taxonomy Integration)
    -- =====================================================
    -- Primary Brand
    brand1.BrandName AS primary_brand,
    brand1_cat.CategoryName AS primary_brand_category,
    brand1_dept.department_name AS primary_brand_department,

    -- Nielsen Hierarchy for Primary Brand
    nh1.CategoryName AS primary_nielsen_category,
    nh1.CategoryPrefix AS primary_nielsen_prefix,
    nh1.HierarchyLevel AS primary_nielsen_level,
    nh1_parent.CategoryName AS primary_nielsen_parent_category,

    -- Brand Variations & Aliases
    brand1.Aliases AS primary_brand_aliases,
    brand1.PronunciationVariations AS primary_brand_pronunciation,

    -- Secondary Brand (for co-purchase analysis)
    brand2.BrandName AS secondary_brand,
    brand2_cat.CategoryName AS secondary_brand_category,
    brand2_dept.department_name AS secondary_brand_department,

    -- =====================================================
    -- CONVERSATION INTELLIGENCE
    -- =====================================================
    si.TranscriptionText AS conversation_text,
    LEN(si.TranscriptionText) AS conversation_length,

    -- Brand mentions in conversation
    sib_primary.BrandName AS conversation_primary_brand,
    sib_primary.Confidence AS conversation_primary_confidence,

    -- All brands mentioned
    stuff((
        SELECT '; ' + sib.BrandName + ' (' + CAST(sib.Confidence AS VARCHAR(10)) + ')'
        FROM SalesInteractionBrands sib
        WHERE sib.InteractionID = si.InteractionID
          AND sib.Confidence > 0.5
        ORDER BY sib.Confidence DESC
        FOR XML PATH('')
    ), 1, 2, '') AS all_brands_mentioned,

    -- Brand switching indicators
    CASE
        WHEN (SELECT COUNT(DISTINCT sib.BrandName)
              FROM SalesInteractionBrands sib
              WHERE sib.InteractionID = si.InteractionID
                AND sib.Confidence > 0.5) > 1
        THEN 'Brand-Switch-Considered'
        ELSE 'Single-Brand'
    END AS brand_switching_indicator,

    -- =====================================================
    -- SUBSTITUTION PATTERNS (Brand/Product/SKU)
    -- =====================================================
    -- Substitution event from SalesInteractions
    si.WasSubstitution AS substitution_occurred,

    -- Substitution analysis from conversation
    CASE
        WHEN si.TranscriptionText LIKE '%hindi available%' OR si.TranscriptionText LIKE '%out of stock%'
        THEN 'Stock-Out-Substitution'
        WHEN si.TranscriptionText LIKE '%mas mura%' OR si.TranscriptionText LIKE '%cheaper%'
        THEN 'Price-Driven-Substitution'
        WHEN si.TranscriptionText LIKE '%try%' OR si.TranscriptionText LIKE '%recommend%'
        THEN 'Recommendation-Substitution'
        WHEN si.WasSubstitution = 1
        THEN 'Confirmed-Substitution'
        ELSE 'No-Substitution'
    END AS substitution_reason_inferred,

    -- Brand substitution patterns (from SalesInteractionBrands)
    CASE
        WHEN EXISTS (
            SELECT 1 FROM SalesInteractionBrands sib1
            JOIN SalesInteractionBrands sib2 ON sib1.InteractionID = sib2.InteractionID
            WHERE sib1.InteractionID = si.InteractionID
              AND sib1.BrandName != sib2.BrandName
              AND sib1.Confidence > 0.3 AND sib2.Confidence > 0.3
              -- Same category brands (competitors)
              AND EXISTS (
                  SELECT 1 FROM dbo.Brands b1
                  JOIN dbo.Brands b2 ON b1.CategoryID = b2.CategoryID
                  WHERE b1.BrandName = sib1.BrandName AND b2.BrandName = sib2.BrandName
              )
        ) THEN 'Within-Category-Substitution'
        WHEN EXISTS (
            SELECT 1 FROM SalesInteractionBrands sib1
            JOIN SalesInteractionBrands sib2 ON sib1.InteractionID = sib2.InteractionID
            WHERE sib1.InteractionID = si.InteractionID
              AND sib1.BrandName != sib2.BrandName
              AND sib1.Confidence > 0.3 AND sib2.Confidence > 0.3
        ) THEN 'Cross-Category-Substitution'
        ELSE 'No-Brand-Substitution'
    END AS brand_substitution_pattern,

    -- SKU-level substitution (comparing similar products)
    CASE
        WHEN EXISTS (
            SELECT 1 FROM sku_items s1
            WHERE s1.canonical_tx_id = si.canonical_tx_id
              AND s1.item_category = sku1.item_category
              AND s1.item_brand != sku1.item_brand
        ) THEN 'SKU-Level-Substitution'
        ELSE 'No-SKU-Substitution'
    END AS sku_substitution_pattern,

    -- Price-based substitution analysis
    CASE
        WHEN sku1.item_unit_price < (
            SELECT AVG(item_unit_price) FROM sku_items
            WHERE item_category = sku1.item_category
        ) THEN 'Downward-Price-Substitution'
        WHEN sku1.item_unit_price > (
            SELECT AVG(item_unit_price) FROM sku_items
            WHERE item_category = sku1.item_category
        ) THEN 'Upward-Price-Substitution'
        ELSE 'Average-Price-Selection'
    END AS price_substitution_direction,

    -- =====================================================
    -- TRANSACTION PATTERNS & ANALYTICS
    -- =====================================================
    CASE
        WHEN si.BasketSize = 1 THEN 'Single-Item'
        WHEN si.BasketSize BETWEEN 2 AND 3 THEN 'Small-Basket'
        WHEN si.BasketSize BETWEEN 4 AND 6 THEN 'Medium-Basket'
        WHEN si.BasketSize > 6 THEN 'Large-Basket'
        ELSE 'Unknown'
    END AS basket_size_category,

    CASE
        WHEN COALESCE(si.TransactionValue, pt.amount) < 50 THEN 'Low-Value'
        WHEN COALESCE(si.TransactionValue, pt.amount) BETWEEN 50 AND 150 THEN 'Medium-Value'
        WHEN COALESCE(si.TransactionValue, pt.amount) BETWEEN 150 AND 300 THEN 'High-Value'
        WHEN COALESCE(si.TransactionValue, pt.amount) > 300 THEN 'Premium'
        ELSE 'Unknown'
    END AS transaction_value_category,

    -- Cross-category purchase indicator
    CASE
        WHEN (SELECT COUNT(DISTINCT sku_items.item_category)
              FROM sku_items
              WHERE sku_items.canonical_tx_id = si.canonical_tx_id) > 1
        THEN 'Cross-Category'
        ELSE 'Single-Category'
    END AS purchase_pattern,

    -- =====================================================
    -- PERSONA INFERENCE & CUSTOMER SEGMENTATION
    -- =====================================================
    -- Basic demographic personas
    CASE
        WHEN si.Age BETWEEN 18 AND 35 AND si.Gender = 'Female' THEN 'Young-Female'
        WHEN si.Age BETWEEN 18 AND 35 AND si.Gender = 'Male' THEN 'Young-Male'
        WHEN si.Age BETWEEN 36 AND 50 AND si.Gender = 'Female' THEN 'Adult-Female'
        WHEN si.Age BETWEEN 36 AND 50 AND si.Gender = 'Male' THEN 'Adult-Male'
        WHEN si.Age > 50 THEN 'Senior'
        ELSE 'Unknown'
    END AS customer_segment,

    -- Shopping behavior personas (based on basket analysis)
    CASE
        WHEN si.BasketSize = 1 AND COALESCE(si.TransactionValue, pt.amount) < 50
        THEN 'Quick-Shopper'
        WHEN si.BasketSize > 5 AND COALESCE(si.TransactionValue, pt.amount) > 200
        THEN 'Family-Shopper'
        WHEN (SELECT COUNT(DISTINCT sku_items.item_category) FROM sku_items WHERE sku_items.canonical_tx_id = si.canonical_tx_id) > 3
        THEN 'Variety-Seeker'
        WHEN si.WasSubstitution = 1
        THEN 'Brand-Switcher'
        WHEN (SELECT COUNT(DISTINCT sku_items.item_brand) FROM sku_items WHERE sku_items.canonical_tx_id = si.canonical_tx_id) = 1
        THEN 'Brand-Loyal'
        ELSE 'Regular-Shopper'
    END AS shopping_behavior_persona,

    -- Time-based personas
    CASE
        WHEN DATEPART(hour, si.CreatedDate) BETWEEN 6 AND 9 THEN 'Early-Bird'
        WHEN DATEPART(hour, si.CreatedDate) BETWEEN 10 AND 14 THEN 'Midday-Shopper'
        WHEN DATEPART(hour, si.CreatedDate) BETWEEN 15 AND 18 THEN 'After-Work-Shopper'
        WHEN DATEPART(hour, si.CreatedDate) BETWEEN 19 AND 22 THEN 'Evening-Shopper'
        ELSE 'Night-Owl'
    END AS time_based_persona,

    -- Value-based personas
    CASE
        WHEN COALESCE(si.TransactionValue, pt.amount) < 30 THEN 'Budget-Conscious'
        WHEN COALESCE(si.TransactionValue, pt.amount) BETWEEN 30 AND 100 THEN 'Value-Seeker'
        WHEN COALESCE(si.TransactionValue, pt.amount) BETWEEN 100 AND 250 THEN 'Regular-Spender'
        WHEN COALESCE(si.TransactionValue, pt.amount) > 250 THEN 'Premium-Shopper'
        ELSE 'Unknown-Value'
    END AS value_based_persona,

    -- Conversation-based personas (from transcription analysis)
    CASE
        WHEN si.TranscriptionText LIKE '%need%' OR si.TranscriptionText LIKE '%kailangan%'
        THEN 'Need-Based-Shopper'
        WHEN si.TranscriptionText LIKE '%sale%' OR si.TranscriptionText LIKE '%discount%' OR si.TranscriptionText LIKE '%promo%'
        THEN 'Deal-Hunter'
        WHEN si.TranscriptionText LIKE '%recommend%' OR si.TranscriptionText LIKE '%suggest%'
        THEN 'Advice-Seeker'
        WHEN si.TranscriptionText LIKE '%quick%' OR si.TranscriptionText LIKE '%mabilis%'
        THEN 'Time-Pressed'
        WHEN LEN(si.TranscriptionText) > 500
        THEN 'Social-Shopper'
        WHEN LEN(si.TranscriptionText) < 50
        THEN 'Silent-Shopper'
        ELSE 'Standard-Communicator'
    END AS conversation_based_persona,

    -- Composite persona (machine learning ready)
    CASE
        WHEN si.Age BETWEEN 18 AND 30 AND si.BasketSize = 1 AND COALESCE(si.TransactionValue, pt.amount) < 50
        THEN 'Young-Quick-Budget'
        WHEN si.Age BETWEEN 30 AND 45 AND si.BasketSize > 3 AND COALESCE(si.TransactionValue, pt.amount) > 150
        THEN 'Family-Value-Focused'
        WHEN si.Age > 45 AND si.WasSubstitution = 0 AND (SELECT COUNT(DISTINCT sku_items.item_brand) FROM sku_items WHERE sku_items.canonical_tx_id = si.canonical_tx_id) = 1
        THEN 'Senior-Brand-Loyal'
        WHEN si.WasSubstitution = 1 AND COALESCE(si.TransactionValue, pt.amount) < 100
        THEN 'Price-Conscious-Switcher'
        WHEN (SELECT COUNT(DISTINCT sku_items.item_category) FROM sku_items WHERE sku_items.canonical_tx_id = si.canonical_tx_id) > 2
        THEN 'Multi-Category-Explorer'
        ELSE 'General-Shopper'
    END AS composite_persona,

    -- Persona confidence score (0-1, based on data completeness)
    CASE
        WHEN si.Age IS NOT NULL AND si.Gender IS NOT NULL AND si.TranscriptionText IS NOT NULL
             AND si.BasketSize IS NOT NULL AND pt.payload_json IS NOT NULL
        THEN 1.0
        WHEN si.Age IS NOT NULL AND si.Gender IS NOT NULL AND si.BasketSize IS NOT NULL
        THEN 0.8
        WHEN si.Age IS NOT NULL AND si.Gender IS NOT NULL
        THEN 0.6
        WHEN si.BasketSize IS NOT NULL AND pt.payload_json IS NOT NULL
        THEN 0.5
        ELSE 0.3
    END AS persona_confidence_score,

    -- =====================================================
    -- PAYLOAD & ETL METADATA
    -- =====================================================
    CASE
        WHEN si.canonical_tx_id IS NOT NULL AND pt.canonical_tx_id IS NOT NULL THEN 'Complete-Data'
        WHEN si.canonical_tx_id IS NOT NULL THEN 'Interaction-Only'
        WHEN pt.canonical_tx_id IS NOT NULL THEN 'Payload-Only'
        ELSE 'Missing-Data'
    END AS data_completeness_status,

    LEFT(pt.payload_json, 200) AS payload_json_sample,
    LEN(pt.payload_json) AS payload_size_bytes,

    -- =====================================================
    -- AUDIT FIELDS
    -- =====================================================
    si.CreatedDate AS interaction_created_date,
    pt.ingestion_timestamp AS payload_ingested_date,
    GETUTCDATE() AS flattened_dataset_generated_date

-- =====================================================
-- FROM CLAUSE: Main fact tables with LEFT JOINs
-- =====================================================
FROM dbo.SalesInteractions si
    LEFT JOIN dbo.PayloadTransactions pt ON si.canonical_tx_id = pt.canonical_tx_id

    -- Store Hierarchy Joins
    LEFT JOIN dbo.Stores s ON si.StoreID = s.StoreID
    LEFT JOIN dbo.Region r ON s.RegionID = r.RegionID
    LEFT JOIN dbo.Province p ON s.ProvinceID = p.ProvinceID
    LEFT JOIN dbo.Municipality m ON s.MunicipalityID = m.MunicipalityID
    LEFT JOIN dbo.Barangay b ON s.BarangayID = b.BarangayID

    -- SKU-Level Data (Primary and Secondary Items)
    LEFT JOIN sku_items sku1 ON si.canonical_tx_id = sku1.canonical_tx_id AND sku1.item_rank = 1
    LEFT JOIN sku_items sku2 ON si.canonical_tx_id = sku2.canonical_tx_id AND sku2.item_rank = 2

    -- Brand Analytics (Primary Brand from SKU)
    LEFT JOIN dbo.Brands brand1 ON sku1.item_brand = brand1.BrandName
    LEFT JOIN BrandCategoryMapping bcm1 ON brand1.BrandName = bcm1.brand_name
    LEFT JOIN TaxonomyCategories brand1_cat ON bcm1.category_id = brand1_cat.category_id
    LEFT JOIN TaxonomyDepartments brand1_dept ON brand1_cat.department_id = brand1_dept.department_id

    -- Nielsen Hierarchy for Primary Brand
    LEFT JOIN ref.NielsenHierarchy nh1 ON brand1.CategoryID = nh1.NielsenCategoryID
    LEFT JOIN ref.NielsenHierarchy nh1_parent ON nh1.ParentCategoryID = nh1_parent.NielsenCategoryID

    -- Secondary Brand Analytics
    LEFT JOIN dbo.Brands brand2 ON sku2.item_brand = brand2.BrandName
    LEFT JOIN BrandCategoryMapping bcm2 ON brand2.BrandName = bcm2.brand_name
    LEFT JOIN TaxonomyCategories brand2_cat ON bcm2.category_id = brand2_cat.category_id
    LEFT JOIN TaxonomyDepartments brand2_dept ON brand2_cat.department_id = brand2_dept.department_id

    -- Conversation Brand Analytics (Primary mention)
    LEFT JOIN SalesInteractionBrands sib_primary ON si.InteractionID = sib_primary.InteractionID
        AND sib_primary.Confidence = (
            SELECT MAX(sib_max.Confidence)
            FROM SalesInteractionBrands sib_max
            WHERE sib_max.InteractionID = si.InteractionID
        )

WHERE si.canonical_tx_id IS NOT NULL;

GO

PRINT 'Complete flattened dataset view created: dbo.v_complete_flattened_dataset';
GO

-- =====================================================
-- MATERIALIZED TABLE VERSION (For Performance)
-- =====================================================

CREATE OR ALTER PROCEDURE dbo.sp_materialize_complete_flattened_dataset
AS
BEGIN
    SET NOCOUNT ON;

    -- Drop existing materialized table
    IF OBJECT_ID('dbo.complete_flattened_dataset', 'U') IS NOT NULL
        DROP TABLE dbo.complete_flattened_dataset;

    -- Create materialized table from view
    SELECT *
    INTO dbo.complete_flattened_dataset
    FROM dbo.v_complete_flattened_dataset;

    -- Add primary key
    ALTER TABLE dbo.complete_flattened_dataset
    ADD CONSTRAINT PK_complete_flattened_dataset PRIMARY KEY (transaction_id);

    -- Add indexes for common queries
    CREATE INDEX IX_complete_flattened_dataset_store ON dbo.complete_flattened_dataset (store_id);
    CREATE INDEX IX_complete_flattened_dataset_date ON dbo.complete_flattened_dataset (transaction_date);
    CREATE INDEX IX_complete_flattened_dataset_brand ON dbo.complete_flattened_dataset (primary_brand);
    CREATE INDEX IX_complete_flattened_dataset_customer ON dbo.complete_flattened_dataset (customer_segment);
    CREATE INDEX IX_complete_flattened_dataset_region ON dbo.complete_flattened_dataset (region_name);

    PRINT 'Materialized complete flattened dataset created with ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';
END;
GO

PRINT 'Complete flattened dataset system created successfully!';
PRINT '';
PRINT 'Usage:';
PRINT '1. View: SELECT * FROM dbo.v_complete_flattened_dataset';
PRINT '2. Materialize: EXEC dbo.sp_materialize_complete_flattened_dataset';
PRINT '3. Query materialized: SELECT * FROM dbo.complete_flattened_dataset';