-- =============================================================================
-- Fuzzy Matching Functions for STT Brand Detection
-- Speech-to-Text brand recognition with confidence scoring
-- =============================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Create fuzzy matching function for brand name similarity
CREATE OR ALTER FUNCTION dbo.fn_calculate_brand_similarity(
    @input_text nvarchar(200),
    @brand_text nvarchar(200)
)
RETURNS decimal(5,3)
AS
BEGIN
    DECLARE @similarity decimal(5,3) = 0.0;
    DECLARE @input_clean nvarchar(200);
    DECLARE @brand_clean nvarchar(200);
    DECLARE @input_len int;
    DECLARE @brand_len int;
    DECLARE @common_chars int = 0;
    DECLARE @i int = 1;

    -- Clean and normalize inputs
    SET @input_clean = LOWER(LTRIM(RTRIM(@input_text)));
    SET @brand_clean = LOWER(LTRIM(RTRIM(@brand_text)));

    -- Remove special characters and spaces
    SET @input_clean = REPLACE(REPLACE(REPLACE(@input_clean, ' ', ''), '&', 'and'), '!', '');
    SET @brand_clean = REPLACE(REPLACE(REPLACE(@brand_clean, ' ', ''), '&', 'and'), '!', '');

    SET @input_len = LEN(@input_clean);
    SET @brand_len = LEN(@brand_clean);

    -- Exact match
    IF @input_clean = @brand_clean
        RETURN 1.0;

    -- Length difference penalty
    IF ABS(@input_len - @brand_len) > 5
        RETURN 0.0;

    -- Calculate common character ratio
    WHILE @i <= @input_len
    BEGIN
        IF CHARINDEX(SUBSTRING(@input_clean, @i, 1), @brand_clean) > 0
            SET @common_chars = @common_chars + 1;
        SET @i = @i + 1;
    END

    -- Calculate similarity score
    IF @input_len > 0 AND @brand_len > 0
        SET @similarity = CAST(@common_chars AS decimal(5,3)) / CAST(CASE WHEN @input_len > @brand_len THEN @input_len ELSE @brand_len END AS decimal(5,3));

    -- Bonus for substring matches
    IF CHARINDEX(@input_clean, @brand_clean) > 0 OR CHARINDEX(@brand_clean, @input_clean) > 0
        SET @similarity = @similarity + 0.2;

    -- Cap at 1.0
    IF @similarity > 1.0
        SET @similarity = 1.0;

    RETURN @similarity;
END;
GO

-- Create STT brand detection stored procedure
CREATE OR ALTER PROCEDURE dbo.sp_detect_brand_from_stt
    @speech_text nvarchar(500),
    @min_confidence decimal(5,3) = 0.7,
    @max_results int = 5
