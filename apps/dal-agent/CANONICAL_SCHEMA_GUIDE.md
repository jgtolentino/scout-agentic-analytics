# Scout v7 Canonical Schema Organization Guide

Complete guide for organizing Scout v7 database with canonical naming patterns, automated ERD generation, and comprehensive documentation.

## 🏗️ Schema Architecture

### Canonical Schema Organization

```
scout_v7_database/
├── dbo/                    # Public Dimensions (Single Source of Truth)
│   ├── DimDate             # Date dimension
│   ├── DimTime             # Time dimension
│   ├── Stores              # Store master data
│   ├── Region              # Geographic hierarchy
│   ├── Province            #
│   ├── Municipality        #
│   ├── Barangay            #
│   ├── Brands              # Brand master data
│   └── Products            # Product master data
│
├── canonical/              # Facts & Contract Views
│   ├── SalesInteractionFact    # Main fact table
│   └── v_export_canonical_13col # 13-column contract view
│
├── intel/                  # Derived Analytics
│   ├── BasketItems         # Market basket analysis
│   ├── SubstitutionEvents  # Substitution tracking
│   ├── v_basket_pairs      # Basket affinity view
│   └── v_substitution_summary # Substitution summary
│
├── ref/                    # Reference Data & Rules
│   ├── NielsenHierarchy    # Nielsen category hierarchy
│   └── PersonaRules        # Customer segmentation rules
│
└── mart/                   # Data Mart Views (existing)
    └── v_store_profiles    # Store analytics
```

## 🚀 Quick Start Commands

### Complete Schema Documentation
```bash
# Generate full schema inventory + ERD
make schema-complete

# Individual operations
make schema-inventory    # Database inventory & data dictionary
make erd                # Full ERD diagram
make erd-simplified     # Core tables only
```

### Analytics Operations
```bash
# Comprehensive analytics export
make analytics-comprehensive

# Traditional analytics
make analytics-enhanced
```

### Schema Reorganization
```bash
# Apply canonical schema structure
./scripts/sql.sh -f sql/schema/canonical_reorganization.sql

# Load enhanced catalog with 1,100+ brands
python3 scripts/load_enhanced_catalog.py data/scout_v7_full_catalog.json
```

## 📊 Generated Outputs

### Schema Documentation (`out/schema/`)
- **`schema_inventory_full.txt`** - Complete database inventory
- **Data dictionary** with column details, types, constraints
- **Naming convention analysis** and recommendations
- **Schema organization** by canonical patterns

### ERD Diagrams (`out/erd/`)
- **`scout_v7_erd.png`** - Full ERD diagram
- **`scout_v7_erd.svg`** - Scalable vector format
- **`scout_v7_erd.pdf`** - Print-quality PDF
- **`scout_v7_erd_simplified.png`** - Core tables only
- **`scout_v7_erd.dot`** - Graphviz source file
- **`erd_statistics.txt`** - Generation statistics

### Analytics Exports (`out/comprehensive_analytics/`)
- **Store Demographics** - 5 detailed exports
- **Tobacco Analytics** - 7 category-specific exports
- **Laundry Analytics** - 6 product-specific exports
- **All Categories** - 4 cross-category exports
- **Conversation Intelligence** - 5 dialogue exports

## 🎯 Naming Conventions

### Table Naming Standards
- **PascalCase objects**: `SalesInteractionFact`, `DimDate`
- **Singular fact tables**: `SalesInteractionFact` (not `SalesInteractions`)
- **No spaces**: Use `_` for compound names
- **Descriptive suffixes**: `Fact`, `Dim`, `View` as appropriate

### Column Naming Standards
- **snake_case or camelCase**: Choose one and be consistent
- **Short, scoped names**: `conf`, `qty`, `reason`, `switch_type`
- **Avoid reserved words**: Don't use `Date`, `Time`, `Order` as column names
- **Foreign key consistency**: `BrandID` references `Brands.BrandID`

### Schema Purpose Classification
| Schema | Purpose | Examples |
|--------|---------|----------|
| **dbo** | Public Dimensions | Stores, Brands, Products, Region |
| **canonical** | Facts & Contract | SalesInteractionFact, v_export_canonical_13col |
| **intel** | Derived Analytics | BasketItems, SubstitutionEvents |
| **ref** | Reference Data | NielsenHierarchy, PersonaRules |
| **mart** | Data Mart Views | v_store_profiles (existing) |

## 🔗 ERD Generation Process

### Automated Graphviz ERD
The ERD generation process:

1. **Extract Foreign Keys** from database metadata
2. **Generate DOT syntax** with schema-based coloring
3. **Render multiple formats** (PNG, SVG, PDF)
4. **Create simplified view** for core tables only

### Schema Color Coding
- **canonical** - Blue (`#B3D9FF`) - Core facts
- **dbo** - Orange (`#FFD4B3`) - Dimensions
- **intel** - Green (`#C8E6C8`) - Analytics
- **mart** - Yellow (`#FFFACD`) - Views
- **ref** - Gray (`#E8E8E8`) - Reference

