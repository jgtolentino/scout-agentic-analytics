
  
    USE [SQL-TBWA-ProjectScout-Reporting-Prod];
    USE [SQL-TBWA-ProjectScout-Reporting-Prod];
    
    

    

    
    USE [SQL-TBWA-ProjectScout-Reporting-Prod];
    EXEC('
        create view "bronze"."bronze_transactions__dbt_tmp__dbt_tmp_vw" as 

SELECT
    canonical_id,
    transaction_id,
    store_id,
    device_id,
    transaction_date,
    transaction_time,
    basket_size,
    total_amount,
    payment_method,
    customer_type,
    municipality,
    barangay,
    latitude,
    longitude,
    data_source,
    _source_file,
    _ingested_at,
    loaded_at
FROM bronze.transactions;
    ')

EXEC('
            SELECT * INTO "SQL-TBWA-ProjectScout-Reporting-Prod"."bronze"."bronze_transactions__dbt_tmp" FROM "SQL-TBWA-ProjectScout-Reporting-Prod"."bronze"."bronze_transactions__dbt_tmp__dbt_tmp_vw" 
    OPTION (LABEL = ''dbt-sqlserver'');

        ')

    
    EXEC('DROP VIEW IF EXISTS bronze.bronze_transactions__dbt_tmp__dbt_tmp_vw')



    
    use [SQL-TBWA-ProjectScout-Reporting-Prod];
    if EXISTS (
        SELECT *
        FROM sys.indexes with (nolock)
        WHERE name = 'bronze_bronze_transactions__dbt_tmp_cci'
        AND object_id=object_id('bronze_bronze_transactions__dbt_tmp')
    )
    DROP index "bronze"."bronze_transactions__dbt_tmp".bronze_bronze_transactions__dbt_tmp_cci
    CREATE CLUSTERED COLUMNSTORE INDEX bronze_bronze_transactions__dbt_tmp_cci
    ON "bronze"."bronze_transactions__dbt_tmp"

   


  