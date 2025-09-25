-- Complete Brand-SKU Mapping Query with Correct Categories
-- Exports all 113 brands with proper categorization and units sold

WITH brand_transactions AS (
    -- Get all brand-category combinations from the main view
    SELECT
        COALESCE(ti.brand_name, t.Brand) as brand_name,
        COALESCE(ti.category, t.Category) as category,
        COUNT(*) as transaction_count,
        SUM(CAST(t.Transaction_Value AS DECIMAL(10,2))) as total_sales
    FROM dbo.v_transactions_flat_production t
    LEFT JOIN dbo.TransactionItems ti
        ON COALESCE(
            CAST(ti.canonical_tx_id AS varchar(64)),
            CAST(ti.sessionId AS varchar(64))
        ) = CAST(t.Transaction_ID AS varchar(64))
    WHERE COALESCE(ti.brand_name, t.Brand) IS NOT NULL
      AND COALESCE(ti.brand_name, t.Brand) != ''
      AND COALESCE(ti.category, t.Category) IS NOT NULL
      AND COALESCE(ti.category, t.Category) != ''
    GROUP BY
        COALESCE(ti.brand_name, t.Brand),
        COALESCE(ti.category, t.Category)
),

brand_correct_categories AS (
    -- Determine the correct category for each brand (non-unspecified with highest volume)
    SELECT
        brand_name,
        category as correct_category,
        transaction_count,
        total_sales,
        ROW_NUMBER() OVER (
            PARTITION BY brand_name
            ORDER BY
                CASE WHEN category = 'unspecified' THEN 0 ELSE 1 END DESC,
                transaction_count DESC
        ) as category_rank
    FROM brand_transactions
),

brand_totals AS (
    -- Calculate total transactions and sales per brand across all categories
    SELECT
        brand_name,
        SUM(transaction_count) as total_transactions,
        SUM(total_sales) as total_brand_sales
    FROM brand_transactions
    GROUP BY brand_name
),

brand_issues AS (
    -- Identify brands with unspecified category issues
    SELECT
        brand_name,
        CASE WHEN COUNT(CASE WHEN category = 'unspecified' THEN 1 END) > 0
             THEN 'YES'
             ELSE 'NO'
        END as has_unspecified_issue
    FROM brand_transactions
    GROUP BY brand_name
)

-- Final export query: Complete brand mapping with correct categories
SELECT
    bcc.brand_name as Brand,
    bcc.correct_category as Category,
    bt.total_transactions as Total_Transactions,
    CAST(bt.total_brand_sales as DECIMAL(10,2)) as Total_Sales,
    bi.has_unspecified_issue as Data_Issues,

    -- Additional analytics
    CASE
        WHEN bt.total_transactions >= 200 THEN 'High Volume'
        WHEN bt.total_transactions >= 50 THEN 'Medium Volume'
        ELSE 'Low Volume'
    END as Volume_Tier,

    CAST(
        bt.total_brand_sales / NULLIF(bt.total_transactions, 0)
        as DECIMAL(10,2)
    ) as Avg_Transaction_Value,

    -- Category ranking within brand's category
    RANK() OVER (
        PARTITION BY bcc.correct_category
        ORDER BY bt.total_transactions DESC
    ) as Category_Rank

FROM brand_correct_categories bcc
JOIN brand_totals bt ON bt.brand_name = bcc.brand_name
JOIN brand_issues bi ON bi.brand_name = bcc.brand_name
WHERE bcc.category_rank = 1  -- Only the correct category per brand

ORDER BY bt.total_transactions DESC;

-- Alternative query for category summary
/*
WITH category_summary AS (
    SELECT
        bcc.correct_category as Category,
        COUNT(*) as Brand_Count,
        SUM(bt.total_transactions) as Category_Transactions,
        SUM(bt.total_brand_sales) as Category_Sales,
        SUM(CASE WHEN bi.has_unspecified_issue = 'YES' THEN 1 ELSE 0 END) as Problematic_Brands
    FROM brand_correct_categories bcc
    JOIN brand_totals bt ON bt.brand_name = bcc.brand_name
    JOIN brand_issues bi ON bi.brand_name = bcc.brand_name
    WHERE bcc.category_rank = 1
    GROUP BY bcc.correct_category
)

SELECT
    Category,
    Brand_Count,
    Category_Transactions,
    CAST(Category_Sales as DECIMAL(12,2)) as Category_Sales,
    Problematic_Brands,
    CAST(
        Category_Sales / NULLIF(Category_Transactions, 0)
        as DECIMAL(10,2)
    ) as Avg_Transaction_Value,
    CAST(
        (Category_Transactions * 100.0) / SUM(Category_Transactions) OVER()
        as DECIMAL(5,2)
    ) as Transaction_Share_Pct
FROM category_summary
ORDER BY Category_Transactions DESC;
*/