-- ========================================================================
-- Scout Platform Enhanced ETL Pipeline
-- Extracts: Items, Brand Detection, Substitutions, Demographics, Audio Context
-- ========================================================================

-- ==========================
-- 1. EXTRACT TRANSACTION ITEMS FROM PAYLOADS
-- ==========================

-- Insert items from PayloadTransactions JSON into TransactionItems
INSERT INTO dbo.TransactionItems (
    transaction_id,
    interaction_id,
    product_name,
    brand_name,
    generic_name,
    local_name,
    category,
    subcategory,
    sku,
    quantity,
    unit,
    unit_price,
    total_price,
    is_substitution,
    original_product_requested,
    original_brand_requested,
    substitution_reason,
    customer_accepted_substitution,
    detection_method,
    brand_confidence,
    product_confidence,
    customer_request_type,
    audio_context
)
SELECT
    pt.transaction_id,
    JSON_VALUE(pt.payload_json, '$.interactionId') as interaction_id,

    -- Product Details
    JSON_VALUE(items.value, '$.productName') as product_name,
    JSON_VALUE(items.value, '$.brandName') as brand_name,
    JSON_VALUE(items.value, '$.genericName') as generic_name,
    JSON_VALUE(items.value, '$.localName') as local_name,
    JSON_VALUE(items.value, '$.category') as category,
    JSON_VALUE(items.value, '$.subcategory') as subcategory,
    JSON_VALUE(items.value, '$.sku') as sku,

    -- Quantities and Pricing
    CAST(JSON_VALUE(items.value, '$.quantity') AS INT) as quantity,
    JSON_VALUE(items.value, '$.unit') as unit,
    CAST(JSON_VALUE(items.value, '$.unitPrice') AS DECIMAL(10,2)) as unit_price,
    CAST(JSON_VALUE(items.value, '$.totalPrice') AS DECIMAL(10,2)) as total_price,

    -- Substitution Details
    CAST(JSON_VALUE(items.value, '$.isSubstitution') AS BIT) as is_substitution,
    JSON_VALUE(items.value, '$.originalProductRequested') as original_product_requested,
    JSON_VALUE(items.value, '$.originalBrandRequested') as original_brand_requested,
    JSON_VALUE(items.value, '$.substitutionReason') as substitution_reason,
    CAST(JSON_VALUE(items.value, '$.customerRequest.acceptedSuggestion') AS BIT) as customer_accepted_substitution,

    -- Detection & Confidence
    JSON_VALUE(items.value, '$.detectionMethod') as detection_method,
    CAST(JSON_VALUE(items.value, '$.brandConfidence') AS DECIMAL(3,2)) as brand_confidence,
    CAST(JSON_VALUE(items.value, '$.confidence') AS DECIMAL(3,2)) as product_confidence,

    -- Customer Request Context
    JSON_VALUE(items.value, '$.customerRequest.requestType') as customer_request_type,

    -- Audio Context
    JSON_VALUE(items.value, '$.notes') as audio_context

FROM dbo.PayloadTransactions pt
CROSS APPLY OPENJSON(pt.payload_json, '$.items') items
WHERE JSON_VALUE(pt.payload_json, '$.items') IS NOT NULL;

PRINT 'Extracted ' + CAST(@@ROWCOUNT AS VARCHAR) + ' transaction items';

-- ==========================
-- 2. EXTRACT BRAND SUBSTITUTIONS
-- ==========================

