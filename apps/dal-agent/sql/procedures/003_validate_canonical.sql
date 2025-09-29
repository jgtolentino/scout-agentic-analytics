-- ========================================================================
-- Canonical Schema Validation Procedures
-- Purpose: Comprehensive validation of views against canonical schema
-- ========================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

PRINT 'Creating canonical schema validation procedures...';

-- Main validation procedure
CREATE OR ALTER PROCEDURE canonical.sp_validate_view_compliance
    @view_name nvarchar(256),
    @throw_on_error bit = 0,
    @detailed_report bit = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @object_id int = OBJECT_ID(@view_name);
    DECLARE @error_count int = 0;
    DECLARE @validation_results TABLE (
        check_type nvarchar(128),
        status nvarchar(16),
        expected nvarchar(500),
        actual nvarchar(500),
        severity nvarchar(16)
    );

    PRINT CONCAT('=== CANONICAL SCHEMA VALIDATION: ', @view_name, ' ===');
    PRINT CONCAT('Timestamp: ', CONVERT(varchar(20), GETDATE(), 120));
    PRINT '';

    -- Check 1: View exists
    IF @object_id IS NULL
    BEGIN
        INSERT INTO @validation_results VALUES
        ('View Existence', 'FAIL', 'View should exist', 'View not found', 'CRITICAL');
        SET @error_count = @error_count + 1;
        GOTO validation_summary;
    END
    ELSE
    BEGIN
        INSERT INTO @validation_results VALUES
        ('View Existence', 'PASS', 'View exists', 'View found', 'INFO');
    END;

    -- Check 2: Column count (must be exactly 13)
    DECLARE @actual_column_count int = (
        SELECT COUNT(*)
        FROM sys.columns
        WHERE object_id = @object_id
    );

    IF @actual_column_count != 13
    BEGIN
        INSERT INTO @validation_results VALUES
        ('Column Count', 'FAIL', '13 columns',
         CONCAT(@actual_column_count, ' columns'), 'CRITICAL');
        SET @error_count = @error_count + 1;
    END
    ELSE
    BEGIN
        INSERT INTO @validation_results VALUES
        ('Column Count', 'PASS', '13 columns', '13 columns', 'INFO');
    END;

    -- Check 3: Column names and order
    WITH canonical_spec AS (
        SELECT column_ord, column_name, data_type, is_nullable
        FROM canonical.flat_schema_definition
    ),
    actual_columns AS (
        SELECT
            column_id as column_ord,
            name as column_name,
            TYPE_NAME(system_type_id) as data_type,
            is_nullable
        FROM sys.columns
        WHERE object_id = @object_id
    ),
    column_comparison AS (
        SELECT
            c.column_ord,
            c.column_name as expected_name,
            c.data_type as expected_type,
            c.is_nullable as expected_nullable,
            a.column_name as actual_name,
            a.data_type as actual_type,
            a.is_nullable as actual_nullable,
            CASE
                WHEN a.column_name IS NULL THEN 'MISSING_COLUMN'
                WHEN c.column_name != a.column_name THEN 'NAME_MISMATCH'
                WHEN c.data_type != a.data_type THEN 'TYPE_MISMATCH'
                WHEN c.is_nullable != a.is_nullable THEN 'NULLABLE_MISMATCH'
                ELSE 'MATCH'
            END as status
        FROM canonical_spec c
        FULL OUTER JOIN actual_columns a ON c.column_ord = a.column_ord
    )
    INSERT INTO @validation_results
    SELECT
        CONCAT('Column ', column_ord, ' (', expected_name, ')'),
        CASE WHEN status = 'MATCH' THEN 'PASS' ELSE 'FAIL' END,
        CONCAT(expected_name, ' ', expected_type, CASE WHEN expected_nullable = 1 THEN ' NULL' ELSE ' NOT NULL' END),
        CASE
            WHEN actual_name IS NULL THEN 'MISSING'
            ELSE CONCAT(actual_name, ' ', actual_type, CASE WHEN actual_nullable = 1 THEN ' NULL' ELSE ' NOT NULL' END)
        END,
        CASE
            WHEN status IN ('MISSING_COLUMN', 'NAME_MISMATCH') THEN 'CRITICAL'
            WHEN status IN ('TYPE_MISMATCH', 'NULLABLE_MISMATCH') THEN 'HIGH'
            ELSE 'INFO'
        END
    FROM column_comparison;

    -- Count column errors
    SET @error_count = @error_count + (
        SELECT COUNT(*)
        FROM @validation_results
        WHERE status = 'FAIL'
          AND check_type LIKE 'Column %'
    );

    -- Check 4: Data quality validation (if view has data)
    DECLARE @row_count bigint;
    DECLARE @null_required_fields int;
    DECLARE @sql nvarchar(max);

    BEGIN TRY
        SET @sql = CONCAT('SELECT @count = COUNT(*) FROM ', @view_name);
        EXEC sp_executesql @sql, N'@count bigint OUTPUT', @count = @row_count OUTPUT;

        IF @row_count > 0
        BEGIN
            -- Check for NULLs in required fields
            SET @sql = CONCAT('
                SELECT @null_count = COUNT(*)
                FROM ', @view_name, '
                WHERE Transaction_ID IS NULL
                   OR Transaction_Value IS NULL
                   OR Basket_Size IS NULL
                   OR Category IS NULL
                   OR Brand IS NULL
                   OR Daypart IS NULL
                   OR Demographics_Age_Gender_Role IS NULL
                   OR Weekday_vs_Weekend IS NULL
                   OR Export_Timestamp IS NULL'
            );
            EXEC sp_executesql @sql, N'@null_count int OUTPUT', @null_count = @null_required_fields OUTPUT;

            IF @null_required_fields > 0
            BEGIN
                INSERT INTO @validation_results VALUES
                ('Required Field NULLs', 'FAIL', '0 NULL required fields',
                 CONCAT(@null_required_fields, ' rows with NULL required fields'), 'HIGH');
                SET @error_count = @error_count + 1;
            END
            ELSE
            BEGIN
                INSERT INTO @validation_results VALUES
                ('Required Field NULLs', 'PASS', 'No NULLs in required fields', 'No NULL violations', 'INFO');
            END;

            INSERT INTO @validation_results VALUES
            ('Data Volume', 'INFO', 'Has data', CONCAT(@row_count, ' rows'), 'INFO');
        END
        ELSE
        BEGIN
            INSERT INTO @validation_results VALUES
            ('Data Volume', 'WARN', 'Has data', '0 rows (empty view)', 'MEDIUM');
        END;
    END TRY
    BEGIN CATCH
        INSERT INTO @validation_results VALUES
        ('Data Access', 'FAIL', 'View should be queryable', ERROR_MESSAGE(), 'CRITICAL');
        SET @error_count = @error_count + 1;
    END CATCH;

