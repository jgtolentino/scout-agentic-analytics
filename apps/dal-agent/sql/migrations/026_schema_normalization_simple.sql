-- 026_schema_normalization_simple.sql
-- Schema improvements: Time/Date dimensions and canonical fact table
-- Incremental approach with proper error handling

-- Step 1: Create schemas
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'canonical')
    EXEC('CREATE SCHEMA canonical');

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ref')
    EXEC('CREATE SCHEMA ref');

PRINT 'Schemas created/verified: canonical, ref';

-- Step 2: Create DimDate
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
        created_date DATETIME2 DEFAULT SYSUTCDATETIME()
    );

    CREATE UNIQUE INDEX UX_DimDate_full_date ON dbo.DimDate(full_date);
    PRINT 'DimDate table created with unique index';
END;

-- Step 3: Create DimTime
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
    PRINT 'DimTime table created with unique index';
END;

PRINT 'Dimension tables ready for population';