AS
BEGIN
    SET NOCOUNT ON;

    -- Results table
    DECLARE @results TABLE (
        brand_name nvarchar(200),
        parent_company nvarchar(200),
        similarity_score decimal(5,3),
        match_type varchar(50),
        matched_text nvarchar(200),
        brand_logo_url nvarchar(500),
        nielsen_category nvarchar(200),
        rank_order int
    );

    -- Clean speech input
    DECLARE @clean_speech nvarchar(500) = LOWER(LTRIM(RTRIM(@speech_text)));

    -- Direct brand name matches
    INSERT INTO @results (brand_name, parent_company, similarity_score, match_type, matched_text, brand_logo_url, nielsen_category, rank_order)
    SELECT
        ds.brand_name,
        ds.parent_company,
        dbo.fn_calculate_brand_similarity(@clean_speech, ds.brand_name) as similarity_score,
        'direct_brand' as match_type,
        ds.brand_name as matched_text,
        ds.brand_logo_url,
        ds.nielsen_category_name,
        ROW_NUMBER() OVER (ORDER BY dbo.fn_calculate_brand_similarity(@clean_speech, ds.brand_name) DESC)
    FROM (SELECT DISTINCT brand_name, parent_company, brand_logo_url, nielsen_category_name FROM dbo.dim_sku_nielsen) ds
    WHERE dbo.fn_calculate_brand_similarity(@clean_speech, ds.brand_name) >= @min_confidence;

    -- Alias matches
    INSERT INTO @results (brand_name, parent_company, similarity_score, match_type, matched_text, brand_logo_url, nielsen_category, rank_order)
    SELECT
        ds.brand_name,
        ds.parent_company,
        ba.confidence_score * dbo.fn_calculate_brand_similarity(@clean_speech, ba.alias_text) as similarity_score,
        CONCAT('alias_', ba.alias_type) as match_type,
        ba.alias_text as matched_text,
        ds.brand_logo_url,
        ds.nielsen_category_name,
        ROW_NUMBER() OVER (ORDER BY ba.confidence_score * dbo.fn_calculate_brand_similarity(@clean_speech, ba.alias_text) DESC) + 1000
    FROM dbo.brand_aliases ba
    JOIN (SELECT DISTINCT brand_name, parent_company, brand_logo_url, nielsen_category_name FROM dbo.dim_sku_nielsen) ds
        ON ds.brand_name = ba.brand_name
    WHERE dbo.fn_calculate_brand_similarity(@clean_speech, ba.alias_text) >= (@min_confidence * 0.8)
      AND ba.brand_name NOT IN (SELECT brand_name FROM @results);

    -- Partial word matches (for compound speech)
    DECLARE @word_cursor CURSOR;
    DECLARE @word nvarchar(100);

    SET @word_cursor = CURSOR FOR
    SELECT value FROM STRING_SPLIT(@clean_speech, ' ') WHERE LEN(value) >= 3;

    OPEN @word_cursor;
    FETCH NEXT FROM @word_cursor INTO @word;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Check each word against brand names
        INSERT INTO @results (brand_name, parent_company, similarity_score, match_type, matched_text, brand_logo_url, nielsen_category, rank_order)
        SELECT
            ds.brand_name,
            ds.parent_company,
            dbo.fn_calculate_brand_similarity(@word, ds.brand_name) * 0.8 as similarity_score,
            'partial_word' as match_type,
            @word as matched_text,
            ds.brand_logo_url,
            ds.nielsen_category_name,
            ROW_NUMBER() OVER (ORDER BY dbo.fn_calculate_brand_similarity(@word, ds.brand_name) DESC) + 2000
        FROM (SELECT DISTINCT brand_name, parent_company, brand_logo_url, nielsen_category_name FROM dbo.dim_sku_nielsen) ds
        WHERE dbo.fn_calculate_brand_similarity(@word, ds.brand_name) >= (@min_confidence * 0.9)
          AND ds.brand_name NOT IN (SELECT brand_name FROM @results);

        -- Check against aliases
        INSERT INTO @results (brand_name, parent_company, similarity_score, match_type, matched_text, brand_logo_url, nielsen_category, rank_order)
        SELECT
            ds.brand_name,
            ds.parent_company,
            ba.confidence_score * dbo.fn_calculate_brand_similarity(@word, ba.alias_text) * 0.7 as similarity_score,
            CONCAT('partial_alias_', ba.alias_type) as match_type,
            ba.alias_text as matched_text,
            ds.brand_logo_url,
            ds.nielsen_category_name,
            ROW_NUMBER() OVER (ORDER BY ba.confidence_score * dbo.fn_calculate_brand_similarity(@word, ba.alias_text) DESC) + 3000
        FROM dbo.brand_aliases ba
        JOIN (SELECT DISTINCT brand_name, parent_company, brand_logo_url, nielsen_category_name FROM dbo.dim_sku_nielsen) ds
            ON ds.brand_name = ba.brand_name
        WHERE dbo.fn_calculate_brand_similarity(@word, ba.alias_text) >= (@min_confidence * 0.8)
          AND ba.brand_name NOT IN (SELECT brand_name FROM @results);

        FETCH NEXT FROM @word_cursor INTO @word;
    END;

    CLOSE @word_cursor;
    DEALLOCATE @word_cursor;

    -- Return ranked results
    SELECT TOP (@max_results)
        brand_name,
        parent_company,
        similarity_score,
        match_type,
        matched_text,
        brand_logo_url,
        nielsen_category,
        CASE
            WHEN similarity_score >= 0.95 THEN 'Very High'
            WHEN similarity_score >= 0.85 THEN 'High'
            WHEN similarity_score >= 0.75 THEN 'Medium'
            ELSE 'Low'
        END as confidence_level
    FROM @results
    WHERE similarity_score >= @min_confidence
    ORDER BY similarity_score DESC, rank_order ASC;
END;
GO