validation_summary:

    -- Display results
    IF @detailed_report = 1
    BEGIN
        PRINT '=== DETAILED VALIDATION RESULTS ===';
        SELECT
            check_type,
            status,
            expected,
            actual,
            severity
        FROM @validation_results
        ORDER BY
            CASE severity
                WHEN 'CRITICAL' THEN 1
                WHEN 'HIGH' THEN 2
                WHEN 'MEDIUM' THEN 3
                WHEN 'INFO' THEN 4
            END,
            check_type;
    END;

    -- Summary
    DECLARE @pass_count int = (SELECT COUNT(*) FROM @validation_results WHERE status = 'PASS');
    DECLARE @fail_count int = (SELECT COUNT(*) FROM @validation_results WHERE status = 'FAIL');
    DECLARE @warn_count int = (SELECT COUNT(*) FROM @validation_results WHERE status = 'WARN');

    PRINT '';
    PRINT '=== VALIDATION SUMMARY ===';
    PRINT CONCAT('✅ PASSED: ', @pass_count);
    IF @warn_count > 0 PRINT CONCAT('⚠️  WARNINGS: ', @warn_count);
    IF @fail_count > 0 PRINT CONCAT('❌ FAILED: ', @fail_count);
    PRINT '';

    IF @error_count = 0
    BEGIN
        PRINT '🎉 CANONICAL COMPLIANCE: ✅ FULLY COMPLIANT';
        PRINT CONCAT('View "', @view_name, '" meets all canonical schema requirements.');
    END
    ELSE
    BEGIN
        PRINT '🚨 CANONICAL COMPLIANCE: ❌ NON-COMPLIANT';
        PRINT CONCAT('View "', @view_name, '" has ', @error_count, ' compliance issues.');

        IF @throw_on_error = 1
        BEGIN
            THROW 50001, 'View does not meet canonical schema requirements', 1;
        END;
    END;

    PRINT '';
    PRINT CONCAT('=== END VALIDATION: ', @view_name, ' ===');

    RETURN @error_count;  -- Return error count for programmatic use
END;
GO

