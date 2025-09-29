-- =====================================================
-- Complete 45-Column Canonical Export with Defensive Casting
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

CREATE OR ALTER PROCEDURE canonical.sp_complete_canonical_45
AS
BEGIN
  SET NOCOUNT ON;

  SELECT
    -- Core Identity (3)
    pt.canonical_tx_id,
    COALESCE(NULLIF(pt.canonical_tx_id_norm,''), pt.canonical_tx_id)  AS canonical_tx_id_norm,
    COALESCE(NULLIF(pt.canonical_tx_id_payload,''), pt.canonical_tx_id) AS canonical_tx_id_payload,

    -- Temporal (8)
    COALESCE(CONVERT(varchar(10), dd.full_date, 120), 'Unknown')       AS transaction_date,
    COALESCE(dd.year_number, 0)                                        AS year_number,
    COALESCE(dd.month_number, 0)                                       AS month_number,
    COALESCE(dd.month_name, 'Unknown')                                 AS month_name,
    COALESCE(dd.quarter_number, 0)                                     AS quarter_number,
    COALESCE(dd.day_name, 'Unknown')                                   AS day_name,
    COALESCE(dd.weekday_vs_weekend, 'Unknown')                         AS weekday_vs_weekend,
    COALESCE(dd.iso_week, 0)                                           AS iso_week,

    -- Transaction Facts (4)
    COALESCE(f.transaction_value, 0.00)                                AS amount,
    COALESCE(f.transaction_value, 0.00)                                AS transaction_value,
    COALESCE(f.basket_size, 1)                                         AS basket_size,
    COALESCE(TRY_CONVERT(int, f.was_substitution), 0)                  AS was_substitution,

    -- Location (3)
    TRY_CONVERT(varchar(50), pt.storeId)                               AS store_id,
    COALESCE(TRY_CONVERT(varchar(50), f.product_id), 'Unknown')        AS product_id,
    COALESCE(si.Barangay, 'Unknown')                                   AS barangay,

    -- Demographics (5)
    COALESCE(f.age, 0)                                                 AS age,
    COALESCE(NULLIF(f.gender,''), 'Unknown')                           AS gender,
    COALESCE(NULLIF(si.EmotionalState,''), 'Unknown')                  AS emotional_state,
    COALESCE(TRY_CONVERT(varchar(50), si.FacialID), 'Unknown')         AS facial_id,
    COALESCE(TRY_CONVERT(varchar(50), f.role_id), 'Unknown')           AS role_id,

    -- Persona (4)
    COALESCE(NULLIF(vp.role_final,''), 'Unknown')                      AS persona_id,
    COALESCE(TRY_CONVERT(decimal(9,3), vp.role_confidence), 0.000)     AS persona_confidence,
    COALESCE(NULLIF(vp.role_suggested,''), 'Unknown')                  AS persona_alternative_roles,
    COALESCE(NULLIF(vp.rule_source,''), 'Unknown')                     AS persona_rule_source,

    -- Brand Analytics (7)   (STRING_AGG w/o OVER; Azure SQL-safe)
    COALESCE((
      SELECT TOP 1 sib.BrandName
      FROM SalesInteractionBrands sib
      WHERE sib.InteractionID = si.InteractionID
      ORDER BY sib.Confidence DESC
    ), 'Unknown')                                                      AS primary_brand,

    COALESCE((
      SELECT TOP 1 sib2.BrandName
      FROM SalesInteractionBrands sib2
      WHERE sib2.InteractionID = si.InteractionID
        AND sib2.BrandName <> (
          SELECT TOP 1 sib1.BrandName
          FROM SalesInteractionBrands sib1
          WHERE sib1.InteractionID = si.InteractionID
          ORDER BY sib1.Confidence DESC
        )
      ORDER BY sib2.Confidence DESC
    ), 'Unknown')                                                      AS secondary_brand,

    COALESCE((
      SELECT TOP 1 TRY_CONVERT(decimal(9,3), sib.Confidence)
      FROM SalesInteractionBrands sib
      WHERE sib.InteractionID = si.InteractionID
      ORDER BY sib.Confidence DESC
    ), 0.000)                                                          AS primary_brand_confidence,

    COALESCE((
      SELECT STRING_AGG(sib.BrandName, ';')
      FROM SalesInteractionBrands sib
      WHERE sib.InteractionID = si.InteractionID AND TRY_CONVERT(decimal(9,3), sib.Confidence) > 0.5
    ), '')                                                             AS all_brands_mentioned,

    CASE
      WHEN f.canonical_tx_id IS NULL THEN 'No-Analytics-Data'
      WHEN (
        SELECT COUNT(DISTINCT sib.BrandName)
        FROM SalesInteractionBrands sib
        WHERE sib.InteractionID = si.InteractionID
      ) > 1 THEN 'Brand-Switch-Considered'
      ELSE 'Single-Brand'
    END                                                                AS brand_switching_indicator,

    COALESCE(si.TranscriptionText, '')                                 AS transcription_text,
    CASE WHEN COALESCE(f.basket_size, 1) > 1 THEN 'Multi-Item' ELSE 'Single-Item' END AS co_purchase_patterns,

    -- Technical (8)
    TRY_CONVERT(varchar(50), pt.deviceId)                              AS device_id,
    TRY_CONVERT(varchar(50), pt.sessionId)                             AS session_id,
    COALESCE(TRY_CONVERT(varchar(50), si.InteractionID), 'Unknown')    AS interaction_id,
    CASE WHEN f.canonical_tx_id IS NOT NULL THEN 'Enhanced-Analytics' ELSE 'Payload-Only' END AS data_source_type,
    CASE WHEN pt.payload_json IS NOT NULL AND LEN(pt.payload_json) > 10 THEN 'JSON-Available' ELSE 'No-JSON' END AS payload_data_status,
    CASE WHEN LEN(pt.payload_json) > 100 THEN LEFT(pt.payload_json,100)+'...' ELSE COALESCE(pt.payload_json,'') END AS payload_json_truncated,
    si.TransactionDate                                                 AS transaction_date_original,
    COALESCE(f.created_date, SYSUTCDATETIME())                         AS created_date,

    -- Derived (3)
    CASE WHEN COALESCE(f.basket_size, 1) > 1 THEN 'Multi-Item' ELSE 'Single-Item' END AS transaction_type,
    CASE
      WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 6  AND 11 THEN 'Morning'
      WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 12 AND 17 THEN 'Afternoon'
      WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 18 AND 21 THEN 'Evening'
      ELSE 'Night'
    END                                                                AS time_of_day_category,
    CASE
      WHEN COALESCE(f.age,0) BETWEEN 18 AND 24 THEN 'Young-Adult'
      WHEN COALESCE(f.age,0) BETWEEN 25 AND 34 THEN 'Adult'
      WHEN COALESCE(f.age,0) BETWEEN 35 AND 54 THEN 'Middle-Age'
      WHEN COALESCE(f.age,0) >= 55 THEN 'Senior'
      ELSE 'Unknown-Age'
    END                                                                AS customer_segment

  FROM PayloadTransactions pt
  LEFT JOIN canonical.SalesInteractionFact f  ON pt.canonical_tx_id = f.canonical_tx_id
  LEFT JOIN dbo.DimDate dd                    ON dd.date_key = f.date_key
  LEFT JOIN dbo.SalesInteractions si          ON si.canonical_tx_id = pt.canonical_tx_id
  LEFT JOIN gold.v_personas_production vp     ON vp.canonical_tx_id = pt.canonical_tx_id
  WHERE pt.canonical_tx_id IS NOT NULL
  ORDER BY pt.canonical_tx_id;
END
GO

PRINT 'Complete 45-column canonical export procedure created successfully';
PRINT 'Usage: EXEC canonical.sp_complete_canonical_45';