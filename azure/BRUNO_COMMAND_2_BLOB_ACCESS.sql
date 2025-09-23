-- ===================================================================
-- BRUNO COMMAND 2: BLOB STORAGE ACCESS CONFIGURATION
-- Execute this second in Bruno AFTER updating the SAS token
-- ===================================================================

PRINT '🔗 Configuring Azure Blob Storage Access...';

-- IMPORTANT: Replace 'YOUR_SAS_TOKEN_HERE' with actual SAS token
-- Format: ?sv=2022-11-02&ss=bfqt&srt=sco&sp=rwdlacupyx&se=2025-12-31T23:59:59Z&st=...
-- Get from: Azure Portal > Storage Account > Shared access signature

IF NOT EXISTS (SELECT 1 FROM sys.database_scoped_credentials WHERE name='SCOUT_BLOB_SAS')
BEGIN
    CREATE DATABASE SCOPED CREDENTIAL SCOUT_BLOB_SAS
    WITH IDENTITY='SHARED ACCESS SIGNATURE',
         SECRET='?sv=2022-11-02&ss=bfqt&srt=sco&sp=rwdlacupyx&se=2025-12-31T23:59:59Z&st=2025-01-01T00:00:00Z&spr=https&sig=working_token_from_upload';
    PRINT '✅ Database scoped credential created';
END
ELSE
    PRINT 'ℹ️ Database scoped credential already exists';

-- External data source to the storage account (container root)
IF NOT EXISTS (SELECT 1 FROM sys.external_data_sources WHERE name='SCOUT_BLOB')
BEGIN
    CREATE EXTERNAL DATA SOURCE SCOUT_BLOB
    WITH ( TYPE = BLOB_STORAGE,
           LOCATION = 'https://projectscoutautoregstr.blob.core.windows.net',
           CREDENTIAL = SCOUT_BLOB_SAS );
    PRINT '✅ External data source created';
END
ELSE
    PRINT 'ℹ️ External data source already exists';

-- Test blob access (verify CSV file exists)
BEGIN TRY
    DECLARE @test_query nvarchar(max) = N'
    SELECT TOP 1 1 as test_result
    FROM OPENROWSET(
        BULK ''gdrive-scout-ingest/out/stores_enriched_with_polygons.csv'',
        DATA_SOURCE = ''SCOUT_BLOB'',
        FORMAT = ''CSV'',
        PARSER_VERSION = ''2.0'',
        FIRSTROW = 1
    ) WITH (
        [StoreID] varchar(32)
    ) AS test_src;';

    EXEC sp_executesql @test_query;
    PRINT '✅ Blob access verified - CSV file found and readable';
END TRY
BEGIN CATCH
    PRINT '⚠️ Blob access test failed - check SAS token and file path';
    PRINT 'Error: ' + ERROR_MESSAGE();
END CATCH;

-- Verify configuration
SELECT
    'SCOUT_BLOB_SAS' as credential_name,
    CASE WHEN EXISTS (SELECT 1 FROM sys.database_scoped_credentials WHERE name='SCOUT_BLOB_SAS')
         THEN 'EXISTS' ELSE 'MISSING' END as credential_status;

SELECT
    'SCOUT_BLOB' as data_source_name,
    CASE WHEN EXISTS (SELECT 1 FROM sys.external_data_sources WHERE name='SCOUT_BLOB')
         THEN 'EXISTS' ELSE 'MISSING' END as data_source_status;

PRINT '';
PRINT '🎯 BLOB ACCESS CONFIGURED!';
PRINT 'Next: Execute BRUNO_COMMAND_3_STORED_PROCEDURE.sql';
PRINT '';

-- ===================================================================
-- MANUAL SAS TOKEN CONFIGURATION INSTRUCTIONS
-- ===================================================================
/*
TO GET YOUR SAS TOKEN:

1. Go to Azure Portal > Storage Accounts > projectscoutautoregstr
2. Click "Shared access signature" in left menu
3. Configure:
   - Allowed services: ✓ Blob
   - Allowed resource types: ✓ Container ✓ Object
   - Allowed permissions: ✓ Read
   - Start time: Current date/time
   - Expiry time: Future date (e.g., 1 year)
   - HTTPS only: ✓
4. Click "Generate SAS and connection string"
5. Copy the "SAS token" (starts with ?sv=...)
6. Replace 'YOUR_SIGNATURE_HERE' in the SECRET above with the full token

EXAMPLE:
SECRET='?sv=2022-11-02&ss=b&srt=co&sp=r&se=2025-12-31T23:59:59Z&st=2025-01-01T00:00:00Z&spr=https&sig=abcd1234...'
*/