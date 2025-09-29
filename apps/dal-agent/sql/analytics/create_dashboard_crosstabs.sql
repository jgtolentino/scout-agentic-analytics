-- =====================================================
-- Dashboard Cross-Tab Views for Scout v7 Analytics
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

/* ===========================
   TIME OF DAY
   =========================== */

-- Time of Day × Product Category
CREATE OR ALTER VIEW gold.v_xtab_time_of_day__category AS
SELECT
  dt.daypart,
  COALESCE(p.Category, 'Unknown') AS category,
  COUNT_BIG(*) AS tx_count
FROM canonical.SalesInteractionFact f
LEFT JOIN dbo.DimTime dt       ON dt.time_key = f.time_key
LEFT JOIN dbo.Products p       ON p.ProductID = f.product_id
GROUP BY dt.daypart, COALESCE(p.Category, 'Unknown');
GO

-- Time of Day × Brand (primary brand via top-confidence subquery)
CREATE OR ALTER VIEW gold.v_xtab_time_of_day__brand AS
WITH primary_brand AS (
  SELECT
    si.InteractionID,
    (SELECT TOP 1 sib.BrandName
     FROM SalesInteractionBrands sib
     WHERE sib.InteractionID = si.InteractionID
     ORDER BY sib.Confidence DESC) AS brand
  FROM dbo.SalesInteractions si
)
SELECT
  dt.daypart,
  COALESCE(pb.brand, 'Unknown') AS brand,
  COUNT_BIG(*) AS tx_count
FROM canonical.SalesInteractionFact f
LEFT JOIN dbo.DimTime dt  ON dt.time_key = f.time_key
LEFT JOIN dbo.SalesInteractions si ON si.InteractionID = f.interaction_id
LEFT JOIN primary_brand pb ON pb.InteractionID = si.InteractionID
GROUP BY dt.daypart, COALESCE(pb.brand, 'Unknown');
GO

-- Time of Day × Demographics (Age Bracket)
CREATE OR ALTER VIEW gold.v_xtab_time_of_day__age_bracket AS
SELECT
  dt.daypart,
  CASE
    WHEN f.age BETWEEN 13 AND 17 THEN 'Teen'
    WHEN f.age BETWEEN 18 AND 24 THEN '18-24'
    WHEN f.age BETWEEN 25 AND 34 THEN '25-34'
    WHEN f.age BETWEEN 35 AND 44 THEN '35-44'
    WHEN f.age BETWEEN 45 AND 54 THEN '45-54'
    WHEN f.age >= 55 THEN '55+'
    ELSE 'Unknown'
  END AS age_bracket,
  COUNT_BIG(*) AS tx_count
FROM canonical.SalesInteractionFact f
LEFT JOIN dbo.DimTime dt ON dt.time_key = f.time_key
GROUP BY dt.daypart,
  CASE
    WHEN f.age BETWEEN 13 AND 17 THEN 'Teen'
    WHEN f.age BETWEEN 18 AND 24 THEN '18-24'
    WHEN f.age BETWEEN 25 AND 34 THEN '25-34'
    WHEN f.age BETWEEN 35 AND 44 THEN '35-44'
    WHEN f.age BETWEEN 45 AND 54 THEN '45-54'
    WHEN f.age >= 55 THEN '55+'
    ELSE 'Unknown'
  END;
GO

-- Time of Day × Emotions
CREATE OR ALTER VIEW gold.v_xtab_time_of_day__emotion AS
SELECT
  dt.daypart,
  COALESCE(si.EmotionalState, 'Unknown') AS emotion,
  COUNT_BIG(*) AS tx_count
FROM canonical.SalesInteractionFact f
LEFT JOIN dbo.DimTime dt ON dt.time_key = f.time_key
LEFT JOIN dbo.SalesInteractions si ON si.InteractionID = f.interaction_id
GROUP BY dt.daypart, COALESCE(si.EmotionalState, 'Unknown');
GO


/* ===========================
   BASKET BEHAVIOR
   =========================== */

-- Basket Size bucketing helper (1=Small, 2-3=Medium, 4+=Large)
CREATE OR ALTER VIEW gold.v_basket_size_buckets AS
SELECT
  f.canonical_tx_id,
  CASE
    WHEN COALESCE(f.basket_size,1) = 1 THEN 'Small (1)'
    WHEN COALESCE(f.basket_size,1) BETWEEN 2 AND 3 THEN 'Medium (2–3)'
    WHEN COALESCE(f.basket_size,1) >= 4 THEN 'Large (4+)'
    ELSE 'Small (1)'
  END AS basket_bucket
FROM canonical.SalesInteractionFact f;
GO

