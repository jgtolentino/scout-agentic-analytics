# Scout Store Geospatial Data Update - Deployment Instructions

## 🎯 Objective
Update Azure SQL Server with enriched store data including GeoJSON polygons for choropleth mapping, using zero-trust validation and no-regression merge strategy.

## 📁 Generated Files

1. **`enrich_stores_geospatial.py`** - Python enrichment script with PSGC codes and polygon generation
2. **`stores_enriched_with_polygons.csv`** - 20 enriched stores ready for Azure SQL
3. **`01_staging_infrastructure.sql`** - Schema and table setup for Azure SQL
4. **`02_upsert_stores_procedure.sql`** - Complete stored procedure with all logic
5. **`03_validators.sql`** - Comprehensive validation suite

## 🚀 Execution Steps

### Step 1: Upload CSV to Blob Storage
```bash
# Upload the enriched CSV to your Azure blob storage
az storage blob upload \
  --account-name projectscoutautoregstr \
  --container-name gdrive-scout-ingest \
  --name out/stores_enriched_with_polygons.csv \
  --file /Users/tbwa/scout-v7/azure/stores_enriched_with_polygons.csv
```

### Step 2: Configure Blob Access in Azure SQL
```sql
-- Execute in Azure SQL (replace ***SAS*** with actual token)
:bruno
CREATE DATABASE SCOPED CREDENTIAL SCOUT_BLOB_SAS
WITH IDENTITY='SHARED ACCESS SIGNATURE',
     SECRET='?sv=2022-11-02&ss=bfqt&srt=sco&sp=rwdlacupyx&se=2025-12-31T23:59:59Z&st=...';
```

### Step 3: Run Infrastructure Setup
```sql
-- Execute 01_staging_infrastructure.sql
:bruno
-- Creates staging schemas, tables, and utility functions
```

### Step 4: Deploy Stored Procedure
```sql
-- Execute 02_upsert_stores_procedure.sql
:bruno
-- Creates staging.sp_upsert_enriched_stores procedure
```

### Step 5: Execute Data Load
```sql
-- Run the upsert procedure
:bruno
EXEC staging.sp_upsert_enriched_stores
    @blob_csv_path = N'gdrive-scout-ingest/out/stores_enriched_with_polygons.csv';
```

### Step 6: Validate Results
```sql
-- Execute 03_validators.sql for comprehensive validation
:bruno
-- Checks geometry presence, NCR bounds, polygon format, etc.
```

## 📊 Enrichment Results

**Processed**: 21 total stores from original CSV
**Valid**: 20 stores with complete geospatial data
**Coordinates**: 20 stores with NCR-compliant lat/lon
**Polygons**: 20 stores with valid GeoJSON polygons
**PSGC Codes**: 20 stores with standardized geographic codes

### Municipality Distribution:
- **Quezon City**: 10 stores
- **City of Manila**: 4 stores
- **Mandaluyong City**: 3 stores
- **Pateros**: 2 stores
- **Makati City**: 1 store

## 🔐 Zero-Trust Features

### Geometry Requirements
- **Polygon OR Coordinates**: Every store must have StorePolygon OR (GeoLatitude AND GeoLongitude)
- **NCR Bounds**: All coordinates validated within 14.2-14.9 lat, 120.9-121.2 lon
- **Valid GeoJSON**: All polygons validated as proper GeoJSON Polygon format

### No-Regression Merge
- **COALESCE Strategy**: Only overwrites existing data with non-null/non-empty values
- **Preserve Existing**: Keeps existing good data if new data is missing
- **Audit Trail**: Complete logging of all operations in ops.LocationLoadLog

### Municipality Normalization
- **Canonical Names**: All municipality names normalized to NCR standard spellings
- **PSGC Compliance**: Standardized PSGC codes for all geographic levels
- **Region/Province**: All stores marked as NCR/Metro Manila

## 🗺️ Choropleth Mapping Support

### Polygon Features
- **0.5km Radius**: Each store has circular polygon with 0.5km radius
- **36-Point Circles**: Smooth circular polygons with 36 coordinate points
- **GeoJSON Format**: Standard GeoJSON Polygon specification
- **Coordinate Precision**: 7 decimal places for high accuracy

### Integration Ready
- **React MapBox**: Compatible with existing PhilippinesMap.tsx component
- **Feature Properties**: Includes store_id, name, municipality for data binding
- **Performance Optimized**: Efficient polygon rendering for web dashboards

## 🎛️ Stored Procedure Features

### `staging.sp_upsert_enriched_stores`
- **Idempotent**: Can be run multiple times safely
- **Error Handling**: Complete try/catch with rollback capability
- **Progress Logging**: Real-time status updates and audit trail
- **Validation**: Built-in NCR bounds and geometry presence checks
- **Performance**: Optimized MERGE operation with minimal locking

### Usage
```sql
EXEC staging.sp_upsert_enriched_stores
    @blob_csv_path = N'gdrive-scout-ingest/out/stores_enriched_with_polygons.csv';

-- Returns summary:
-- Status: SUCCESS
-- RowsLoaded: 20
-- RowsUpserted: 20
-- RowsSkipped: 0
-- Details: Complete operation log
```

## ✅ Validation Checklist

After deployment, run validators to confirm:

- [ ] **Geometry Presence**: All stores have polygon OR coordinates
- [ ] **NCR Bounds**: All coordinates within valid NCR region
- [ ] **Municipality Names**: All use NCR standard spellings
- [ ] **PSGC Codes**: All have valid regional/municipal codes
- [ ] **Polygon Format**: All polygons are valid GeoJSON
- [ ] **Scout Stores**: Known good stores (102,103,104,109,110,112) present
- [ ] **Audit Trail**: Load operation logged successfully

## 🔧 Troubleshooting

### Common Issues

**Blob Access Error**: Verify SAS token has read permissions and hasn't expired
**Invalid Coordinates**: Check NCR bounds validation (14.2-14.9, 120.9-121.2)
**Polygon Format**: Ensure GeoJSON is valid JSON with "type":"Polygon"
**Municipality Mismatch**: Review normalization rules in stored procedure

### Support Files
- **Logs**: Check ops.LocationLoadLog for detailed operation history
- **Staging**: Query staging.StoreLocationImport for intermediate data
- **Validation**: Run 03_validators.sql for comprehensive diagnostics

---

## 🎉 Success Criteria

✅ **20 enriched stores** loaded into dbo.Stores
✅ **Zero data regression** - existing good data preserved
✅ **NCR compliance** - all coordinates within valid bounds
✅ **Polygon support** - GeoJSON ready for choropleth mapping
✅ **PSGC standardization** - geographic codes for all levels
✅ **Audit trail** - complete operation logging

**Result**: Azure SQL database ready for advanced geospatial analytics and choropleth visualization with Scout's enriched store master data.