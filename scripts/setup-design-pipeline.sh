#!/bin/bash
set -euo pipefail

echo "🎨 Setting up Figma-to-Code Design Pipeline"

# Check prerequisites
if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found. Please install Node.js first."
    exit 1
fi

if ! command -v pnpm &> /dev/null && ! command -v npm &> /dev/null; then
    echo "❌ Package manager not found. Please install pnpm or npm."
    exit 1
fi

# Set package manager
PKG_MGR="pnpm"
if ! command -v pnpm &> /dev/null; then
    PKG_MGR="npm"
fi

echo "📦 Using package manager: $PKG_MGR"

# Install dependencies
echo "📦 Installing dependencies..."
if [ "$PKG_MGR" = "pnpm" ]; then
    pnpm add -D @figma/code-connect @playwright/test @storybook/react @storybook/addon-designs @tokens-studio/sd-transforms pixelmatch pngjs style-dictionary
else
    npm install -D @figma/code-connect @playwright/test @storybook/react @storybook/addon-designs @tokens-studio/sd-transforms pixelmatch pngjs style-dictionary
fi

# Install global tools
echo "🔧 Installing global tools..."
npm install -g style-dictionary @figma/code-connect

# Install Playwright browsers
echo "🎭 Installing Playwright browsers..."
npx playwright install

# Setup environment variables template
echo "🔐 Creating environment template..."
cat > .env.design.example << 'EOF'
# Figma Design File IDs
FIGMA_FILE_ID_R19=MxZzjY9lcdl9sYERJfAFYN
FIGMA_FILE_ID_HEALTH=your-health-dashboard-file-id

# Figma Access Token (get from figma.com/developers)
FIGMA_TOKEN=your-figma-token-here
EOF

# Create initial design tokens if they don't exist
if [ ! -f "design/tokens/design.tokens.json" ]; then
    echo "🎨 Creating initial design tokens..."
    mkdir -p design/tokens
    cat > design/tokens/design.tokens.json << 'EOF'
{
  "color": {
    "health-primary": { "value": "#10B981" },
    "health-secondary": { "value": "#6366F1" },
    "r19-blue-6": { "value": "#3B82F6" },
    "r19-red-6": { "value": "#EF4444" },
    "bg": { "value": "#FFFFFF" },
    "fg": { "value": "#111827" },
    "fg-muted": { "value": "#6B7280" },
    "border": { "value": "#E5E7EB" },
    "ring-bg": { "value": "#F3F4F6" }
  },
  "spacing": {
    "1": { "value": "4px" },
    "2": { "value": "8px" },
    "3": { "value": "12px" },
    "4": { "value": "16px" }
  },
  "radius": {
    "sm": { "value": "4px" },
    "md": { "value": "8px" },
    "lg": { "value": "12px" }
  }
}
EOF
fi

# Build initial design tokens
echo "🏗️  Building design tokens..."
style-dictionary build

# Setup Storybook if not exists
if [ ! -f ".storybook/main.ts" ]; then
    echo "📖 Initializing Storybook..."
    npx storybook@latest init --type react --no-dev
    
    # Add design addon to Storybook
    cat > .storybook/main.ts << 'EOF'
import type { StorybookConfig } from '@storybook/react';

const config: StorybookConfig = {
  stories: [
    "../apps/**/src/**/*.stories.@(js|jsx|ts|tsx|mdx)",
    "../packages/**/src/**/*.stories.@(js|jsx|ts|tsx|mdx)"
  ],
  addons: [
    "@storybook/addon-essentials",
    "@storybook/addon-designs"
  ],
  framework: {
    name: "@storybook/react",
    options: {},
  },
};

export default config;
EOF
fi

echo "✅ Design pipeline setup complete!"
echo ""
echo "Next steps:"
echo "1. Copy .env.design.example to .env and fill in your Figma credentials"
echo "2. Update FIGMA_FILE_ID_* with your actual Figma file IDs"  
echo "3. Run 'npm run design:sync' to sync from Figma"
echo "4. Run 'npm run storybook' to start component development"
echo "5. Run 'npm run parity:test' to run visual regression tests"
echo ""
echo "🎯 Daily workflow:"
echo "• Make design changes in Figma"
echo "• Run 'npm run design:sync' to pull changes"
echo "• Update components and run 'npm run parity:test'"
echo "• Only merge when parity tests pass!"