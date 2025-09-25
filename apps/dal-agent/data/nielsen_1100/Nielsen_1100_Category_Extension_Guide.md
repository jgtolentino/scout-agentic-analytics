# Complete Guide: Extending to Nielsen's 1,100 Category Taxonomy

## Executive Summary

This guide provides a step-by-step approach to extend your current 23-category taxonomy to match Nielsen's industry-standard 1,100 product categories. Currently, your 111 brands map to only **38 Nielsen categories**. To reach 1,100 categories, you need to implement the full hierarchical structure detailed below.

---

## 📊 Current State vs Target State

### Current State
- **Your Categories**: 23
- **Your Brands**: 111  
- **Nielsen Categories Used**: 38 (3.5% of target)
- **Subcategories Mapped**: 315

### Target State (Nielsen Standard)
- **Level 1 - Departments**: 10
- **Level 2 - Product Groups**: 125
- **Level 3 - Product Categories**: 1,100
- **Level 4 - Subcategories**: ~3,500
- **Level 5 - Brands**: Your 111 + more
- **Level 6 - SKUs**: ~5,000-10,000

---

## 🏗️ Nielsen Hierarchy Structure

```
Department (10)
  └── Product Group (125)
       └── Product Category (1,100)
            └── Subcategory (~3,500)
                 └── Brand
                      └── SKU/UPC
```

---

## 📋 Implementation Roadmap

### Phase 1: Foundation (Weeks 1-2)
**Goal**: Establish core structure with 100 categories

1. **Map All 10 Departments**
   ```
   01. Food & Beverages
   02. Personal & Health Care  
   03. Household Products
   04. Tobacco Products
   05. Telecommunications
   06. General Merchandise
   07. Pharmacy/OTC
   08. Baby Care
   09. Pet Care
   10. Seasonal/Promotional
   ```

2. **Expand Current 38 Categories → 100**
   - Add missing beverage categories (15 → 30)
   - Expand snacks taxonomy (10 → 25)
   - Create detailed personal care (8 → 20)
   - Add household subcategories (5 → 15)
   - Include telecommunications detail (3 → 10)

### Phase 2: Category Expansion (Weeks 3-4)
**Goal**: Reach 300 categories

#### Food & Beverages Expansion (Current: 15 → Target: 150)

**BEVERAGES (50 categories)**
```
01. Carbonated Soft Drinks (10 subcategories)
    - Cola Regular/Diet/Zero
    - Lemon-Lime variants
    - Orange/Grape/Root Beer
    - Regional flavors
    
02. Juice & Nectars (15 subcategories)
    - 100% Juice by fruit type
    - Juice drinks (<100%)
    - Nectars
    - Smoothies
    - Fresh-squeezed
    
03. Water (8 subcategories)
    - Still/Sparkling
    - Flavored/Unflavored
    - Premium/Value
    - By package size
    
04. Sports & Energy (12 subcategories)
    - Isotonic/Hypotonic
    - Energy regular/sugar-free
    - Pre/Post workout
    - Natural energy
    
05. Coffee RTD (5 subcategories)
    - Iced coffee variants
    - Specialty coffee drinks
```

**SNACKS (50 categories)**
```
01. Potato-based (10)
02. Corn-based (10)
03. Rice-based (5)
04. Nuts & Seeds (8)
05. Dried Fruits (5)
06. Meat Snacks (5)
07. Crackers (7)
```

**INSTANT FOODS (30 categories)**
```
01. Noodles (15 types)
02. Coffee (10 variants)
03. Soups (5 types)
```

**DAIRY (20 categories)**
```
01. Liquid Milk (8)
02. Powdered Milk (5)
03. Cheese (4)
04. Yogurt (3)
```

### Phase 3: Granular Detail (Weeks 5-6)
**Goal**: Reach 600 categories

Add granular subcategories for:
- **Package Sizes**: Create separate categories for each size
  - Single-serve/Sachets
  - Regular size
  - Family/Value packs
  - Bulk/Institutional
  
