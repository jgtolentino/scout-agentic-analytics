/* ===========================================
   COMPLETE 45-COLUMN EXPORT (type-safe)
   =========================================== */
USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

CREATE OR ALTER PROCEDURE canonical.sp_complete_canonical_45_safe
AS
BEGIN
  SET NOCOUNT ON;

  /* brand picks via OUTER APPLY to avoid subqueries + keep types clean */
  WITH si_join AS (
    SELECT
      pt.canonical_tx_id,
      pt.canonical_tx_id_norm,
      pt.canonical_tx_id_payload,
      pt.deviceId, pt.sessionId, pt.payload_json,
      pt.storeId,
      si.InteractionID,
      si.TransactionDate,
      si.FacialID,
      si.EmotionalState,
      si.Barangay,
      f.product_id,
      f.age, f.gender, f.role_id,
      TRY_CONVERT(decimal(18,2), f.transaction_value) AS transaction_value,
      COALESCE(f.basket_size, 1) AS basket_size,
      COALESCE(CAST(f.was_substitution AS int), 0) AS was_substitution,
      f.date_key, f.time_key,
      f.created_date
    FROM PayloadTransactions       pt
    LEFT JOIN canonical.SalesInteractionFact f
           ON f.canonical_tx_id = pt.canonical_tx_id
    LEFT JOIN dbo.SalesInteractions si
           ON si.canonical_tx_id = pt.canonical_tx_id
    WHERE pt.canonical_tx_id IS NOT NULL
  )
  SELECT
    /* Identity (3) */
    s.canonical_tx_id,
    COALESCE(NULLIF(s.canonical_tx_id_norm,''), s.canonical_tx_id)   AS canonical_tx_id_norm,
    COALESCE(NULLIF(s.canonical_tx_id_payload,''), s.canonical_tx_id) AS canonical_tx_id_payload,

    /* Temporal (8) – all numeric stay numeric, strings stay strings */
    CASE WHEN s.TransactionDate IS NOT NULL
         THEN CONVERT(varchar(10), s.TransactionDate, 120)
         ELSE 'Unknown' END                                           AS transaction_date,
    COALESCE(YEAR(s.TransactionDate), 0)                               AS year_number,
    COALESCE(MONTH(s.TransactionDate), 0)                              AS month_number,
    CASE WHEN s.TransactionDate IS NOT NULL
         THEN DATENAME(month, s.TransactionDate) ELSE 'Unknown' END    AS month_name,
    COALESCE(DATEPART(quarter, s.TransactionDate), 0)                  AS quarter_number,
    CASE WHEN s.TransactionDate IS NOT NULL
         THEN DATENAME(weekday, s.TransactionDate) ELSE 'Unknown' END  AS day_name,
    CASE
      WHEN s.TransactionDate IS NULL                      THEN 'Unknown'
      WHEN DATEPART(weekday, s.TransactionDate) IN (1,7)  THEN 'Weekend'
      ELSE 'Weekday'
    END                                                                AS weekday_vs_weekend,
    COALESCE(DATEPART(ISO_WEEK, s.TransactionDate), 0)                 AS iso_week,

    /* Transaction Facts (4) */
    COALESCE(s.transaction_value, TRY_CONVERT(decimal(18,2), 0))       AS amount,          -- echo as amount
    COALESCE(s.transaction_value, TRY_CONVERT(decimal(18,2), 0))       AS transaction_value,
    s.basket_size,
    s.was_substitution,

    /* Location (3) */
    CAST(s.storeId AS varchar(50))                                     AS store_id,
    COALESCE(CAST(s.product_id AS varchar(50)),'Unknown')              AS product_id,
    COALESCE(s.Barangay,'Unknown')                                     AS barangay,

    /* Demographics (5) */
    COALESCE(s.age, 0)                                                 AS age,
    COALESCE(NULLIF(s.gender,''),'Unknown')                            AS gender,
    COALESCE(s.EmotionalState,'Unknown')                               AS emotional_state,
    COALESCE(CAST(s.FacialID AS varchar(100)),'Unknown')               AS facial_id,
    COALESCE(CAST(s.role_id AS varchar(50)),'Unknown')                 AS role_id,

    /* Persona (4) */
    COALESCE(vp.role_final,'Unknown')                                   AS persona_id,
    COALESCE(TRY_CONVERT(decimal(9,3), vp.role_confidence), 0.000)      AS persona_confidence,
    COALESCE(vp.role_suggested,'Unknown')                               AS persona_alternative_roles,
    COALESCE(vp.rule_source,'Unknown')                                  AS persona_rule_source,

    /* Brand Analytics (7) */
    COALESCE(pb.primary_brand,'Unknown')                                 AS primary_brand,
    COALESCE(sb.secondary_brand,'Unknown')                               AS secondary_brand,
    COALESCE(TRY_CONVERT(decimal(9,3), pb.primary_conf), 0.000)          AS primary_brand_confidence,
    COALESCE(ab.all_brands,'')                                           AS all_brands_mentioned,
    CASE
      WHEN s.transaction_value IS NULL THEN 'No-Analytics-Data'
      WHEN pb.primary_brand IS NOT NULL AND sb.secondary_brand IS NOT NULL THEN 'Brand-Switch-Considered'
      ELSE 'Single-Brand'
    END                                                                  AS brand_switching_indicator,
    COALESCE(si.TranscriptionText,'')                                    AS transcription_text,
    CASE WHEN s.basket_size > 1 THEN 'Multi-Item' ELSE 'Single-Item' END AS co_purchase_patterns,

    /* Technical Metadata (8) */
    s.deviceId                                                          AS device_id,
    s.sessionId                                                         AS session_id,
    COALESCE(CAST(si.InteractionID AS varchar(60)),'Unknown')           AS interaction_id,
    CASE WHEN s.transaction_value IS NOT NULL THEN 'Enhanced-Analytics' ELSE 'Payload-Only' END AS data_source_type,
    CASE WHEN s.payload_json IS NOT NULL AND LEN(s.payload_json) > 10 THEN 'JSON-Available' ELSE 'No-JSON' END AS payload_data_status,
    CASE WHEN s.payload_json IS NULL THEN ''
         WHEN LEN(s.payload_json) > 100 THEN LEFT(s.payload_json,100)+'...'
         ELSE s.payload_json END                                        AS payload_json_truncated,
    s.TransactionDate                                                   AS transaction_date_original,
    COALESCE(s.created_date, GETUTCDATE())                              AS created_date,

    /* Derived Analytics (3) */
    CASE WHEN s.basket_size > 1 THEN 'Multi-Item' ELSE 'Single-Item' END AS transaction_type,
    CASE
      WHEN s.TransactionDate IS NULL THEN 'Unknown'
      WHEN DATEPART(HOUR, s.TransactionDate) BETWEEN 6  AND 11 THEN 'Morning'
      WHEN DATEPART(HOUR, s.TransactionDate) BETWEEN 12 AND 17 THEN 'Afternoon'
      WHEN DATEPART(HOUR, s.TransactionDate) BETWEEN 18 AND 21 THEN 'Evening'
      ELSE 'Night'
    END                                                                  AS time_of_day_category,
    CASE
      WHEN COALESCE(s.age,0) BETWEEN 18 AND 24 THEN 'Young-Adult'
      WHEN COALESCE(s.age,0) BETWEEN 25 AND 34 THEN 'Adult'
      WHEN COALESCE(s.age,0) BETWEEN 35 AND 54 THEN 'Middle-Age'
      WHEN COALESCE(s.age,0) >= 55 THEN 'Senior'
      ELSE 'Unknown-Age'
    END                                                                  AS customer_segment
  FROM si_join s
  LEFT JOIN dbo.SalesInteractions si
         ON si.InteractionID = s.InteractionID
  OUTER APPLY (
      SELECT TOP 1 sib.BrandName AS primary_brand,
                   TRY_CONVERT(decimal(9,3), sib.Confidence) AS primary_conf
      FROM SalesInteractionBrands sib
      WHERE sib.InteractionID = s.InteractionID
      ORDER BY sib.Confidence DESC
  ) pb
  OUTER APPLY (
      SELECT TOP 1 sib.BrandName AS secondary_brand
      FROM SalesInteractionBrands sib
      WHERE sib.InteractionID = s.InteractionID
        AND sib.BrandName <> COALESCE(pb.primary_brand,'')
      ORDER BY sib.Confidence DESC
  ) sb
  OUTER APPLY (
      SELECT STUFF((
        SELECT ';' + sib.BrandName
        FROM SalesInteractionBrands sib
        WHERE sib.InteractionID = s.InteractionID
          AND TRY_CONVERT(decimal(9,3), sib.Confidence) > 0.5
        FOR XML PATH('')
      ), 1, 1, '') AS all_brands
  ) ab
  LEFT JOIN gold.v_personas_production vp
         ON vp.canonical_tx_id = s.canonical_tx_id
  ORDER BY s.canonical_tx_id;
END;
GO

PRINT 'Type-safe 45-column canonical export procedure created successfully';
PRINT 'Usage: EXEC canonical.sp_complete_canonical_45_safe';