-- Basket Size × Product Category
CREATE OR ALTER VIEW gold.v_xtab_basket__category AS
SELECT
  bsb.basket_bucket,
  COALESCE(p.Category, 'Unknown') AS category,
  COUNT_BIG(*) AS tx_count
FROM gold.v_basket_size_buckets bsb
JOIN canonical.SalesInteractionFact f ON f.canonical_tx_id = bsb.canonical_tx_id
LEFT JOIN dbo.Products p ON p.ProductID = f.product_id
GROUP BY bsb.basket_bucket, COALESCE(p.Category, 'Unknown');
GO

-- Basket Size × Payment Method (payments placeholder view)
CREATE OR ALTER VIEW gold.v_xtab_basket__payment AS
SELECT
  bsb.basket_bucket,
  COALESCE(pay.payment_method, 'Unknown') AS payment_method,
  COUNT_BIG(*) AS tx_count
FROM gold.v_basket_size_buckets bsb
JOIN canonical.SalesInteractionFact f ON f.canonical_tx_id = bsb.canonical_tx_id
LEFT JOIN gold.v_tx_payments pay ON pay.canonical_tx_id = f.canonical_tx_id
GROUP BY bsb.basket_bucket, COALESCE(pay.payment_method, 'Unknown');
GO

-- Basket Size × Customer Type (uses v_customer_type)
CREATE OR ALTER VIEW gold.v_xtab_basket__customer_type AS
SELECT
  bsb.basket_bucket,
  COALESCE(ct.customer_type, 'Unknown') AS customer_type,
  COUNT_BIG(*) AS tx_count
FROM gold.v_basket_size_buckets bsb
JOIN canonical.SalesInteractionFact f ON f.canonical_tx_id = bsb.canonical_tx_id
LEFT JOIN gold.v_customer_type ct ON ct.interaction_id = f.interaction_id
GROUP BY bsb.basket_bucket, COALESCE(ct.customer_type, 'Unknown');
GO

-- Basket Size × Emotions
CREATE OR ALTER VIEW gold.v_xtab_basket__emotion AS
SELECT
  bsb.basket_bucket,
  COALESCE(si.EmotionalState, 'Unknown') AS emotion,
  COUNT_BIG(*) AS tx_count
FROM gold.v_basket_size_buckets bsb
JOIN canonical.SalesInteractionFact f ON f.canonical_tx_id = bsb.canonical_tx_id
LEFT JOIN dbo.SalesInteractions si ON si.InteractionID = f.interaction_id
GROUP BY bsb.basket_bucket, COALESCE(si.EmotionalState, 'Unknown');
GO


/* ===========================
   PRODUCT / BRAND SWITCHING
   =========================== */

-- Substitution Event × Product Category (uses f.was_substitution)
CREATE OR ALTER VIEW gold.v_xtab_substitution__category AS
SELECT
  CASE WHEN COALESCE(f.was_substitution,0) = 1 THEN 'Substitution' ELSE 'No Substitution' END AS substitution_status,
  COALESCE(p.Category, 'Unknown') AS category,
  COUNT_BIG(*) AS tx_count
FROM canonical.SalesInteractionFact f
LEFT JOIN dbo.Products p ON p.ProductID = f.product_id
GROUP BY CASE WHEN COALESCE(f.was_substitution,0) = 1 THEN 'Substitution' ELSE 'No Substitution' END,
         COALESCE(p.Category, 'Unknown');
GO

-- Substitution Event × Reason (heuristic on transcript)
-- Heuristic: stockout if contains 'wala', 'ubos'; suggestion if contains 'pwede', 'na lang', 'meron bang [alt]'
CREATE OR ALTER VIEW gold.v_xtab_substitution__reason AS
SELECT
  CASE WHEN COALESCE(f.was_substitution,0) = 1 THEN 'Substitution' ELSE 'No Substitution' END AS substitution_status,
  CASE
    WHEN si.TranscriptionText LIKE '%wala%' OR si.TranscriptionText LIKE '%ubos%' THEN 'Stockout'
    WHEN si.TranscriptionText LIKE '%pwede%' OR si.TranscriptionText LIKE '%na lang%' THEN 'Storeowner Suggestion'
    ELSE 'Unspecified'
  END AS reason,
  COUNT_BIG(*) AS tx_count
FROM canonical.SalesInteractionFact f
LEFT JOIN dbo.SalesInteractions si ON si.InteractionID = f.interaction_id
GROUP BY CASE WHEN COALESCE(f.was_substitution,0) = 1 THEN 'Substitution' ELSE 'No Substitution' END,
         CASE
           WHEN si.TranscriptionText LIKE '%wala%' OR si.TranscriptionText LIKE '%ubos%' THEN 'Stockout'
           WHEN si.TranscriptionText LIKE '%pwede%' OR si.TranscriptionText LIKE '%na lang%' THEN 'Storeowner Suggestion'
           ELSE 'Unspecified'
         END;
