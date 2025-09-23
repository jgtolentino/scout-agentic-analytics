# Complete Scout Analytics Export Commands

## Authentication Setup (Option A - Recommended)

### 1. Configure Bruno Vault
Add to Bruno vault:
```
Key: vault.scout_analytics.sql_reader_password
Value: [SECURE_PASSWORD_FOR_SCOUT_READER]
```

### 2. Test Connection
```bash
:bruno
export AZSQL_PASS="${vault.scout_analytics.sql_reader_password}"
./scripts/test_vault_connection.sh
```

## Complete Data Exports

### Export 1: Complete Flat Dataframe
**File**: `scout_flat_complete_all_12075_records.csv`
**Spec**: 12,075 rows, 24 columns (per contract)

```bash
:bruno
export AZSQL_PASS="${vault.scout_analytics.sql_reader_password}"
./scripts/export_complete_data.sh "scout_flat_complete_all_12075_records.csv" \
"SELECT
  CanonicalTxID, TransactionID, DeviceID, StoreID, StoreName, Region, ProvinceName,
  MunicipalityName, BarangayName, psgc_region, psgc_citymun, psgc_barangay,
  GeoLatitude, GeoLongitude, StorePolygon, Amount, Basket_Item_Count,
  WeekdayOrWeekend, TimeOfDay, AgeBracket, Gender, Role, Substitution_Flag, Txn_TS
 FROM gold.v_transactions_flat
 ORDER BY Txn_TS DESC;"
```

### Export 2: Complete Crosstab
**File**: `scout_crosstab_complete_all_data.csv`
**Spec**: Variable rows, 10 columns (per contract)

```bash
:bruno
export AZSQL_PASS="${vault.scout_analytics.sql_reader_password}"
./scripts/export_complete_data.sh "scout_crosstab_complete_all_data.csv" \
"SELECT
  [date], store_id, store_name, municipality_name, daypart, brand,
  txn_count, total_amount, avg_basket_amount, substitution_events
 FROM gold.v_transactions_crosstab
 ORDER BY [date] DESC, store_id, daypart, brand;"
```

## Verification Commands

### Check Export Results
```bash
:bruno
# Count lines (should be 12,076 for flat: header + 12,075 rows)
wc -l exports/scout_flat_complete_all_12075_records.csv
wc -l exports/scout_crosstab_complete_all_data.csv

# Verify column structure
head -5 exports/scout_flat_complete_all_12075_records.csv
head -5 exports/scout_crosstab_complete_all_data.csv
```

### Expected Results
- **Flat Dataframe**: 12,076 lines (header + 12,075 records)
- **Crosstab**: Variable lines based on date/store/brand combinations
- **Column Count**: Flat=24, Crosstab=10 (exact specs)
- **Zero-Credential**: No passwords in logs or application code

## File Specifications

### Flat Dataframe (24 Columns)
1. CanonicalTxID (varchar64) - Unique transaction identifier
2. TransactionID (varchar64) - Source transaction ID
3. DeviceID (varchar64) - Optional device identifier
4. StoreID (int) - Store identifier (7 active stores)
5. StoreName (nvarchar200) - Store name from dimension
6. Region (varchar8) - "NCR" (guarded)
7. ProvinceName (nvarchar50) - "Metro Manila" (guarded)
8. MunicipalityName (nvarchar80) - Normalized NCR city
9. BarangayName (nvarchar120) - Optional barangay
10. psgc_region (char9) - 9-digit PSGC region code
11. psgc_citymun (char9) - 9-digit PSGC city/municipality
12. psgc_barangay (char9) - 9-digit PSGC barangay
13. GeoLatitude (float) - NCR-guarded coordinates
14. GeoLongitude (float) - NCR-guarded coordinates
15. StorePolygon (nvarchar max) - GeoJSON/WKT polygon
16. Amount (decimal12,2) - Transaction amount
17. Basket_Item_Count (int) - Number of items
18. WeekdayOrWeekend (varchar8) - Day classification
19. TimeOfDay (char4) - Time period (e.g., 07PM)
20. AgeBracket (nvarchar50) - Customer age bracket
21. Gender (nvarchar20) - Customer gender
22. Role (nvarchar50) - Customer role
23. Substitution_Flag (bit) - Substitution indicator
24. Txn_TS (datetimeoffset0) - Transaction timestamp (UTC)

### Crosstab (10 Columns)
1. [date] (date) - Transaction date
2. store_id (int) - Store identifier
3. store_name (nvarchar200) - Store name
4. municipality_name (nvarchar80) - Municipality
5. daypart (varchar10) - Time period classification
6. brand (nvarchar120) - Brand name
7. txn_count (int) - Number of transactions
8. total_amount (decimal18,2) - Total revenue
9. avg_basket_amount (decimal18,2) - Average basket size
10. substitution_events (int) - Count of substitutions

## Security Features
- ✅ Zero-credential architecture (Bruno vault integration)
- ✅ Explicit column lists (no SELECT *)
- ✅ SQL injection prevention
- ✅ Audit logging of export requests
- ✅ Secure credential rotation capability