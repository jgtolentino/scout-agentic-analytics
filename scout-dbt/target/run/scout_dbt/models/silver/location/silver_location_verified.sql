
      
  
    USE [SQL-TBWA-ProjectScout-Reporting-Prod];
    USE [SQL-TBWA-ProjectScout-Reporting-Prod];
    
    

    

    
    USE [SQL-TBWA-ProjectScout-Reporting-Prod];
    EXEC('
        create view "dbo"."silver_location_verified__dbt_tmp_vw" as 

WITH source_data AS (
    SELECT
        canonical_id as transaction_id,
        store_id,
        transaction_date,
        municipality,
        barangay,
        CAST(latitude AS DECIMAL(10,7)) as geo_latitude,
        CAST(longitude AS DECIMAL(10,7)) as geo_longitude,
        CASE
    WHEN latitude IS NULL OR longitude IS NULL THEN 0
    WHEN latitude < 14.2 OR latitude > 14.9 THEN 0
    WHEN longitude < 120.9 OR longitude > 121.2 THEN 0
    ELSE 1
  END as coordinates_valid,
        data_source,
        loaded_at
    FROM "SQL-TBWA-ProjectScout-Reporting-Prod"."bronze"."bronze_transactions"

    
),

verified AS (
    SELECT
        s.*,
        d.store_name,
        d.region,
        d.province,
        d.psgc_region,
        d.psgc_citymun,
        d.psgc_barangay,
        CASE
            WHEN d.store_id IS NOT NULL THEN
                1
            ELSE
                0
        END as location_verified
    FROM source_data s
    LEFT JOIN "SQL-TBWA-ProjectScout-Reporting-Prod"."bronze"."dim_stores_ncr" d
        ON s.store_id = d.store_id
)

SELECT
    transaction_id,
    store_id,
    store_name,
    transaction_date,
    municipality,
    barangay,
    geo_latitude,
    geo_longitude,
    coordinates_valid,
    location_verified,
    region,
    province,
    psgc_region,
    psgc_citymun,
    psgc_barangay,
    data_source,
    SYSDATETIMEOFFSET() as processed_at
FROM verified;
    ')

EXEC('
            SELECT * INTO "SQL-TBWA-ProjectScout-Reporting-Prod"."dbo"."silver_location_verified" FROM "SQL-TBWA-ProjectScout-Reporting-Prod"."dbo"."silver_location_verified__dbt_tmp_vw" 
    OPTION (LABEL = ''dbt-sqlserver'');

        ')

    
    EXEC('DROP VIEW IF EXISTS dbo.silver_location_verified__dbt_tmp_vw')



    
    use [SQL-TBWA-ProjectScout-Reporting-Prod];
    if EXISTS (
        SELECT *
        FROM sys.indexes with (nolock)
        WHERE name = 'dbo_silver_location_verified_cci'
        AND object_id=object_id('dbo_silver_location_verified')
    )
    DROP index "dbo"."silver_location_verified".dbo_silver_location_verified_cci
    CREATE CLUSTERED COLUMNSTORE INDEX dbo_silver_location_verified_cci
    ON "dbo"."silver_location_verified"

   


  
  