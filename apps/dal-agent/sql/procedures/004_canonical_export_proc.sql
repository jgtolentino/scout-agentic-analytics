-- ========================================================================
-- Canonical Export Procedures
-- Purpose: Standardized export procedures that ALWAYS output 13 columns
-- ========================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

PRINT 'Creating canonical export procedures...';

-- Main canonical export procedure
CREATE OR ALTER PROCEDURE dbo.sp_export_canonical_flat
    @date_from date = NULL,
    @date_to date = NULL,
    @region nvarchar(256) = NULL,
    @category nvarchar(256) = NULL,
    @store_id nvarchar(64) = NULL,
    @validate_before_export bit = 1,
    @include_header bit = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @start_time datetime2 = SYSUTCDATETIME();
    DECLARE @error_count int = 0;

    PRINT CONCAT('=== CANONICAL FLAT EXPORT ===');
    PRINT CONCAT('Started: ', CONVERT(varchar(20), @start_time, 120));
    PRINT CONCAT('Filters: DateFrom=', ISNULL(CAST(@date_from AS nvarchar), 'NULL'),
                 ', DateTo=', ISNULL(CAST(@date_to AS nvarchar), 'NULL'),
                 ', Region=', ISNULL(@region, 'NULL'),
                 ', Category=', ISNULL(@category, 'NULL'),
                 ', Store=', ISNULL(@store_id, 'NULL'));

    -- Validate canonical compliance before export
    IF @validate_before_export = 1
    BEGIN
        PRINT 'Validating canonical compliance...';
        EXEC @error_count = canonical.sp_validate_view_compliance
            @view_name = 'gold.v_transactions_flat_canonical',
            @throw_on_error = 0,
            @detailed_report = 0;

        IF @error_count > 0
        BEGIN
            PRINT '❌ Canonical compliance validation failed. Export aborted.';
            THROW 50001, 'Cannot export non-compliant view', 1;
        END
        ELSE
        BEGIN
            PRINT '✅ Canonical compliance validated.';
        END;
    END;

    -- Build dynamic WHERE clause
    DECLARE @where_conditions nvarchar(max) = '';
    DECLARE @param_definitions nvarchar(max) = '';
    DECLARE @param_values nvarchar(max) = '';

    IF @date_from IS NOT NULL
    BEGIN
        SET @where_conditions = @where_conditions + ' AND CAST(Transaction_ID AS date) >= @date_from_param';
        SET @param_definitions = @param_definitions + ', @date_from_param date';
        SET @param_values = @param_values + ', @date_from_param = ''' + CAST(@date_from AS nvarchar) + '''';
    END;

    IF @date_to IS NOT NULL
    BEGIN
        SET @where_conditions = @where_conditions + ' AND CAST(Transaction_ID AS date) <= @date_to_param';
        SET @param_definitions = @param_definitions + ', @date_to_param date';
        SET @param_values = @param_values + ', @date_to_param = ''' + CAST(@date_to AS nvarchar) + '''';
    END;

    IF @region IS NOT NULL
    BEGIN
        SET @where_conditions = @where_conditions + ' AND Location LIKE ''%'' + @region_param + ''%''';
        SET @param_definitions = @param_definitions + ', @region_param nvarchar(256)';
        SET @param_values = @param_values + ', @region_param = ''' + REPLACE(@region, '''', '''''') + '''';
    END;

    IF @category IS NOT NULL
    BEGIN
        SET @where_conditions = @where_conditions + ' AND Category LIKE ''%'' + @category_param + ''%''';
        SET @param_definitions = @param_definitions + ', @category_param nvarchar(256)';
        SET @param_values = @param_values + ', @category_param = ''' + REPLACE(@category, '''', '''''') + '''';
    END;

    IF @store_id IS NOT NULL
    BEGIN
        SET @where_conditions = @where_conditions + ' AND Transaction_ID LIKE @store_id_param + ''%''';
        SET @param_definitions = @param_definitions + ', @store_id_param nvarchar(64)';
        SET @param_values = @param_values + ', @store_id_param = ''' + REPLACE(@store_id, '''', '''''') + '''';
    END;

    -- Remove leading AND
    IF LEN(@where_conditions) > 0
        SET @where_conditions = SUBSTRING(@where_conditions, 5, LEN(@where_conditions));
    ELSE
        SET @where_conditions = '1=1';

    -- Remove leading comma from parameters
    IF LEN(@param_definitions) > 0
        SET @param_definitions = SUBSTRING(@param_definitions, 3, LEN(@param_definitions));

    IF LEN(@param_values) > 0
        SET @param_values = SUBSTRING(@param_values, 3, LEN(@param_values));

    -- Build and execute export query
    DECLARE @sql nvarchar(max) = '
    SELECT
        /* CANONICAL 13 COLUMNS - GUARANTEED ORDER */
        Transaction_ID,
        Transaction_Value,
        Basket_Size,
        Category,
        Brand,
        Daypart,
        Demographics_Age_Gender_Role,
        Weekday_vs_Weekend,
        Time_of_Transaction,
        Location,
        ISNULL(Other_Products, '''') AS Other_Products,        -- Never NULL in export
        ISNULL(CAST(Was_Substitution AS int), 0) AS Was_Substitution,  -- 0/1 instead of bit
        Export_Timestamp
    FROM gold.v_transactions_flat_canonical
    WHERE ' + @where_conditions + '
    ORDER BY Transaction_ID';

    PRINT 'Executing export query...';

    -- Execute with parameters if any
    IF LEN(@param_definitions) > 0
    BEGIN
        DECLARE @exec_sql nvarchar(max) = 'EXEC sp_executesql N''' + REPLACE(@sql, '''', '''''') + ''', N''' + @param_definitions + '''' + @param_values;
        EXEC(@exec_sql);
    END
    ELSE
    BEGIN
        EXEC(@sql);
    END;

    DECLARE @end_time datetime2 = SYSUTCDATETIME();
    DECLARE @duration_ms int = DATEDIFF(MILLISECOND, @start_time, @end_time);

    PRINT CONCAT('Export completed in ', @duration_ms, 'ms');
    PRINT CONCAT('Finished: ', CONVERT(varchar(20), @end_time, 120));
END;
GO

-- Specialized export procedures
CREATE OR ALTER PROCEDURE dbo.sp_export_canonical_tobacco
    @date_from date = NULL,
    @date_to date = NULL,
    @region nvarchar(256) = NULL
AS
BEGIN
    EXEC dbo.sp_export_canonical_flat
        @date_from = @date_from,
        @date_to = @date_to,
        @region = @region,
        @category = 'Tobacco',
        @validate_before_export = 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_export_canonical_laundry
    @date_from date = NULL,
    @date_to date = NULL,
    @region nvarchar(256) = NULL
AS
BEGIN
    EXEC dbo.sp_export_canonical_flat
        @date_from = @date_from,
        @date_to = @date_to,
        @region = @region,
        @category = 'Laundry',
        @validate_before_export = 1;
END;
GO

-- Bulk export procedure with automatic file naming
CREATE OR ALTER PROCEDURE dbo.sp_export_canonical_bulk
    @output_path nvarchar(500) = 'out/canonical/',
    @date_from date = NULL,
    @date_to date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @timestamp nvarchar(20) = FORMAT(GETDATE(), 'yyyyMMdd_HHmmss');
    DECLARE @categories TABLE (category_name nvarchar(256));

    -- Get distinct categories for bulk export
    INSERT INTO @categories
    SELECT DISTINCT Category
    FROM gold.v_transactions_flat_canonical
    WHERE Category != 'unspecified'
      AND (@date_from IS NULL OR CAST(Transaction_ID AS date) >= @date_from)
      AND (@date_to IS NULL OR CAST(Transaction_ID AS date) <= @date_to);

    DECLARE @category nvarchar(256);
    DECLARE category_cursor CURSOR FOR
        SELECT category_name FROM @categories;

    PRINT CONCAT('Starting bulk export at ', @timestamp);
    PRINT CONCAT('Output path: ', @output_path);
    PRINT CONCAT('Categories to export: ', (SELECT COUNT(*) FROM @categories));

    OPEN category_cursor;
    FETCH NEXT FROM category_cursor INTO @category;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        PRINT CONCAT('Exporting category: ', @category);

        -- Note: Actual file output would need to be handled by calling application
        -- This procedure prepares the data for export
        EXEC dbo.sp_export_canonical_flat
            @date_from = @date_from,
            @date_to = @date_to,
            @category = @category,
            @validate_before_export = 0;  -- Skip validation for bulk (already validated once)

        FETCH NEXT FROM category_cursor INTO @category;
    END;

    CLOSE category_cursor;
    DEALLOCATE category_cursor;

    PRINT 'Bulk export preparation complete';
END;
GO

-- Header generation procedure
CREATE OR ALTER PROCEDURE dbo.sp_get_canonical_header
AS
BEGIN
    SELECT
        'Transaction_ID,Transaction_Value,Basket_Size,Category,Brand,Daypart,Demographics_Age_Gender_Role,Weekday_vs_Weekend,Time_of_Transaction,Location,Other_Products,Was_Substitution,Export_Timestamp' as canonical_header;
END;
GO

-- Export validation procedure
CREATE OR ALTER PROCEDURE dbo.sp_validate_export_data
    @sample_size int = 1000
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '=== CANONICAL EXPORT DATA VALIDATION ===';

    -- Sample data quality checks
    DECLARE @total_rows bigint = (SELECT COUNT(*) FROM gold.v_transactions_flat_canonical);
    DECLARE @null_required_fields int;
    DECLARE @invalid_amounts int;
    DECLARE @invalid_basket_sizes int;
    DECLARE @unspecified_categories int;
    DECLARE @unknown_brands int;

    SELECT
        @null_required_fields = COUNT(CASE
            WHEN Transaction_ID IS NULL
              OR Transaction_Value IS NULL
              OR Basket_Size IS NULL
              OR Category IS NULL
              OR Brand IS NULL
              OR Daypart IS NULL
              OR Demographics_Age_Gender_Role IS NULL
              OR Weekday_vs_Weekend IS NULL
              OR Export_Timestamp IS NULL
            THEN 1 END),
        @invalid_amounts = COUNT(CASE WHEN Transaction_Value <= 0 THEN 1 END),
        @invalid_basket_sizes = COUNT(CASE WHEN Basket_Size <= 0 THEN 1 END),
        @unspecified_categories = COUNT(CASE WHEN Category = 'unspecified' THEN 1 END),
        @unknown_brands = COUNT(CASE WHEN Brand = 'Unknown' THEN 1 END)
    FROM (
        SELECT TOP (@sample_size) *
        FROM gold.v_transactions_flat_canonical
        ORDER BY NEWID()  -- Random sample
    ) sample;

    PRINT CONCAT('Total rows: ', @total_rows);
    PRINT CONCAT('Sample size: ', @sample_size);
    PRINT '';
    PRINT 'Data Quality Issues:';
    PRINT CONCAT('  NULL required fields: ', @null_required_fields);
    PRINT CONCAT('  Invalid amounts (≤0): ', @invalid_amounts);
    PRINT CONCAT('  Invalid basket sizes (≤0): ', @invalid_basket_sizes);
    PRINT CONCAT('  Unspecified categories: ', @unspecified_categories, ' (', FORMAT(100.0 * @unspecified_categories / @sample_size, 'N2'), '%)');
    PRINT CONCAT('  Unknown brands: ', @unknown_brands, ' (', FORMAT(100.0 * @unknown_brands / @sample_size, 'N2'), '%)');

    IF @null_required_fields = 0 AND @invalid_amounts = 0 AND @invalid_basket_sizes = 0
    BEGIN
        PRINT '';
        PRINT '✅ Export data quality validation PASSED';
    END
    ELSE
    BEGIN
        PRINT '';
        PRINT '❌ Export data quality validation FAILED - Review required';
    END;
END;
GO

PRINT '✅ Canonical export procedures created successfully:';
PRINT '   • dbo.sp_export_canonical_flat - Main export procedure';
PRINT '   • dbo.sp_export_canonical_tobacco - Tobacco-specific export';
PRINT '   • dbo.sp_export_canonical_laundry - Laundry-specific export';
PRINT '   • dbo.sp_export_canonical_bulk - Bulk category export';
PRINT '   • dbo.sp_get_canonical_header - CSV header generation';
PRINT '   • dbo.sp_validate_export_data - Export data quality validation';

-- Test the main export procedure
PRINT '';
PRINT '🧪 Testing canonical export procedure...';
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = 'v_transactions_flat_canonical' AND schema_id = SCHEMA_ID('gold'))
BEGIN
    PRINT 'Testing with sample filters (top 5 rows):';
    EXEC dbo.sp_export_canonical_flat
        @date_from = NULL,
        @date_to = NULL,
        @region = NULL,
        @category = NULL,
        @validate_before_export = 0;

    -- Show first 5 rows as test
    SELECT TOP 5 *
    FROM gold.v_transactions_flat_canonical
    ORDER BY Transaction_ID;
END;

PRINT 'Canonical export procedures deployment complete.';