-- Extract brand substitution events
INSERT INTO dbo.BrandSubstitutions (
    interaction_id,
    transaction_id,
    original_brand,
    original_product,
    substituted_brand,
    substituted_product,
    substituted_sku,
    substitution_reason,
    suggestion_accepted,
    customer_requested,
    substituted_price,
    original_price,
    confidence_score,
    detection_timestamp
)
SELECT
    JSON_VALUE(pt.payload_json, '$.interactionId') as interaction_id,
    pt.transaction_id,

    -- Original vs Substituted
    JSON_VALUE(items.value, '$.originalBrandRequested') as original_brand,
    JSON_VALUE(items.value, '$.originalProductRequested') as original_product,
    JSON_VALUE(items.value, '$.brandName') as substituted_brand,
    JSON_VALUE(items.value, '$.productName') as substituted_product,
    JSON_VALUE(items.value, '$.sku') as substituted_sku,

    -- Substitution Details
    JSON_VALUE(items.value, '$.substitutionReason') as substitution_reason,
    CAST(JSON_VALUE(items.value, '$.customerRequest.acceptedSuggestion') AS BIT) as suggestion_accepted,
    CASE WHEN JSON_VALUE(items.value, '$.customerRequest.requestType') = 'specific_substitution' THEN 1 ELSE 0 END as customer_requested,

    -- Pricing
    CAST(JSON_VALUE(items.value, '$.unitPrice') AS DECIMAL(10,2)) as substituted_price,
    CAST(JSON_VALUE(items.value, '$.originalPrice') AS DECIMAL(10,2)) as original_price,

    -- Detection
    CAST(JSON_VALUE(items.value, '$.confidence') AS DECIMAL(3,2)) as confidence_score,
    TRY_CAST(JSON_VALUE(pt.payload_json, '$.timestamp') AS DATETIME2) as detection_timestamp

FROM dbo.PayloadTransactions pt
CROSS APPLY OPENJSON(pt.payload_json, '$.items') items
WHERE CAST(JSON_VALUE(items.value, '$.isSubstitution') AS BIT) = 1;

PRINT 'Extracted ' + CAST(@@ROWCOUNT AS VARCHAR) + ' brand substitutions';

-- ==========================
-- 3. EXTRACT MARKET BASKET DATA
-- ==========================

-- Create transaction baskets with product combinations
WITH BasketAggregation AS (
    SELECT
        transaction_id,
        JSON_VALUE(pt.payload_json, '$.interactionId') as interaction_id,
        COUNT(*) as total_items,
        COUNT(DISTINCT JSON_VALUE(items.value, '$.productName')) as unique_products,
        COUNT(DISTINCT JSON_VALUE(items.value, '$.brandName')) as unique_brands,
        COUNT(DISTINCT JSON_VALUE(items.value, '$.category')) as unique_categories,
        SUM(CAST(JSON_VALUE(items.value, '$.totalPrice') AS DECIMAL(10,2))) as total_basket_value,
        AVG(CAST(JSON_VALUE(items.value, '$.unitPrice') AS DECIMAL(10,2))) as avg_item_price,
        MAX(CAST(JSON_VALUE(items.value, '$.unitPrice') AS DECIMAL(10,2))) as max_item_price,

        -- Product combinations as JSON
        JSON_QUERY('[' + STRING_AGG(
            '{"product":"' + JSON_VALUE(items.value, '$.productName') +
            '","brand":"' + JSON_VALUE(items.value, '$.brandName') +
            '","category":"' + JSON_VALUE(items.value, '$.category') +
            '","quantity":' + JSON_VALUE(items.value, '$.quantity') + '}', ',') + ']') as product_list,

        -- Brand list as JSON
        JSON_QUERY('[' + STRING_AGG(DISTINCT '"' + JSON_VALUE(items.value, '$.brandName') + '"', ',') + ']') as brand_list,

        -- Category flags
        MAX(CASE WHEN JSON_VALUE(items.value, '$.category') IN ('Tobacco', 'Cigarettes') THEN 1 ELSE 0 END) as has_tobacco,
        MAX(CASE WHEN JSON_VALUE(items.value, '$.category') IN ('Laundry', 'Detergent', 'Home Care') THEN 1 ELSE 0 END) as has_laundry,
        MAX(CASE WHEN JSON_VALUE(items.value, '$.category') IN ('Beverages', 'Drinks') THEN 1 ELSE 0 END) as has_beverages,
        MAX(CASE WHEN JSON_VALUE(items.value, '$.category') IN ('Snacks', 'Food') THEN 1 ELSE 0 END) as has_snacks,

        TRY_CAST(JSON_VALUE(pt.payload_json, '$.timestamp') AS DATETIME2) as basket_timestamp

    FROM dbo.PayloadTransactions pt
    CROSS APPLY OPENJSON(pt.payload_json, '$.items') items
    WHERE JSON_VALUE(pt.payload_json, '$.items') IS NOT NULL
    GROUP BY transaction_id, pt.payload_json
)
INSERT INTO dbo.TransactionBaskets (
    transaction_id,
    interaction_id,
    total_items,
    unique_products,
    unique_brands,
    unique_categories,
    total_basket_value,
    avg_item_price,
    max_item_price,
    product_list,
    brand_list,
    has_tobacco,
    has_laundry,
    has_beverages,
    has_snacks,
    basket_timestamp
)
SELECT * FROM BasketAggregation;