- **Flavor Variants**: Each as separate category
  - Original/Plain
  - All flavor variations
  - Limited editions
  - Regional preferences

- **Price Tiers**:
  - Premium/Imported
  - Mid-tier/National
  - Value/Local brands
  - Generic/Store brands

### Phase 4: Complete Taxonomy (Weeks 7-8)
**Goal**: Reach 1,100 categories

#### Detailed Category Breakdown

**1. FOOD & BEVERAGES (400 categories)**
```
Beverages Non-Alcoholic: 100
Beverages Alcoholic: 40
Snacks & Confectionery: 80
Instant Foods: 40
Canned/Packaged: 40
Dairy: 30
Condiments: 30
Cooking Ingredients: 20
Bakery: 20
```

**2. PERSONAL & HEALTH CARE (250 categories)**
```
Hair Care: 50
Body Care: 40
Oral Care: 30
Facial Care: 30
Feminine Care: 25
Men's Grooming: 25
OTC Medicine: 30
Vitamins: 20
```

**3. HOUSEHOLD PRODUCTS (200 categories)**
```
Laundry: 50
Dishwashing: 30
Surface Cleaners: 30
Air Care: 20
Paper Products: 25
Pest Control: 20
Tools & Hardware: 25
```

**4. TOBACCO PRODUCTS (50 categories)**
```
Premium Cigarettes: 20
Value Cigarettes: 15
E-cigarettes/Vaping: 10
Other Tobacco: 5
```

**5. TELECOMMUNICATIONS (50 categories)**
```
Regular Load: 10
Data Packages: 15
Combo Promos: 10
International: 5
Accessories: 10
```

**6. GENERAL MERCHANDISE (150 categories)**
```
School Supplies: 30
Batteries: 10
Electronics Accessories: 20
Seasonal Items: 30
Toys & Games: 20
Personal Accessories: 20
Small Appliances: 20
```

---

## 🔧 Technical Implementation

### 1. Database Schema
```sql
CREATE TABLE nielsen_taxonomy (
    id INT PRIMARY KEY,
    dept_code VARCHAR(10),
    dept_name VARCHAR(100),
    group_code VARCHAR(10),
    group_name VARCHAR(100),
    category_code VARCHAR(10),
    category_name VARCHAR(100),
    subcategory_code VARCHAR(10),
    subcategory_name VARCHAR(100),
    brand_id INT,
    sku_code VARCHAR(50),
    UNIQUE KEY (dept_code, group_code, category_code, subcategory_code)
);
```

### 2. SKU Coding System
```
Format: [DEPT]-[GROUP]-[CAT]-[SUBCAT]-[BRAND]-[SIZE]-[VAR]

Example: FOO-BEV-CAR-COL-COC-500ML-REG
(Food-Beverages-Carbonated-Cola-CocaCola-500ml-Regular)
```

### 3. Mapping Rules Engine
```python
def categorize_product(product_name, brand, size, price):
    # Rule 1: Brand mapping
    if brand in brand_mappings:
        base_category = brand_mappings[brand]
    
    # Rule 2: Size classification
    if size < 100:
        size_cat = "single_serve"
    elif size < 500:
        size_cat = "regular"
    else:
        size_cat = "family"
    
    # Rule 3: Price tier
    if price > premium_threshold:
        tier = "premium"
    else:
        tier = "value"
    
    return generate_nielsen_code(base_category, size_cat, tier)
```

---

## 📈 Practical Examples

### Example 1: Coca-Cola Products
Current: 1 category ("Non-Alcoholic")
Nielsen: 15 categories
```
1. Cola Regular 200ml
2. Cola Regular 500ml  
3. Cola Regular 1.5L
4. Cola Regular Multi-pack
5. Cola Zero 500ml
6. Cola Zero 1.5L
7. Cola Light 500ml
8. Sprite Regular 500ml
9. Sprite Zero 500ml
10. Royal Orange 500ml
11. Minute Maid Juice
12. Powerade Isotonic
13. Coca-Cola Frozen
14. Fountain Syrup
15. Promotional Packs
```

