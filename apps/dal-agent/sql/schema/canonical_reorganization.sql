-- Canonical Schema Reorganization for Scout v7
-- Implements proper schema organization with canonical naming patterns
-- Created: 2025-09-26

-- =====================================================
-- SECTION 1: SCHEMA CREATION
-- =====================================================

-- Create canonical schemas if they don't exist
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'canonical')
    EXEC('CREATE SCHEMA canonical');

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'intel')
    EXEC('CREATE SCHEMA intel');

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'ref')
    EXEC('CREATE SCHEMA ref');

PRINT 'Canonical schemas created/verified';

-- =====================================================
-- SECTION 2: CANONICAL DIMENSION TABLES (dbo schema)
-- =====================================================

-- Standardized dimension tables in dbo schema
-- These should be the single source of truth for dimensional data

-- DimDate (if not exists)
IF NOT EXISTS (SELECT * FROM sys.objects WHERE name = 'DimDate' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.DimDate (
        DateKey INT PRIMARY KEY,
        FullDate DATE NOT NULL,
        DayOfWeek TINYINT NOT NULL,
        DayName NVARCHAR(10) NOT NULL,
        DayOfMonth TINYINT NOT NULL,
        DayOfYear SMALLINT NOT NULL,
        WeekOfYear TINYINT NOT NULL,
        MonthNumber TINYINT NOT NULL,
        MonthName NVARCHAR(10) NOT NULL,
        Quarter TINYINT NOT NULL,
        Year SMALLINT NOT NULL,
        IsWeekend BIT NOT NULL,
        IsHoliday BIT DEFAULT 0,

        INDEX IX_DimDate_FullDate (FullDate),
        INDEX IX_DimDate_Year_Month (Year, MonthNumber)
    );
    PRINT 'Created dbo.DimDate';
END

-- DimTime (if not exists)
IF NOT EXISTS (SELECT * FROM sys.objects WHERE name = 'DimTime' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.DimTime (
        TimeKey INT PRIMARY KEY,
        Time24H TIME NOT NULL,
        Hour24 TINYINT NOT NULL,
        Hour12 TINYINT NOT NULL,
        Minute TINYINT NOT NULL,
        Second TINYINT NOT NULL,
        AmPm CHAR(2) NOT NULL,
        Daypart NVARCHAR(20) NOT NULL, -- Morning, Afternoon, Evening, Night

        INDEX IX_DimTime_Hour (Hour24),
        INDEX IX_DimTime_Daypart (Daypart)
    );
    PRINT 'Created dbo.DimTime';
END

-- Ensure core dimension tables exist with proper naming
-- Region table (standardize name)
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'regions' AND schema_id = SCHEMA_ID('dbo'))
    AND NOT EXISTS (SELECT * FROM sys.objects WHERE name = 'Region' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    EXEC sp_rename 'dbo.regions', 'Region';
    PRINT 'Renamed dbo.regions to dbo.Region';
END

-- Province table (standardize name)
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'provinces' AND schema_id = SCHEMA_ID('dbo'))
    AND NOT EXISTS (SELECT * FROM sys.objects WHERE name = 'Province' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    EXEC sp_rename 'dbo.provinces', 'Province';
    PRINT 'Renamed dbo.provinces to dbo.Province';
END

-- Municipality table (standardize name)
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'municipalities' AND schema_id = SCHEMA_ID('dbo'))
    AND NOT EXISTS (SELECT * FROM sys.objects WHERE name = 'Municipality' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    EXEC sp_rename 'dbo.municipalities', 'Municipality';
    PRINT 'Renamed dbo.municipalities to dbo.Municipality';
END

-- Barangay table (standardize name and fix typos)
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'barangays' AND schema_id = SCHEMA_ID('dbo'))
    AND NOT EXISTS (SELECT * FROM sys.objects WHERE name = 'Barangay' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    EXEC sp_rename 'dbo.barangays', 'Barangay';
    PRINT 'Renamed dbo.barangays to dbo.Barangay';
END

-- Fix column name typo in Barangay if it exists
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Barangay') AND name = 'BaranggayName')
BEGIN
    EXEC sp_rename 'dbo.Barangay.BaranggayName', 'BarangayName', 'COLUMN';
    PRINT 'Fixed column name: BaranggayName -> BarangayName';
END

-- Stores table (ensure proper structure)
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'stores' AND schema_id = SCHEMA_ID('dbo'))
    AND NOT EXISTS (SELECT * FROM sys.objects WHERE name = 'Stores' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    EXEC sp_rename 'dbo.stores', 'Stores';
    PRINT 'Renamed dbo.stores to dbo.Stores';
END

-- Brands table (ensure proper structure)
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'brands' AND schema_id = SCHEMA_ID('dbo'))
    AND NOT EXISTS (SELECT * FROM sys.objects WHERE name = 'Brands' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    EXEC sp_rename 'dbo.brands', 'Brands';
    PRINT 'Renamed dbo.brands to dbo.Brands';
END

-- Products table (ensure proper structure)
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'products' AND schema_id = SCHEMA_ID('dbo'))
    AND NOT EXISTS (SELECT * FROM sys.objects WHERE name = 'Products' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    EXEC sp_rename 'dbo.products', 'Products';
    PRINT 'Renamed dbo.products to dbo.Products';
END

-- =====================================================
-- SECTION 3: CANONICAL FACT TABLES
-- =====================================================

-- SalesInteractionFact - The canonical fact table
-- This should be the single source of truth for all transaction/interaction data
IF NOT EXISTS (SELECT * FROM sys.objects WHERE name = 'SalesInteractionFact' AND schema_id = SCHEMA_ID('canonical'))
BEGIN
    CREATE TABLE canonical.SalesInteractionFact (
        InteractionID BIGINT IDENTITY(1,1) PRIMARY KEY,
        CanonicalTxID NVARCHAR(64) NOT NULL UNIQUE, -- The 13-column contract ID
        OriginalTransactionID NVARCHAR(64),

        -- Dimension keys
        StoreID INT,
        DateKey INT,
        TimeKey INT,
        BrandID INT,
        ProductID INT,
        CustomerID BIGINT,

        -- Measures
        TransactionValue DECIMAL(12,2),
        Quantity DECIMAL(10,3),
        ItemCount INT,
        BasketSize INT,
        UnitPrice DECIMAL(10,2),

        -- Customer demographics (denormalized for performance)
        CustomerGender NVARCHAR(10),
        CustomerAge TINYINT,
        CustomerFacialID NVARCHAR(64),

        -- Conversation intelligence
        ConversationDurationSeconds INT,
        SpeakerTurnsCustomer INT,
        SpeakerTurnsOwner INT,
        BrandsDiscussed INT,
        SuggestionAcceptanceRate DECIMAL(5,3),

        -- Enhanced payload (JSON)
        EnhancedPayload NVARCHAR(MAX),

        -- Audit fields
        SourceSystem NVARCHAR(50) DEFAULT 'Scout v7',
        CreatedDate DATETIME2 DEFAULT SYSUTCDATETIME(),
        UpdatedDate DATETIME2 DEFAULT SYSUTCDATETIME(),

        -- Indexes
        INDEX IX_SalesInteraction_CanonicalTxID (CanonicalTxID),
        INDEX IX_SalesInteraction_Store_Date (StoreID, DateKey),
        INDEX IX_SalesInteraction_Brand_Product (BrandID, ProductID),
        INDEX IX_SalesInteraction_Customer (CustomerID),
        INDEX IX_SalesInteraction_Date_Time (DateKey, TimeKey)
    );
    PRINT 'Created canonical.SalesInteractionFact';
END

-- =====================================================
-- SECTION 4: INTEL SCHEMA (DERIVED ANALYTICS)
-- =====================================================

-- Market basket analysis table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE name = 'BasketItems' AND schema_id = SCHEMA_ID('intel'))
BEGIN
    CREATE TABLE intel.BasketItems (
        BasketItemID BIGINT IDENTITY(1,1) PRIMARY KEY,
        CanonicalTxID NVARCHAR(64) NOT NULL,
        ItemSequence TINYINT NOT NULL,
        ProductID INT,
        BrandID INT,
        CategoryID INT,
        Quantity DECIMAL(10,3),
        ItemValue DECIMAL(12,2),
        Confidence DECIMAL(5,3),
        Source NVARCHAR(20) DEFAULT 'JSON_Extract',

        INDEX IX_BasketItems_TxID (CanonicalTxID),
        INDEX IX_BasketItems_Product (ProductID),
        INDEX IX_BasketItems_Brand (BrandID)
    );
    PRINT 'Created intel.BasketItems';
END

-- Substitution events table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE name = 'SubstitutionEvents' AND schema_id = SCHEMA_ID('intel'))
BEGIN
    CREATE TABLE intel.SubstitutionEvents (
        SubstitutionID BIGINT IDENTITY(1,1) PRIMARY KEY,
        CanonicalTxID NVARCHAR(64) NOT NULL,
        ItemSequence TINYINT NOT NULL,
        SwitchType NVARCHAR(20), -- brand_switch, category_switch, unavailable
        FromBrandID INT,
        ToBrandID INT,
        FromCategory NVARCHAR(100),
        ToCategory NVARCHAR(100),
        Reason NVARCHAR(200),
        Confidence DECIMAL(5,3),
        DetectionMethod NVARCHAR(50), -- conversation, inventory_check, pattern

        INDEX IX_Substitution_TxID (CanonicalTxID),
        INDEX IX_Substitution_Brands (FromBrandID, ToBrandID),
        INDEX IX_Substitution_Type (SwitchType)
    );
    PRINT 'Created intel.SubstitutionEvents';