PRINT 'Created ' + CAST(@@ROWCOUNT AS VARCHAR) + ' transaction baskets';

-- ==========================
-- 4. EXTRACT TRANSACTION COMPLETION STATUS
-- ==========================

-- Extract completion and abandonment data
INSERT INTO dbo.TransactionCompletionStatus (
    interaction_id,
    transaction_id,
    interaction_started,
    selection_made,
    payment_initiated,
    transaction_completed,
    transaction_abandoned,
    abandonment_stage,
    abandonment_reason,
    time_to_abandonment_seconds,
    potential_revenue_lost,
    items_in_abandoned_basket,
    completed_transaction_value,
    interaction_timestamp,
    completion_timestamp,
    abandonment_timestamp
)
SELECT
    JSON_VALUE(pt.payload_json, '$.interactionId') as interaction_id,
    pt.transaction_id,

    -- Status flags
    1 as interaction_started, -- If record exists, interaction started
    CASE WHEN JSON_VALUE(pt.payload_json, '$.items') IS NOT NULL THEN 1 ELSE 0 END as selection_made,
    CASE WHEN JSON_VALUE(pt.payload_json, '$.transactionContext.paymentMethod') IS NOT NULL THEN 1 ELSE 0 END as payment_initiated,
    CASE WHEN CAST(JSON_VALUE(pt.payload_json, '$.totals.totalAmount') AS DECIMAL) > 0 THEN 1 ELSE 0 END as transaction_completed,
    CAST(JSON_VALUE(pt.payload_json, '$.transactionContext.abandoned') AS BIT) as transaction_abandoned,

    -- Abandonment details
    JSON_VALUE(pt.payload_json, '$.transactionContext.abandonmentStage') as abandonment_stage,
    JSON_VALUE(pt.payload_json, '$.transactionContext.abandonmentReason') as abandonment_reason,
    CAST(JSON_VALUE(pt.payload_json, '$.transactionContext.timeToAbandonmentSeconds') AS INT) as time_to_abandonment_seconds,

    -- Financial impact
    CASE WHEN CAST(JSON_VALUE(pt.payload_json, '$.transactionContext.abandoned') AS BIT) = 1
         THEN CAST(JSON_VALUE(pt.payload_json, '$.totals.totalAmount') AS DECIMAL(10,2))
         ELSE 0 END as potential_revenue_lost,
    CAST(JSON_VALUE(pt.payload_json, '$.totals.totalItems') AS INT) as items_in_abandoned_basket,
    CASE WHEN CAST(JSON_VALUE(pt.payload_json, '$.totals.totalAmount') AS DECIMAL) > 0
         THEN CAST(JSON_VALUE(pt.payload_json, '$.totals.totalAmount') AS DECIMAL(10,2))
         ELSE 0 END as completed_transaction_value,

    -- Timestamps
    TRY_CAST(JSON_VALUE(pt.payload_json, '$.timestamp') AS DATETIME2) as interaction_timestamp,
    CASE WHEN CAST(JSON_VALUE(pt.payload_json, '$.totals.totalAmount') AS DECIMAL) > 0
         THEN TRY_CAST(JSON_VALUE(pt.payload_json, '$.timestamp') AS DATETIME2)
         ELSE NULL END as completion_timestamp,
    CASE WHEN CAST(JSON_VALUE(pt.payload_json, '$.transactionContext.abandoned') AS BIT) = 1
         THEN TRY_CAST(JSON_VALUE(pt.payload_json, '$.timestamp') AS DATETIME2)
         ELSE NULL END as abandonment_timestamp

FROM dbo.PayloadTransactions pt;

PRINT 'Extracted ' + CAST(@@ROWCOUNT AS VARCHAR) + ' transaction completion records';

-- ==========================
-- 5. EXTRACT TOBACCO-SPECIFIC ANALYTICS
-- ==========================