GO

-- Suggestion Accepted × Brand (proxy/heuristic)
-- Heuristic acceptance if multiple brands mentioned and top confidence < 0.90
CREATE OR ALTER VIEW gold.v_xtab_suggestion_accepted__brand AS
WITH brand_stats AS (
  SELECT
    si.InteractionID,
    COUNT(DISTINCT sib.BrandName) AS brand_count,
    MAX(TRY_CONVERT(decimal(9,3), sib.Confidence)) AS top_conf,
    (SELECT TOP 1 sib1.BrandName FROM SalesInteractionBrands sib1
     WHERE sib1.InteractionID = si.InteractionID
     ORDER BY sib1.Confidence DESC) AS primary_brand
  FROM dbo.SalesInteractions si
  LEFT JOIN SalesInteractionBrands sib ON sib.InteractionID = si.InteractionID
  GROUP BY si.InteractionID
)
SELECT
  CASE WHEN bs.brand_count > 1 AND COALESCE(bs.top_conf,0) < 0.90 THEN 'Suggestion Accepted (Heuristic)'
       WHEN bs.brand_count > 1 THEN 'Considered Multiple'
       ELSE 'Single-Brand'
  END AS suggestion_status,
  COALESCE(bs.primary_brand, 'Unknown') AS brand,
  COUNT_BIG(*) AS tx_count
FROM canonical.SalesInteractionFact f
LEFT JOIN dbo.SalesInteractions si ON si.InteractionID = f.interaction_id
LEFT JOIN brand_stats bs ON bs.InteractionID = si.InteractionID
GROUP BY
  CASE WHEN bs.brand_count > 1 AND COALESCE(bs.top_conf,0) < 0.90 THEN 'Suggestion Accepted (Heuristic)'
       WHEN bs.brand_count > 1 THEN 'Considered Multiple'
       ELSE 'Single-Brand'
  END,
  COALESCE(bs.primary_brand, 'Unknown');
GO


/* ===========================
   SHOPPER DEMOGRAPHICS
   =========================== */

-- Age Bracket × Product Category
CREATE OR ALTER VIEW gold.v_xtab_age_bracket__category AS
SELECT
  CASE
    WHEN f.age BETWEEN 13 AND 17 THEN 'Teen'
    WHEN f.age BETWEEN 18 AND 24 THEN '18-24'
    WHEN f.age BETWEEN 25 AND 34 THEN '25-34'
    WHEN f.age BETWEEN 35 AND 44 THEN '35-44'
    WHEN f.age BETWEEN 45 AND 54 THEN '45-54'
    WHEN f.age >= 55 THEN '55+'
    ELSE 'Unknown'
  END AS age_bracket,
  COALESCE(p.Category, 'Unknown') AS category,
  COUNT_BIG(*) AS tx_count
FROM canonical.SalesInteractionFact f
LEFT JOIN dbo.Products p ON p.ProductID = f.product_id
GROUP BY
  CASE
    WHEN f.age BETWEEN 13 AND 17 THEN 'Teen'
    WHEN f.age BETWEEN 18 AND 24 THEN '18-24'
    WHEN f.age BETWEEN 25 AND 34 THEN '25-34'
    WHEN f.age BETWEEN 35 AND 44 THEN '35-44'
    WHEN f.age BETWEEN 45 AND 54 THEN '45-54'
    WHEN f.age >= 55 THEN '55+'
    ELSE 'Unknown'
  END,
  COALESCE(p.Category, 'Unknown');
GO

-- Age Bracket × Brand (primary brand)
CREATE OR ALTER VIEW gold.v_xtab_age_bracket__brand AS
WITH primary_brand AS (
  SELECT
    si.InteractionID,
    (SELECT TOP 1 sib.BrandName
     FROM SalesInteractionBrands sib
     WHERE sib.InteractionID = si.InteractionID
     ORDER BY sib.Confidence DESC) AS brand
  FROM dbo.SalesInteractions si
)
SELECT
  CASE
    WHEN f.age BETWEEN 13 AND 17 THEN 'Teen'
    WHEN f.age BETWEEN 18 AND 24 THEN '18-24'
    WHEN f.age BETWEEN 25 AND 34 THEN '25-34'
    WHEN f.age BETWEEN 35 AND 44 THEN '35-44'
    WHEN f.age BETWEEN 45 AND 54 THEN '45-54'
    WHEN f.age >= 55 THEN '55+'
    ELSE 'Unknown'
  END AS age_bracket,
  COALESCE(pb.brand, 'Unknown') AS brand,
  COUNT_BIG(*) AS tx_count
