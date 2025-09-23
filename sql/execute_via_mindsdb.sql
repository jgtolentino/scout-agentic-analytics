-- Execute T-SQL bundle via MindsDB connection to Azure SQL Scout
-- Data confirmed: PayloadTransactions=12,192 rows, SalesInteractions=165,480 rows

-- Step 1: Create flat production view
CREATE VIEW azure_sql_scout.dbo.v_transactions_flat_production_via_mindsdb AS (
    SELECT
        pt.sessionId as CanonicalTxID,
        pt.sessionId as TransactionID,
        pt.deviceId as DeviceID,
        CAST(pt.storeId AS INT) as StoreID,
        CONCAT('Store_', pt.storeId) as StoreName,
        s.RegionID as Region,
        s.ProvinceName,
        s.MunicipalityName,
        s.BarangayName,
        s.RegionID as psgc_region,
        s.MunicipalityID as psgc_citymun,
        s.BarangayID as psgc_barangay,
        s.GeoLatitude,
        s.GeoLongitude,
        NULL as StorePolygon,
        pt.amount as Amount,
        1 as Basket_Item_Count,
        CASE
            WHEN EXTRACT(DOW FROM si.TransactionDate) IN (1,2,3,4,5) THEN 'Weekday'
            ELSE 'Weekend'
        END as WeekdayOrWeekend,
        CASE
            WHEN EXTRACT(HOUR FROM si.TransactionDate) BETWEEN 6 AND 11 THEN 'Morn'
            WHEN EXTRACT(HOUR FROM si.TransactionDate) BETWEEN 12 AND 17 THEN 'Afternoon'
            WHEN EXTRACT(HOUR FROM si.TransactionDate) BETWEEN 18 AND 23 THEN 'Evening'
            ELSE 'Night'
        END as TimeOfDay,
        si.Age as AgeBracket,
        si.Gender as Gender,
        NULL as Role,
        NULL as Substitution_Flag,
        si.TransactionDate as Txn_TS
    FROM azure_sql_scout.dbo.PayloadTransactions pt
    LEFT JOIN azure_sql_scout.dbo.SalesInteractions si
        ON CAST(pt.storeId AS INT) = si.StoreID
        AND pt.deviceId = si.DeviceID
    LEFT JOIN azure_sql_scout.dbo.Stores s
        ON CAST(pt.storeId AS INT) = s.StoreID
    WHERE pt.amount IS NOT NULL
);

-- Step 2: Test the view
SELECT COUNT(*) as view_row_count FROM azure_sql_scout.dbo.v_transactions_flat_production_via_mindsdb;