-- Extract tobacco purchases with demographics
INSERT INTO dbo.TobaccoAnalytics (
    transaction_id,
    interaction_id,
    brand_name,
    product_type,
    stick_count,
    pack_type,
    customer_age,
    customer_gender,
    purchase_time,
    day_of_month,
    is_payday_period,
    hour_of_day,
    purchased_with_alcohol,
    purchased_with_snacks,
    purchased_with_beverages,
    spoken_terms
)
SELECT
    ti.transaction_id,
    ti.interaction_id,
    ti.brand_name,

    -- Product classification
    CASE
        WHEN ti.product_name LIKE '%cigarette%' THEN 'cigarettes'
        WHEN ti.product_name LIKE '%tobacco%' THEN 'tobacco_roll'
        ELSE 'other'
    END as product_type,

    ti.quantity as stick_count,

    CASE
        WHEN ti.unit = 'pc' AND ti.quantity = 1 THEN 'single'
        WHEN ti.unit = 'pack' THEN 'pack_of_20'
        ELSE 'bulk'
    END as pack_type,

    si.customer_age,
    si.customer_gender,
    si.interaction_timestamp as purchase_time,
    DATEPART(DAY, si.interaction_timestamp) as day_of_month,

    -- Payday analysis
    CASE WHEN DATEPART(DAY, si.interaction_timestamp) BETWEEN 13 AND 17 OR
              DATEPART(DAY, si.interaction_timestamp) BETWEEN 28 AND 31 THEN 1 ELSE 0 END as is_payday_period,

    DATEPART(HOUR, si.interaction_timestamp) as hour_of_day,

    -- Co-purchase analysis (checking same transaction)
    CASE WHEN EXISTS (
        SELECT 1 FROM dbo.TransactionItems ti2
        WHERE ti2.transaction_id = ti.transaction_id
        AND ti2.category IN ('Alcohol', 'Beer', 'Liquor')
    ) THEN 1 ELSE 0 END as purchased_with_alcohol,

    CASE WHEN EXISTS (
        SELECT 1 FROM dbo.TransactionItems ti2
        WHERE ti2.transaction_id = ti.transaction_id
        AND ti2.category IN ('Snacks', 'Food')
    ) THEN 1 ELSE 0 END as purchased_with_snacks,

    CASE WHEN EXISTS (
        SELECT 1 FROM dbo.TransactionItems ti2
        WHERE ti2.transaction_id = ti.transaction_id
        AND ti2.category IN ('Beverages', 'Drinks')
    ) THEN 1 ELSE 0 END as purchased_with_beverages,

    -- Extract spoken terms from audio context
    JSON_QUERY('[' + CASE
        WHEN ti.audio_context LIKE '%yosi%' OR ti.audio_context LIKE '%stick%' OR ti.audio_context LIKE '%kaha%'
        THEN STRING_AGG('"' +
            CASE
                WHEN ti.audio_context LIKE '%yosi%' THEN 'yosi'
                WHEN ti.audio_context LIKE '%stick%' THEN 'stick'
                WHEN ti.audio_context LIKE '%kaha%' THEN 'kaha'
                WHEN ti.audio_context LIKE '%reds%' THEN 'reds'
                WHEN ti.audio_context LIKE '%lights%' THEN 'lights'
            END + '"', ',')
        ELSE NULL
    END + ']') as spoken_terms

FROM dbo.TransactionItems ti
INNER JOIN dbo.SalesInteractions si ON ti.interaction_id = si.interaction_id
WHERE ti.category IN ('Tobacco', 'Cigarettes', 'Smoking')
GROUP BY ti.transaction_id, ti.interaction_id, ti.brand_name, ti.product_name, ti.quantity, ti.unit,
         si.customer_age, si.customer_gender, si.interaction_timestamp, ti.audio_context;

PRINT 'Extracted ' + CAST(@@ROWCOUNT AS VARCHAR) + ' tobacco analytics records';

-- ==========================
-- 6. EXTRACT LAUNDRY-SPECIFIC ANALYTICS
-- ==========================

