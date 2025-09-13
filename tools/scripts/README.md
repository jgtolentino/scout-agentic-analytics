# Database Migration Scripts

This directory contains helper scripts for managing Supabase database migrations and maintaining sync between the repository and remote database.

## Scripts Overview

### `new-migration.sh <name>`
Creates a new timestamped migration file.

```bash
./tools/scripts/new-migration.sh add_user_preferences
# Creates: supabase/migrations/20250823134745_add_user_preferences.sql
```

**Usage:**
- Provide a descriptive name in snake_case
- Edit the created SQL file with your changes
- Follow up with `push-and-types.sh` to apply

### `push-and-types.sh`
Applies migrations to remote database and regenerates TypeScript types.

```bash
./tools/scripts/push-and-types.sh
# 1. Pushes migrations to Supabase
# 2. Generates TypeScript types
# 3. Shows git status of changes
```

**What it does:**
- Runs `supabase db push` to apply migrations
- Generates types for schemas: public, auth, storage, scout_dash, masterdata, deep_research
- Updates `apps/web/src/lib/supabase.types.ts`

### `check-drift.sh`
Detects drift between remote database and local migrations.

```bash
./tools/scripts/check-drift.sh
# ✅ No drift.
# OR
# ❌ Drift detected. See .tmp/drift.sql
```

**Purpose:**
- Prevents unauthorized database changes
- Generates SQL to reconcile differences
- Exit code 2 indicates drift detected
- Used by GitHub Actions for validation

### `snapshot-schema.sh`
Creates a complete schema snapshot for documentation and audit purposes.

```bash
./tools/scripts/snapshot-schema.sh
# ✅ Schema snapshot updated at docs/db/schema_snapshot.sql
```

**Features:**
- Includes all tables, functions, policies
- Excludes data (structure only)
- Useful for code reviews and documentation
- Automatically committed by CI/CD

## Development Workflow

### Standard Change Process

1. **Create migration:**
   ```bash
   ./tools/scripts/new-migration.sh feature_name
   ```

2. **Edit SQL file:** Add your database changes

3. **Test locally (optional):**
   ```bash
   supabase db start  # Start local instance
   supabase db push   # Apply migrations
   ```

4. **Apply and generate types:**
   ```bash
   ./tools/scripts/push-and-types.sh
   ```

5. **Commit changes:**
   ```bash
   git add supabase/migrations/ apps/web/src/lib/supabase.types.ts
   git commit -m "feat: add feature_name schema"
   ```

### Emergency Drift Resolution

If someone changed the database via Supabase UI:

1. **Check for drift:**
   ```bash
   ./tools/scripts/check-drift.sh
   ```

2. **Review drift file:**
   ```bash
   cat .tmp/drift.sql
   ```

3. **Create migration from drift:**
   ```bash
   ./tools/scripts/new-migration.sh fix_drift
   # Copy relevant parts from .tmp/drift.sql
   ```

4. **Apply fix:**
   ```bash
   ./tools/scripts/push-and-types.sh
   ```

## CI/CD Integration

These scripts are used by GitHub Actions:

- **PR Validation:** `check-drift.sh` ensures no unauthorized changes
- **Main Deployment:** `push-and-types.sh` applies changes to production
- **Nightly Guard:** `check-drift.sh` detects drift and creates PRs
- **Documentation:** `snapshot-schema.sh` maintains schema snapshots

## File Permissions

Scripts are executable (`chmod +x`). If you get permission errors:

```bash
chmod +x tools/scripts/*.sh
```

## Requirements

- Supabase CLI installed and authenticated
- Project linked (`supabase link --project-ref cxzllzyxwpyptfretryc`)
- Git repository initialized
- Node.js/npm for TypeScript type generation

## Schema Coverage

Types are generated for these schemas:
- `public` - Default Postgres schema
- `auth` - Supabase authentication
- `storage` - Supabase storage
- `scout_dash` - Scout Dashboard data
- `masterdata` - Reference data
- `deep_research` - Analytics data

## Troubleshooting

### Common Issues

**Script not found:**
```bash
# Ensure you're in the repo root
cd /path/to/ai-aas-hardened-lakehouse
./tools/scripts/new-migration.sh test
```

**Permission denied:**
```bash
chmod +x tools/scripts/*.sh
```

**Supabase not linked:**
```bash
supabase link --project-ref cxzllzyxwpyptfretryc
```

**Migration fails:**
```bash
# Check syntax and dependencies
supabase db start
supabase db reset  # Fresh local DB
# Test migration locally first
```

### Getting Help

1. Run with Supabase debug: `supabase db push --debug`
2. Check GitHub Actions logs for CI/CD issues
3. Verify schema permissions in Supabase dashboard
4. Use `supabase status` to check local environment

## Best Practices

### Migration Naming
- Use descriptive snake_case names
- Include the purpose: `add_`, `fix_`, `remove_`, `update_`
- Examples: `add_user_preferences`, `fix_index_performance`, `remove_deprecated_table`

### SQL Best Practices
- Use `IF NOT EXISTS` for idempotent operations
- Include proper constraints and indexes
- Add comments for complex logic
- Test rollback scenarios where possible

### Type Safety
- Always regenerate types after schema changes
- Commit generated types with migrations
- Use strict TypeScript configuration
- Validate types in CI/CD pipeline

### Security
- Include RLS policies in migrations
- Grant minimal necessary permissions
- Never commit sensitive data
- Use environment variables for secrets