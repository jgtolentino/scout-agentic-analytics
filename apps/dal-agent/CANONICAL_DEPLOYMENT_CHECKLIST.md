# Canonical Table Deployment Checklist

## ✅ Pre-Deployment Validation

- [ ] Database connectivity confirmed (`make doctor-db`)
- [ ] All SQL files present and validated (`./test_canonical_structure.sh`)
- [ ] Backup strategy confirmed (`--backup` flag ready)
- [ ] Schema permissions verified (CREATE SCHEMA, VIEW, PROCEDURE)

## ✅ Deployment Steps

### 1. Deploy Canonical Schema
```bash
make canonical-deploy
```
**Expected Output:**
- ✅ Canonical schema definition created with 13 columns
- ✅ Canonical flat views created successfully
- ✅ Validation procedures created
- ✅ Export procedures created

### 2. Validate Deployment
```bash
make canonical-validate
```
**Pass Criteria:**
- All views show "✅ FULLY COMPLIANT"
- No CRITICAL or HIGH severity issues
- Column count = 13 for all canonical views

### 3. Smoke Test Data
```sql
-- Row volume check (expect ~12,192 for full mart)
SELECT COUNT(*) AS total_rows FROM gold.v_transactions_flat_canonical;

-- Sample data inspection
SELECT TOP 5 * FROM gold.v_transactions_flat_canonical ORDER BY Transaction_ID;

-- Null validation for required fields
SELECT
    SUM(CASE WHEN Transaction_ID IS NULL THEN 1 ELSE 0 END) AS null_txn_id,
    SUM(CASE WHEN Category IS NULL THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN Brand IS NULL THEN 1 ELSE 0 END) AS null_brand,
    COUNT(*) AS total_rows
FROM gold.v_transactions_flat_canonical;
```
**Pass Criteria:**
- `total_rows` > 0 and matches expected volume
- `null_txn_id` = 0 (Transaction_ID never NULL)
- Sample data looks reasonable

## ✅ Export Testing

### 4. Test Sample Export (Quick)
```bash
make canonical-sample
```
**Pass Criteria:**
- File created: `out/canonical/canonical_sample_*.csv`
- Opens cleanly in Numbers/Excel
- Header row matches exactly: `Transaction_ID,Transaction_Value,Basket_Size,Category,Brand,Daypart,Demographics_Age_Gender_Role,Weekday_vs_Weekend,Time_of_Transaction,Location,Other_Products,Was_Substitution,Export_Timestamp`

### 5. Test Full Export
```bash
make canonical-export
```
**Pass Criteria:**
- File created: `out/canonical/canonical_flat_*.csv.gz`
- Manifest created: `out/canonical/export_manifest_*.json`
- Manifest shows: `"row_count" > 0`, valid `"md5_hash"`
- Header validation:
  ```bash
  gunzip -c out/canonical/canonical_flat_*.csv.gz | head -1 | grep -Fx "Transaction_ID,Transaction_Value,Basket_Size,Category,Brand,Daypart,Demographics_Age_Gender_Role,Weekday_vs_Weekend,Time_of_Transaction,Location,Other_Products,Was_Substitution,Export_Timestamp"
  ```

### 6. Test Category Exports
```bash
make canonical-tobacco
make canonical-laundry
```
**Pass Criteria:**
- Tobacco file contains only tobacco-related transactions
- Laundry file contains only laundry-related transactions
- Both maintain 13-column structure

## ✅ Production Integration

### 7. Update Existing Workflows
- [ ] Update any scripts referencing `dbo.v_flat_export_sheet` → `gold.v_transactions_flat_canonical`
- [ ] Update dashboard connections to use canonical view
- [ ] Update any ETL processes to expect 13-column structure

### 8. Documentation Updates
- [ ] Update API documentation with canonical schema
- [ ] Update data dictionary with 13-column definitions
- [ ] Share runbook with stakeholders (Paolo, Dan, Jaymie)

## ✅ Quality Gates

### 9. Schema Compliance Monitoring
```bash
make canonical-status
```
**Ongoing Monitoring:**
- All views show "✅ Compliant"
- Set up alerts if compliance status changes
- Regular validation runs (weekly)

### 10. Data Quality Monitoring
```sql
-- Run weekly to monitor data quality
EXEC dbo.sp_validate_export_data @sample_size = 1000;
```
**Quality Thresholds:**
- NULL required fields: 0
- Invalid amounts (≤0): <1%
- Invalid basket sizes (≤0): 0
- Unspecified categories: <10%

## ✅ Rollback Plan (if needed)

### If Issues Detected:
1. **Stop using canonical exports immediately**
2. **Execute rollback:**
   ```bash
   ./scripts/migrate_to_canonical.sh --rollback /path/to/backup/directory
   ```
3. **Verify rollback:**
   ```bash
   make flat-export  # Should work with original structure
   ```
4. **Investigate and fix issues**
5. **Re-test deployment on non-production first**

## ✅ Success Criteria Summary

| Component | Pass Criteria | Command |
|-----------|---------------|---------|
| **Schema** | 13 columns defined, all compliant | `make canonical-validate` |
| **Data** | Row count matches, no NULL required fields | SQL smoke tests |
| **Exports** | Clean CSV with correct headers, valid manifest | `make canonical-export` |
| **Categories** | Tobacco/Laundry exports work with filtering | `make canonical-tobacco canonical-laundry` |
| **Sample** | Opens in Numbers/Excel without issues | `make canonical-sample` |

## ✅ Post-Deployment Actions

- [ ] Share sample file with Paolo for spreadsheet testing
- [ ] Update existing exports to use canonical structure
- [ ] Schedule regular compliance validation (weekly)
- [ ] Archive old export procedures (mark as deprecated)
- [ ] Update team training materials

---

## Quick Commands Reference

```bash
# Deploy everything
make canonical-deploy

# Validate compliance
make canonical-validate

# Export samples for testing
make canonical-sample

# Full production export
make canonical-export

# Category-specific exports
make canonical-tobacco
make canonical-laundry

# Monitor compliance
make canonical-status

# Rollback if needed
./scripts/migrate_to_canonical.sh --rollback <backup_dir>
```

## Emergency Contacts & Escalation

If deployment issues occur:
1. **Database Issues**: Run `make doctor-db` for diagnostics
2. **Schema Issues**: Check `migration_*.log` file
3. **Export Issues**: Verify database connectivity and view permissions
4. **Critical Issues**: Use rollback procedure immediately

---

**Deployment Complete When:**
- ✅ All checklist items verified
- ✅ Sample file opens cleanly in Numbers/Excel
- ✅ Full export generates correctly
- ✅ Category exports work properly
- ✅ Schema compliance monitoring active