# Views

## analytics.v_stg_brands

```sql

```

##     CREATE   VIEW analytics.v_stg_brands AS.

```sql

```

##     SELECT.

```sql

```

##       BrandName AS brand_name,.

```sql

```

##       NULL AS parent_company,.

```sql

```

##       Category AS category.

```sql

```

##     FROM [dbo].[Brands] WITH (NOLOCK);.

```sql

```

## analytics.v_stg_products

```sql

```

##     CREATE   VIEW analytics.v_stg_products AS.

```sql

```

##     SELECT.

```sql

```

##       NULL AS sku_code,.

```sql

```

##       ProductName AS product_name,.

```sql

```

##       NULL AS brand_name,.

```sql

```

##       Category AS category,.

```sql

```

##       NULL AS uom,.

```sql

```

##       NULL AS price.

```sql

```

##     FROM [dbo].[Products] WITH (NOLOCK);.

```sql

```

## analytics.v_stg_sales_interactions

```sql

```

##     CREATE   VIEW analytics.v_stg_sales_interactions AS.

```sql

```

##     SELECT.

```sql

```

##       Canonical_Tx_Id AS canonical_tx_id,.

```sql

```

##       NULL AS interaction_ts,.

```sql

```

##       NULL AS age_bracket,.

```sql

```

##       Gender AS gender,.

```sql

```

##       NULL AS emotion,.

```sql

```

##       NULL AS confidence_score,.

```sql

```

##       Devi.

```sql

```

## analytics.v_stg_stores

```sql

```

##     CREATE   VIEW analytics.v_stg_stores AS.

```sql

```

##     SELECT.

```sql

```

##       CAST(StoreID AS int) AS store_id,.

```sql

```

##       NULL AS store_code,.

```sql

```

##       StoreName AS store_name,.

```sql

```

##       Region AS region,.

```sql

```

##       NULL AS province,.

```sql

```

##       NULL AS city_municipality,.

```sql

```

##       Barangay AS bara.

```sql

```

## analytics.v_stg_transaction_items

```sql

```

##     CREATE   VIEW analytics.v_stg_transaction_items AS.

```sql

```

##     SELECT.

```sql

```

##       NULL AS canonical_tx_id,.

```sql

```

##       NULL AS sku,.

```sql

```

##       NULL AS brand,.

```sql

```

##       NULL AS category,.

```sql

```

##       quantity AS quantity,.

```sql

```

##       unit_price AS unit_price,.

```sql

```

##       NULL AS line_amount.

```sql

```

##     FROM.

```sql

```

## analytics.v_stg_transactions

```sql

```

##     CREATE   VIEW analytics.v_stg_transactions AS.

```sql

```

##     SELECT.

```sql

```

##       id AS canonical_tx_id,.

```sql

```

##       timestamp AS txn_ts,.

```sql

```

##       CAST(store_id AS int) AS store_id,.

```sql

```

##       peso_value AS total_amount,.

```sql

```

##       basket_size AS total_items.

```sql

```

##     FROM [gold].[scout_dashboa.

```sql

```

## dbo.ct_ageXbrand

```sql
CREATE VIEW dbo.ct_ageXbrand AS
```

## SELECT age_bracket, brand,.

```sql

```

##   COUNT(*) AS txn_cnt,.

```sql

```

##   SUM(amount) AS sales_total,.

```sql

```

##   AVG(TRY_CAST(basket_size AS float)) AS avg_basket_size.

```sql

```

## FROM dbo.v_insight_base.

```sql

```

## GROUP BY age_bracket, brand;.

```sql

```

## dbo.ct_ageXcategory

```sql
CREATE VIEW dbo.ct_ageXcategory AS
```

## SELECT age_bracket, category,.

```sql

```

##   COUNT(*) AS txn_cnt,.

```sql

```

##   SUM(amount) AS sales_total,.

```sql

```

##   AVG(TRY_CAST(basket_size AS float)) AS avg_basket_size.

```sql

```

## FROM dbo.v_insight_base.

```sql

```

## GROUP BY age_bracket, category;.

```sql

```

## dbo.ct_ageXpack

```sql
CREATE VIEW dbo.ct_ageXpack AS
```

## SELECT age_bracket, pack_size,.

```sql

```

##   COUNT(*) AS txn_cnt,.

```sql

```

##   SUM(amount) AS sales_total,.

```sql

```

