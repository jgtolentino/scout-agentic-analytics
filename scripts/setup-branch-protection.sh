#!/bin/bash

# Script to set up GitHub branch protection rules using GitHub CLI
# Requires: gh CLI tool to be installed and authenticated

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔒 Setting up branch protection rules..."

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) is not installed. Please install it first.${NC}"
    echo "Visit: https://cli.github.com/"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ Not authenticated with GitHub CLI. Run 'gh auth login' first.${NC}"
    exit 1
fi

# Get repository info
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
echo "📦 Repository: $REPO"

# Function to create branch protection
create_branch_protection() {
    local branch=$1
    local require_reviews=$2
    local review_count=$3
    local enforce_admins=$4
    
    echo -e "\n${YELLOW}Protecting branch: $branch${NC}"
    
    # Create protection rule
    gh api \
        --method PUT \
        -H "Accept: application/vnd.github+json" \
        "/repos/$REPO/branches/$branch/protection" \
        --field required_status_checks='{"strict":true,"contexts":["Security Check","TypeScript Check","Run Tests"]}' \
        --field enforce_admins=$enforce_admins \
        --field required_pull_request_reviews="{\"dismiss_stale_reviews\":true,\"require_code_owner_reviews\":true,\"required_approving_review_count\":$review_count}" \
        --field restrictions=null \
        --field allow_force_pushes=false \
        --field allow_deletions=false \
        --field required_conversation_resolution=true \
        --field lock_branch=false \
        --field allow_fork_syncing=true
    
    echo -e "${GREEN}✅ Branch $branch protected${NC}"
}

# Main branch protection
create_branch_protection "main" true 2 true

# Develop branch protection (if exists)
if gh api "/repos/$REPO/branches/develop" &> /dev/null; then
    create_branch_protection "develop" true 1 false
fi

# Create deployment environments
echo -e "\n${YELLOW}Setting up deployment environments...${NC}"

# Preview environment
gh api \
    --method PUT \
    -H "Accept: application/vnd.github+json" \
    "/repos/$REPO/environments/preview" \
    --field wait_timer=0 \
    --field deployment_branch_policy='{"protected_branches":false,"custom_branch_policies":true}'

echo -e "${GREEN}✅ Preview environment configured${NC}"

# Staging environment
gh api \
    --method PUT \
    -H "Accept: application/vnd.github+json" \
    "/repos/$REPO/environments/staging" \
    --field wait_timer=5 \
    --field deployment_branch_policy='{"protected_branches":false,"custom_branch_policies":true}'

echo -e "${GREEN}✅ Staging environment configured${NC}"

# Production environment
gh api \
    --method PUT \
    -H "Accept: application/vnd.github+json" \
    "/repos/$REPO/environments/production" \
    --field wait_timer=30 \
    --field deployment_branch_policy='{"protected_branches":true,"custom_branch_policies":false}'

echo -e "${GREEN}✅ Production environment configured${NC}"

# Create required secrets reminder
echo -e "\n${YELLOW}⚠️  Don't forget to add these secrets to your repository:${NC}"
echo "  - VERCEL_TOKEN"
echo "  - VERCEL_ORG_ID"
echo "  - VERCEL_PROJECT_ID"
echo "  - CODECOV_TOKEN (optional)"
echo ""
echo "Add them at: https://github.com/$REPO/settings/secrets/actions"

echo -e "\n${GREEN}🎉 Branch protection setup complete!${NC}"