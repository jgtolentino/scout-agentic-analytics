
  
    USE [SQL-TBWA-ProjectScout-Reporting-Prod];
    USE [SQL-TBWA-ProjectScout-Reporting-Prod];
    
    

    

    
    USE [SQL-TBWA-ProjectScout-Reporting-Prod];
    EXEC('
        create view "bronze"."dim_stores_ncr__dbt_tmp__dbt_tmp_vw" as 

SELECT
    store_id,
    store_name,
    region,
    province,
    municipality,
    barangay,
    psgc_region,
    psgc_citymun,
    psgc_barangay,
    geo_latitude,
    geo_longitude,
    store_polygon
FROM bronze.dim_stores_ncr;
    ')

EXEC('
            SELECT * INTO "SQL-TBWA-ProjectScout-Reporting-Prod"."bronze"."dim_stores_ncr__dbt_tmp" FROM "SQL-TBWA-ProjectScout-Reporting-Prod"."bronze"."dim_stores_ncr__dbt_tmp__dbt_tmp_vw" 
    OPTION (LABEL = ''dbt-sqlserver'');

        ')

    
    EXEC('DROP VIEW IF EXISTS bronze.dim_stores_ncr__dbt_tmp__dbt_tmp_vw')



    
    use [SQL-TBWA-ProjectScout-Reporting-Prod];
    if EXISTS (
        SELECT *
        FROM sys.indexes with (nolock)
        WHERE name = 'bronze_dim_stores_ncr__dbt_tmp_cci'
        AND object_id=object_id('bronze_dim_stores_ncr__dbt_tmp')
    )
    DROP index "bronze"."dim_stores_ncr__dbt_tmp".bronze_dim_stores_ncr__dbt_tmp_cci
    CREATE CLUSTERED COLUMNSTORE INDEX bronze_dim_stores_ncr__dbt_tmp_cci
    ON "bronze"."dim_stores_ncr__dbt_tmp"

   


  