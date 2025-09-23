-- Power BI brand performance view
CREATE OR ALTER VIEW gold.v_pbi_brand_performance
AS
SELECT
    brand,
    category,
    COUNT(*) as total_transactions,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_transaction_value,
    MIN(txn_ts) as first_transaction,
    MAX(txn_ts) as latest_transaction,
    COUNT(DISTINCT store_id) as stores_present,
    COUNT(DISTINCT CAST(txn_ts AS DATE)) as active_days,

    -- Performance metrics
    ROUND(SUM(total_amount) / COUNT(*), 2) as revenue_per_transaction,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as market_share_transactions,
    ROUND(SUM(total_amount) * 100.0 / SUM(SUM(total_amount)) OVER(), 2) as market_share_revenue

FROM gold.v_transactions_flat
GROUP BY brand, category;