# Mock Users Testing Guide

## 🧪 Testing RLS with Mock Users

This guide shows how to test the Row-Level Security (RLS) implementation using mock users in Microsoft Fabric.

## 📋 Prerequisites

1. **Security table created** in Fabric Warehouse (run `setup-security-table.sql`)
2. **PBIP model updated** with `security_assignments` table
3. **Dynamic RLS roles** configured in the model
4. **Fabric workspace** with the updated model deployed

## 👥 Mock Users Available

### Regional Managers
| Email | Role | Region | Expected Access |
|-------|------|--------|----------------|
| `maria.santos@scout.com` | region_manager | NCR | NCR stores only |
| `juan.dela.cruz@scout.com` | region_manager | Central Luzon | Central Luzon stores only |
| `ana.reyes@scout.com` | region_manager | Central Visayas | Central Visayas stores only |
| `carlos.garcia@scout.com` | region_manager | Davao Region | Davao Region stores only |

### Store Managers
| Email | Role | Store ID | Expected Access |
|-------|------|----------|----------------|
| `store.manager.1001@scout.com` | store_manager | 1001 | Store 1001 only |
| `store.manager.2045@scout.com` | store_manager | 2045 | Store 2045 only |
| `store.manager.3022@scout.com` | store_manager | 3022 | Store 3022 only |

### Category Managers
| Email | Role | Category | Expected Access |
|-------|------|----------|----------------|
| `tobacco.manager@scout.com` | category_manager | tobacco | Tobacco products only |
| `laundry.manager@scout.com` | category_manager | laundry | Laundry products only |
| `premium.manager@scout.com` | category_manager | premium | Premium brands only |

### Dev/Test Users (for "View as" testing)
| Email | Role | Scope | Notes |
|-------|------|-------|-------|
| `alice@mock.local` | region_manager | NCR | Non-existent user for testing |
| `bob@mock.local` | store_manager | Store 1001 | Non-existent user for testing |
| `carol@mock.local` | category_manager | tobacco | Non-existent user for testing |
| `dave@mock.local` | data_analyst | All data | Non-existent user for testing |

## 🔍 How to Test

### Method 1: "View as" Feature (Recommended for Mock Users)

1. **Open Dataset in Fabric**
   - Navigate to your workspace
   - Open the "scout-core-dataset"
   - Go to **Model view**

2. **Use "View as" Feature**
   - Look for **"View as"** button in the ribbon
   - Select role: `Dynamic Regional Manager`
   - Enter effective user: `alice@mock.local`
   - Click **Apply**

3. **Test Filtering**
   - Open any report connected to the dataset
   - Verify only NCR data appears
   - Check that regional filters show NCR only

### Method 2: Real User Assignment (Production)

1. **Add Users to Workspace**
   - Go to Workspace → Manage Access
   - Add the mock user emails
   - Assign **Viewer** role

2. **Assign RLS Roles**
   - Go to Dataset → Security
   - Add users to appropriate RLS roles:
     - `maria.santos@scout.com` → Dynamic Regional Manager
     - `store.manager.1001@scout.com` → Dynamic Store Manager
     - `tobacco.manager@scout.com` → Dynamic Category Manager

3. **Test with Actual Login**
   - Have users log in with their credentials
   - Verify data filtering works as expected

## ✅ Test Scenarios

### Scenario 1: Regional Manager (NCR)
```
User: maria.santos@scout.com OR alice@mock.local
Role: Dynamic Regional Manager
Expected Result:
- Store list shows only NCR stores
- Sales data filtered to NCR region
- Regional charts show NCR only
- No access to Luzon, Visayas, or Mindanao data
```

### Scenario 2: Store Manager
```
User: store.manager.1001@scout.com OR bob@mock.local
Role: Dynamic Store Manager
Expected Result:
- Store selector shows single store (1001)
- All metrics reflect Store 1001 only
- Store comparison charts show single store
- No access to other store data
```

### Scenario 3: Category Manager (Tobacco)
```
User: tobacco.manager@scout.com OR carol@mock.local
Role: Dynamic Category Manager
Expected Result:
- Product list shows tobacco brands only
- Category breakdown shows tobacco category
- Sales metrics for tobacco across all regions
- No access to laundry or other categories
```

### Scenario 4: Data Analyst (Full Access)
```
User: data.analyst@scout.com OR dave@mock.local
Role: Data Analyst
Expected Result:
- Full access to all regions and categories
- Complete dataset for analysis
- All stores and products visible
- No restrictions on data access
```

## 🐛 Troubleshooting

### Issue: User sees no data
**Possible Causes:**
- User not assigned to security table
- RLS role not assigned to user
- Username/email mismatch

**Solution:**
```sql
-- Check user assignment in security table
SELECT * FROM security.assignments
WHERE email = 'maria.santos@scout.com'

-- Verify role assignment in Fabric
-- Go to Dataset → Security → Role Members
```

### Issue: User sees all data (RLS not working)
**Possible Causes:**
- User assigned to wrong role
- RLS role filter not working
- Security table not refreshed

**Solution:**
```sql
-- Refresh security assignments table
-- In Fabric: Dataset → Refresh Now

-- Check RLS role logic
-- Use "View as" to test role filters
```

### Issue: "View as" shows no effect
**Possible Causes:**
- Security assignments table not loaded
- Role filter syntax error
- Model relationships broken

**Solution:**
```sql
-- Verify security_assignments table in model
-- Check table data in Data view
-- Validate DAX syntax in RLS roles
```

## 📊 Test Queries

Use these DAX queries in Fabric to verify filtering:

### Check Current User Context
```dax
EVALUATE
ADDCOLUMNS(
    SUMMARIZE(
        security_assignments,
        security_assignments[Email],
        security_assignments[RoleName],
        security_assignments[RegionName],
        security_assignments[StoreID]
    ),
    "CurrentUser", USERPRINCIPALNAME(),
    "IsCurrentUser", security_assignments[Email] = USERPRINCIPALNAME()
)
```

### Test Regional Filtering
```dax
EVALUATE
SUMMARIZE(
    dim_store,
    dim_store[RegionName],
    "StoreCount", COUNTROWS(dim_store),
    "TotalSales", [Total Sales]
)
```

### Test Store Filtering
```dax
EVALUATE
TOPN(
    10,
    SUMMARIZE(
        dim_store,
        dim_store[StoreID],
        dim_store[StoreName],
        dim_store[RegionName]
    ),
    dim_store[StoreID],
    ASC
)
```

## 🔄 Updating Mock Users

To add or modify mock users:

1. **Update Security Table**
   ```sql
   INSERT INTO security.assignments (email, role_name, region_name, store_id, category_filter)
   VALUES ('new.user@scout.com', 'region_manager', 'CALABARZON', NULL, NULL);
   ```

2. **Refresh Dataset**
   - Go to Fabric workspace
   - Refresh the dataset to pick up new assignments
   - Test with "View as" feature

3. **Assign RLS Role**
   - Add user to appropriate RLS role in Fabric
   - Test filtering works correctly

## 📈 Performance Notes

- **Security table refresh**: Set to refresh with dimension tables (weekly)
- **RLS performance**: Dynamic filtering may impact query performance
- **Caching**: Fabric caches RLS results for better performance
- **Monitoring**: Use Performance Analyzer to check query times

## 🎯 Next Steps

1. **Test all mock users** using "View as" feature
2. **Validate RLS filtering** works correctly for each role
3. **Document any issues** and adjust role filters if needed
4. **Prepare for production** by replacing mock users with real accounts
5. **Set up monitoring** for RLS performance and effectiveness