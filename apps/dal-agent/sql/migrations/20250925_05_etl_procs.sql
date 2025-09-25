SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* Upsert Brands (SCD type-lite) */
CREATE OR ALTER PROCEDURE etl.sp_upsert_dim_brands
AS
BEGIN
  SET NOCOUNT ON;
  MERGE dim.brands AS d
  USING (
    SELECT DISTINCT b.brand_name, b.category AS brand_category, b.parent_company AS company_name
    FROM dbo.Brands b
  ) AS s
  ON (d.brand_name = s.brand_name AND d.is_current = 1)
  WHEN MATCHED AND (ISNULL(d.brand_category,'') <> ISNULL(s.brand_category,'') OR ISNULL(d.company_name,'') <> ISNULL(s.company_name,''))
    THEN UPDATE SET d.is_current = 0, d.effective_to = CAST(GETDATE() AS DATE)
  WHEN NOT MATCHED BY TARGET
    THEN INSERT (brand_code, brand_name, company_name, brand_category, effective_from, is_current)
         VALUES (s.brand_name, s.brand_name, s.company_name, s.brand_category, CAST(GETDATE() AS DATE), 1);
END
GO

/* Upsert Products */
CREATE OR ALTER PROCEDURE etl.sp_upsert_dim_products
AS
BEGIN
  SET NOCOUNT ON;
  MERGE dim.products AS d
  USING (
    SELECT DISTINCT
      p.sku_code, p.product_name, b.brand_name, p.category, p.uom
    FROM dbo.Products p
    LEFT JOIN dbo.Brands b ON b.brand_id = p.brand_id
  ) AS s
  ON (d.sku = s.sku_code AND d.is_current = 1)
  WHEN MATCHED AND (
    ISNULL(d.product_name,'') <> ISNULL(s.product_name,'')
    OR ISNULL(d.brand_name,'') <> ISNULL(s.brand_name,'')
    OR ISNULL(d.category,'') <> ISNULL(s.category,'')
    OR ISNULL(d.unit_of_measure,'') <> ISNULL(s.uom,'')
  )
    THEN UPDATE SET d.is_current = 0, d.valid_to = CAST(GETDATE() AS DATE)
  WHEN NOT MATCHED BY TARGET
    THEN INSERT (sku, product_name, brand_name, category, unit_of_measure, valid_from, is_current)
         VALUES (s.sku_code, s.product_name, s.brand_name, s.category, s.uom, CAST(GETDATE() AS DATE), 1);
END
GO

/* Load fact.transactions from dbo.Transactions */
CREATE OR ALTER PROCEDURE etl.sp_load_fact_transactions
AS
BEGIN
  SET NOCOUNT ON;
  INSERT INTO fact.transactions (
    transaction_uuid, store_id, device_id, customer_id,
    transaction_date, transaction_time, transaction_datetime,
    year, month, day, hour, day_of_week, week_of_year,
    transaction_type, payment_method,
    total_items, unique_products, total_amount, discount_amount, tax_amount, net_amount,
    processing_status, canonical_tx_id
  )
  SELECT
    NEWID(), t.store_id, NULL, NULL,
    CAST(t.txn_ts AS DATE), CAST(t.txn_ts AS TIME), t.txn_ts,
    DATEPART(YEAR,t.txn_ts), DATEPART(MONTH,t.txn_ts), DATEPART(DAY,t.txn_ts),
    DATEPART(HOUR,t.txn_ts), DATEPART(WEEKDAY,t.txn_ts), DATEPART(WEEK,t.txn_ts),
    'Purchase', NULL,
    t.total_items, NULL, t.total_amount, 0, 0, t.total_amount,
    'New', t.canonical_tx_id
  FROM dbo.Transactions t
  WHERE NOT EXISTS (
    SELECT 1 FROM fact.transactions f WHERE f.canonical_tx_id = t.canonical_tx_id
  );
END
GO

/* Load fact.transaction_items from dbo.TransactionItems */
CREATE OR ALTER PROCEDURE etl.sp_load_fact_transaction_items
AS
BEGIN
  SET NOCOUNT ON;

  INSERT INTO fact.transaction_items (
    transaction_uuid, product_id, sku, brand_id, category, quantity, unit_price, line_amount
  )
  SELECT
    f.transaction_uuid,
    NULL,                -- optional: resolve to dim.products.product_id if you maintain surrogate
    ti.canonical_tx_id,  -- placeholder sku column if needed; replace mapping as appropriate
    NULL,                -- optional: resolve brand_id via dim.brands
    ti.category,
    ti.quantity, ti.unit_price, ti.line_amount
  FROM dbo.TransactionItems ti
  JOIN fact.transactions f ON f.canonical_tx_id = ti.canonical_tx_id
  WHERE NOT EXISTS (
    SELECT 1
    FROM fact.transaction_items fi
    WHERE fi.transaction_uuid = f.transaction_uuid
      AND fi.category = ti.category
      AND ISNULL(fi.line_amount,-1) = ISNULL(ti.line_amount,-1)
  );
END
GO

/* Fixed peak-hour summary (no MODE()) */
CREATE OR ALTER PROCEDURE etl.sp_update_daily_sales_summary
  @target_date date
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @peak_hour int;

  WITH hours AS (
    SELECT DATEPART(HOUR, t.transaction_time) AS h
    FROM fact.transactions t
    WHERE t.transaction_date = @target_date
  ),
  freq AS (
    SELECT h, COUNT(*) AS cnt
    FROM hours
    GROUP BY h
  )
  SELECT TOP (1) @peak_hour = h
  FROM freq
  ORDER BY cnt DESC;

  INSERT INTO ops.data_quality_issues ( -- or ops.daily_sales_summary if defined differently
    issue_id, issue_type, issue_severity, detected_at, details
  )
  SELECT NEWID(), 'DAILY_SUMMARY', 'INFO', SYSUTCDATETIME(),
         CONCAT('Peak hour for ', CONVERT(varchar(10), @target_date, 120), ' is ', @peak_hour);
END
GO