-- Extract laundry purchases with demographics
INSERT INTO dbo.LaundryAnalytics (
    transaction_id,
    interaction_id,
    brand_name,
    product_type,
    size_description,
    customer_age,
    customer_gender,
    purchase_time,
    day_of_month,
    is_payday_period,
    has_detergent,
    has_bar_soap,
    has_fabric_softener,
    has_bleach,
    spoken_terms
)
SELECT
    ti.transaction_id,
    ti.interaction_id,
    ti.brand_name,

    -- Product type classification
    CASE
        WHEN ti.product_name LIKE '%bar%' OR ti.local_name LIKE '%baro%' THEN 'bar_soap'
        WHEN ti.product_name LIKE '%powder%' OR ti.product_name LIKE '%pulbos%' THEN 'powder_detergent'
        WHEN ti.product_name LIKE '%liquid%' THEN 'liquid_detergent'
        WHEN ti.product_name LIKE '%fabric%' OR ti.product_name LIKE '%fabcon%' THEN 'fabric_softener'
        ELSE 'other'
    END as product_type,

    CASE
        WHEN ti.unit = 'sachet' THEN 'sachet'
        WHEN ti.product_name LIKE '%small%' THEN 'small'
        WHEN ti.product_name LIKE '%medium%' THEN 'medium'
        WHEN ti.product_name LIKE '%large%' THEN 'large'
        ELSE 'regular'
    END as size_description,

    si.customer_age,
    si.customer_gender,
    si.interaction_timestamp as purchase_time,
    DATEPART(DAY, si.interaction_timestamp) as day_of_month,

    -- Payday analysis
    CASE WHEN DATEPART(DAY, si.interaction_timestamp) BETWEEN 13 AND 17 OR
              DATEPART(DAY, si.interaction_timestamp) BETWEEN 28 AND 31 THEN 1 ELSE 0 END as is_payday_period,

    -- Co-purchase patterns in same transaction
    MAX(CASE WHEN ti2.product_name LIKE '%detergent%' THEN 1 ELSE 0 END) as has_detergent,
    MAX(CASE WHEN ti2.product_name LIKE '%bar%' OR ti2.local_name LIKE '%baro%' THEN 1 ELSE 0 END) as has_bar_soap,
    MAX(CASE WHEN ti2.product_name LIKE '%fabric%' OR ti2.product_name LIKE '%fabcon%' THEN 1 ELSE 0 END) as has_fabric_softener,
    MAX(CASE WHEN ti2.product_name LIKE '%bleach%' THEN 1 ELSE 0 END) as has_bleach,

    -- Extract spoken terms
    JSON_QUERY('[' + CASE
        WHEN ti.audio_context LIKE '%sabon%' OR ti.audio_context LIKE '%labada%' OR ti.audio_context LIKE '%panlaba%'
        THEN STRING_AGG('"' +
            CASE
                WHEN ti.audio_context LIKE '%sabon%' THEN 'sabon'
                WHEN ti.audio_context LIKE '%labada%' THEN 'labada'
                WHEN ti.audio_context LIKE '%panlaba%' THEN 'panlaba'
                WHEN ti.audio_context LIKE '%bars%' THEN 'bars'
                WHEN ti.audio_context LIKE '%pulbos%' THEN 'pulbos'
                WHEN ti.audio_context LIKE '%fabcon%' THEN 'fabcon'
            END + '"', ',')
        ELSE NULL
    END + ']') as spoken_terms

FROM dbo.TransactionItems ti
INNER JOIN dbo.SalesInteractions si ON ti.interaction_id = si.interaction_id
LEFT JOIN dbo.TransactionItems ti2 ON ti.transaction_id = ti2.transaction_id -- For co-purchase analysis
WHERE ti.category IN ('Laundry', 'Detergent', 'Home Care', 'Cleaning')
GROUP BY ti.transaction_id, ti.interaction_id, ti.brand_name, ti.product_name, ti.local_name, ti.unit,
         si.customer_age, si.customer_gender, si.interaction_timestamp, ti.audio_context;

PRINT 'Extracted ' + CAST(@@ROWCOUNT AS VARCHAR) + ' laundry analytics records';

-- ==========================
-- 7. CALCULATE PRODUCT ASSOCIATIONS (Market Basket Mining)
-- ==========================

