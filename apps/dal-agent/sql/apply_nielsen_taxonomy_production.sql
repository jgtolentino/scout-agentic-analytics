-- Apply Nielsen/Kantar Taxonomy to Production Scout System
-- This integrates our Nielsen taxonomy with the existing brand-category data

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Create procedure to apply Nielsen taxonomy to existing production system
CREATE OR ALTER PROCEDURE sp_ApplyNielsenTaxonomyProduction
    @DryRun BIT = 1,
    @LogResults BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UpdatedBrands INT = 0;
    DECLARE @UpdatedTransactions INT = 0;
    DECLARE @UnspecifiedBefore INT;
    DECLARE @UnspecifiedAfter INT;

    IF @LogResults = 1
    BEGIN
        PRINT 'Nielsen/Kantar Taxonomy Integration - Production Scout System';
        PRINT 'Started: ' + CONVERT(NVARCHAR(30), GETDATE(), 120);
        PRINT 'Mode: ' + CASE WHEN @DryRun = 1 THEN 'DRY RUN (no changes)' ELSE 'LIVE EXECUTION' END;
        PRINT '';
    END

    -- Get baseline unspecified count
    SELECT @UnspecifiedBefore = SUM(txn_count)
    FROM v_xtab_time_brand_category_abs
    WHERE category = 'unspecified';

    IF @LogResults = 1
    BEGIN
        PRINT 'Current unspecified transactions: ' + CAST(@UnspecifiedBefore AS NVARCHAR(20));
        PRINT '';
        PRINT 'Brands that will be updated with Nielsen taxonomy:';
    END

    -- Show brands that will be updated (for both dry run and live)
    SELECT DISTINCT
        vt.brand,
        vt.category as current_category,
        tc.category_name as nielsen_category,
        td.department_name as nielsen_department,
        SUM(vt.txn_count) as affected_transactions
    FROM v_xtab_time_brand_category_abs vt
    INNER JOIN dbo.BrandCategoryMapping bcm ON vt.brand = bcm.brand_name
    INNER JOIN dbo.TaxonomyCategories tc ON bcm.category_id = tc.category_id
    INNER JOIN dbo.TaxonomyCategoryGroups tcg ON tc.category_group_id = tcg.category_group_id
    INNER JOIN dbo.TaxonomyDepartments td ON tcg.department_id = td.department_id
    WHERE vt.category = 'unspecified'
    GROUP BY vt.brand, vt.category, tc.category_name, td.department_name
    ORDER BY affected_transactions DESC;

    SELECT @UpdatedBrands = @@ROWCOUNT;

    IF @DryRun = 0
    BEGIN
        PRINT '';
        PRINT 'EXECUTING LIVE UPDATES...';

        -- Here we would update the underlying data source that feeds v_xtab_time_brand_category_abs
        -- Since this is a view, we need to update the source tables

        -- Method 1: Update via the JSON payloads (most comprehensive)
        -- This would involve updating the brand detection results in PayloadTransactions

        -- Method 2: Update source brand/category tables if they exist
        -- Find and update the underlying brand-category mapping tables

        -- For now, we'll create a mapping table that can be used by the views
        IF OBJECT_ID('dbo.ProductionBrandCategoryOverride', 'U') IS NULL
        BEGIN
            CREATE TABLE dbo.ProductionBrandCategoryOverride (
                brand_name NVARCHAR(200) NOT NULL,
                original_category NVARCHAR(200),
                nielsen_category NVARCHAR(200) NOT NULL,
                nielsen_department NVARCHAR(200) NOT NULL,
                nielsen_category_id INT NOT NULL,
                updated_date DATETIME DEFAULT GETDATE(),
                PRIMARY KEY (brand_name)
            );
            PRINT 'Created ProductionBrandCategoryOverride table';
        END

        -- Populate the override table with Nielsen mappings
        INSERT INTO dbo.ProductionBrandCategoryOverride (
            brand_name, original_category, nielsen_category, nielsen_department, nielsen_category_id
        )
        SELECT DISTINCT
            vt.brand,
            vt.category,
            tc.category_name,
            td.department_name,
            tc.category_id
        FROM v_xtab_time_brand_category_abs vt
        INNER JOIN dbo.BrandCategoryMapping bcm ON vt.brand = bcm.brand_name
        INNER JOIN dbo.TaxonomyCategories tc ON bcm.category_id = tc.category_id
        INNER JOIN dbo.TaxonomyCategoryGroups tcg ON tc.category_group_id = tcg.category_group_id
        INNER JOIN dbo.TaxonomyDepartments td ON tcg.department_id = td.department_id
        WHERE vt.category = 'unspecified'
        AND NOT EXISTS (
            SELECT 1 FROM dbo.ProductionBrandCategoryOverride po
            WHERE po.brand_name = vt.brand
        );

        SET @UpdatedBrands = @@ROWCOUNT;

        PRINT 'Created brand category overrides for ' + CAST(@UpdatedBrands AS NVARCHAR(20)) + ' brands';
    END

    -- Calculate improvement potential
    SELECT @UpdatedTransactions = SUM(vt.txn_count)
    FROM v_xtab_time_brand_category_abs vt
    INNER JOIN dbo.BrandCategoryMapping bcm ON vt.brand = bcm.brand_name
    WHERE vt.category = 'unspecified';

    IF @LogResults = 1
    BEGIN
        PRINT '';
        PRINT 'IMPACT SUMMARY:';
        PRINT '==============';
        PRINT 'Brands with Nielsen mappings: ' + CAST(@UpdatedBrands AS NVARCHAR(20));
        PRINT 'Transactions that can be fixed: ' + CAST(@UpdatedTransactions AS NVARCHAR(20));
        PRINT 'Current unspecified rate: ' + CAST((@UnspecifiedBefore * 100.0 / (SELECT SUM(txn_count) FROM v_xtab_time_brand_category_abs)) AS NVARCHAR(10)) + '%';
        PRINT 'Potential unspecified rate: ' + CAST(((@UnspecifiedBefore - @UpdatedTransactions) * 100.0 / (SELECT SUM(txn_count) FROM v_xtab_time_brand_category_abs)) AS NVARCHAR(10)) + '%';
        PRINT 'Improvement: ' + CAST((@UpdatedTransactions * 100.0 / @UnspecifiedBefore) AS NVARCHAR(10)) + '% reduction in unspecified';
        PRINT '';

        IF @DryRun = 1
            PRINT 'DRY RUN COMPLETED - No changes made';
        ELSE
            PRINT 'LIVE EXECUTION COMPLETED - Changes applied';

        PRINT 'Completed: ' + CONVERT(NVARCHAR(30), GETDATE(), 120);
    END

    -- Return summary results
    SELECT
        @UpdatedBrands as brands_mapped,
        @UpdatedTransactions as transactions_improved,
        @UnspecifiedBefore as unspecified_before,
        (@UnspecifiedBefore - @UpdatedTransactions) as unspecified_after_potential,
        (@UpdatedTransactions * 100.0 / @UnspecifiedBefore) as improvement_percentage;
END
GO

PRINT 'sp_ApplyNielsenTaxonomyProduction procedure created successfully';