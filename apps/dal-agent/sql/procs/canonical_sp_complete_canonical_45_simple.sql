-- =====================================================
-- Simple 45-Column Canonical Export (Working Version)
-- =====================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

CREATE OR ALTER PROCEDURE canonical.sp_complete_canonical_45_simple
AS
BEGIN
  SET NOCOUNT ON;

  SELECT
    -- Core Identity (3)
    pt.canonical_tx_id,
    COALESCE(NULLIF(pt.canonical_tx_id_norm,''), pt.canonical_tx_id)  AS canonical_tx_id_norm,
    COALESCE(NULLIF(pt.canonical_tx_id_payload,''), pt.canonical_tx_id) AS canonical_tx_id_payload,

    -- Temporal (8) - Simplified with NULL handling
    CASE WHEN si.TransactionDate IS NOT NULL THEN CONVERT(varchar(10), si.TransactionDate, 120) ELSE 'Unknown' END AS transaction_date,
    CASE WHEN si.TransactionDate IS NOT NULL THEN YEAR(si.TransactionDate) ELSE 0 END AS year_number,
    CASE WHEN si.TransactionDate IS NOT NULL THEN MONTH(si.TransactionDate) ELSE 0 END AS month_number,
    CASE WHEN si.TransactionDate IS NOT NULL THEN DATENAME(month, si.TransactionDate) ELSE 'Unknown' END AS month_name,
    CASE WHEN si.TransactionDate IS NOT NULL THEN DATEPART(quarter, si.TransactionDate) ELSE 0 END AS quarter_number,
    CASE WHEN si.TransactionDate IS NOT NULL THEN DATENAME(weekday, si.TransactionDate) ELSE 'Unknown' END AS day_name,
    CASE WHEN si.TransactionDate IS NOT NULL AND DATEPART(weekday, si.TransactionDate) IN (1,7) THEN 'Weekend'
         WHEN si.TransactionDate IS NOT NULL THEN 'Weekday' ELSE 'Unknown' END AS weekday_vs_weekend,
    CASE WHEN si.TransactionDate IS NOT NULL THEN DATEPART(week, si.TransactionDate) ELSE 0 END AS iso_week,

    -- Transaction Facts (4)
    COALESCE(f.transaction_value, 0.00)                               AS amount,
    COALESCE(f.transaction_value, 0.00)                               AS transaction_value,
    COALESCE(f.basket_size, 1)                                        AS basket_size,
    COALESCE(CAST(f.was_substitution AS INT), 0)                      AS was_substitution,

    -- Location (3)
    COALESCE(CAST(f.store_id AS VARCHAR(50)), 'Unknown')              AS store_id,
    COALESCE(CAST(f.product_id AS VARCHAR(50)), 'Unknown')            AS product_id,
    COALESCE(si.Barangay, 'Unknown')                                  AS barangay,

    -- Demographics (5)
    COALESCE(f.age, 0)                                                AS age,
    COALESCE(NULLIF(f.gender,''), 'Unknown')                          AS gender,
    COALESCE(NULLIF(si.EmotionalState,''), 'Unknown')                 AS emotional_state,
    COALESCE(CAST(si.FacialID AS VARCHAR(50)), 'Unknown')             AS facial_id,
    COALESCE(CAST(f.role_id AS VARCHAR(50)), 'Unknown')               AS role_id,

    -- Persona (4) - Simplified
    COALESCE(NULLIF(vp.role_final,''), 'Unknown')                     AS persona_id,
    COALESCE(TRY_CONVERT(decimal(9,3), vp.role_confidence), 0.000)    AS persona_confidence,
    COALESCE(NULLIF(vp.role_suggested,''), 'Unknown')                 AS persona_alternative_roles,
    COALESCE(NULLIF(vp.rule_source,''), 'Unknown')                    AS persona_rule_source,

    -- Brand Analytics (7) - Simplified
    'Unknown'                                                         AS primary_brand,
    'Unknown'                                                         AS secondary_brand,
    0.000                                                             AS primary_brand_confidence,
    ''                                                                AS all_brands_mentioned,
    CASE WHEN f.canonical_tx_id IS NULL THEN 'No-Analytics-Data' ELSE 'Single-Brand' END AS brand_switching_indicator,
    COALESCE(si.TranscriptionText, '')                                AS transcription_text,
    CASE WHEN COALESCE(f.basket_size, 1) > 1 THEN 'Multi-Item' ELSE 'Single-Item' END AS co_purchase_patterns,

    -- Technical (8)
    COALESCE(CAST(pt.deviceId AS VARCHAR(50)), 'Unknown')             AS device_id,
    COALESCE(CAST(pt.sessionId AS VARCHAR(50)), 'Unknown')            AS session_id,
    COALESCE(CAST(si.InteractionID AS VARCHAR(50)), 'Unknown')        AS interaction_id,
    CASE WHEN f.canonical_tx_id IS NOT NULL THEN 'Enhanced-Analytics' ELSE 'Payload-Only' END AS data_source_type,
    CASE WHEN pt.payload_json IS NOT NULL AND LEN(pt.payload_json) > 10 THEN 'JSON-Available' ELSE 'No-JSON' END AS payload_data_status,
    CASE WHEN LEN(pt.payload_json) > 100 THEN LEFT(pt.payload_json,100)+'...' ELSE COALESCE(pt.payload_json,'') END AS payload_json_truncated,
    si.TransactionDate                                                AS transaction_date_original,
    COALESCE(f.created_date, GETUTCDATE())                            AS created_date,

    -- Derived (3)
    CASE WHEN COALESCE(f.basket_size, 1) > 1 THEN 'Multi-Item' ELSE 'Single-Item' END AS transaction_type,
    CASE
      WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 6  AND 11 THEN 'Morning'
      WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 12 AND 17 THEN 'Afternoon'
      WHEN DATEPART(HOUR, si.TransactionDate) BETWEEN 18 AND 21 THEN 'Evening'
      ELSE 'Night'
    END                                                               AS time_of_day_category,
    CASE
      WHEN COALESCE(f.age,0) BETWEEN 18 AND 24 THEN 'Young-Adult'
      WHEN COALESCE(f.age,0) BETWEEN 25 AND 34 THEN 'Adult'
      WHEN COALESCE(f.age,0) BETWEEN 35 AND 54 THEN 'Middle-Age'
      WHEN COALESCE(f.age,0) >= 55 THEN 'Senior'
      ELSE 'Unknown-Age'
    END                                                               AS customer_segment

  FROM PayloadTransactions pt
  LEFT JOIN canonical.SalesInteractionFact f  ON pt.canonical_tx_id = f.canonical_tx_id
  LEFT JOIN dbo.SalesInteractions si          ON si.canonical_tx_id = pt.canonical_tx_id
  LEFT JOIN gold.v_personas_production vp     ON vp.canonical_tx_id = pt.canonical_tx_id
  WHERE pt.canonical_tx_id IS NOT NULL
  ORDER BY pt.canonical_tx_id;
END
GO

PRINT 'Simple 45-column canonical export procedure created successfully';
PRINT 'Usage: EXEC canonical.sp_complete_canonical_45_simple';