### Prerequisites
```bash
# Install Graphviz
brew install graphviz              # macOS
sudo apt-get install graphviz     # Ubuntu
choco install graphviz            # Windows
```

## 📋 Schema Inventory Features

### Complete Database Analysis
- **All tables, views, procedures** across schemas
- **Column-level data dictionary** with types, constraints
- **Primary/Foreign key relationships**
- **Index documentation**
- **Naming pattern analysis**

### Reorganization Recommendations
- **Schema migration suggestions** based on table purpose
- **Naming convention improvements**
- **Foreign key optimization**
- **Index recommendations**

## 🏢 Enhanced Catalog Support

### 1,100+ Brand Scale Features
- **Lexical variations** - Filipino market brand recognition
- **Nielsen category integration** - 70 categories with hierarchy
- **TBWA client tracking** - Competitive intelligence
- **Conversation intelligence** - Filipino dialogue patterns

### Brand Variation Types
```json
{
  "lexical_variations": {
    "formal": ["Coca-Cola", "Nescafé coffee"],
    "informal": ["coke", "kape", "3-in-1"],
    "code_switched": ["yung coke", "coffee ko"],
    "abbreviated": ["CC", "NES"]
  }
}
```

## 🔧 Implementation Workflow

### Phase 1: Documentation & Analysis
```bash
# Generate current state documentation
make schema-inventory
make erd

# Analyze current structure and naming
# Review outputs in out/schema/ and out/erd/
```

### Phase 2: Schema Reorganization
```bash
# Apply canonical schema structure
./scripts/sql.sh -f sql/schema/canonical_reorganization.sql

# Verify new structure
make schema-inventory
make erd
```

### Phase 3: Data Migration
```bash
# Load enhanced brand catalog
python3 scripts/load_enhanced_catalog.py data/scout_v7_full_catalog.json

# Migrate existing data to canonical.SalesInteractionFact
# (Custom migration scripts based on current data structure)
```

### Phase 4: Analytics Validation
```bash
# Test analytics with new structure
make analytics-comprehensive

# Validate 13-column contract view
# Verify data quality and completeness
```

## 📈 Benefits of Canonical Organization

### 1. **Clear Separation of Concerns**
- **dbo**: Stable dimension data
- **canonical**: Core business facts
- **intel**: Derived insights
- **ref**: Configuration & rules

### 2. **Maintainable Relationships**
- Consistent foreign key patterns
- Single source of truth per entity
- Clear dependency hierarchy

### 3. **Scalable Analytics**
- Purpose-built analytics schema (`intel`)
- Optimized for performance
- Easy to extend with new insights

### 4. **Contract Compliance**
- 13-column view maintained
- Backward compatibility
- Clear external interface

## 🎯 Best Practices

### Database Design
1. **Use meaningful names** that describe business concepts
2. **Maintain referential integrity** with proper foreign keys
3. **Index strategically** for common query patterns
4. **Document relationships** through ERD and data dictionary

### Schema Evolution
1. **Version control** all schema changes
2. **Test migrations** on copy before production
3. **Maintain backward compatibility** for existing integrations
4. **Document breaking changes** and migration paths

### Performance Optimization
1. **Star schema design** for analytics workloads
2. **Appropriate indexing** on fact table dimensions
3. **Partitioning strategy** for large fact tables
4. **Regular statistics updates** for query optimization

## 🚨 Migration Checklist

### Pre-Migration
- [ ] Generate current schema documentation
- [ ] Create ERD of existing structure
- [ ] Backup production database
- [ ] Test canonical schema on development

### During Migration
- [ ] Apply canonical schema structure
- [ ] Migrate dimension data to standardized tables
- [ ] Transform fact data to canonical.SalesInteractionFact
- [ ] Update foreign key relationships
- [ ] Rebuild indexes and statistics

### Post-Migration
- [ ] Validate data integrity
- [ ] Test 13-column contract view
- [ ] Run comprehensive analytics
- [ ] Update application connection strings
- [ ] Monitor performance metrics

## 📞 Support & Troubleshooting

### Common Issues
1. **Foreign key violations** - Check dimension data completeness
2. **Performance degradation** - Rebuild indexes and update statistics
3. **Missing data** - Verify migration scripts and data mapping
4. **ERD generation failures** - Check Graphviz installation

### Validation Queries
```sql
-- Verify 13-column contract
SELECT COUNT(*) FROM canonical.v_export_canonical_13col;

-- Check foreign key integrity
EXEC sp_msforeachtable 'DBCC CHECKFOREIGNKEY (''?'')';

-- Validate analytics exports
SELECT COUNT(*) FROM intel.v_basket_pairs;
SELECT COUNT(*) FROM intel.v_substitution_summary;
```

---

**Last Updated**: 2025-09-26
**Version**: 1.0
**Database**: Scout v7 Canonical Schema