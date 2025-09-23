#!/bin/bash

# Scout v7 Dashboard Deployment Debug Script
# Checks the scout-dashboard-xi deployment for common issues

set -e

echo "🔍 Scout v7 Dashboard Deployment Debug"
echo "======================================="

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo "❌ Error: Not in project root directory"
    echo "   Please run this script from /Users/tbwa/scout-v7/apps/scout-dashboard"
    exit 1
fi

# Check Vercel CLI
if ! command -v vercel &> /dev/null; then
    echo "❌ Error: Vercel CLI not found"
    echo "   Install with: npm i -g vercel"
    exit 1
fi

echo "✅ Vercel CLI found"

# 1. Link to Vercel project
echo ""
echo "📡 Step 1: Linking to Vercel project..."
vercel link --confirm

# 2. Check deployment status
echo ""
echo "🔍 Step 2: Checking deployment status..."
DEPLOYMENT_URL="https://scout-dashboard-xi.vercel.app"
echo "Deployment URL: $DEPLOYMENT_URL"

# Test health endpoint
echo ""
echo "🏥 Step 3: Testing health endpoints..."

echo "Testing /api/health..."
curl -s -w "Status: %{http_code}\n" "$DEPLOYMENT_URL/api/health" || echo "❌ Health check failed"

echo ""
echo "Testing /api/dq/summary..."
curl -s -w "Status: %{http_code}\n" "$DEPLOYMENT_URL/api/dq/summary" || echo "❌ DQ summary failed"

echo ""
echo "Testing /api/transactions/kpis..."
curl -s -w "Status: %{http_code}\n" "$DEPLOYMENT_URL/api/transactions/kpis" || echo "❌ KPI endpoint failed"

echo ""
echo "Testing /api/stores/geo..."
curl -s -w "Status: %{http_code}\n" "$DEPLOYMENT_URL/api/stores/geo" || echo "❌ Store geo failed"

# 3. Pull environment variables
echo ""
echo "🔧 Step 4: Pulling production environment..."
vercel env pull .env.production --environment=production --yes

# Check critical env vars
echo ""
echo "🔍 Step 5: Checking critical environment variables..."

if [ -f ".env.production" ]; then
    echo "✅ Environment file pulled successfully"

    # Check critical client vars
    if grep -q "NEXT_PUBLIC_SUPABASE_URL" .env.production; then
        echo "✅ NEXT_PUBLIC_SUPABASE_URL found"
    else
        echo "❌ NEXT_PUBLIC_SUPABASE_URL missing"
    fi

    if grep -q "NEXT_PUBLIC_SUPABASE_ANON_KEY" .env.production; then
        echo "✅ NEXT_PUBLIC_SUPABASE_ANON_KEY found"
    else
        echo "❌ NEXT_PUBLIC_SUPABASE_ANON_KEY missing"
    fi

    if grep -q "NEXT_PUBLIC_MAPBOX_TOKEN" .env.production; then
        echo "✅ NEXT_PUBLIC_MAPBOX_TOKEN found"
    else
        echo "⚠️  NEXT_PUBLIC_MAPBOX_TOKEN missing (map won't work)"
    fi

    # Check server vars
    if grep -q "SUPABASE_SERVICE_ROLE_KEY" .env.production; then
        echo "✅ SUPABASE_SERVICE_ROLE_KEY found"
    else
        echo "❌ SUPABASE_SERVICE_ROLE_KEY missing"
    fi

else
    echo "❌ Failed to pull environment variables"
fi

# 4. Get recent logs
echo ""
echo "📄 Step 6: Checking recent logs..."
vercel logs "$DEPLOYMENT_URL" --since=1h | head -20

# 5. Check recent deployments
echo ""
echo "🚀 Step 7: Recent deployments..."
vercel ls | grep scout-dashboard | head -5

echo ""
echo "✅ Debug complete!"
echo ""
echo "Next steps:"
echo "1. Check the health endpoint responses above"
echo "2. If environment variables are missing, add them in Vercel Dashboard"
echo "3. If all looks good, test locally with: cp .env.production .env.local && npm run dev"
echo "4. Deploy a preview with: vercel"
echo "5. Promote with: vercel --prod"