FROM canonical.SalesInteractionFact f
LEFT JOIN dbo.SalesInteractions si ON si.InteractionID = f.interaction_id
LEFT JOIN primary_brand pb ON pb.InteractionID = si.InteractionID
GROUP BY
  CASE
    WHEN f.age BETWEEN 13 AND 17 THEN 'Teen'
    WHEN f.age BETWEEN 18 AND 24 THEN '18-24'
    WHEN f.age BETWEEN 25 AND 34 THEN '25-34'
    WHEN f.age BETWEEN 35 AND 44 THEN '35-44'
    WHEN f.age BETWEEN 45 AND 54 THEN '45-54'
    WHEN f.age >= 55 THEN '55+'
    ELSE 'Unknown'
  END,
  COALESCE(pb.brand, 'Unknown');
GO

-- Age Bracket × Pack Size (uses gold.v_tx_sku_size)
CREATE OR ALTER VIEW gold.v_xtab_age_bracket__pack_size AS
SELECT
  CASE
    WHEN f.age BETWEEN 13 AND 17 THEN 'Teen'
    WHEN f.age BETWEEN 18 AND 24 THEN '18-24'
    WHEN f.age BETWEEN 25 AND 34 THEN '25-34'
    WHEN f.age BETWEEN 35 AND 44 THEN '35-44'
    WHEN f.age BETWEEN 45 AND 54 THEN '45-54'
    WHEN f.age >= 55 THEN '55+'
    ELSE 'Unknown'
  END AS age_bracket,
  COALESCE(s.pack_size, 'Standard') AS pack_size,
  COUNT_BIG(*) AS tx_count
FROM canonical.SalesInteractionFact f
LEFT JOIN gold.v_tx_sku_size s ON s.canonical_tx_id = f.canonical_tx_id
GROUP BY
  CASE
    WHEN f.age BETWEEN 13 AND 17 THEN 'Teen'
    WHEN f.age BETWEEN 18 AND 24 THEN '18-24'
    WHEN f.age BETWEEN 25 AND 34 THEN '25-34'
    WHEN f.age BETWEEN 35 AND 44 THEN '35-44'
    WHEN f.age BETWEEN 45 AND 54 THEN '45-54'
    WHEN f.age >= 55 THEN '55+'
    ELSE 'Unknown'
  END,
  COALESCE(s.pack_size, 'Standard');
GO

-- Gender × Daypart
CREATE OR ALTER VIEW gold.v_xtab_gender__daypart AS
SELECT
  COALESCE(NULLIF(f.gender,''), 'Unknown') AS gender,
  dt.daypart,
  COUNT_BIG(*) AS tx_count
FROM canonical.SalesInteractionFact f
LEFT JOIN dbo.DimTime dt ON dt.time_key = f.time_key
GROUP BY COALESCE(NULLIF(f.gender,''), 'Unknown'), dt.daypart;
GO

-- Payment Method × Demographics
CREATE OR ALTER VIEW gold.v_xtab_payment__demographics AS
SELECT
  COALESCE(pay.payment_method, 'Unknown') AS payment_method,
  COALESCE(NULLIF(f.gender,''), 'Unknown') AS gender,
  CASE
    WHEN f.age BETWEEN 13 AND 17 THEN 'Teen'
    WHEN f.age BETWEEN 18 AND 24 THEN '18-24'
    WHEN f.age BETWEEN 25 AND 34 THEN '25-34'
    WHEN f.age BETWEEN 35 AND 44 THEN '35-44'
    WHEN f.age BETWEEN 45 AND 54 THEN '45-54'
    WHEN f.age >= 55 THEN '55+'
    ELSE 'Unknown'
  END AS age_bracket,
  COUNT_BIG(*) AS tx_count
FROM canonical.SalesInteractionFact f
LEFT JOIN gold.v_tx_payments pay ON pay.canonical_tx_id = f.canonical_tx_id
GROUP BY
  COALESCE(pay.payment_method, 'Unknown'),
  COALESCE(NULLIF(f.gender,''), 'Unknown'),
  CASE
    WHEN f.age BETWEEN 13 AND 17 THEN 'Teen'
    WHEN f.age BETWEEN 18 AND 24 THEN '18-24'
    WHEN f.age BETWEEN 25 AND 34 THEN '25-34'
    WHEN f.age BETWEEN 35 AND 44 THEN '35-44'
    WHEN f.age BETWEEN 45 AND 54 THEN '45-54'
    WHEN f.age >= 55 THEN '55+'
    ELSE 'Unknown'
  END;
GO

PRINT 'Dashboard cross-tab views created successfully';
PRINT 'Usage: SELECT * FROM gold.v_xtab_[category]__[dimension]';