##   AVG(TRY_CAST(basket_size AS float)) AS avg_basket_size.

```sql

```

## FROM dbo.v_insight_base.

```sql

```

## GROUP BY age_bracket, pack_size;.

```sql

```

## dbo.ct_basketXcategory

```sql
CREATE VIEW dbo.ct_basketXcategory AS
```

## SELECT basket_size, category,.

```sql

```

##   COUNT(*) AS txn_cnt,.

```sql

```

##   SUM(amount) AS sales_total,.

```sql

```

##   AVG(TRY_CAST(basket_size AS float)) AS avg_basket_size.

```sql

```

## FROM dbo.v_insight_base.

```sql

```

## GROUP BY basket_size, category;.

```sql

```

## dbo.ct_basketXcusttype

```sql
CREATE VIEW dbo.ct_basketXcusttype AS
```

## SELECT basket_size, customer_type,.

```sql

```

##   COUNT(*) AS txn_cnt,.

```sql

```

##   SUM(amount) AS sales_total,.

```sql

```

##   AVG(TRY_CAST(basket_size AS float)) AS avg_basket_size.

```sql

```

## FROM dbo.v_insight_base.

```sql

```

## GROUP BY basket_size, customer_type;.

```sql

```

## dbo.ct_basketXemotions

```sql
CREATE VIEW dbo.ct_basketXemotions AS
```

## SELECT basket_size, emotions,.

```sql

```

##   COUNT(*) AS txn_cnt,.

```sql

```

##   SUM(amount) AS sales_total,.

```sql

```

##   AVG(TRY_CAST(basket_size AS float)) AS avg_basket_size.

```sql

```

## FROM dbo.v_insight_base.

```sql

```

## GROUP BY basket_size, emotions;.

```sql

```

## dbo.ct_basketXpay

```sql
CREATE VIEW dbo.ct_basketXpay AS
```

## SELECT basket_size, payment_method,.

```sql

```

##   COUNT(*) AS txn_cnt,.

```sql

```

##   SUM(amount) AS sales_total,.

```sql

```

##   AVG(TRY_CAST(basket_size AS float)) AS avg_basket_size.

```sql

```

## FROM dbo.v_insight_base.

```sql

```

## GROUP BY basket_size, payment_method;.

```sql

```

## dbo.ct_genderXdaypart

```sql
CREATE VIEW dbo.ct_genderXdaypart AS
```

## SELECT gender, daypart,.

```sql

```

##   COUNT(*) AS txn_cnt,.

```sql

```

##   SUM(amount) AS sales_total,.

```sql

```

##   AVG(TRY_CAST(basket_size AS float)) AS avg_basket_size.

```sql

```

## FROM dbo.v_insight_base.

```sql

```

## GROUP BY gender, daypart;.

```sql

```

## dbo.ct_payXdemo

```sql
CREATE VIEW dbo.ct_payXdemo AS
```

## SELECT payment_method, age_bracket, gender,.

```sql

```

##   COUNT(*) AS txn_cnt,.

```sql

```

##   SUM(amount) AS sales_total,.

```sql

```

##   AVG(TRY_CAST(basket_size AS float)) AS avg_basket_size.

```sql

```

## FROM dbo.v_insight_base.

```sql

```

## GROUP BY payment_method, age_bracket, gender;.

```sql

```

## dbo.ct_substEventXcategory

```sql
CREATE VIEW dbo.ct_substEventXcategory AS
```

## SELECT substitution_event, category,.

```sql

```

##   COUNT(*) AS txn_cnt,.

```sql

```

##   SUM(amount) AS sales_total,.

```sql

```

##   AVG(TRY_CAST(basket_size AS float)) AS avg_basket_size.

```sql

```

## FROM dbo.v_insight_base.

```sql

```

## WHERE substitution_event IS NOT NULL.

```sql

```

## GROUP .

```sql

```

## dbo.ct_substEventXreason

```sql
CREATE VIEW dbo.ct_substEventXreason AS
```

## SELECT substitution_event, substitution_reason,.

```sql

```

##   COUNT(*) AS txn_cnt,.

```sql

```

##   SUM(amount) AS sales_total,.

```sql

```

##   AVG(TRY_CAST(basket_size AS float)) AS avg_basket_size.

```sql

```

## FROM dbo.v_insight_base.

```sql

```

## WHERE substitution_event IS NOT NU.

```sql

```

