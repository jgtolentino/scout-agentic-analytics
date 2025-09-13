#!/usr/bin/env node

/**
 * Bundle optimization script for Scout Dashboard v5.0
 * 
 * This script analyzes and optimizes bundle sizes across all apps
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const APPS = ['web', 'dashboard', 'agentdash'];
const BUILD_COMMANDS = {
  web: 'npm run build:analyze',
  dashboard: 'npm run build:analyze', 
  agentdash: 'npm run build:analyze'
};

// Color codes for console output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function checkFileSize(filePath) {
  if (!fs.existsSync(filePath)) return 0;
  const stats = fs.statSync(filePath);
  return stats.size;
}

function formatBytes(bytes, decimals = 2) {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
}

function analyzeBundleSize(appName, buildDir) {
  log(`\\n📊 Analyzing ${appName} bundle...`, 'cyan');
  
  const staticDir = path.join(buildDir, '_next', 'static');
  if (!fs.existsSync(staticDir)) {
    log(`❌ No build found for ${appName}`, 'red');
    return null;
  }

  let totalSize = 0;
  const analysis = {
    js: 0,
    css: 0,
    chunks: 0,
    images: 0
  };

  function walkDir(dir) {
    const files = fs.readdirSync(dir);
    for (const file of files) {
      const filePath = path.join(dir, file);
      const stat = fs.statSync(filePath);
      
      if (stat.isDirectory()) {
        walkDir(filePath);
      } else {
        const size = stat.size;
        totalSize += size;
        
        if (file.endsWith('.js')) {
          analysis.js += size;
          if (file.includes('chunk')) analysis.chunks += size;
        } else if (file.endsWith('.css')) {
          analysis.css += size;
        } else if (/\\.(png|jpg|jpeg|gif|svg|webp)$/.test(file)) {
          analysis.images += size;
        }
      }
    }
  }

  walkDir(staticDir);

  log(`  📦 Total: ${formatBytes(totalSize)}`, 'bright');
  log(`  📄 JavaScript: ${formatBytes(analysis.js)}`, 'yellow');
  log(`  📝 CSS: ${formatBytes(analysis.css)}`, 'blue');
  log(`  🧩 Chunks: ${formatBytes(analysis.chunks)}`, 'green');
  log(`  🖼️  Images: ${formatBytes(analysis.images)}`, 'cyan');

  // Performance recommendations
  const jsPercent = (analysis.js / totalSize) * 100;
  if (jsPercent > 70) {
    log(`  ⚠️  JavaScript is ${jsPercent.toFixed(1)}% of bundle - consider code splitting`, 'yellow');
  }

  if (analysis.js > 1024 * 1024) {
    log(`  ⚠️  Large JavaScript bundle (${formatBytes(analysis.js)}) - optimize with tree shaking`, 'yellow');
  }

  return { totalSize, analysis };
}

function buildApp(appName) {
  const appDir = path.join('apps', appName);
  if (!fs.existsSync(appDir)) {
    log(`❌ App directory not found: ${appName}`, 'red');
    return false;
  }

  log(`\\n🔨 Building ${appName}...`, 'cyan');
  
  try {
    const command = BUILD_COMMANDS[appName] || 'npm run build';
    execSync(command, { 
      cwd: appDir, 
      stdio: 'pipe',
      encoding: 'utf8'
    });
    log(`✅ ${appName} built successfully`, 'green');
    return true;
  } catch (error) {
    log(`❌ Failed to build ${appName}: ${error.message}`, 'red');
    return false;
  }
}

function generateReport(results) {
  log('\\n📊 Bundle Analysis Report', 'bright');
  log('='.repeat(50), 'cyan');

  let totalAppSize = 0;
  const appSummary = [];

  for (const [appName, result] of Object.entries(results)) {
    if (result) {
      totalAppSize += result.totalSize;
      appSummary.push({
        name: appName,
        size: result.totalSize,
        js: result.analysis.js
      });
    }
  }

  // Sort by size
  appSummary.sort((a, b) => b.size - a.size);

  log(`\\nTotal bundle size across all apps: ${formatBytes(totalAppSize)}`, 'bright');
  log('\\nApp breakdown:', 'cyan');
  
  appSummary.forEach(app => {
    const percentage = ((app.size / totalAppSize) * 100).toFixed(1);
    log(`  ${app.name}: ${formatBytes(app.size)} (${percentage}%)`, 'yellow');
  });

  // Recommendations
  log('\\n💡 Optimization Recommendations:', 'green');
  
  if (totalAppSize > 5 * 1024 * 1024) { // > 5MB
    log('  • Consider implementing dynamic imports for large components', 'yellow');
  }
  
  if (appSummary.some(app => app.js > 2 * 1024 * 1024)) { // > 2MB JS
    log('  • Use tree shaking to remove unused code', 'yellow');
    log('  • Consider splitting vendor libraries into separate chunks', 'yellow');
  }

  log('  • Enable compression (gzip/brotli) in your web server', 'yellow');
  log('  • Use CDN for static assets', 'yellow');
  log('  • Implement service worker for caching', 'yellow');
}

async function main() {
  log('🚀 Starting Bundle Optimization Analysis', 'bright');
  log('=' .repeat(50), 'cyan');

  const results = {};

  // Build and analyze each app
  for (const appName of APPS) {
    const buildSuccess = buildApp(appName);
    if (buildSuccess) {
      const buildDir = appName === 'web' 
        ? path.join('apps', appName, 'build')
        : path.join('apps', appName, '.next');
      
      results[appName] = analyzeBundleSize(appName, buildDir);
    }
  }

  // Generate comprehensive report
  generateReport(results);

  // Create optimization checklist
  const checklist = `
# Bundle Optimization Checklist

## Completed ✅
- [x] Code splitting configuration
- [x] Manual chunk optimization 
- [x] Bundle analyzer integration
- [x] Production build optimizations
- [x] Console log removal in production
- [x] Asset optimization (images, fonts)
- [x] Lazy loading for components

## TODO 📋
- [ ] Service worker implementation
- [ ] CDN setup for static assets
- [ ] HTTP/2 server push configuration
- [ ] Critical CSS inlining
- [ ] Preload critical resources
- [ ] Web workers for heavy computations
- [ ] Module federation (if needed)

## Performance Targets 🎯
- First Contentful Paint (FCP): < 1.5s
- Largest Contentful Paint (LCP): < 2.5s
- Cumulative Layout Shift (CLS): < 0.1
- First Input Delay (FID): < 100ms
- Total Bundle Size: < 2MB (gzipped)

## Monitoring 📈
- Set up Lighthouse CI
- Monitor bundle sizes in CI/CD
- Track performance metrics in production
- Set up performance budgets
`;

  fs.writeFileSync('BUNDLE_OPTIMIZATION.md', checklist.trim());
  log('\\n📝 Created BUNDLE_OPTIMIZATION.md with checklist', 'green');

  log('\\n✨ Bundle optimization analysis complete!', 'bright');
}

// Run the script
if (require.main === module) {
  main().catch(console.error);
}

module.exports = { analyzeBundleSize, buildApp, formatBytes };