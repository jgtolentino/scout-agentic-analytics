#!/bin/bash

# NPM Provenance Setup Script
# This script configures npm for package provenance and attestation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔐 Configuring NPM Package Provenance...${NC}"

# Check npm version
NPM_VERSION=$(npm --version)
MAJOR_VERSION=$(echo $NPM_VERSION | cut -d. -f1)
MINOR_VERSION=$(echo $NPM_VERSION | cut -d. -f2)

echo "Current npm version: $NPM_VERSION"

# Check if npm supports provenance (9.5+)
if [ "$MAJOR_VERSION" -lt 9 ] || ([ "$MAJOR_VERSION" -eq 9 ] && [ "$MINOR_VERSION" -lt 5 ]); then
    echo -e "${YELLOW}⚠️  npm $NPM_VERSION doesn't support provenance attestation.${NC}"
    echo "Please upgrade to npm 9.5 or higher:"
    echo "  npm install -g npm@latest"
    exit 1
fi

# Enable provenance in .npmrc
echo -e "\n${YELLOW}Configuring .npmrc for provenance...${NC}"
if ! grep -q "provenance=true" .npmrc 2>/dev/null; then
    echo "provenance=true" >> .npmrc
    echo -e "${GREEN}✅ Added provenance=true to .npmrc${NC}"
else
    echo "Provenance already enabled in .npmrc"
fi

# Create publish workflow with provenance
echo -e "\n${YELLOW}Creating GitHub Action for npm publish with provenance...${NC}"

mkdir -p .github/workflows

cat > .github/workflows/npm-publish-provenance.yml << 'EOF'
name: Publish to npm with Provenance

on:
  release:
    types: [created]
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to publish (e.g., 1.0.0)'
        required: true
        type: string

permissions:
  contents: read
  id-token: write  # Required for provenance

jobs:
  publish:
    name: Publish with Provenance
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          registry-url: 'https://registry.npmjs.org'
          cache: 'npm'
      
      - name: Verify npm version
        run: |
          NPM_VERSION=$(npm --version)
          echo "npm version: $NPM_VERSION"
          
          # Ensure npm 9.5+ for provenance
          MAJOR=$(echo $NPM_VERSION | cut -d. -f1)
          MINOR=$(echo $NPM_VERSION | cut -d. -f2)
          
          if [ "$MAJOR" -lt 9 ] || ([ "$MAJOR" -eq 9 ] && [ "$MINOR" -lt 5 ]); then
            echo "❌ npm $NPM_VERSION doesn't support provenance. Upgrading..."
            npm install -g npm@latest
          fi
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run tests
        run: npm test
      
      - name: Build
        run: npm run build
      
      - name: Set version
        if: github.event.inputs.version
        run: npm version ${{ github.event.inputs.version }} --no-git-tag-version
      
      - name: Publish with provenance
        run: npm publish --provenance --access public
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
      
      - name: Verify provenance
        run: |
          PACKAGE_NAME=$(node -p "require('./package.json').name")
          PACKAGE_VERSION=$(node -p "require('./package.json').version")
          
          echo "Verifying provenance for $PACKAGE_NAME@$PACKAGE_VERSION"
          
          # Wait for npm to process
          sleep 10
          
          # Check provenance
          npm view "$PACKAGE_NAME@$PACKAGE_VERSION" --json | jq '.dist.attestations'
EOF

echo -e "${GREEN}✅ Created npm publish workflow with provenance${NC}"

# Create script to verify provenance
echo -e "\n${YELLOW}Creating provenance verification script...${NC}"

cat > scripts/verify-provenance.js << 'EOF'
#!/usr/bin/env node

const { execSync } = require('child_process');
const fs = require('fs');

const colors = {
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  reset: '\x1b[0m'
};

async function verifyProvenance(packageName, version) {
  try {
    console.log(`${colors.blue}🔍 Verifying provenance for ${packageName}@${version}...${colors.reset}`);
    
    // Get package info
    const packageInfo = JSON.parse(
      execSync(`npm view ${packageName}@${version} --json`, { encoding: 'utf-8' })
    );
    
    // Check for attestations
    if (packageInfo.dist && packageInfo.dist.attestations) {
      console.log(`${colors.green}✅ Package has provenance attestations!${colors.reset}`);
      
      const attestations = packageInfo.dist.attestations;
      console.log(`\nAttestations found: ${attestations.length}`);
      
      attestations.forEach((attestation, index) => {
        console.log(`\nAttestation ${index + 1}:`);
        console.log(`  Type: ${attestation.predicateType}`);
        console.log(`  URL: ${attestation.url}`);
      });
      
      // Verify signatures if npm supports it
      try {
        execSync(`npm audit signatures`, { stdio: 'inherit' });
      } catch (e) {
        console.log(`${colors.yellow}⚠️  Could not verify signatures (requires npm 9.5+)${colors.reset}`);
      }
      
      return true;
    } else {
      console.log(`${colors.yellow}⚠️  No provenance attestations found${colors.reset}`);
      return false;
    }
  } catch (error) {
    console.error(`${colors.red}❌ Error verifying provenance: ${error.message}${colors.reset}`);
    return false;
  }
}

