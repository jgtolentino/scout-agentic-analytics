-- Final Nielsen-Standard Flat Export View
-- Solves JSON truncation + Implements 6-Level Nielsen Hierarchy

CREATE OR ALTER VIEW dbo.v_nielsen_flat_export AS
WITH enhanced_transactions AS (
    SELECT
        si.canonical_tx_id,
        si.TransactionValue,
        si.TransactionDate,
        si.StoreID,

        -- Enhanced Brand & Category Intelligence
        CASE
            -- Direct brand mapping from existing TransactionItems
            WHEN ti.brand_name IS NOT NULL AND ti.brand_name != 'unspecified'
                THEN ti.brand_name
            -- Brand extraction from JSON (first 950 chars to avoid truncation)
            WHEN si.payload_json IS NOT NULL
                THEN COALESCE(
                    -- Try to extract brand from JSON patterns
                    CASE
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%great%taste%' THEN 'Great Taste'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%nescafe%' THEN 'Nescafé'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%kopiko%' THEN 'Kopiko'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%coca%cola%' THEN 'Coca-Cola'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%sprite%' THEN 'Sprite'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%royal%' THEN 'Royal'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%tang%' THEN 'Tang'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%lucky%me%' THEN 'Lucky Me'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%oishi%' THEN 'Oishi'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%piattos%' THEN 'Piattos'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%alaska%' THEN 'Alaska'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%bear%brand%' THEN 'Bear Brand'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%milo%' THEN 'Milo'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%surf%' THEN 'Surf'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%tide%' THEN 'Tide'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%downy%' THEN 'Downy'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%ariel%' THEN 'Ariel'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%colgate%' THEN 'Colgate'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%safeguard%' THEN 'Safeguard'
                        WHEN LEFT(si.payload_json, 950) LIKE '%"brand"%marlboro%' THEN 'Marlboro'
                        -- Add more patterns as needed...
                        ELSE 'Unknown'
                    END,
                    'Unknown'
                )
            ELSE 'Unknown'
        END as brand_name,

        -- Primary category from TransactionItems or default
        COALESCE(ti.category, 'unspecified') as original_category,

        ROW_NUMBER() OVER (PARTITION BY si.canonical_tx_id ORDER BY si.canonical_tx_id) as rn

    FROM dbo.SalesInteractions si
    LEFT JOIN dbo.TransactionItems ti ON ti.canonical_tx_id = si.canonical_tx_id
    WHERE si.canonical_tx_id IS NOT NULL
),

nielsen_enhanced AS (
    SELECT
        et.*,
        -- Nielsen Hierarchy (6 levels)
        nh.department_name,
        nh.department_code,
        nh.group_name,
        nh.group_code,
        nh.category_name,
        nh.category_code,
        nh.subcategory_name,
        nh.subcategory_code,
        nh.package_types,
        nh.typical_sizes,
        nh.manufacturer,
        nh.brand_owner,
        nh.position_desc,
        nh.distribution_desc,
        nh.sari_sari_importance,

        -- Data Quality Flags
        CASE
            WHEN et.brand_name = 'Unknown' THEN 'Brand_Missing'
            WHEN et.original_category = 'unspecified' THEN 'Category_Missing'
            WHEN nh.brand_name IS NULL THEN 'Not_In_Nielsen'
            WHEN nh.sari_sari_importance = 'Critical' THEN 'High_Quality'
            WHEN nh.sari_sari_importance = 'High Priority' THEN 'Good_Quality'
            ELSE 'Standard_Quality'
        END as data_quality_flag,

        -- Business Intelligence Fields
        CASE
            WHEN nh.department_code = 'BEVERAGE' THEN 'Beverages'
            WHEN nh.department_code = 'FOOD' THEN 'Food Products'
            WHEN nh.department_code = 'PERSONAL' THEN 'Personal Care'
            WHEN nh.department_code = 'HOUSEHOLD' THEN 'Household Products'
            WHEN nh.department_code = 'TOBACCO' THEN 'Tobacco Products'
            WHEN nh.department_code = 'TELECOM' THEN 'Telecommunications'
            ELSE 'Other Categories'
        END as department_group,

        -- Revenue Classification
        CASE
            WHEN TRY_CAST(et.TransactionValue AS DECIMAL(10,2)) >= 100 THEN 'High Value'
            WHEN TRY_CAST(et.TransactionValue AS DECIMAL(10,2)) >= 50 THEN 'Medium Value'
            WHEN TRY_CAST(et.TransactionValue AS DECIMAL(10,2)) >= 10 THEN 'Low Value'
            ELSE 'Micro Value'
        END as transaction_tier

    FROM enhanced_transactions et
    LEFT JOIN dbo.v_nielsen_brand_hierarchy nh ON et.brand_name = nh.brand_name
    WHERE et.rn = 1 -- Ensure 1:1 relationship
)