## dbo.ct_suggestionAcceptedXbrand

```sql
CREATE VIEW dbo.ct_suggestionAcceptedXbrand AS
```

## SELECT suggestion_accepted, brand,.

```sql

```

##   COUNT(*) AS txn_cnt,.

```sql

```

##   SUM(amount) AS sales_total,.

```sql

```

##   AVG(TRY_CAST(basket_size AS float)) AS avg_basket_size.

```sql

```

## FROM dbo.v_insight_base.

```sql

```

## GROUP BY suggestion_accepted, brand;.

```sql

```

## dbo.ct_timeXbrand

```sql
CREATE VIEW dbo.ct_timeXbrand AS
```

## SELECT daypart, brand,.

```sql

```

##   COUNT(*) AS txn_cnt,.

```sql

```

##   SUM(amount) AS sales_total,.

```sql

```

##   AVG(TRY_CAST(basket_size AS float)) AS avg_basket_size.

```sql

```

## FROM dbo.v_insight_base.

```sql

```

## GROUP BY daypart, brand;.

```sql

```

## dbo.ct_timeXcategory

```sql
CREATE VIEW dbo.ct_timeXcategory AS
```

## SELECT.

```sql

```

##   daypart,.

```sql

```

##   category,.

```sql

```

##   COUNT(*) AS txn_cnt,.

```sql

```

##   SUM(amount) AS sales_total,.

```sql

```

##   AVG(TRY_CAST(basket_size AS float)) AS avg_basket_size.

```sql

```

## FROM dbo.v_insight_base.

```sql

```

## GROUP BY daypart, category;.

```sql

```

## dbo.ct_timeXdemo

```sql
CREATE VIEW dbo.ct_timeXdemo AS
```

## SELECT daypart, age_bracket, gender, role,.

```sql

```

##   COUNT(*) AS txn_cnt,.

```sql

```

##   SUM(amount) AS sales_total,.

```sql

```

##   AVG(TRY_CAST(basket_size AS float)) AS avg_basket_size.

```sql

```

## FROM dbo.v_insight_base.

```sql

```

## GROUP BY daypart, age_bracket, gender, role;.

```sql

```

## dbo.ct_timeXemotions

```sql
CREATE VIEW dbo.ct_timeXemotions AS
```

## SELECT daypart, emotions,.

```sql

```

##   COUNT(*) AS txn_cnt,.

```sql

```

##   SUM(amount) AS sales_total,.

```sql

```

##   AVG(TRY_CAST(basket_size AS float)) AS avg_basket_size.

```sql

```

## FROM dbo.v_insight_base.

```sql

```

## GROUP BY daypart, emotions;.

```sql

```

## dbo.gold_interaction_summary

```sql

```

## -- ================================.

```sql

```

## -- 🟨 GOLD LAYER VIEW.

```sql

```

## -- ================================.

```sql

```

## .

```sql

```

## CREATE VIEW dbo.gold_interaction_summary AS.

```sql

```

## SELECT .

```sql

```

##     t.StoreID,.

```sql

```

##     t.FacialID,.

```sql

```

##     t.Timestamp AS TranscriptTime,.

```sql

```

##     v.Timestamp AS VisionTime,.

```sql

```

##  .

```sql

```

## dbo.gold_reconstructed_transcripts

```sql
CREATE VIEW dbo.gold_reconstructed_transcripts AS SELECT s.InteractionID, STRING_AGG(t.ChunkText, ' ') WITHIN GROUP (ORDER BY t.ChunkIndex) AS FullTranscript, s.StoreID, s.ProductID, s.TransactionDate, s.DeviceID, s.FacialID, s.Sex, s.Age, s.EmotionalState
```

## dbo.silver_transcripts

```sql

```

## -- ================================.

```sql

```

## -- 🟨 SILVER LAYER VIEWS.

```sql

```

## -- ================================.

```sql

```

## .

```sql

```

## CREATE VIEW dbo.silver_transcripts AS.

```sql

```

## SELECT .

```sql

```

##     TranscriptID,.

```sql

```

##     StoreID,.

```sql

```

##     FacialID,.

```sql

```

##     Timestamp,.

```sql

```

##     TranscriptText,.

```sql

```

##     Language.

```sql

```

## FROM d.

```sql

```

## dbo.silver_vision_detections

```sql

```

## CREATE VIEW dbo.silver_vision_detections AS.

```sql

```

## SELECT .

