# Scout Analytics Data Dictionary - Location Hierarchy Update

## Updated: September 28, 2025

## 🗺️ **Complete Location Hierarchy Integration**

### **Core Location Tables**

#### `platinum.v_location_complete` - Master Location View
| Field | Type | Description | Example |
|-------|------|-------------|---------|
| **store_id** | int | Unique store identifier | `104` |
| **store_code** | varchar(50) | Standardized store code | `Store_104` |
| **store_name** | nvarchar(200) | Store business name | `ERRSON` |
| **store_type** | nvarchar(50) | Store size/category | `Small`, `Medium`, `Large` |
| **latitude** | float | Geographic latitude | `14.5764` |
| **longitude** | float | Geographic longitude | `121.0851` |
| **street_address** | nvarchar(500) | Full street address | `STA. ANA` |

#### **Administrative Hierarchy**
| Field | Type | Description | Example |
|-------|------|-------------|---------|
| **barangay_id** | int | Barangay reference ID | `101` |
| **barangay_name** | nvarchar(100) | Barangay name | `STA. ANA` |
| **municipality_id** | int | Municipality reference ID | `1376` |
| **municipality_name** | nvarchar(100) | City/Municipality name | `Pateros` |
| **province_name** | nvarchar(100) | Province name | `Metro Manila` |
| **region_name** | nvarchar(100) | Administrative region | `NCR` |

#### **PSGC Integration** (Philippine Standard Geographic Code)
| Field | Type | Description | Example |
|-------|------|-------------|---------|
| **psgc_barangay** | char(9) | Official barangay code | `137603001` |
| **psgc_citymun** | char(6) | Official city/municipality code | `137603` |
| **psgc_region** | char(2) | Official region code | `13` |

#### **Geographic Classifications**
| Field | Type | Description | Values |
|-------|------|-------------|--------|
| **island_group** | varchar(50) | Major island grouping | `Metro Manila`, `Greater Manila Area`, `Luzon`, `Visayas`, `Mindanao` |
| **urbanization_level** | varchar(20) | Development classification | `Urban`, `Semi-Urban`, `Rural` |
| **full_address** | nvarchar(MAX) | Complete hierarchical address | `STA. ANA, Brgy. STA. ANA, Pateros, Metro Manila, NCR` |

---

## 📊 **Enhanced Canonical Views**

### `canonical.v_transactions_location_complete` - Complete Transaction Data
*Extends the flat transaction view with comprehensive location hierarchy*

#### **New Location Fields Added:**
| Field | Type | Description | Coverage |
|-------|------|-------------|----------|
| **store_latitude** | float | Store geographic latitude | 33% (7/21 stores) |
| **store_longitude** | float | Store geographic longitude | 33% (7/21 stores) |
| **barangay_name** | nvarchar(100) | Barangay where transaction occurred | 33% (7/21 stores) |
| **municipality_name** | nvarchar(100) | Municipality/City | 100% (21/21 stores) |
| **province_name** | nvarchar(100) | Province name | 100% (21/21 stores) |
| **region_name** | nvarchar(100) | Administrative region | 100% (21/21 stores) |
| **island_group** | varchar(50) | Island classification | 100% (21/21 stores) |
| **urbanization_level** | varchar(20) | Urban/Rural classification | 100% (21/21 stores) |
| **full_address** | nvarchar(MAX) | Complete address hierarchy | 100% (21/21 stores) |
| **psgc_barangay** | char(9) | Official barangay code | Available where mapped |
| **psgc_citymun** | char(6) | Official municipality code | Available where mapped |
| **psgc_region** | char(2) | Official region code | Available where mapped |

#### **Store Management Fields:**
| Field | Type | Description | Example |
|-------|------|-------------|---------|
| **store_manager** | nvarchar(200) | Store manager name | `Juan Dela Cruz` |
| **pos_device** | nvarchar(100) | POS device identifier | `DEVICE_001` |

---

## 🎯 **Geographic Analytics Views**

### `gold.v_regional_analytics_complete` - Regional Performance
*Comprehensive regional performance metrics with location intelligence*

