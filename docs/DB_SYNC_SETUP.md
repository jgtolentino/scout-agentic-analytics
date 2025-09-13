# Supabase-GitHub Database Sync Setup

This document outlines the complete setup for maintaining Supabase → GitHub synchronization to ensure the repository is the single source of truth for database schema changes.

## Overview

The system implements:
- **Repository as source of truth**: All DB changes become migrations committed to the repo
- **Automated CI/CD**: GitHub Actions push migrations to Supabase
- **Drift detection**: Nightly checks detect out-of-band edits and create PRs
- **Type generation**: Automatic TypeScript type generation

## Setup Components

### 1. Helper Scripts (`tools/scripts/`)

- `new-migration.sh <name>` - Creates a new timestamped migration file
- `push-and-types.sh` - Pushes migrations and regenerates TypeScript types
- `check-drift.sh` - Detects drift between remote DB and local migrations
- `snapshot-schema.sh` - Creates schema snapshot for documentation

### 2. GitHub Actions Workflows (`.github/workflows/`)

#### a) `db-validate.yml` (Pull Request validation)
- Validates migrations apply cleanly
- Checks for drift against remote DB
- Generates preview TypeScript types
- Triggers on PR changes to `supabase/**`, `tools/scripts/**`

#### b) `db-deploy.yml` (Main branch deployment)
- Pushes migrations to remote Supabase
- Generates and commits updated TypeScript types
- Creates schema snapshot
- Triggers on pushes to main branch

#### c) `db-drift-nightly.yml` (Drift guard)
- Runs daily at 2:00 AM PH time (18:00 UTC)
- Detects unauthorized DB changes
- Opens PR with drift SQL for review
- Can be triggered manually via workflow_dispatch

### 3. Required GitHub Secrets

Add these secrets in repository settings → Secrets and variables → Actions:

- `SUPABASE_ACCESS_TOKEN` - Personal access token from Supabase account settings

## Developer Workflow

### Making Database Changes

1. **Create migration**:
   ```bash
   ./tools/scripts/new-migration.sh add_new_feature
   ```

2. **Edit the created SQL file** in `supabase/migrations/`

3. **Test locally** (optional):
   ```bash
   supabase db start
   supabase db push
   ```

4. **Push and generate types**:
   ```bash
   ./tools/scripts/push-and-types.sh
   ```

5. **Commit and create PR**:
   ```bash
   git add .
   git commit -m "feat: add new feature schema"
   git push origin feature-branch
   ```

6. **PR validation**: GitHub Actions will validate the migration and check for drift

7. **Merge**: Once approved, changes are automatically deployed to remote Supabase

### Emergency Procedures

If someone makes changes via Supabase UI (creating drift):

1. **Nightly drift guard** will detect and create a PR
2. **Manual check**: Run `./tools/scripts/check-drift.sh`
3. **Review drift SQL** in `.tmp/drift.sql`
4. **Create proper migration** from the drift SQL
5. **Apply migration** to restore sync

## File Structure

```
├── .github/workflows/
│   ├── db-validate.yml      # PR validation
│   ├── db-deploy.yml        # Main branch deployment
│   └── db-drift-nightly.yml # Drift detection
├── tools/scripts/
│   ├── new-migration.sh     # Create migration
│   ├── push-and-types.sh    # Push & generate types
│   ├── check-drift.sh       # Check drift
│   └── snapshot-schema.sh   # Schema snapshot
├── supabase/
│   ├── migrations/          # All database migrations
│   └── config.toml         # Supabase configuration
├── apps/web/src/lib/
│   └── supabase.types.ts   # Generated TypeScript types
└── docs/db/
    └── schema_snapshot.sql # Latest schema snapshot
```

## Branch Protection Rules

Recommended branch protection for `main`:
- Require status checks to pass: `DB Validate (PR)`
- Require branches to be up to date before merging
- Restrict pushes that create new migrations without validation

## Team Guidelines

### DO ✅
- Always create migrations for schema changes
- Use the helper scripts for consistency
- Test migrations locally before pushing
- Include descriptive migration names
- Review drift PRs promptly

### DON'T ❌
- Make schema changes via Supabase UI
- Push migrations without testing
- Ignore drift detection alerts
- Commit generated types manually (they're auto-generated)
- Skip PR validation checks

## Monitoring

### Health Checks
- CI/CD pipeline status in GitHub Actions
- Daily drift detection reports
- Schema snapshot updates
- TypeScript type generation

### Alerts
- Failed migrations (via GitHub Actions notifications)
- Drift detection (via automated PR creation)
- Schema validation errors (via PR checks)

## Troubleshooting

### Common Issues

1. **Migration fails to apply**
   - Check migration syntax
   - Ensure proper dependencies
   - Test on local instance first

2. **Drift detected**
   - Review `.tmp/drift.sql`
   - Create proper migration
   - Never ignore drift alerts

3. **Type generation fails**
   - Ensure Supabase CLI is authenticated
   - Check schema permissions
   - Verify linked project reference

### Getting Help

1. Check GitHub Actions logs for detailed error messages
2. Run scripts with `--debug` flag for troubleshooting
3. Use `supabase status` to verify local setup
4. Check Supabase project permissions and access tokens

## Security Considerations

- Personal access tokens have appropriate scopes
- RLS policies are included in migrations
- Generated types don't expose sensitive data
- Schema snapshots are sanitized of sensitive information

---

This setup ensures that your Supabase database schema is always version-controlled, tested, and synchronized with your repository, preventing drift and maintaining data integrity across environments.