```sql

```

##     DetectionID,.

```sql

```

##     StoreID,.

```sql

```

##     DeviceID,.

```sql

```

##     Timestamp,.

```sql

```

##     DetectedObject,.

```sql

```

##     Confidence.

```sql

```

## FROM dbo.bronze_vision_detections.

```sql

```

## WHERE Confidence >= 0.6;.

```sql

```

## .

```sql

```

## dbo.v_azure_norm

```sql
CREATE VIEW dbo.v_azure_norm AS
```

##         SELECT.

```sql

```

##           CAST(InteractionID AS varchar(128))      AS sessionId,.

```sql

```

##           CAST(DeviceID      AS varchar(128))      AS azure_deviceId,.

```sql

```

##           CAST(StoreID       AS varchar(64))       AS azure_storeId,.

```sql

```

##      .

```sql

```

## dbo.v_data_quality_monitor

```sql
CREATE VIEW dbo.v_data_quality_monitor AS
```

## SELECT.

```sql

```

##   CAST(GETDATE() AS date) as report_date,.

```sql

```

##   GETDATE() as report_timestamp,.

```sql

```

##   storeId,.

```sql

```

##   deviceId,.

```sql

```

## .

```sql

```

##   -- Record Counts.

```sql

```

##   COUNT(*) as total_records,.

```sql

```

##   COUNT(CASE WHEN azure_ts >= DATEADD(day, -1, GETDATE()) TH.

```sql

```

## dbo.v_duplicate_detection_monitor

```sql
CREATE VIEW dbo.v_duplicate_detection_monitor AS
```

## WITH payload_duplicates AS (.

```sql

```

##   SELECT sessionId, COUNT(*) as duplicate_count.

```sql

```

##   FROM dbo.PayloadTransactions.

```sql

```

##   GROUP BY sessionId.

```sql

```

##   HAVING COUNT(*) > 1.

```sql

```

## ).

```sql

```

## SELECT.

```sql

```

##   CAST(GETDATE() AS date) as check_date,.

```sql

```

##   GETD.

```sql

```

## dbo.v_flat_export_csvsafe

```sql
-- CSV-Safe Flat Export View
```

## -- Eliminates JSON parsing issues by cleaning text fields and removing CR/LF characters.

```sql

```

## .

```sql

```

## CREATE   VIEW dbo.v_flat_export_csvsafe AS.

```sql

```

## WITH src AS (.

```sql

```

##   SELECT.

```sql

```

##       [Transaction_ID].

```sql

```

##     , [Transaction_Value].

```sql

```

##     , [Basket_Size].

```sql

```

##    .

```sql

```

## dbo.v_flat_export_sheet

```sql
-- ========================================================================
```

## -- CREATE CORRECTED FLAT EXPORT VIEW (Fix Join Multiplication).

```sql

```

## -- ========================================================================.

```sql

```

## .

```sql

```

## CREATE   VIEW dbo.v_flat_export_sheet AS.

```sql

```

## dbo.v_flat_export_with_roles

```sql

```

##         CREATE VIEW dbo.v_flat_export_with_roles.

```sql

```

##         AS.

```sql

```

##         SELECT.

```sql

```

##             vf.*,.

```sql

```

##             pic.inferred_role,.

```sql

```

##             pic.confidence_score AS role_confidence.

```sql

```

##         FROM dbo.v_flat_export_sheet vf.

```sql

```

##         LEFT JOIN etl.persona_inference.

```sql

```

## dbo.v_insight_base

```sql
CREATE VIEW dbo.v_insight_base AS
```

## SELECT.

```sql

```

##   -- Core identifiers.

```sql

```

##   sessionId,.

```sql

```

##   deviceId,.

```sql

```

##   storeId,.

```sql

```

##   amount,.

```sql

```

## .

```sql

```

##   -- JSON extracted fields.

```sql

```

##   JSON_VALUE(payload_json,'$.category') AS category,.

```sql

```

##   JSON_VALUE(payload_json,'$.brand') AS brand,.

```sql

```

##   JSON_VALUE(payloa.

```sql

```

## dbo.v_nielsen_complete_analytics

```sql

```

## -- Create enhanced analytics view that includes ALL transactions.

```sql

```

## CREATE   VIEW dbo.v_nielsen_complete_analytics AS.

```sql

```

## WITH EnhancedTransactions AS (.

```sql

```

##     SELECT.

```sql

```