-- Calculate support, confidence, and lift for product pairs
WITH TransactionPairs AS (
    SELECT
        t1.transaction_id,
        t1.product_name as product_a,
        t1.brand_name as brand_a,
        t1.category as category_a,
        t2.product_name as product_b,
        t2.brand_name as brand_b,
        t2.category as category_b
    FROM dbo.TransactionItems t1
    INNER JOIN dbo.TransactionItems t2
        ON t1.transaction_id = t2.transaction_id
        AND t1.product_name < t2.product_name -- Avoid duplicates and self-pairs
),
TotalTransactions AS (
    SELECT COUNT(DISTINCT transaction_id) as total_count
    FROM dbo.TransactionItems
),
AssociationMetrics AS (
    SELECT
        tp.product_a,
        tp.brand_a,
        tp.category_a,
        tp.product_b,
        tp.brand_b,
        tp.category_b,
        COUNT(*) as transactions_together,
        COUNT(*) * 1.0 / tt.total_count as support,
        COUNT(*) * 1.0 / (
            SELECT COUNT(DISTINCT transaction_id)
            FROM dbo.TransactionItems
            WHERE product_name = tp.product_a
        ) as confidence
    FROM TransactionPairs tp
    CROSS JOIN TotalTransactions tt
    GROUP BY tp.product_a, tp.brand_a, tp.category_a, tp.product_b, tp.brand_b, tp.category_b, tt.total_count
    HAVING COUNT(*) >= 3 -- Minimum 3 co-occurrences
)
INSERT INTO dbo.ProductAssociations (
    product_a,
    product_b,
    brand_a,
    brand_b,
    category_a,
    category_b,
    support,
    confidence,
    lift,
    transactions_together,
    transactions_a_only,
    transactions_b_only,
    total_transactions_analyzed
)
SELECT
    am.product_a,
    am.product_b,
    am.brand_a,
    am.brand_b,
    am.category_a,
    am.category_b,
    am.support,
    am.confidence,
    -- Calculate lift: confidence / P(B)
    am.confidence / NULLIF((
        SELECT COUNT(DISTINCT transaction_id) * 1.0 / (SELECT COUNT(DISTINCT transaction_id) FROM dbo.TransactionItems)
        FROM dbo.TransactionItems
        WHERE product_name = am.product_b
    ), 0) as lift,
    am.transactions_together,
    (SELECT COUNT(DISTINCT transaction_id) FROM dbo.TransactionItems WHERE product_name = am.product_a) as transactions_a_only,
    (SELECT COUNT(DISTINCT transaction_id) FROM dbo.TransactionItems WHERE product_name = am.product_b) as transactions_b_only,
    (SELECT COUNT(DISTINCT transaction_id) FROM dbo.TransactionItems) as total_transactions_analyzed
FROM AssociationMetrics am
WHERE am.support >= 0.005; -- Minimum 0.5% support

PRINT 'Calculated ' + CAST(@@ROWCOUNT AS VARCHAR) + ' product associations';

-- ==========================
-- 8. LOG ETL EXECUTION
-- ==========================

INSERT INTO dbo.ETLProcessingLog (
    process_name,
    files_processed,
    transactions_extracted,
    items_extracted,
    brands_detected,
    status
)
VALUES (
    'Enhanced ETL Pipeline v1.0',
    (SELECT COUNT(*) FROM dbo.PayloadTransactions),
    (SELECT COUNT(DISTINCT transaction_id) FROM dbo.TransactionItems),
    (SELECT COUNT(*) FROM dbo.TransactionItems),
    (SELECT COUNT(DISTINCT brand_name) FROM dbo.TransactionItems WHERE brand_name IS NOT NULL),
    'success'
);

PRINT '========================================';
PRINT 'Enhanced ETL Pipeline Completed Successfully!';
PRINT 'Data extracted:';
PRINT '- Transaction Items: ' + CAST((SELECT COUNT(*) FROM dbo.TransactionItems) AS VARCHAR);
PRINT '- Brand Substitutions: ' + CAST((SELECT COUNT(*) FROM dbo.BrandSubstitutions) AS VARCHAR);
PRINT '- Transaction Baskets: ' + CAST((SELECT COUNT(*) FROM dbo.TransactionBaskets) AS VARCHAR);
PRINT '- Product Associations: ' + CAST((SELECT COUNT(*) FROM dbo.ProductAssociations) AS VARCHAR);
PRINT '- Tobacco Analytics: ' + CAST((SELECT COUNT(*) FROM dbo.TobaccoAnalytics) AS VARCHAR);
PRINT '- Laundry Analytics: ' + CAST((SELECT COUNT(*) FROM dbo.LaundryAnalytics) AS VARCHAR);
PRINT '========================================';