END

-- =====================================================
-- SECTION 5: REF SCHEMA (REFERENCE DATA)
-- =====================================================

-- Nielsen category hierarchy
IF NOT EXISTS (SELECT * FROM sys.objects WHERE name = 'NielsenHierarchy' AND schema_id = SCHEMA_ID('ref'))
BEGIN
    CREATE TABLE ref.NielsenHierarchy (
        NielsenCategoryID NVARCHAR(50) PRIMARY KEY,
        CategoryName NVARCHAR(200) NOT NULL,
        CategoryPrefix NVARCHAR(10),
        ParentCategoryID NVARCHAR(50),
        HierarchyLevel TINYINT DEFAULT 1,
        TotalBrands INT DEFAULT 0,
        IsActive BIT DEFAULT 1,

        INDEX IX_Nielsen_Parent (ParentCategoryID),
        INDEX IX_Nielsen_Level (HierarchyLevel)
    );
    PRINT 'Created ref.NielsenHierarchy';
END

-- Persona rules for customer segmentation
IF NOT EXISTS (SELECT * FROM sys.objects WHERE name = 'PersonaRules' AND schema_id = SCHEMA_ID('ref'))
BEGIN
    CREATE TABLE ref.PersonaRules (
        RuleID INT IDENTITY(1,1) PRIMARY KEY,
        PersonaName NVARCHAR(50) NOT NULL,
        RuleType NVARCHAR(30), -- demographic, behavioral, purchase_pattern
        Condition NVARCHAR(500), -- SQL-like condition
        Weight DECIMAL(5,3) DEFAULT 1.0,
        IsActive BIT DEFAULT 1,

        INDEX IX_PersonaRules_Persona (PersonaName),
        INDEX IX_PersonaRules_Type (RuleType)
    );
    PRINT 'Created ref.PersonaRules';