##         v.canonical_tx_id,.

```sql

```

##         CAST(v.txn_ts AS date) AS transaction_date,.

```sql

```

##         v.store_id,.

```sql

```

## dbo.v_nielsen_flat_export

```sql

```

## CREATE VIEW dbo.v_nielsen_flat_export AS.

```sql

```

## SELECT.

```sql

```

##     -- Existing columns from v_flat_export_sheet for compatibility.

```sql

```

##     vf.Transaction_ID,.

```sql

```

##     vf.Transaction_Value,.

```sql

```

##     vf.Basket_Size,.

```sql

```

##     vf.Brand,.

```sql

```

##     vf.Daypart,.

```sql

```

##     vf.[Demographics (Age/Gender/Role)],.

```sql

```

## .

```sql

```

## dbo.v_nielsen_summary_analytics

```sql

```

## CREATE VIEW dbo.v_nielsen_summary_analytics AS.

```sql

```

## SELECT.

```sql

```

##     nd.department_name AS Department,.

```sql

```

##     COALESCE(parent.category_name, nc.category_name) AS Product_Group,.

```sql

```

##     nc.category_name AS Category,.

```sql

```

##     COUNT(DISTINCT vnf.Transaction_ID) AS Transaction_Coun.

```sql

```

## dbo.v_payload_norm

```sql
CREATE VIEW dbo.v_payload_norm AS
```

## SELECT.

```sql

```

##   -- sessionId: from table or inside JSON.

```sql

```

##   COALESCE(.

```sql

```

##     TRY_CAST(sessionId AS varchar(128)),.

```sql

```

##     JSON_VALUE(payload_json, '$.transactionId'),.

```sql

```

##     JSON_VALUE(payload_json, '$.sessionId'),.

```sql

```

##     JSON_VALUE(payload_jso.

```sql

```

## dbo.v_performance_metrics_dashboard

```sql
CREATE VIEW dbo.v_performance_metrics_dashboard AS
```

## SELECT.

```sql

```

##   -- Time Windows.

```sql

```

##   'Last Hour' as time_window,.

```sql

```

##   COUNT(CASE WHEN azure_ts >= DATEADD(hour, -1, GETDATE()) THEN 1 END) as transaction_count,.

```sql

```

##   COUNT(DISTINCT CASE WHEN azure_ts >= DATEADD(hour, -1, .

```sql

```

## dbo.v_pipeline_realtime_monitor

```sql
CREATE VIEW dbo.v_pipeline_realtime_monitor AS
```

## SELECT.

```sql

```

##   CAST(azure_ts AS date) as transaction_date,.

```sql

```

##   DATEPART(hour, azure_ts) as transaction_hour,.

```sql

```

##   storeId,.

```sql

```

##   deviceId,.

```sql

```

##   COUNT(*) as transaction_count,.

```sql

```

##   SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) a.

```sql

```

## dbo.v_SalesInteractionsComplete

```sql

```

## -- Create a comprehensive view that handles all NULLs and JOINs properly.

```sql

```

## CREATE   VIEW dbo.v_SalesInteractionsComplete AS.

```sql

```

## SELECT .

```sql

```

##     si.InteractionID,.

```sql

```

##     si.StoreID,.

```sql

```

##     s.StoreName,.

```sql

```

##     s.Location as StoreLocation,.

```sql

```

##     si.ProductID,.

```sql

```

##     si.TransactionD.

```sql

```

## dbo.v_store_facial_age_101_120

```sql
CREATE   VIEW dbo.v_store_facial_age_101_120 AS
```

## SELECT.

```sql

```

##   s.StoreID,.

```sql

```

##   s.StoreName,.

```sql

```

##   s.DeviceID,.

```sql

```

##   s.Location,.

```sql

```

##   s.BarangayName,.

```sql

```

##   s.MunicipalityName,.

```sql

```

##   s.MunicipalityID,.

```sql

```

##   s.GeoLatitude,.

```sql

```

##   s.GeoLongitude,.

```sql

```

##   COUNT(DISTINCT si.InteractionId) AS unique_inter.

```sql

```

## dbo.v_store_health_dashboard

```sql
CREATE VIEW dbo.v_store_health_dashboard AS
```

## SELECT.

```sql

```

##   storeId,.

```sql

```

##   deviceId,.

```sql

```

##   COUNT(*) as total_transactions,.

```sql

```

