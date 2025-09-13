#!/usr/bin/env bash
set -euo pipefail

echo "🔍 Validating Supabase-GitHub sync setup..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

success_count=0
error_count=0

check_pass() {
    echo -e "${GREEN}✅ $1${NC}"
    ((success_count++))
}

check_fail() {
    echo -e "${RED}❌ $1${NC}"
    ((error_count++))
}

check_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if we're in a git repo
if git rev-parse --git-dir > /dev/null 2>&1; then
    check_pass "Git repository detected"
else
    check_fail "Not in a Git repository"
fi

# Check Supabase CLI
if command -v supabase &> /dev/null; then
    check_pass "Supabase CLI installed"
    echo "   Version: $(supabase --version 2>/dev/null || echo 'unknown')"
else
    check_fail "Supabase CLI not found. Install from: https://supabase.com/docs/guides/cli"
fi

# Check if Supabase is initialized
if [ -f "supabase/config.toml" ]; then
    check_pass "Supabase project initialized"
else
    check_fail "Supabase not initialized. Run: supabase init"
fi

# Check helper scripts
scripts=("new-migration.sh" "push-and-types.sh" "check-drift.sh" "snapshot-schema.sh")
for script in "${scripts[@]}"; do
    if [ -x "tools/scripts/$script" ]; then
        check_pass "Script tools/scripts/$script exists and is executable"
    elif [ -f "tools/scripts/$script" ]; then
        check_warn "Script tools/scripts/$script exists but is not executable"
        echo "   Run: chmod +x tools/scripts/$script"
    else
        check_fail "Script tools/scripts/$script not found"
    fi
done

# Check GitHub Actions workflows
workflows=("db-validate.yml" "db-deploy.yml" "db-drift-nightly.yml")
for workflow in "${workflows[@]}"; do
    if [ -f ".github/workflows/$workflow" ]; then
        check_pass "GitHub workflow .github/workflows/$workflow exists"
    else
        check_fail "GitHub workflow .github/workflows/$workflow not found"
    fi
done

# Check TypeScript types location
if [ -d "apps/web/src/lib" ]; then
    check_pass "TypeScript types directory exists: apps/web/src/lib"
    if [ -f "apps/web/src/lib/supabase.types.ts" ]; then
        check_pass "TypeScript types file exists"
    else
        check_warn "TypeScript types file not found. Will be generated on first run."
    fi
else
    check_fail "TypeScript types directory not found: apps/web/src/lib"
fi

# Check docs directory
if [ -d "docs" ]; then
    check_pass "Documentation directory exists"
    mkdir -p docs/db
    check_pass "Database docs directory created: docs/db"
else
    check_warn "Creating docs directory"
    mkdir -p docs/db
fi

# Check migrations directory
if [ -d "supabase/migrations" ]; then
    migration_count=$(find supabase/migrations -name "*.sql" -type f | wc -l)
    check_pass "Migrations directory exists with $migration_count migration(s)"
else
    check_fail "Migrations directory not found: supabase/migrations"
fi

# Check .tmp directory for drift detection
mkdir -p .tmp
check_pass "Drift detection directory ready: .tmp"

# Test new migration script
echo ""
echo "🧪 Testing migration creation..."
if [ -x "tools/scripts/new-migration.sh" ]; then
    test_migration="tools/scripts/new-migration.sh test_validation"
    if $test_migration > /dev/null 2>&1; then
        check_pass "Migration creation script works"
        # Clean up test migration
        latest_migration=$(find supabase/migrations -name "*test_validation.sql" -type f | head -1)
        if [ -f "$latest_migration" ]; then
            rm "$latest_migration"
            echo "   Cleaned up test migration"
        fi
    else
        check_fail "Migration creation script failed"
    fi
fi

# Summary
echo ""
echo "📊 Validation Summary:"
echo "   ✅ Passed: $success_count"
echo "   ❌ Failed: $error_count"

if [ $error_count -eq 0 ]; then
    echo -e "${GREEN}"
    echo "🎉 Setup validation passed! Your Supabase-GitHub sync is ready."
    echo ""
    echo "Next steps:"
    echo "1. Set SUPABASE_ACCESS_TOKEN secret in GitHub repository settings"
    echo "2. Link your Supabase project: supabase link --project-ref cxzllzyxwpyptfretryc"
    echo "3. Create your first migration: ./tools/scripts/new-migration.sh initial_setup"
    echo "4. Apply migrations: ./tools/scripts/push-and-types.sh"
    echo -e "${NC}"
    exit 0
else
    echo -e "${RED}"
    echo "❌ Setup validation failed. Please fix the errors above."
    echo ""
    echo "Common fixes:"
    echo "- Install Supabase CLI: https://supabase.com/docs/guides/cli"
    echo "- Make scripts executable: chmod +x tools/scripts/*.sh"
    echo "- Initialize Supabase: supabase init"
    echo "- Create missing directories manually"
    echo -e "${NC}"
    exit 1
fi