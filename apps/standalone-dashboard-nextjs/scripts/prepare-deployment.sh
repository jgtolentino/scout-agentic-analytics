#!/bin/bash
set -euo pipefail

echo "🚀 Preparing Next.js standalone deployment for Azure App Service"

# Check if we're in the right directory
if [ ! -f "next.config.ts" ]; then
  echo "❌ Error: next.config.ts not found. Run this script from the standalone-dashboard-nextjs directory."
  exit 1
fi

# Install dependencies
echo "📦 Installing dependencies..."
npm ci

# Build the application
echo "🔨 Building Next.js application..."
npm run build

# Verify standalone output was created
if [ ! -d ".next/standalone" ]; then
  echo "❌ Error: Standalone build not found. Check next.config.ts has output: 'standalone'"
  exit 1
fi

# Prepare deployment directory
DEPLOY_DIR="deploy"
echo "📁 Preparing deployment directory: $DEPLOY_DIR"
rm -rf "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"

# Copy standalone server files
echo "📋 Copying standalone server files..."
cp -r .next/standalone/* "$DEPLOY_DIR"/

# Copy static assets
echo "🎨 Copying static assets..."
mkdir -p "$DEPLOY_DIR/.next"
cp -r .next/static "$DEPLOY_DIR/.next/static"

# Copy public directory if it exists
if [ -d "public" ]; then
  echo "🌐 Copying public assets..."
  cp -r public "$DEPLOY_DIR/public"
fi

# Copy package.json for npm start
echo "📄 Copying package.json..."
cp package.json "$DEPLOY_DIR"/

# Copy package-lock.json if it exists
if [ -f "package-lock.json" ]; then
  echo "🔒 Copying package-lock.json..."
  cp package-lock.json "$DEPLOY_DIR"/
fi

# Copy environment configuration
if [ -f ".env.production" ]; then
  echo "⚙️  Copying production environment config..."
  cp .env.production "$DEPLOY_DIR"/.env.production
fi

# Create a minimal package.json for Azure
echo "📝 Creating optimized package.json for deployment..."
cat > "$DEPLOY_DIR/package.json" <<EOF
{
  "name": "scout-dashboard-standalone",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "start": "NODE_ENV=production node server.js"
  },
  "dependencies": {
    "mssql": "^11.0.1"
  },
  "engines": {
    "node": ">=20.0.0",
    "npm": ">=10.0.0"
  }
}
EOF

echo "🧪 Testing standalone server locally..."
cd "$DEPLOY_DIR"
PORT=4010 NODE_ENV=production timeout 10s node server.js > /tmp/standalone-test.log 2>&1 &
PID=$!
sleep 3

# Test if server responds
if curl -s http://localhost:4010 > /dev/null; then
  echo "✅ Standalone server test passed"
else
  echo "⚠️  Standalone server test failed (this may be normal if database connection is required)"
  echo "📋 Server log:"
  cat /tmp/standalone-test.log || true
fi

# Kill test server
kill $PID > /dev/null 2>&1 || true
cd ..

# Create deployment zip
ZIP_FILE="scout-dashboard-azure.zip"
echo "📦 Creating deployment zip: $ZIP_FILE"
cd "$DEPLOY_DIR" && zip -r "../$ZIP_FILE" . && cd ..

echo "🎉 Deployment preparation complete!"
echo "📁 Deploy directory: $DEPLOY_DIR"
echo "📦 Deployment zip: $ZIP_FILE"
echo ""
echo "Next steps for Azure App Service:"
echo "1. Create Azure App Service (Linux, Node 20)"
echo "2. Enable System-assigned Managed Identity"
echo "3. Grant SQL access to the Managed Identity"
echo "4. Set environment variables in App Service Configuration"
echo "5. Upload and deploy the zip file"
echo "6. Set Startup Command: 'npm start'"
echo ""
echo "Environment variables to set in Azure App Service:"
echo "- NODE_ENV=production"
echo "- MI_ENABLED=1"
echo "- AZURE_SQL_SERVER=sqltbwaprojectscoutserver.database.windows.net"
echo "- AZURE_SQL_DATABASE=SQL-TBWA-ProjectScout-Reporting-Prod"
echo "- NEXT_PUBLIC_DATA_SOURCE=sql"