END

-- =====================================================
-- SECTION 6: CANONICAL CONTRACT VIEW
-- =====================================================

-- The 13-column contract view - this is the external interface
CREATE OR ALTER VIEW canonical.v_export_canonical_13col AS
SELECT
    sif.CanonicalTxID AS [Transaction_ID],
    s.StoreName AS [Store_Name],
    r.RegionName AS [Region],
    sif.TransactionValue AS [Amount],
    dt.FullDate AS [Date],
    CASE
        WHEN dt24.Hour24 BETWEEN 6 AND 11 THEN 'Morning'
        WHEN dt24.Hour24 BETWEEN 12 AND 17 THEN 'Afternoon'
        WHEN dt24.Hour24 BETWEEN 18 AND 23 THEN 'Evening'
        ELSE 'Night'
    END AS [Daypart],
    sif.BasketSize AS [Basket_Size],
    COALESCE(nh.CategoryName, 'Unknown') AS [Category],
    b.BrandName AS [Brand],
    p.ProductName AS [Product],
    CONCAT(sif.CustomerGender, ' ', sif.CustomerAge) AS [Demographics (Age/Gender/Role)],
    sif.Quantity AS [Quantity],
    sif.EnhancedPayload AS [Enhanced_Payload]
FROM canonical.SalesInteractionFact sif
    LEFT JOIN dbo.Stores s ON sif.StoreID = s.StoreID
    LEFT JOIN dbo.Region r ON s.RegionID = r.RegionID
    LEFT JOIN dbo.DimDate dt ON sif.DateKey = dt.DateKey
    LEFT JOIN dbo.DimTime dt24 ON sif.TimeKey = dt24.TimeKey
    LEFT JOIN dbo.Brands b ON sif.BrandID = b.BrandID
    LEFT JOIN dbo.Products p ON sif.ProductID = p.ProductID
    LEFT JOIN ref.NielsenHierarchy nh ON b.CategoryID = nh.NielsenCategoryID
