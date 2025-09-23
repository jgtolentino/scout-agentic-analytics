# Database Schema Documentation

*Auto-generated from database schema - awaiting first sync*

This documentation will be automatically populated when the Schema Sync Agent runs its first synchronization with the database.

## Schema Sync Status

🔄 **Initial Setup Complete**
- DDL triggers installed and active
- Schema drift detection enabled
- Documentation platform configured
- GitHub Actions workflows ready

⏳ **Awaiting First Sync**
To populate this documentation, run:
```bash
cd etl/agents
python schema_sync_agent.py --mode sync
```

## What Will Be Generated

Once the sync agent runs, this page will contain:

### Database Objects
- **Tables**: Complete column definitions, data types, constraints
- **Views**: Business logic views with column mappings
- **Procedures**: Stored procedure documentation
- **Functions**: User-defined function specifications

### ETL Integration
- **Canonical ID Columns**: Critical for transaction matching
- **Timestamp Policies**: SI-only timestamp enforcement
- **Contract Validation**: flatten.py safety checks

### Change Tracking
- **Schema Drift Log**: Historical change tracking
- **Sync Status**: Documentation synchronization state
- **Quality Gates**: ETL contract compliance

---

*This page will be automatically updated when schema changes are detected*