##   COUNT(CASE WHEN azure_ts >= DATEADD(hour, -24, GETDATE()) THEN 1 END) as transactions_last_24h,.

```sql

```

##   COUNT(CASE WHEN azure_ts >= DATEADD(hour, -1, GE.

```sql

```

## dbo.v_transactions_crosstab_production

```sql

```

## -- Crosstab (long form, stable 10 cols).

```sql

```

## CREATE   VIEW dbo.v_transactions_crosstab_production.

```sql

```

## AS.

```sql

```

## WITH f AS (.

```sql

```

##   SELECT.

```sql

```

##     [date]       = CAST(txn_ts AS date),.

```sql

```

##     store_id,.

```sql

```

##     daypart,.

```sql

```

##     brand,.

```sql

```

##     total_amount.

```sql

```

##   FROM dbo.v_transactions_flat_production.

```sql

```

## .

```sql

```

## dbo.v_transactions_flat_production

```sql

```

## -- Flat view: canonical_tx_id join; timestamp ONLY from SalesInteractions.

```sql

```

## CREATE   VIEW dbo.v_transactions_flat_production.

```sql

```

## AS.

```sql

```

## SELECT.

```sql

```

##   -- IDs / store.

```sql

```

##   canonical_tx_id = LOWER(REPLACE(COALESCE(.

```sql

```

##     CASE WHEN ISJSON(pt.payload_json) = 1.

```sql

```

##          THEN JSON_.

```sql

```

## dbo.v_transactions_flat_v24

```sql
CREATE   VIEW dbo.v_transactions_flat_v24
```

## AS.

```sql

```

## /* 24-column compatibility view.

```sql

```

##    - Source of truth: dbo.v_transactions_flat_production (JSON-safe with canonical joins).

```sql

```

##    - Simplified to use only production view data.

```sql

```

## */.

```sql

```

## SELECT.

```sql

```

##   canonical_tx_id             .

```sql

```

## dbo.v_xtab_basketsize_category_abs

```sql
CREATE VIEW dbo.v_xtab_basketsize_category_abs AS
```

## WITH s AS (.

```sql

```

##   SELECT.

```sql

```

##       CAST(v.txn_ts AS date) AS [date],.

```sql

```

##       v.store_id, v.store_name,.

```sql

```

##       NULLIF(LTRIM(RTRIM(v.category)),'') AS category,.

```sql

```

##       TRY_CONVERT(int, v.total_items)     AS total_items,.

```sql

```

## .

```sql

```

## dbo.v_xtab_basketsize_payment_abs

```sql
CREATE VIEW dbo.v_xtab_basketsize_payment_abs AS
```

## WITH s AS (.

```sql

```

##   SELECT.

```sql

```

##       CAST(v.txn_ts AS date) AS [date],.

```sql

```

##       v.store_id, v.store_name,.

```sql

```

##       NULLIF(LTRIM(RTRIM(v.payment_method)),'') AS payment_method,.

```sql

```

##       TRY_CONVERT(int, v.total_items)          .

```sql

```

## dbo.v_xtab_daypart_weektype_abs

```sql
CREATE VIEW dbo.v_xtab_daypart_weektype_abs AS
```

## SELECT.

```sql

```

##     CAST(v.txn_ts AS date) AS [date],.

```sql

```

##     v.store_id, v.store_name,.

```sql

```

##     v.daypart,.

```sql

```

##     v.weekday_weekend,.

```sql

```

##     COUNT(*)                              AS txn_count,.

```sql

```

##     SUM(TRY_CONVERT(int, v.total_items)).

```sql

```

## dbo.v_xtab_time_brand_abs

```sql
CREATE VIEW dbo.v_xtab_time_brand_abs AS
```

## SELECT.

```sql

```

##     b.[date], b.store_id, b.store_name, b.daypart, b.brand,.

```sql

```

##     COUNT(*)                          AS txn_count,.

```sql

```

##     SUM(ISNULL(b.total_items,0))      AS items_sum,.

```sql

```

##     SUM(ISNULL(b.total_amount,0.00))  AS amo.

```sql

```

## dbo.v_xtab_time_brand_category_abs

```sql
CREATE VIEW dbo.v_xtab_time_brand_category_abs AS
```

## SELECT.

```sql

```

##     CAST(v.txn_ts AS date) AS [date],.

```sql

```

##     v.store_id, v.store_name,.

```sql

```

