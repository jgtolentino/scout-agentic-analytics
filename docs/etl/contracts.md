# ETL Contract Validation

*Auto-generated ETL contract validation results*

## Overview

This document outlines the data contracts that ETL processes depend on and validates their current status. The Schema Sync Agent automatically monitors these contracts to ensure data pipeline integrity.

## Contract Validation Status

🔄 **Awaiting Initial Validation**
Contract validation will run automatically when the Schema Sync Agent performs its first sync.

To manually validate contracts:
```bash
cd etl/agents
python schema_sync_agent.py --mode validate
```

## Critical ETL Dependencies

### Canonical ID Normalization
The ETL system depends on normalized canonical transaction IDs for accurate data processing:

| Table | Column | Purpose | Status |
|-------|--------|---------|--------|
| `PayloadTransactions` | `canonical_tx_id_norm` | Core transaction matching | ⏳ Pending |
| `SalesInteractions` | `canonical_tx_id_norm` | Sales data correlation | ⏳ Pending |
| `TransactionItems` | `CanonicalTxID` | Product analysis | ⏳ Pending |

### Data Quality Requirements

- **Canonical ID Format**: `LOWER(REPLACE(canonical_tx_id,'-',''))` for consistent matching
- **Timestamp Policy**: All production views use SI-only timestamps
- **Change Tracking**: Enabled for efficient delta detection

## Contract Violation Impact

If any critical contracts are violated:

- ❌ **ETL processes may fail** - Data processing pipelines could break
- ❌ **flatten.py safety** - Data extraction scripts may encounter errors
- ❌ **Analytics accuracy** - Reporting and analytics may produce incorrect results
- ❌ **Canonical matching** - Transaction correlation across tables may fail

## Automated Protection

The Schema Sync Agent provides automated protection:

1. **Pre-deployment Validation** - Contracts checked before schema changes
2. **Real-time Monitoring** - DDL triggers capture all schema modifications
3. **GitHub Integration** - Contract violations trigger PR creation
4. **Documentation Updates** - Contract status automatically synchronized

## Recovery Procedures

If contract violations are detected:

1. **Review Schema Changes** - Identify which DDL operations caused violations
2. **Assess Impact** - Determine which ETL processes are affected
3. **Create Recovery Plan** - Design schema fixes to restore contract compliance
4. **Test ETL Pipelines** - Validate that fixes restore full functionality

---

*Contract validation runs automatically on schema changes*
*Last validation: Awaiting first sync*