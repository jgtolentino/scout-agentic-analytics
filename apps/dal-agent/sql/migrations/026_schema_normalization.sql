-- 026_schema_normalization.sql
-- Schema improvements: persona_rules integration, canonical fact table, Time/Date dimensions
-- Author: Claude Code SuperClaude
-- Date: 2025-09-26
-- SURGICAL FIXES: Atomic, idempotent, set-based, production-ready
-- PRESERVES: Existing dbo.SalesInteractions table structure

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON; -- Hard stop & rollback on any error
GO

BEGIN TRANSACTION SchemaEnhancement
BEGIN TRY

    PRINT 'Starting schema normalization with surgical fixes (preserving SalesInteractions)...'

    -- ===========================================
    -- 1. CREATE SCHEMAS SAFELY
    -- ===========================================

    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'canonical')
        EXEC('CREATE SCHEMA canonical');
    IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ref')
        EXEC('CREATE SCHEMA ref');

    PRINT 'Schemas canonical and ref verified/created.'

    -- ===========================================
    -- 2. CREATE TIME/DATE DIMENSIONS (SET-BASED, IDEMPOTENT)
    -- ===========================================

    PRINT 'Creating DimDate table with set-based population...'

    -- Date Dimension with locale-safe weekend calculation
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='DimDate' AND schema_id=SCHEMA_ID('dbo'))
    BEGIN
        CREATE TABLE dbo.DimDate(
            date_key INT IDENTITY(1,1) PRIMARY KEY,
            full_date DATE NOT NULL UNIQUE,
            year_number SMALLINT NOT NULL,
            month_number TINYINT NOT NULL,
            month_name VARCHAR(20) NOT NULL,
            day_number TINYINT NOT NULL,
            day_name VARCHAR(20) NOT NULL,
            day_of_week TINYINT NOT NULL,
            day_of_year SMALLINT NOT NULL,
            iso_week TINYINT NOT NULL,
            quarter_number TINYINT NOT NULL,
            quarter_name VARCHAR(6) NOT NULL,
            is_weekend BIT NOT NULL,
            weekday_vs_weekend VARCHAR(10) NOT NULL,
            fiscal_year SMALLINT NULL,
            fiscal_quarter TINYINT NULL,
            created_date DATETIME2 DEFAULT SYSUTCDATETIME()
        );
        CREATE UNIQUE INDEX UX_DimDate_full_date ON dbo.DimDate(full_date);
        PRINT 'DimDate table created with unique index.'
    END;

    -- Set-based population (2020-2030) with duplicate prevention
    WITH d AS (
        SELECT CAST('2020-01-01' AS DATE) AS d
        UNION ALL
        SELECT DATEADD(DAY,1,d) FROM d WHERE d < '2030-12-31'
    )
    INSERT INTO dbo.DimDate(
        full_date, year_number, month_number, month_name,
        day_number, day_name, day_of_week, day_of_year,
        iso_week, quarter_number, quarter_name,
        is_weekend, weekday_vs_weekend
    )
    SELECT
        d,
        YEAR(d),
        MONTH(d),
        DATENAME(MONTH,d),
        DAY(d),
        DATENAME(WEEKDAY,d),
        DATEPART(WEEKDAY,d),
        DATEPART(DAYOFYEAR,d),
        DATEPART(ISO_WEEK,d),
        DATEPART(QUARTER,d),
        CONCAT('Q',DATEPART(QUARTER,d)),
        -- Locale-safe weekend calculation
        IIF(((DATEPART(WEEKDAY,d)+@@DATEFIRST-1)%7) IN (0,6),1,0),
        IIF(((DATEPART(WEEKDAY,d)+@@DATEFIRST-1)%7) IN (0,6),'Weekend','Weekday')
    FROM d
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimDate x WHERE x.full_date=d)
    OPTION (MAXRECURSION 32767);

    PRINT 'DimDate populated: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' records added.'

    PRINT 'Creating DimTime table with set-based population...'

    -- Time Dimension (every minute)
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='DimTime' AND schema_id=SCHEMA_ID('dbo'))
    BEGIN
        CREATE TABLE dbo.DimTime(
            time_key INT IDENTITY(1,1) PRIMARY KEY,
            time_24h TIME NOT NULL UNIQUE,
            time_12h VARCHAR(11) NOT NULL,
            hour_24 TINYINT NOT NULL,
            hour_12 TINYINT NOT NULL,
            minute_number TINYINT NOT NULL,
            second_number TINYINT NOT NULL,
            am_pm VARCHAR(2) NOT NULL,
            daypart VARCHAR(20) NOT NULL,
            business_hour BIT NOT NULL,
            rush_hour BIT NOT NULL,
            created_date DATETIME2 DEFAULT SYSUTCDATETIME()
        );
        CREATE UNIQUE INDEX UX_DimTime_time_24h ON dbo.DimTime(time_24h);
        PRINT 'DimTime table created with unique index.'
    END;

    -- Set-based population (every minute of day)
    WITH t AS (SELECT TOP (1440) ROW_NUMBER() OVER(ORDER BY (SELECT 1))-1 AS m FROM sys.all_objects)
    INSERT INTO dbo.DimTime(
        time_24h, time_12h, hour_24, hour_12,
        minute_number, second_number, am_pm, daypart,
        business_hour, rush_hour
    )
    SELECT
        CAST(DATEADD(MINUTE,m,'00:00:00') AS TIME),
        CONVERT(VARCHAR(11), DATEADD(MINUTE,m,'19000101'), 0),
        DATEPART(HOUR, DATEADD(MINUTE,m,'00:00:00')),
        IIF(DATEPART(HOUR,DATEADD(MINUTE,m,'00:00:00')) IN (0,12),12, DATEPART(HOUR,DATEADD(MINUTE,m,'00:00:00')) % 12),
        DATEPART(MINUTE, DATEADD(MINUTE,m,'00:00:00')),
        0,
        IIF(DATEPART(HOUR,DATEADD(MINUTE,m,'00:00:00'))<12,'AM','PM'),
        CASE WHEN DATEPART(HOUR,DATEADD(MINUTE,m,'00:00:00')) BETWEEN 5 AND 11 THEN 'Morning'
             WHEN DATEPART(HOUR,DATEADD(MINUTE,m,'00:00:00')) BETWEEN 12 AND 16 THEN 'Afternoon'
             WHEN DATEPART(HOUR,DATEADD(MINUTE,m,'00:00:00')) BETWEEN 17 AND 20 THEN 'Evening'
             ELSE 'Night' END,
        IIF(DATEPART(HOUR,DATEADD(MINUTE,m,'00:00:00')) BETWEEN 9 AND 17,1,0),
        IIF(DATEPART(HOUR,DATEADD(MINUTE,m,'00:00:00')) BETWEEN 7 AND 9 OR DATEPART(HOUR,DATEADD(MINUTE,m,'00:00:00')) BETWEEN 17 AND 19,1,0)
    FROM t
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.DimTime x
        WHERE x.time_24h = CAST(DATEADD(MINUTE,m,'00:00:00') AS TIME)
    );

    PRINT 'DimTime populated: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' records added.'

    -- ===========================================
    -- 3. ENSURE PERSONA_RULES TABLE EXISTS
    -- ===========================================

    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='persona_rules' AND schema_id=SCHEMA_ID('ref'))
    BEGIN
        PRINT 'Creating ref.persona_rules table...'

        CREATE TABLE ref.persona_rules (
            rule_id INT IDENTITY(1,1) PRIMARY KEY,
            role_name VARCHAR(100) NOT NULL,
            priority TINYINT NOT NULL DEFAULT 100,
            include_terms NVARCHAR(500) NULL,
            exclude_terms NVARCHAR(500) NULL,
            must_have_categories NVARCHAR(500) NULL,
            must_have_brands NVARCHAR(500) NULL,
            daypart_in VARCHAR(100) NULL,
            hour_min TINYINT NULL,
            hour_max TINYINT NULL,
            min_items INT NULL,
            min_age TINYINT NULL,
            max_age TINYINT NULL,
            gender_in VARCHAR(50) NULL,
            notes NVARCHAR(1000) NULL,
            created_date DATETIME2 DEFAULT SYSUTCDATETIME(),
            is_active BIT DEFAULT 1,
            active_hours VARCHAR(100) NULL,
            required_groups VARCHAR(200) NULL
        );

        -- Insert default persona rules
        INSERT INTO ref.persona_rules (role_name, priority, min_age, max_age, gender_in, notes)
        VALUES
            ('General Consumer', 100, NULL, NULL, NULL, 'Default persona for unmatched interactions'),
            ('Young Adult Male', 10, 18, 35, 'Male,M', 'Young adult male shoppers'),
            ('Young Adult Female', 10, 18, 35, 'Female,F', 'Young adult female shoppers'),
            ('Middle Age Consumer', 20, 36, 55, NULL, 'Middle-aged shoppers'),
            ('Senior Consumer', 30, 56, NULL, NULL, 'Senior shoppers');

        PRINT 'ref.persona_rules created with 5 default rules.'
    END;

    -- ===========================================
    -- 4. CREATE CANONICAL INTERACTION FACT TABLE
    -- ===========================================

    PRINT 'Creating canonical SalesInteractionFact table...'

    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='SalesInteractionFact' AND schema_id=SCHEMA_ID('canonical'))
    BEGIN
        CREATE TABLE canonical.SalesInteractionFact (
            interaction_id NVARCHAR(64) PRIMARY KEY,      -- Safer length for GUIDs
            store_id INT NULL,
            product_id INT NULL,
            customer_id NVARCHAR(100) NULL,               -- facial_id
            transaction_date DATE NULL,
            transaction_time TIME NULL,
            date_key INT NULL,
            time_key INT NULL,
            device_id NVARCHAR(100) NULL,
            age TINYINT NULL,
            gender NVARCHAR(20) NULL,                     -- Consistent NVARCHAR
            emotional_state NVARCHAR(50) NULL,
            transcription_text NVARCHAR(MAX) NULL,
            barangay_id INT NULL,
            canonical_tx_id_norm NVARCHAR(100) NULL,
            canonical_tx_id NVARCHAR(64) NULL,            -- Safer length
            persona_rule_id INT NULL,
            assigned_persona NVARCHAR(100) NULL,
            created_date DATETIME2 DEFAULT SYSUTCDATETIME(),

            -- Foreign Keys
            CONSTRAINT FK_SIF_DimDate FOREIGN KEY (date_key) REFERENCES dbo.DimDate(date_key),
            CONSTRAINT FK_SIF_DimTime FOREIGN KEY (time_key) REFERENCES dbo.DimTime(time_key),
            CONSTRAINT FK_SIF_PersonaRules FOREIGN KEY (persona_rule_id) REFERENCES ref.persona_rules(rule_id)
        );

        -- Performance indexes
        CREATE INDEX IX_SIF_store_date ON canonical.SalesInteractionFact(store_id, date_key);
        CREATE INDEX IX_SIF_persona ON canonical.SalesInteractionFact(persona_rule_id);
        CREATE INDEX IX_SIF_customer_date ON canonical.SalesInteractionFact(customer_id, date_key);
        CREATE INDEX IX_SIF_txid ON canonical.SalesInteractionFact(canonical_tx_id) WHERE canonical_tx_id IS NOT NULL;

        PRINT 'canonical.SalesInteractionFact created with performance indexes.'
    END;

    -- ===========================================
    -- 5. MIGRATE DATA FROM EXISTING SALESINTERACTIONS (IDEMPOTENT)
    -- ===========================================

    PRINT 'Migrating data from dbo.SalesInteractions to canonical fact table (idempotent)...'

    -- Idempotent insert with dimension lookups
    INSERT INTO canonical.SalesInteractionFact (
        interaction_id, store_id, product_id, customer_id,
        transaction_date, transaction_time, date_key, time_key,
        device_id, age, gender, emotional_state, transcription_text,
        barangay_id, canonical_tx_id_norm, canonical_tx_id
    )
    SELECT
        si.InteractionID,
        si.StoreID,
        si.ProductID,
        si.FacialID,
        CAST(si.TransactionDate AS DATE),
        CAST(si.TransactionDate AS TIME),
        dd.date_key,
        dt.time_key,
        si.DeviceID,
        si.Age,
        si.Gender,
        si.EmotionalState,
        si.TranscriptionText,
        si.Barangay,
        si.canonical_tx_id_norm,
        si.canonical_tx_id
    FROM dbo.SalesInteractions si
    LEFT JOIN dbo.DimDate dd ON dd.full_date = CAST(si.TransactionDate AS DATE)
    LEFT JOIN dbo.DimTime dt ON dt.time_24h = CAST(si.TransactionDate AS TIME)
    WHERE si.InteractionID IS NOT NULL
      AND NOT EXISTS (
            SELECT 1 FROM canonical.SalesInteractionFact x
            WHERE x.interaction_id = si.InteractionID
        );

    PRINT 'Migrated ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' interactions to canonical fact table.'

    -- ===========================================
    -- 6. CREATE ROBUST PERSONA ASSIGNMENT PROCEDURE
    -- ===========================================

    PRINT 'Creating robust persona assignment procedure...'

    EXEC('
    CREATE OR ALTER PROCEDURE canonical.sp_assign_personas
    AS
    BEGIN
        SET NOCOUNT ON;

        DECLARE @assigned_count INT = 0;

        -- Update persona assignments with robust gender/time matching
        UPDATE S
        SET persona_rule_id = P.rule_id,
            assigned_persona = P.role_name
        FROM canonical.SalesInteractionFact S
        CROSS APPLY (
            SELECT TOP 1 pr.rule_id, pr.role_name
            FROM ref.persona_rules pr
            OUTER APPLY (
                SELECT LTRIM(RTRIM(value)) AS g
                FROM STRING_SPLIT(COALESCE(pr.gender_in,''''), '','')
                WHERE LTRIM(RTRIM(value)) != ''''
            ) g
            WHERE pr.is_active = 1
              AND (pr.min_age IS NULL OR S.age >= pr.min_age)
              AND (pr.max_age IS NULL OR S.age <= pr.max_age)
              AND (
                   pr.gender_in IS NULL OR pr.gender_in = '''' OR
                   LOWER(LTRIM(RTRIM(S.gender))) IN (SELECT LOWER(g.g))
              )
              AND (
                   pr.hour_min IS NULL OR pr.hour_max IS NULL OR
                   (pr.hour_min <= pr.hour_max AND DATEPART(HOUR, S.transaction_time) BETWEEN pr.hour_min AND pr.hour_max) OR
                   (pr.hour_min > pr.hour_max AND (DATEPART(HOUR, S.transaction_time) >= pr.hour_min OR DATEPART(HOUR, S.transaction_time) <= pr.hour_max))
              )
            ORDER BY pr.priority ASC
        ) P
        WHERE S.persona_rule_id IS NULL;

        SET @assigned_count = @@ROWCOUNT;
        PRINT ''Assigned personas to '' + CAST(@assigned_count AS VARCHAR(10)) + '' interactions'';
    END
    ');

    -- Run initial persona assignment
    EXEC canonical.sp_assign_personas;

    -- ===========================================
    -- 7. CREATE ENHANCED CANONICAL EXPORT VIEW (13 COLUMNS)
    -- ===========================================

    PRINT 'Creating enhanced canonical export view (13 columns)...'

    EXEC('
    CREATE OR ALTER VIEW canonical.v_export_canonical_enhanced
    AS
    SELECT
        S.canonical_tx_id                       AS Transaction_ID,
        COALESCE(T.transaction_amount, 0.00)    AS Transaction_Value,   -- TODO: wire actual source
        COALESCE(T.basket_item_count, 1)        AS Basket_Size,         -- TODO: wire actual source
        COALESCE(P.Category, N''unspecified'')  AS Category,
        COALESCE(B.BrandName, N''Unknown'')     AS Brand,
        COALESCE(DT.daypart, N''Unknown'')      AS Daypart,
        CONCAT(
            ISNULL(CAST(S.age AS VARCHAR(3)), N''??''), N''/'',
            ISNULL(S.gender, N''Unknown''), N''/'',
            ISNULL(S.assigned_persona, N''General'')
        )                                       AS Demographics_Age_Gender_Role,
        COALESCE(DD.weekday_vs_weekend, N''Unknown'') AS Weekday_vs_Weekend,
        ISNULL(FORMAT(S.transaction_time, N''HH:mm:ss''), N''Unknown'') AS Time_of_Transaction,
        COALESCE(St.Location, N''Unknown Location'') AS Location,
        N''''                                   AS Other_Products,  -- TODO: basket analysis
        N''N''                                  AS Was_Substitution, -- TODO: substitution logic
        S.created_date                          AS Export_Timestamp
    FROM canonical.SalesInteractionFact S
    LEFT JOIN dbo.DimDate   DD ON S.date_key = DD.date_key
    LEFT JOIN dbo.DimTime   DT ON S.time_key = DT.time_key
    LEFT JOIN dbo.Products  P  ON S.product_id = P.ProductID
    LEFT JOIN dbo.Brands    B  ON P.BrandID = B.BrandID
    LEFT JOIN dbo.Stores    St ON S.store_id = St.StoreID
    LEFT JOIN (
        -- Placeholder for transaction projection - replace with actual view when available
        SELECT canonical_tx_id, 0.00 AS transaction_amount, 1 AS basket_item_count
        WHERE 1=0
    ) T ON T.canonical_tx_id = S.canonical_tx_id
    WHERE S.canonical_tx_id IS NOT NULL
    ');

    -- ===========================================
    -- 8. CREATE MIGRATION STATUS TRACKING
    -- ===========================================

    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='schema_migrations' AND schema_id=SCHEMA_ID('dbo'))
    BEGIN
        CREATE TABLE dbo.schema_migrations (
            migration_id VARCHAR(50) PRIMARY KEY,
            migration_name VARCHAR(200) NOT NULL,
            applied_date DATETIME2 DEFAULT SYSUTCDATETIME(),
            success BIT DEFAULT 1,
            notes NVARCHAR(MAX) NULL
        );
    END;

    -- Record this migration
    INSERT INTO dbo.schema_migrations (migration_id, migration_name, notes)
    VALUES (
        '026_schema_normalization',
        'Schema improvements: persona_rules integration, canonical fact table, time/date dimensions',
        'Created DimDate, DimTime, canonical.SalesInteractionFact with persona_rules integration. Applied surgical fixes: atomic, idempotent, set-based population. Preserves existing dbo.SalesInteractions.'
    );

    COMMIT TRANSACTION SchemaEnhancement
    PRINT '✅ Schema normalization completed successfully!'

END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION SchemaEnhancement

    PRINT '❌ Error occurred during schema migration:'
    PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(10))
    PRINT 'Error Message: ' + ERROR_MESSAGE()
    PRINT 'Error Line: ' + CAST(ERROR_LINE() AS VARCHAR(10))

    RAISERROR('Schema migration failed', 16, 1);
END CATCH
GO

-- ===========================================
-- 9. POST-MIGRATION VALIDATION (SMOKE CHECKS)
-- ===========================================

PRINT '🔍 Running post-migration validation...'

-- Row counts validation
SELECT 'DimDate' AS table_name, COUNT(*) AS row_count FROM dbo.DimDate
UNION ALL
SELECT 'DimTime', COUNT(*) FROM dbo.DimTime
UNION ALL
SELECT 'SalesInteractionFact', COUNT(*) FROM canonical.SalesInteractionFact
UNION ALL
SELECT 'SalesInteractions (original)', COUNT(*) FROM dbo.SalesInteractions;

-- 13 columns check for export view
DECLARE @column_count INT
SELECT @column_count = COUNT(*)
FROM sys.columns
WHERE object_id = OBJECT_ID('canonical.v_export_canonical_enhanced');

PRINT 'Export view has ' + CAST(@column_count AS VARCHAR(10)) + ' columns (expected: 13)'

-- Persona assignment validation
SELECT
    ISNULL(assigned_persona, 'Unassigned') AS persona,
    COUNT(*) AS interaction_count,
    AVG(CAST(age AS FLOAT)) AS avg_age
FROM canonical.SalesInteractionFact
GROUP BY assigned_persona
ORDER BY interaction_count DESC;

-- Sample export data validation
PRINT 'Sample export data (first 3 rows):'
SELECT TOP 3 * FROM canonical.v_export_canonical_enhanced;

PRINT '✅ Post-migration validation completed!'
PRINT ''
PRINT '📋 Next Steps:'
PRINT '1. Test 13-column export: SELECT TOP 10 * FROM canonical.v_export_canonical_enhanced'
PRINT '2. Reassign personas: EXEC canonical.sp_assign_personas'
PRINT '3. Wire Transaction_Value and Basket_Size (marked TODO in view)'
PRINT '4. Run inquiries export using new canonical view'