WHERE sif.InteractionID IS NOT NULL;

PRINT 'Created canonical.v_export_canonical_13col view';

-- =====================================================
-- SECTION 7: INTEL ANALYTICS VIEWS
-- =====================================================

-- Market basket pairs view
CREATE OR ALTER VIEW intel.v_basket_pairs AS
SELECT
    bi1.CanonicalTxID,
    b1.BrandName AS Item1_Brand,
    b2.BrandName AS Item2_Brand,
    nh1.CategoryName AS Item1_Category,
    nh2.CategoryName AS Item2_Category,

    -- Support calculations
    COUNT(*) OVER() AS total_transactions,
    COUNT(*) AS co_occurrence_count,

    -- Confidence and lift (simplified)
    CAST(COUNT(*) * 100.0 / COUNT(*) OVER() AS DECIMAL(5,2)) AS support_pct
FROM intel.BasketItems bi1
    INNER JOIN intel.BasketItems bi2 ON bi1.CanonicalTxID = bi2.CanonicalTxID AND bi1.ItemSequence < bi2.ItemSequence
    LEFT JOIN dbo.Brands b1 ON bi1.BrandID = b1.BrandID
    LEFT JOIN dbo.Brands b2 ON bi2.BrandID = b2.BrandID
    LEFT JOIN ref.NielsenHierarchy nh1 ON b1.CategoryID = nh1.NielsenCategoryID
    LEFT JOIN ref.NielsenHierarchy nh2 ON b2.CategoryID = nh2.NielsenCategoryID
WHERE bi1.BrandID != bi2.BrandID;

PRINT 'Created intel.v_basket_pairs view';

-- Substitution summary view
CREATE OR ALTER VIEW intel.v_substitution_summary AS
SELECT
    se.SwitchType,
    fb.BrandName AS FromBrand,
    tb.BrandName AS ToBrand,
    fnh.CategoryName AS FromCategory,
    tnh.CategoryName AS ToCategory,
    COUNT(*) AS SubstitutionCount,
    AVG(se.Confidence) AS AvgConfidence,
    se.Reason AS CommonReason
FROM intel.SubstitutionEvents se
    LEFT JOIN dbo.Brands fb ON se.FromBrandID = fb.BrandID
    LEFT JOIN dbo.Brands tb ON se.ToBrandID = tb.BrandID
    LEFT JOIN ref.NielsenHierarchy fnh ON fb.CategoryID = fnh.NielsenCategoryID
    LEFT JOIN ref.NielsenHierarchy tnh ON tb.CategoryID = tnh.NielsenCategoryID
GROUP BY se.SwitchType, fb.BrandName, tb.BrandName, fnh.CategoryName, tnh.CategoryName, se.Reason;

PRINT 'Created intel.v_substitution_summary view';

-- =====================================================
-- SECTION 8: DATA MIGRATION RECOMMENDATIONS
-- =====================================================

PRINT '========================================';
PRINT 'CANONICAL SCHEMA REORGANIZATION COMPLETE';
PRINT '========================================';
PRINT '';
PRINT 'NEXT STEPS FOR DATA MIGRATION:';
PRINT '';
PRINT '1. Migrate existing transaction data to canonical.SalesInteractionFact';
PRINT '2. Extract basket items from JSON payloads to intel.BasketItems';
PRINT '3. Detect and populate substitution events in intel.SubstitutionEvents';
PRINT '4. Update foreign key references to use new canonical structure';
PRINT '5. Create stored procedures for ongoing ETL processes';
PRINT '';
PRINT 'SCHEMA STRUCTURE:';
PRINT '- dbo: Dimension tables (Stores, Brands, Products, Region, etc.)';
PRINT '- canonical: Fact tables and contract views';
PRINT '- intel: Derived analytics (baskets, substitutions)';
PRINT '- ref: Reference data (Nielsen hierarchy, persona rules)';
PRINT '';
PRINT 'Use the following commands to proceed:';
PRINT '- make schema-inventory  (document current state)';
PRINT '- make erd              (visualize relationships)';
PRINT '- make analytics-comprehensive (test with new structure)';