-- Batch validation procedure for multiple views
CREATE OR ALTER PROCEDURE canonical.sp_validate_all_flat_views
    @throw_on_any_error bit = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @views_to_check TABLE (
        view_name nvarchar(256),
        priority int
    );

    -- Define critical views to validate
    INSERT INTO @views_to_check VALUES
    ('gold.v_transactions_flat_canonical', 1),
    ('gold.v_transactions_flat_production', 2),
    ('gold.v_transactions_flat_tobacco', 3),
    ('gold.v_transactions_flat_laundry', 4),
    ('dbo.v_flat_export_sheet', 5);  -- Legacy view

    DECLARE @total_errors int = 0;
    DECLARE @view_name nvarchar(256);
    DECLARE @error_count int;

    PRINT '🔍 STARTING BATCH CANONICAL VALIDATION';
    PRINT CONCAT('Timestamp: ', CONVERT(varchar(20), GETDATE(), 120));
    PRINT '';

    DECLARE view_cursor CURSOR FOR
        SELECT view_name
        FROM @views_to_check
        WHERE EXISTS (SELECT 1 FROM sys.objects WHERE name = PARSENAME(view_name, 1) AND type = 'V')
        ORDER BY priority;

    OPEN view_cursor;
    FETCH NEXT FROM view_cursor INTO @view_name;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC @error_count = canonical.sp_validate_view_compliance
            @view_name = @view_name,
            @throw_on_error = 0,
            @detailed_report = 1;

        SET @total_errors = @total_errors + @error_count;

        PRINT '';
        PRINT REPLICATE('-', 80);
        PRINT '';

        FETCH NEXT FROM view_cursor INTO @view_name;
    END;

    CLOSE view_cursor;
    DEALLOCATE view_cursor;

    PRINT '📊 BATCH VALIDATION SUMMARY';
    PRINT CONCAT('Total views checked: ', (SELECT COUNT(*) FROM @views_to_check WHERE EXISTS (SELECT 1 FROM sys.objects WHERE name = PARSENAME(view_name, 1) AND type = 'V')));
    PRINT CONCAT('Total compliance issues: ', @total_errors);

    IF @total_errors = 0
    BEGIN
        PRINT '🎉 ALL VIEWS ARE CANONICALLY COMPLIANT!';
    END
    ELSE
    BEGIN
        PRINT '🚨 COMPLIANCE ISSUES FOUND - REVIEW REQUIRED';

        IF @throw_on_any_error = 1
        BEGIN
            THROW 50002, 'One or more views have canonical compliance issues', 1;
        END;
    END;

    RETURN @total_errors;
END;
GO

-- Quick compliance check function
CREATE OR ALTER FUNCTION canonical.fn_is_view_compliant(@view_name nvarchar(256))
RETURNS bit
AS
BEGIN
    DECLARE @error_count int;

    BEGIN TRY
        EXEC @error_count = canonical.sp_validate_view_compliance
            @view_name = @view_name,
            @throw_on_error = 0,
            @detailed_report = 0;
    END TRY
    BEGIN CATCH
        RETURN 0;  -- If validation itself fails, not compliant
    END CATCH;

    RETURN CASE WHEN @error_count = 0 THEN 1 ELSE 0 END;
END;
GO

-- Create monitoring view for compliance status
CREATE OR ALTER VIEW canonical.v_view_compliance_status AS
WITH flat_views AS (
    SELECT
        CONCAT(SCHEMA_NAME(schema_id), '.', name) as view_name,
        name as short_name,
        create_date,
        modify_date
    FROM sys.objects
    WHERE type = 'V'
      AND name LIKE '%flat%'
)
SELECT
    fv.view_name,
    fv.short_name,
    canonical.fn_is_view_compliant(fv.view_name) as is_compliant,
    CASE canonical.fn_is_view_compliant(fv.view_name)
        WHEN 1 THEN '✅ Compliant'
        ELSE '❌ Non-Compliant'
    END as compliance_status,
    fv.create_date,
    fv.modify_date
FROM flat_views fv;
GO

PRINT '✅ Canonical validation procedures created successfully';
PRINT '   • canonical.sp_validate_view_compliance - Single view validation';
PRINT '   • canonical.sp_validate_all_flat_views - Batch validation';
PRINT '   • canonical.fn_is_view_compliant - Quick compliance check';
PRINT '   • canonical.v_view_compliance_status - Monitoring view';

-- Test the main validation procedure
PRINT '';
PRINT '🧪 Testing validation system...';
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = 'v_transactions_flat_canonical' AND schema_id = SCHEMA_ID('gold'))
BEGIN
    PRINT 'Testing canonical view validation:';
    EXEC canonical.sp_validate_view_compliance
        @view_name = 'gold.v_transactions_flat_canonical',
        @detailed_report = 0;
END;

PRINT 'Canonical validation system deployment complete.';