##     v.daypart,.

```sql

```

##     NULLIF(LTRIM(RTRIM(v.brand)),'')    AS brand,.

```sql

```

##     NULLIF(LTRIM(RTRIM(v.category)),'') AS category,.

```sql

```

##     COUNT(*) .

```sql

```

## dbo.v_xtab_time_category_abs

```sql
CREATE VIEW dbo.v_xtab_time_category_abs AS
```

## SELECT.

```sql

```

##     b.[date], b.store_id, b.store_name, b.daypart, b.category,.

```sql

```

##     COUNT(*)                          AS txn_count,.

```sql

```

##     SUM(ISNULL(b.total_items,0))      AS items_sum,.

```sql

```

##     SUM(ISNULL(b.total_amount,0.00))  .

```sql

```

## dbo.vw_campaign_effectiveness

```sql
-- === Views for Analytics ===
```

## .

```sql

```

## -- Campaign effectiveness view.

```sql

```

## CREATE   VIEW vw_campaign_effectiveness AS.

```sql

```

## SELECT .

```sql

```

##     ca.campaign_id,.

```sql

```

##     ca.asset_name,.

```sql

```

##     p.brand,.

```sql

```

##     p.category,.

```sql

```

##     avr.overall_score,.

```sql

```

##     avr.brand_compliance_score,.

```sql

```

##     avr.technical_q.

```sql

```

## dbo.vw_tbwa_brand_performance_mock

```sql

```

##     CREATE   VIEW [dbo].[vw_tbwa_brand_performance_mock] AS.

```sql

```

##     SELECT .

```sql

```

##       [brand],.

```sql

```

##       [category],.

```sql

```

##       [subcategory],.

```sql

```

##       COUNT(*) as transaction_count,.

```sql

```

##       SUM([peso_value]) as total_value,.

```sql

```

##       AVG([peso_value]) as avg_value,.

```sql

```

##       SUM([vol.

```sql

```

## dbo.vw_tbwa_latest_mock_transactions

```sql

```

##     CREATE   VIEW [dbo].[vw_tbwa_latest_mock_transactions] AS.

```sql

```

##     SELECT t.*, m.[dataset_name], m.[created_at] as upload_date.

```sql

```

##     FROM [dbo].[tbwa_transactions_mock] t.

```sql

```

##     JOIN [dbo].[tbwa_data_metadata] m ON t.[metadata_id] = m.[id].

```sql

```

##     WHERE m.[id] = (S.

```sql

```

## dbo.vw_tbwa_location_analytics_mock

```sql

```

##     CREATE   VIEW [dbo].[vw_tbwa_location_analytics_mock] AS.

```sql

```

##     SELECT .

```sql

```

##       [location],.

```sql

```

##       [region],.

```sql

```

##       COUNT(*) as transaction_count,.

```sql

```

##       SUM([peso_value]) as total_value,.

```sql

```

##       AVG([peso_value]) as avg_value,.

```sql

```

##       COUNT(DISTINCT [consumer_id.

```sql

```

## dbo.vw_transaction_analytics

```sql
-- Transaction analytics view
```

## CREATE   VIEW vw_transaction_analytics AS.

```sql

```

## SELECT .

```sql

```

##     t.txn_id,.

```sql

```

##     l.region,.

```sql

```

##     l.province,.

```sql

```

##     l.city,.

```sql

```

##     l.barangay,.

```sql

```

##     p.brand,.

```sql

```

##     p.category,.

```sql

```

##     ti.units,.

```sql

```

##     ti.total_price,.

```sql

```

##     t.ts as transaction_date,.

```sql

```

##     c.age_b.

```sql

```

## etl.v_persona_coverage_summary

```sql

```

## /* Helper view to see persona rule application results */.

```sql

```

## CREATE   VIEW etl.v_persona_coverage_summary.

```sql

```

## AS.

```sql

```

## SELECT.

```sql

```

##     pic.inferred_role,.

```sql

```

##     COUNT(*) AS transaction_count,.

```sql

```

##     AVG(pic.confidence_score) AS avg_confidence,.

```sql

```

##     MIN(pic.confidence_score) AS mi.

```sql

```

## gold.v_sample_sari_transactions

```sql

```

## /* Sample sheet view using existing flat production view + demographics */.

```sql

```

## CREATE   VIEW gold.v_sample_sari_transactions.

```sql

```

## AS.

```sql

```