-- Final 15-Column Nielsen Export (Enhanced from original 12)
SELECT
    /* 1 */ canonical_tx_id AS [Transaction_ID],
    /* 2 */ ISNULL(TRY_CAST(TransactionValue AS DECIMAL(10,2)), 0) AS [Transaction_Value],
    /* 3 */ TransactionDate AS [Transaction_Date],
    /* 4 */ StoreID AS [Store_ID],

    -- Brand & Product Information (Nielsen Level 5-6)
    /* 5 */ brand_name AS [Brand_Name],
    /* 6 */ ISNULL(manufacturer, 'Unknown') AS [Manufacturer],

    -- Nielsen Hierarchy (Levels 1-4)
    /* 7 */ ISNULL(department_name, 'Unclassified') AS [Nielsen_Department],
    /* 8 */ ISNULL(category_name, original_category) AS [Nielsen_Category],
    /* 9 */ ISNULL(subcategory_name, 'General') AS [Nielsen_Subcategory],

    -- Business Intelligence
    /* 10 */ department_group AS [Category_Group],
    /* 11 */ ISNULL(sari_sari_importance, 'Unknown') AS [Sari_Sari_Priority],
    /* 12 */ transaction_tier AS [Value_Tier],

    -- Data Quality & Metadata
    /* 13 */ data_quality_flag AS [Quality_Flag],
    /* 14 */ CASE WHEN brand_name != 'Unknown' AND department_name IS NOT NULL THEN 'Nielsen_Mapped' ELSE 'Legacy_Data' END AS [Data_Source],
    /* 15 */ GETDATE() AS [Export_Timestamp];

-- Create Summary View for Analytics
CREATE OR ALTER VIEW dbo.v_nielsen_summary AS
SELECT
    'NIELSEN TAXONOMY SUMMARY' as summary_type,

    -- Transaction Counts by Nielsen Department
    SUM(CASE WHEN Nielsen_Department = 'Beverages' THEN 1 ELSE 0 END) as Beverages_Transactions,
    SUM(CASE WHEN Nielsen_Department = 'Food Products' THEN 1 ELSE 0 END) as Food_Transactions,
    SUM(CASE WHEN Nielsen_Department = 'Personal Care' THEN 1 ELSE 0 END) as PersonalCare_Transactions,
    SUM(CASE WHEN Nielsen_Department = 'Household Products' THEN 1 ELSE 0 END) as Household_Transactions,
    SUM(CASE WHEN Nielsen_Department = 'Tobacco Products' THEN 1 ELSE 0 END) as Tobacco_Transactions,
    SUM(CASE WHEN Nielsen_Department = 'Telecommunications' THEN 1 ELSE 0 END) as Telecom_Transactions,

    -- Data Quality Metrics
    SUM(CASE WHEN Quality_Flag = 'High_Quality' THEN 1 ELSE 0 END) as High_Quality_Count,
    SUM(CASE WHEN Quality_Flag = 'Good_Quality' THEN 1 ELSE 0 END) as Good_Quality_Count,
    SUM(CASE WHEN Quality_Flag = 'Brand_Missing' THEN 1 ELSE 0 END) as Brand_Missing_Count,
    SUM(CASE WHEN Quality_Flag = 'Category_Missing' THEN 1 ELSE 0 END) as Category_Missing_Count,
    SUM(CASE WHEN Quality_Flag = 'Not_In_Nielsen' THEN 1 ELSE 0 END) as Not_In_Nielsen_Count,

    -- Coverage Metrics
    COUNT(*) as Total_Transactions,
    SUM(CASE WHEN Data_Source = 'Nielsen_Mapped' THEN 1 ELSE 0 END) as Nielsen_Mapped_Count,
    CAST(100.0 * SUM(CASE WHEN Data_Source = 'Nielsen_Mapped' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) as Nielsen_Coverage_Percent,

    -- Value Analysis
    SUM(Transaction_Value) as Total_Transaction_Value,
    AVG(Transaction_Value) as Avg_Transaction_Value,
    MAX(Transaction_Value) as Max_Transaction_Value,

    -- Top Categories by Transaction Count
    (SELECT TOP 1 Nielsen_Category FROM dbo.v_nielsen_flat_export WHERE Nielsen_Category != 'Unclassified' GROUP BY Nielsen_Category ORDER BY COUNT(*) DESC) as Top_Category_By_Count,

    -- Export Metadata
    GETDATE() as Summary_Generated

FROM dbo.v_nielsen_flat_export;

-- Create Brand Performance View
CREATE OR ALTER VIEW dbo.v_nielsen_brand_performance AS
SELECT
    Brand_Name,
    Manufacturer,
    Nielsen_Department,
    Nielsen_Category,
    Sari_Sari_Priority,

    -- Performance Metrics
    COUNT(*) as Transaction_Count,
    SUM(Transaction_Value) as Total_Revenue,
    AVG(Transaction_Value) as Avg_Transaction_Value,
    COUNT(DISTINCT Store_ID) as Store_Reach,

    -- Market Position
    RANK() OVER (PARTITION BY Nielsen_Department ORDER BY COUNT(*) DESC) as Dept_Rank_By_Transactions,
    RANK() OVER (PARTITION BY Nielsen_Department ORDER BY SUM(Transaction_Value) DESC) as Dept_Rank_By_Revenue,
    RANK() OVER (ORDER BY COUNT(*) DESC) as Overall_Rank_By_Transactions,

    -- Quality Metrics
    CAST(100.0 * SUM(CASE WHEN Quality_Flag IN ('High_Quality', 'Good_Quality') THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) as Quality_Score,

    GETDATE() as Analysis_Date

FROM dbo.v_nielsen_flat_export
WHERE Brand_Name != 'Unknown'
GROUP BY Brand_Name, Manufacturer, Nielsen_Department, Nielsen_Category, Sari_Sari_Priority
HAVING COUNT(*) >= 5; -- Only brands with significant presence