#### **Regional Metrics:**
| Field | Type | Description | Business Use |
|-------|------|-------------|-------------|
| **region_name** | nvarchar(100) | Administrative region | Market segmentation |
| **island_group** | varchar(50) | Island classification | Logistics planning |
| **urbanization_level** | varchar(20) | Development level | Product mix optimization |
| **total_transactions** | int | Transaction count | Market size |
| **unique_brands** | int | Brand variety | Competition analysis |
| **active_stores** | int | Store network size | Distribution coverage |
| **municipalities_covered** | int | Geographic reach | Market penetration |
| **barangays_covered** | int | Granular coverage | Local market depth |
| **geocoding_rate** | decimal(5,1) | % with coordinates | Data quality metric |

---

## 🛠️ **Enhanced Nielsen Integration**

### **Location-Enhanced Brand Analytics**
*Nielsen taxonomy now includes location intelligence for market analysis*

#### **New Combined Fields:**
| Field | Type | Description | Business Value |
|-------|------|-------------|---------------|
| **brand_location_performance** | Computed | Brand performance by location | Regional strategy |
| **category_urbanization_mix** | Computed | Product categories by urban/rural | Market adaptation |
| **regional_brand_penetration** | Computed | Brand presence across regions | Expansion planning |

---

## 📈 **Data Quality Improvements**

### **Current Coverage Metrics:**
- **Total Stores**: 21 locations
- **Barangay Data**: 33% coverage (7/21 stores)
- **Geographic Coordinates**: 100% coverage (21/21 stores) ✅ **COMPLETED**
- **GeoJSON Point Data**: 100% coverage (21/21 stores) ✅ **COMPLETED**
- **Municipality Coverage**: 100% (5 unique municipalities)
- **Region Coverage**: 100% (NCR focus)

### **Data Enhancement Opportunities:**
1. **🎯 Barangay Mapping**: Expand from 33% to 80%+ coverage
2. **✅ Geocoding**: ~~Complete coordinate collection for remaining 14 stores~~ **COMPLETED**
3. **🏘️ PSGC Integration**: Map all locations to official government codes
4. **🗺️ GeoJSON Boundaries**: Add administrative boundary definitions

### **Geocoding Completion Summary (September 28, 2025):**
- **Objective**: Complete coordinate collection for 14 stores lacking geocoding
- **Method**: Municipality-level centroid coordinates for Metro Manila cities
- **Results**:
  - 7 stores with original precise coordinates (maintained)
  - 14 stores updated with municipality centroid coordinates
  - All 21 stores now have GeoJSON Point geometry data
  - 100% geocoding coverage achieved
- **Coordinate Sources**:
  - **Original GPS**: 7 stores (ERRSON, Cris sari sari, Lourdes, Merly, Riza, Ruby, Tess)
  - **Municipality Centroids**: 14 stores (distributed across Quezon City, Manila, Makati, Mandaluyong, Pateros)

---

## 🚀 **New Capabilities Enabled**

### **Geographic Intelligence:**
- **Heat Maps**: Store performance visualization
- **Catchment Analysis**: Market area definition
- **Route Optimization**: Logistics and field force
- **Demographic Overlays**: Population-based insights

### **Market Insights:**
- **Urban vs Rural Analysis**: Product preference patterns
- **Regional Brand Performance**: Territory management
- **Municipality Ranking**: Market opportunity scoring
- **Island Group Comparison**: Macro-market analysis

### **Operational Analytics:**
- **Store Density Analysis**: Market saturation assessment
- **Territory Performance**: Sales rep effectiveness
- **Expansion Planning**: New location identification
- **Competitor Mapping**: Market position analysis

---

## 🔄 **API Integration Points**

### **GeoJSON Exports:**
```sql
EXEC dbo.sp_export_stores_geojson @region_code = 'NCR'
```

### **Location Lookup:**
```sql
SELECT * FROM platinum.v_location_complete
WHERE municipality_name = 'Quezon City'
```

### **Regional Analytics:**
```sql
SELECT * FROM gold.v_regional_analytics_complete
WHERE island_group = 'Metro Manila'
```

---

## 📍 **Next Phase Roadmap**

### **Phase 1: Data Completion** (Next 30 days)
- Complete barangay mapping for remaining 14 stores
- Geocode all store locations
- Integrate PSGC official codes

### **Phase 2: Advanced Analytics** (Next 60 days)
- Demographic overlays with census data
- Competitor store mapping
- Market potential modeling

### **Phase 3: Real-time Integration** (Next 90 days)
- Live location-based dashboards
- Mobile field force integration
- Dynamic territory management

---

*This update completes the Scout Analytics location hierarchy, providing comprehensive geographic intelligence for data-driven market expansion and operational optimization.*