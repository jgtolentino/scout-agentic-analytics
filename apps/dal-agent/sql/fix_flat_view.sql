CREATE OR ALTER VIEW dbo.v_flat_export_sheet AS
WITH primary_item AS (           -- pick one brand per basket (largest qty; tie-breaker by item id)
  SELECT
    ti.canonical_tx_id,
    ti.TransactionItemId,
    ti.brand_name AS brand_raw,
    LOWER(REPLACE(REPLACE(ti.brand_name,' ',''),'-','')) AS brand_norm,
    TRY_CAST(ti.Qty AS int) AS qty,
    ROW_NUMBER() OVER (
      PARTITION BY ti.canonical_tx_id
      ORDER BY TRY_CAST(ti.Qty AS int) DESC, ti.TransactionItemId ASC
    ) AS rn
  FROM dbo.TransactionItems ti
),
others AS (                      -- all other brands in the basket (pipe list)
  SELECT
    ti.canonical_tx_id,
    STRING_AGG(NULLIF(LTRIM(RTRIM(ti.brand_name)),''), N' | ')
      AS other_products
  FROM dbo.TransactionItems ti
  JOIN primary_item p
    ON p.canonical_tx_id = ti.canonical_tx_id
  WHERE ti.brand_name IS NOT NULL
    AND LOWER(REPLACE(REPLACE(ti.brand_name,' ',''),'-','')) <> p.brand_norm
  GROUP BY ti.canonical_tx_id
),
cat AS (                         -- category by brand (prefer Nielsen FK if present)
  SELECT
    bcm.BrandNameNorm,
    COALESCE(nc.category_name, bcm.NielsenCategory) AS CategoryName
  FROM dbo.BrandCategoryMapping bcm
  LEFT JOIN ref.NielsenCategories nc
    ON nc.category_code = bcm.CategoryCode AND nc.is_active = 1
)
SELECT
  /* 1  */ b.canonical_tx_id                                 AS [Transaction_ID],
  /* 2  */ b.transaction_value                                AS [Transaction_Value],
  /* 3  */ b.basket_size                                      AS [Basket_Size],
  /* 4  */ c.CategoryName                                     AS [Category],
  /* 5  */ p.brand_raw                                        AS [Brand],
  /* 6  */ CASE
            WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 5  AND 11 THEN 'morning'
            WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 12 AND 17 THEN 'afternoon'
            WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 18 AND 22 THEN 'evening'
            ELSE 'night'
          END                                                 AS [Daypart],
  /* 7  */ CONCAT(COALESCE(si.age_bracket,''),' ',
                 COALESCE(si.gender,''),' ',
                 COALESCE(si.customer_type,''))               AS [Demographics (Age/Gender/Role)],
  /* 8  */ CASE WHEN DATENAME(WEEKDAY, si.TransactionDate) IN ('Saturday','Sunday')
                THEN 'Weekend' ELSE 'Weekday' END            AS [Weekday_vs_Weekend],
  /* 9  */ FORMAT(si.TransactionDate, 'htt', 'en-US')         AS [Time of transaction],
  /* 10 */ COALESCE(b.store_name, b.municipality_name, CAST(b.store_id AS nvarchar(32)))
                                                             AS [Location],
  /* 11 */ COALESCE(o.other_products, '')                     AS [Other_Products],
  /* 12 */ CASE WHEN COALESCE(s.was_substitution,0)=1 THEN 'true'
               WHEN s.was_substitution=0 THEN 'false' ELSE '' END
                                                             AS [Was_Substitution]
FROM dbo.v_transactions_flat_production b                    -- ✅ single base row per tx
LEFT JOIN dbo.SalesInteractions si
  ON si.canonical_tx_id = b.canonical_tx_id                  -- ✅ single-key join
LEFT JOIN primary_item p
  ON p.canonical_tx_id = b.canonical_tx_id AND p.rn = 1
LEFT JOIN cat c
  ON c.BrandNameNorm = p.brand_norm
LEFT JOIN others o
  ON o.canonical_tx_id = b.canonical_tx_id
LEFT JOIN (
  SELECT v.sessionId AS canonical_tx_id,
         MAX(CASE WHEN v.substitution_event = '1' THEN 1 ELSE 0 END) AS was_substitution
  FROM dbo.v_insight_base v
  WHERE v.sessionId IS NOT NULL
  GROUP BY v.sessionId
) s
  ON s.canonical_tx_id = b.canonical_tx_id;