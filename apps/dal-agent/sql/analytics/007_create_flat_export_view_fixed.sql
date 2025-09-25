-- Fixed SQL query handling JSON truncation at position 1000
-- Create flat export view with 12 columns for 1:1 Stata analysis

CREATE OR ALTER VIEW dbo.v_flat_export_sheet AS
WITH primary_item AS (
    SELECT
        si.canonical_tx_id,
        si.TransactionValue,
        si.TransactionDate,
        si.StoreID,
        -- Use existing brand_sku_catalog instead of parsing truncated JSON
        COALESCE(bsc.brand_name, 'Unknown') as brand_name,
        COALESCE(bsc.category, 'unspecified') as category,
        ROW_NUMBER() OVER (PARTITION BY si.canonical_tx_id ORDER BY si.canonical_tx_id) as rn
    FROM dbo.SalesInteractions si
    LEFT JOIN dbo.brand_sku_catalog bsc ON (
        -- Try multiple matching strategies due to JSON truncation
        LEFT(si.payload_json, 900) LIKE '%' + bsc.brand_name + '%'
        OR si.canonical_tx_id IN (
            SELECT ti.canonical_tx_id
            FROM dbo.TransactionItems ti
            WHERE ti.brand_name = bsc.brand_name
        )
    )
    WHERE si.canonical_tx_id IS NOT NULL
),
sub AS (
    SELECT
        canonical_tx_id,
        COUNT(*) as item_count,
        SUM(TRY_CAST(TransactionValue AS DECIMAL(10,2))) as total_value
    FROM dbo.SalesInteractions
    WHERE canonical_tx_id IS NOT NULL
    GROUP BY canonical_tx_id
),
others AS (
    SELECT
        si.canonical_tx_id,
        si.StoreID,
        COUNT(DISTINCT si.canonical_tx_id) as tx_count
    FROM dbo.SalesInteractions si
    WHERE si.canonical_tx_id IS NOT NULL
    GROUP BY si.canonical_tx_id, si.StoreID
)
SELECT
    /* 1 */ b.canonical_tx_id AS [Transaction_ID],
    /* 2 */ ISNULL(b.TransactionValue, 0) AS [Transaction_Value],
    /* 3 */ b.TransactionDate AS [Transaction_Date],
    /* 4 */ b.StoreID AS [Store_ID],
    /* 5 */ b.brand_name AS [Brand_Name],
    /* 6 */ b.category AS [Category],
    /* 7 */ ISNULL(s.item_count, 1) AS [Item_Count],
    /* 8 */ ISNULL(s.total_value, b.TransactionValue) AS [Total_Value],
    /* 9 */ ISNULL(o.tx_count, 1) AS [TX_Count],
    /* 10 */ 'Mapped' AS [Data_Source],
    /* 11 */ CASE WHEN b.category = 'unspecified' THEN 'Needs_Review' ELSE 'Clean' END AS [Quality_Flag],
    /* 12 */ GETDATE() AS [Export_Timestamp]
FROM primary_item b
LEFT JOIN sub s ON s.canonical_tx_id = b.canonical_tx_id
LEFT JOIN others o ON o.canonical_tx_id = b.canonical_tx_id
WHERE b.rn = 1;  -- Ensure 1:1 relationship