// Check local package
async function checkLocalPackage() {
  try {
    const packageJson = JSON.parse(fs.readFileSync('package.json', 'utf-8'));
    const { name, version } = packageJson;
    
    // Try to verify if published
    await verifyProvenance(name, version);
  } catch (error) {
    console.log(`${colors.yellow}Package not published or error reading package.json${colors.reset}`);
  }
}

// Allow checking specific packages
if (process.argv.length > 2) {
  const [packageName, version = 'latest'] = process.argv.slice(2);
  verifyProvenance(packageName, version);
} else {
  checkLocalPackage();
}
EOF

chmod +x scripts/verify-provenance.js

echo -e "${GREEN}✅ Created provenance verification script${NC}"

# Update package.json scripts
echo -e "\n${YELLOW}Updating package.json scripts...${NC}"
npm pkg set scripts.verify:provenance="node scripts/verify-provenance.js"
npm pkg set scripts.publish:provenance="npm publish --provenance"

# Create documentation
echo -e "\n${YELLOW}Creating provenance documentation...${NC}"

cat > docs/PROVENANCE.md << 'EOF'
# NPM Package Provenance

## Overview

Package provenance provides verifiable information about how and where a package was built, establishing a chain of trust from source code to published package.

## Requirements

- npm 9.5 or higher
- GitHub Actions (for automated publishing)
- NPM account with publishing permissions

## Configuration

### Local Configuration (.npmrc)

```ini
provenance=true
```

### GitHub Actions Configuration

The workflow `.github/workflows/npm-publish-provenance.yml` automatically:
1. Builds the package in a secure environment
2. Generates provenance attestations
3. Publishes with cryptographic signatures
4. Creates verifiable build attestations

## Publishing with Provenance

### Manual Publishing

```bash
npm publish --provenance
```

### Automated Publishing

1. Create a release on GitHub
2. The workflow automatically publishes with provenance
3. Verify the provenance:
   ```bash
   npm run verify:provenance
   ```

## Verifying Package Provenance

### Check Published Package

```bash
# Check specific package
node scripts/verify-provenance.js @your/package-name 1.0.0

# Check latest version
node scripts/verify-provenance.js @your/package-name

# Verify signatures
npm audit signatures
```

### What Provenance Provides

1. **Build Environment**: Where and how the package was built
2. **Source Repository**: Link to the exact source code
3. **Build Timestamp**: When the package was built
4. **Builder Identity**: Who/what built the package
5. **Cryptographic Signatures**: Tamper-proof attestations

## Security Benefits

1. **Supply Chain Security**: Verify packages haven't been tampered with
2. **Build Transparency**: Know exactly how packages were built
3. **Automated Verification**: npm automatically verifies provenance
4. **SLSA Compliance**: Meets SLSA Level 3 requirements

## Troubleshooting

### "npm doesn't support provenance"
- Upgrade npm: `npm install -g npm@latest`
- Minimum version: 9.5.0

### "No attestations found"
- Ensure `provenance=true` in .npmrc
- Check if published with `--provenance` flag
- Verify GitHub Actions has `id-token: write` permission

### "Cannot verify signatures"
- This is normal for packages without provenance
- Only packages published with npm 9.5+ have verifiable provenance

## Best Practices

1. Always publish from CI/CD (not local machines)
2. Use GitHub Actions with provenance workflow
3. Regularly verify published packages
4. Monitor for security advisories
5. Keep npm updated to latest version
EOF

echo -e "${GREEN}✅ Created provenance documentation${NC}"

# Summary
echo -e "\n${GREEN}🎉 NPM Provenance setup complete!${NC}"
echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Add NPM_TOKEN to GitHub Secrets"
echo "2. Commit the changes"
echo "3. Use 'npm run publish:provenance' to publish"
echo "4. Use 'npm run verify:provenance' to verify"
echo ""
echo "For automated publishing:"
echo "- Create a GitHub release"
echo "- Or manually trigger the workflow"