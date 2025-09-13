#!/usr/bin/env bash
# Deploy Scout Dashboard to Vercel Production

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Scout Dashboard Production Deployment${NC}"
echo "======================================"

# Check prerequisites
if ! command -v vercel &> /dev/null; then
    echo -e "${RED}❌ Vercel CLI not found. Install with: npm i -g vercel${NC}"
    exit 1
fi

if ! command -v pnpm &> /dev/null; then
    echo -e "${RED}❌ pnpm not found. Install with: npm i -g pnpm${NC}"
    exit 1
fi

# Environment check
if [ ! -f ".env.production.example" ]; then
    echo -e "${RED}❌ .env.production.example not found${NC}"
    exit 1
fi

# Pre-deployment checks
echo -e "\n${YELLOW}📋 Running pre-deployment checks...${NC}"

# 1. Check for exposed secrets
echo "Checking for exposed secrets..."
if [ -f ".gitleaks.toml" ]; then
    if command -v gitleaks &> /dev/null; then
        gitleaks detect --source . --verbose --redact || {
            echo -e "${RED}❌ Secrets detected! Fix before deploying.${NC}"
            exit 1
        }
    else
        echo "⚠️  Gitleaks not installed, skipping secret scan"
    fi
fi

# 2. Lint and type check
echo "Running lint and type checks..."
pnpm lint || {
    echo -e "${RED}❌ Linting failed${NC}"
    exit 1
}

pnpm type-check || {
    echo -e "${RED}❌ Type checking failed${NC}"
    exit 1
}

# 3. Run tests
echo "Running tests..."
pnpm test || {
    echo -e "${RED}❌ Tests failed${NC}"
    exit 1
}

# 4. Build locally to verify
echo "Building project..."
pnpm build || {
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
}

# 5. Check bundle size
echo "Checking bundle size..."
if [ -d ".next" ]; then
    size=$(du -sh .next | cut -f1)
    echo "Bundle size: $size"
fi

echo -e "${GREEN}✅ Pre-deployment checks passed${NC}"

# Deployment
echo -e "\n${YELLOW}🚀 Starting deployment...${NC}"

# Set environment variables in Vercel
echo "Setting production environment variables..."

# Read required env vars from .env.production.example
while IFS= read -r line; do
    # Skip comments and empty lines
    if [[ ! "$line" =~ ^# ]] && [[ -n "$line" ]] && [[ "$line" =~ = ]]; then
        var_name=$(echo "$line" | cut -d'=' -f1)
        if [[ ! "$var_name" =~ EXAMPLE ]] && [[ -n "$var_name" ]]; then
            echo "  - $var_name"
        fi
    fi
done < .env.production.example

echo -e "\n${YELLOW}⚠️  Make sure all environment variables are set in Vercel dashboard${NC}"
echo "Visit: https://vercel.com/your-team/scout-dashboard/settings/environment-variables"
echo ""
read -p "Have you set all required environment variables? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}❌ Deployment cancelled${NC}"
    exit 1
fi

# Deploy to production
echo -e "\n${YELLOW}Deploying to production...${NC}"
vercel --prod || {
    echo -e "${RED}❌ Deployment failed${NC}"
    exit 1
}

echo -e "\n${GREEN}✅ Deployment successful!${NC}"

# Post-deployment tasks
echo -e "\n${YELLOW}📋 Post-deployment tasks:${NC}"
echo "1. Verify deployment at: https://scout-dashboard.vercel.app"
echo "2. Check health endpoint: https://scout-dashboard.vercel.app/api/health"
echo "3. Monitor logs: vercel logs --follow"
echo "4. Set up monitoring alerts in Vercel dashboard"
echo "5. Configure custom domain if needed"
echo ""
echo -e "${GREEN}🎉 Scout Dashboard is now live in production!${NC}"