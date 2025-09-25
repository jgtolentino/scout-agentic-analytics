# CLAUDE.md — Secure Execution & Bruno Usage

> Principle: Claude Code never sees credentials and never executes raw SQL directly. All sensitive ops are delegated to **Bruno** or **Makefile targets** that resolve secrets from macOS **Keychain** (local) or **AZURE_SQL_CONN_STR** (CI).

## Non-negotiables
- No creds in prompts, code, env files, or logs.
- Claude only calls approved wrappers/targets:
  - `make flat`, `make crosstabs`, `make marts`, `make catalog-export`, `make doctor`
  - `bruno run bruno-analytics-complete.yml`
  - `./scripts/sql.sh -Q "<approved SELECT>"`
- Single DB source of truth: Keychain item `SQL-TBWA-ProjectScout-Reporting-Prod` (primary), env fallback `AZURE_SQL_CONN_STR`.

## Secrets — resolution order
1) macOS Keychain: service=`SQL-TBWA-ProjectScout-Reporting-Prod`, account=`scout-analytics`
2) Env fallback: `AZURE_SQL_CONN_STR` (for CI/Linux/Windows)

Add/update locally:
```bash
security add-generic-password -U \
  -s "SQL-TBWA-ProjectScout-Reporting-Prod" \
  -a "scout-analytics" \
  -w "<azure-sql-connection-string>"
```

## Allowed entry points

* **Makefile**
  * `make doctor` (env/Bruno/sqlcmd/DB identity guard)
  * `make flat` (exports 12-col CSV from `dbo.v_flat_export_sheet`)
  * `make marts` (exports marts CSVs)
  * `make crosstabs` (exports cross-tab CSVs)
  * `make catalog-export` (~140 live brand catalog)
* **Bruno**
  * `bruno run bruno-analytics-complete.yml` (infra + validations + exports)
* **Wrapper**
  * `./scripts/sql.sh -Q "<approved SELECT only>"`

## Wrapper scripts (never call sqlcmd directly)

`scripts/conn_default.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
CANDS=( "SQL-TBWA-ProjectScout-Reporting-Prod" "tbwa-scout-prod" "scout-analytics-prod" )
for s in "${CANDS[@]}"; do
  if CONN=$(security find-generic-password -s "$s" -a "scout-analytics" -w 2>/dev/null); then
    [[ -n "${CONN:-}" ]] && { printf '%s' "$CONN"; exit 0; }
  fi
done
[[ -n "${AZURE_SQL_CONN_STR:-}" ]] && { printf '%s' "$AZURE_SQL_CONN_STR"; exit 0; }
echo "No Azure SQL connection found (Keychain or AZURE_SQL_CONN_STR)." >&2; exit 1
```

## Database Connection Details
- **Server**: sqltbwaprojectscoutserver.database.windows.net
- **Database**: SQL-TBWA-ProjectScout-Reporting-Prod (CORRECT)
- **User**: Retrieved from secure credential store
- **Connection Status**: Use environment variables or secure credential management

## Project Status

### Nielsen Taxonomy Extension - COMPLETE ✅
- **All SQL scripts created and ready**
- **113 brands mapped to Nielsen hierarchy**
- **6-level taxonomy structure built**
- **JSON truncation issue solved**
- **Deployment script ready**: `./scripts/deploy_nielsen_taxonomy.sh`

### Key Files Created:
- `sql/analytics/008_nielsen_taxonomy_extension.sql`
- `sql/analytics/009_brand_to_nielsen_mapping.sql`
- `sql/analytics/010_nielsen_flat_export_final.sql`
- `scripts/deploy_nielsen_taxonomy.sh`
- `NIELSEN_TAXONOMY_EXTENSION_COMPLETE.md`

### Data Quality Problem Solved:
- **Original**: 48.3% "unspecified" categories
- **Target**: <10% unspecified with Nielsen mapping
- **Brand Coverage**: All 113 brands mapped to industry standards

### Next Action:
Once database access restored, run deployment script to transform analytics platform to Nielsen industry standard.

## Working Directory
/Users/tbwa/scout-v7/apps/dal-agent

## Session Context
Secure credential management system implemented. Nielsen taxonomy ready for deployment.