-- Create comprehensive transaction join view with all fact fields
CREATE OR ALTER VIEW platinum.v_transaction_facts_complete AS
SELECT
    -- Transaction identifiers
    sif.TransactionID,
    sif.TransactionDate,
    sif.CustomerID,
    sif.StoreID,

    -- Customer demographics
    sif.Gender,
    sif.Age,
    sif.AgeGroup,

    -- Location data from stores
    s.Region,
    s.ProvinceName,
    s.MunicipalityName,
    s.StoreName,
    s.StoreType,

    -- Product information
    sif.ProductID,
    sif.ProductName,
    sif.Brand,
    sif.Category,
    sif.SubCategory,

    -- Nielsen taxonomy integration
    dsn.nielsen_category_code,
    dsn.nielsen_category_name,
    dsn.nielsen_group_name,
    dsn.nielsen_dept_name,
    dsn.parent_company,
    dsn.brand_logo_url,
    dsn.sari_sari_priority,
    dsn.ph_market_relevant,

    -- Transaction metrics
    sif.Quantity,
    sif.UnitPrice,
    sif.TotalAmount,
    sif.Discount,
    sif.NetAmount,

    -- Behavioral data
    sif.PaymentMethod,
    sif.PromotionUsed,
    sif.RepurchaseFlag,
    sif.CustomerSegment,

    -- Computed fields
    CASE
        WHEN sif.TotalAmount > 500 THEN 'High Value'
        WHEN sif.TotalAmount > 200 THEN 'Medium Value'
        ELSE 'Low Value'
    END as transaction_value_tier,

    CASE
        WHEN sif.Quantity > 5 THEN 'Bulk Purchase'
        WHEN sif.Quantity > 2 THEN 'Multiple Items'
        ELSE 'Single/Small Purchase'
    END as purchase_pattern,

    -- STT support fields
    CONCAT(sif.Brand, ' ', sif.ProductName) as speech_search_text,
    dsn.estimated_price as nielsen_price_reference

FROM canonical.SalesInteractionFact sif
LEFT JOIN dbo.Stores s ON s.StoreID = sif.StoreID
LEFT JOIN dbo.dim_sku_nielsen dsn ON (
    dsn.brand_name = sif.Brand
    OR dsn.brand_name IN (
        SELECT brand_name
        FROM dbo.brand_aliases
        WHERE dbo.fn_calculate_brand_similarity(sif.Brand, alias_text) >= 0.8
    )
)
WHERE sif.TransactionDate >= DATEADD(month, -12, GETDATE())  -- Last 12 months
  AND sif.TotalAmount > 0;  -- Valid transactions only
GO

-- Create STT brand search helper procedure
CREATE OR ALTER PROCEDURE dbo.sp_search_brands_by_speech
    @speech_input nvarchar(500),
    @include_aliases bit = 1,
    @min_confidence decimal(5,3) = 0.7
AS
BEGIN
    SET NOCOUNT ON;

    -- Get brand matches with transaction context
    SELECT
        bd.brand_name,
        bd.parent_company,
        bd.similarity_score,
        bd.match_type,
        bd.matched_text,
        bd.brand_logo_url,
        bd.nielsen_category,
        bd.confidence_level,

        -- Transaction statistics
        ISNULL(stats.total_transactions, 0) as total_transactions,
        ISNULL(stats.total_revenue, 0) as total_revenue,
        ISNULL(stats.avg_transaction_value, 0) as avg_transaction_value,
        ISNULL(stats.unique_customers, 0) as unique_customers,
        ISNULL(stats.last_transaction_date, '1900-01-01') as last_transaction_date

    FROM (
        EXEC dbo.sp_detect_brand_from_stt @speech_input, @min_confidence, 10
    ) bd
    LEFT JOIN (
        SELECT
            Brand,
            COUNT(*) as total_transactions,
            SUM(TotalAmount) as total_revenue,
            AVG(TotalAmount) as avg_transaction_value,
            COUNT(DISTINCT CustomerID) as unique_customers,
            MAX(TransactionDate) as last_transaction_date
        FROM canonical.SalesInteractionFact
        WHERE TransactionDate >= DATEADD(month, -6, GETDATE())
        GROUP BY Brand
    ) stats ON stats.Brand = bd.brand_name
    ORDER BY bd.similarity_score DESC, stats.total_transactions DESC;
END;
GO

PRINT 'STT fuzzy matching functions and procedures created successfully.';

-- Test the fuzzy matching system
PRINT 'Testing STT brand detection system...';

-- Test with common STT variations
EXEC dbo.sp_detect_brand_from_stt 'koka kola', 0.7, 3;
EXEC dbo.sp_detect_brand_from_stt 'neskape', 0.7, 3;
EXEC dbo.sp_detect_brand_from_stt 'laki mi pamilihin', 0.7, 3;
EXEC dbo.sp_detect_brand_from_stt 'hed en solders', 0.7, 3;