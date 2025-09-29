#!/usr/bin/env bash
set -euo pipefail

# Scout Dashboard Build Script
# Optimized build for Azure Static Web Apps deployment

echo "🔨 Building Scout Dashboard for Azure Static Web Apps..."

# ---- Configuration ----
BUILD_ENV="${BUILD_ENV:-production}"
OUTPUT_DIR="${OUTPUT_DIR:-out}"
SKIP_LINT="${SKIP_LINT:-false}"

# ---- Helper Functions ----
log() { printf "\\033[1;34m[%s]\\033[0m %s\\n" "$(date +'%F %T')" "$*"; }
ok()  { printf "\\033[1;32m✓\\033[0m %s\\n" "$*"; }
warn(){ printf "\\033[1;33m⚠\\033[0m %s\\n" "$*"; }
error(){ printf "\\033[1;31m✗\\033[0m %s\\n" "$*" >&2; exit 1; }

# ---- Preflight Checks ----
log "Preflight checks..."

# Ensure we're in the right directory
cd "$(dirname "$0")/.."

# Check if package.json exists
[ -f package.json ] || error "package.json not found"

# Check Node.js version
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node -v | sed 's/v//')
    log "Node.js version: $NODE_VERSION"
else
    error "Node.js not found"
fi

# Check npm
if command -v npm >/dev/null 2>&1; then
    NPM_VERSION=$(npm -v)
    log "npm version: $NPM_VERSION"
else
    error "npm not found"
fi

ok "Environment checks passed"

# ---- 1) Clean Previous Build ----
log "Cleaning previous build artifacts..."

# Remove build directories
rm -rf out .next dist

# Clear npm cache if needed
if [ "${CLEAN_CACHE:-false}" = "true" ]; then
    npm cache clean --force
    ok "npm cache cleared"
fi

ok "Build artifacts cleaned"

# ---- 2) Install Dependencies ----
log "Installing dependencies..."

# Use npm ci for faster, reliable builds
if [ -f package-lock.json ]; then
    npm ci --silent
    ok "Dependencies installed with npm ci"
else
    npm install --silent
    ok "Dependencies installed with npm install"
fi

# ---- 3) Lint and Type Check ----
if [ "$SKIP_LINT" != "true" ]; then
    log "Running lint and type checks..."

    # ESLint
    if npm run lint >/dev/null 2>&1; then
        ok "ESLint passed"
    else
        warn "ESLint issues found (continuing build)"
    fi

    # TypeScript check (if applicable)
    if [ -f tsconfig.json ]; then
        if npx tsc --noEmit >/dev/null 2>&1; then
            ok "TypeScript check passed"
        else
            warn "TypeScript issues found (continuing build)"
        fi
    fi
else
    log "Skipping lint checks (SKIP_LINT=true)"
fi

# ---- 4) Build Application ----
log "Building Next.js application..."

# Set environment for build
export NODE_ENV="$BUILD_ENV"
export NEXT_TELEMETRY_DISABLED=1

# Build the application
npm run build

# Verify build output
if [ ! -d "$OUTPUT_DIR" ]; then
    error "Build failed - no '$OUTPUT_DIR' directory found"
fi

# Check for essential files
if [ ! -f "$OUTPUT_DIR/index.html" ]; then
    error "Build failed - no index.html found in output"
fi

ok "Next.js build completed"

# ---- 5) Build Optimization ----
log "Optimizing build for Azure Static Web Apps..."

# Create _headers file for additional security (if not exists)
if [ ! -f "$OUTPUT_DIR/_headers" ]; then
    cat > "$OUTPUT_DIR/_headers" << 'EOF'
/*
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
  X-XSS-Protection: 1; mode=block
  Referrer-Policy: strict-origin-when-cross-origin
  Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' https://*.azurewebsites.net;
EOF
    ok "Security headers added"
fi

# Create _redirects file for SPA routing (if not exists)
if [ ! -f "$OUTPUT_DIR/_redirects" ]; then
    cat > "$OUTPUT_DIR/_redirects" << 'EOF'
# API proxy to Azure Functions
/api/* https://scout-func-prod.azurewebsites.net/api/:splat 200

# SPA routing fallback
/* /index.html 200
EOF
    ok "Redirects configuration added"
fi

# ---- 6) Build Validation ----
log "Validating build output..."

# Count files in build
FILE_COUNT=$(find "$OUTPUT_DIR" -type f | wc -l)
log "Build contains $FILE_COUNT files"

# Check build size
BUILD_SIZE=$(du -sh "$OUTPUT_DIR" | cut -f1)
log "Build size: $BUILD_SIZE"

# Validate critical files
critical_files=(
    "index.html"
    "_next/static/css"
    "_next/static/js"
)

for file in "${critical_files[@]}"; do
    if [ -e "$OUTPUT_DIR/$file" ]; then
        ok "Found: $file"
    else
        warn "Missing: $file"
    fi
done

# ---- 7) Summary ----
log "Build Summary"
echo "✅ Dashboard build completed successfully"
echo ""
echo "📁 Output directory: $OUTPUT_DIR"
echo "📊 File count: $FILE_COUNT"
echo "💾 Build size: $BUILD_SIZE"
echo "🌍 Environment: $BUILD_ENV"
echo ""
echo "🚀 Ready for Azure Static Web Apps deployment"
echo "   Run: npm run azure:deploy"