### Example 2: Lucky Me Noodles
Current: 1 category ("Instant Foods")
Nielsen: 20 categories
```
1. Pancit Canton Original Single
2. Pancit Canton Original 6-pack
3. Pancit Canton Sweet & Spicy Single
4. Pancit Canton Chilimansi
5. Pancit Canton Extra Hot
6. Instant Mami Chicken
7. Instant Mami Beef
8. Cup Noodles Mini
9. Cup Noodles Regular
10. Cup Noodles Jumbo
11. Supreme La Paz Batchoy
12. Supreme Bulalo
13. Instant Pancit Palabok
14. Instant Sotanghon
15. Go Cup variants (5 types)
```

---

## 💡 Quick Wins to Add 500+ Categories

### 1. Size Variations (×4 multiplier)
For each existing category, add:
- Sachet/Single-serve
- Regular size
- Family pack
- Bulk/Sari-sari store pack

### 2. Flavor Extensions (×3 multiplier)
- Original/Plain
- Top 2 flavor variants
- Limited/Seasonal edition

### 3. Price Segmentation (×3 multiplier)
- Premium/Imported
- Standard/National brand
- Value/Local brand

### 4. Package Type (×2 multiplier)
- Primary package (bottle, pouch, box)
- Secondary (multi-pack, promo bundle)

**Math**: 38 current categories × 4 sizes × 3 flavors × 3 price points × 2 packages = **2,736 potential categories**

---

## 📊 Measurement & KPIs

### Success Metrics
1. **Category Coverage**: % of transactions with proper Nielsen categorization
2. **SKU Completeness**: % of products with full 6-level hierarchy
3. **Data Quality**: Error rate in categorization
4. **Business Impact**: Improved inventory turnover from better categorization

### Monthly Targets
- Month 1: 100 categories (10% of target)
- Month 2: 300 categories (30%)
- Month 3: 600 categories (60%)
- Month 4: 900 categories (90%)
- Month 5: 1,100 categories (100%)
- Month 6: Optimization and refinement

---

## 🎯 Action Items

### Immediate (Week 1)
1. ✅ Implement the 38 mapped Nielsen categories
2. ✅ Fix the 21 "unspecified" brands
3. ✅ Add size variations to top 20 brands
4. ✅ Create flavor subcategories for beverages

### Short-term (Month 1)
1. 📋 Expand snacks to 50 subcategories
2. 📋 Detail telecommunications offerings
3. 📋 Add all cigarette variants
4. 📋 Map dairy products properly

### Medium-term (Months 2-3)
1. 📋 Implement size-based categorization
2. 📋 Add seasonal/promotional categories
3. 📋 Create region-specific categories
4. 📋 Include all sachets as separate SKUs

### Long-term (Months 4-6)
1. 📋 Complete 1,100 category structure
2. 📋 Integrate with POS systems
3. 📋 Train staff on new taxonomy
4. 📋 Align with Nielsen reporting

---

## 📁 Deliverables Created

1. **nielsen_taxonomy_structure.xlsx** - Complete 227-category starting framework
2. **brand_nielsen_mapping.xlsx** - All 111 brands mapped to Nielsen structure  
3. **brand_nielsen_mapping.json** - Programmatic mapping file
4. **Python Implementation Scripts** - Automated categorization tools

---

## 🚀 Next Steps

1. **Review** the mapped categories in `brand_nielsen_mapping.xlsx`
2. **Prioritize** which categories to expand first based on transaction volume
3. **Implement** size and flavor variations for top 20 brands
4. **Test** the new categorization with sample transactions
5. **Train** your team on the Nielsen structure
6. **Monitor** categorization accuracy weekly

With this systematic approach, you'll transform your current 23 categories into Nielsen's 1,100-category standard, enabling:
- Industry-standard benchmarking
- Better inventory management
- Improved supplier negotiations
- Enhanced business intelligence
- Competitive market analysis

The key is to start with high-volume products and progressively add detail. Each brand can easily generate 10-20 Nielsen categories when properly classified by size, flavor, package, and price point.