## WITH base AS (.

```sql

```

##   SELECT.

```sql

```

##     vt.transaction_id                               AS Transaction_ID,.

```sql

```

##     TRY_CONVERT(decimal(18,2), vt.to.

```sql

```

## gold.v_transactions_crosstab

```sql

```

## CREATE VIEW gold.v_transactions_crosstab AS.

```sql

```

## SELECT.

```sql

```

##   [date],.

```sql

```

##   store_id,.

```sql

```

##   store_name,.

```sql

```

##   daypart,.

```sql

```

##   brand,.

```sql

```

##   txn_count,.

```sql

```

##   total_amount.

```sql

```

## FROM dbo.v_transactions_crosstab_production.

```sql

```

## .

```sql

```

## gold.v_transactions_flat

```sql

```

## CREATE VIEW gold.v_transactions_flat AS.

```sql

```

## SELECT.

```sql

```

##   canonical_tx_id       AS CanonicalTxID,.

```sql

```

##   transaction_id        AS TransactionID,.

```sql

```

##   device_id             AS DeviceID,.

```sql

```

##   store_id              AS StoreID,.

```sql

```

##   store_name            AS StoreName,.

```sql

```

##   brand,.

```sql

```

##   pr.

```sql

```

## gold.v_transactions_flat_v24

```sql
CREATE VIEW gold.v_transactions_flat_v24 AS SELECT * FROM dbo.v_transactions_flat_v24
```

## gold.v_transactions_nielsen

```sql

```

## /* Nielsen-aware transaction view (transaction × SKU × Nielsen) */.

```sql

```

## CREATE   VIEW gold.v_transactions_nielsen.

```sql

```

## AS.

```sql

```

## SELECT.

```sql

```

##   si.canonical_tx_id,.

```sql

```

##   si.TransactionDate,.

```sql

```

##   si.StoreID,.

```sql

```

##   i.ProductID,.

```sql

```

##   p.ProductName,.

```sql

```

##   p.Category AS product_category,.

```sql

```

##   n.taxonomy.

```sql

```

## gold.v_txn_best_interaction

```sql

```

## /* Helper: choose a single interaction record per transaction (latest TransactionDate, with demographics) */.

```sql

```

## CREATE   VIEW gold.v_txn_best_interaction.

```sql

```

## AS.

```sql

```

## WITH ranked AS (.

```sql

```

##   SELECT.

```sql

```

##     si.canonical_tx_id,.

```sql

```

##     si.TransactionDate,.

```sql

```

##     si.Age,.

```sql

```

##     si.Gender,.

```sql

```

## .

```sql

```

## ref.v_ItemCategoryResolved

```sql

```

## -- 7) Create analytics preference view: SKU-first, brand-fallback.

```sql

```

## CREATE   VIEW ref.v_ItemCategoryResolved AS.

```sql

```

## SELECT.

```sql

```

##     ti.TransactionItemID,.

```sql

```

##     ti.InteractionID,.

```sql

```

##     ti.ProductID,.

```sql

```

##     ti.Quantity,.

```sql

```

##     ti.UnitPrice,.

```sql

```

##     ti.sku_id,.

```sql

```

## .

```sql

```

##     -- SKU informatio.

```sql

```

## ref.v_persona_inference

```sql
-- ========================================================================
```

## -- CREATE SIMPLIFIED PERSONA INFERENCE VIEW.

```sql

```

## -- ========================================================================.

```sql

```

## .

```sql

```

## CREATE   VIEW ref.v_persona_inference AS.

```sql

```

## WITH base AS (.

```sql

```

##   -.

```sql

```

## ref.v_SkuCoverage

```sql

```

## -- 8) Create coverage helper view.

```sql

```

## CREATE   VIEW ref.v_SkuCoverage AS.

```sql

```

## SELECT.

```sql

```

##     total_transaction_items = COUNT(*),.

```sql

```

##     items_with_sku = COUNT(CASE WHEN sku_id IS NOT NULL THEN 1 END),.

```sql

```

##     items_with_brand_only = COUNT(CASE WHEN sku_id IS NULL THEN 1 END).

```sql

```

## sys.database_firewall_rules

```sql
CREATE VIEW sys.database_firewall_rules AS SELECT id, name, start_ip_address, end_ip_address, create_date, modify_date FROM sys.database_firewall_rules_table
```

## .

```sql

```

## (67 rows affected).

```sql

```

