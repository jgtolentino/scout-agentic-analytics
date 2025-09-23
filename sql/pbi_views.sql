-- Create optimized views for Power BI
CREATE OR ALTER VIEW gold.v_pbi_transactions_summary
AS
SELECT
    CAST(txn_ts AS DATE) as transaction_date,
    DATEPART(YEAR, txn_ts) as year,
    DATEPART(MONTH, txn_ts) as month,
    DATEPART(DAY, txn_ts) as day,
    DATENAME(WEEKDAY, txn_ts) as weekday_name,
    daypart,
    weekday_weekend,

    store_id,
    store_name,

    brand,
    category,

    COUNT(*) as transaction_count,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_transaction_value,
    SUM(total_items) as total_items_sold,

    -- Additional metrics for dashboards
    COUNT(DISTINCT canonical_tx_id) as unique_transactions,
    COUNT(DISTINCT device_id) as unique_devices

FROM gold.v_transactions_flat
GROUP BY
    CAST(txn_ts AS DATE),
    DATEPART(YEAR, txn_ts),
    DATEPART(MONTH, txn_ts),
    DATEPART(DAY, txn_ts),
    DATENAME(WEEKDAY, txn_ts),
    daypart,
    weekday_weekend,
    store_id,
    store_name,
    brand,
    category;