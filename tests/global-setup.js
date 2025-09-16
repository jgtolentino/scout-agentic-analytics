/**
 * Global Setup for Scout Design System Tests
 * 
 * Prepares the environment for visual testing and token validation
 */

const { chromium } = require('@playwright/test');
const path = require('path');
const fs = require('fs');

async function globalSetup() {
  console.log('🚀 Setting up Scout Design System test environment...');

  // Ensure test directories exist
  const testDirs = [
    'test-results',
    'test-results/visual-diffs',
    'test-results/baseline',
    'test-results/screenshots'
  ];

  testDirs.forEach(dir => {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  });

  // Ensure tokens are built and up-to-date
  const { execSync } = require('child_process');
  
  try {
    console.log('📦 Building design tokens...');
    execSync('npm run tokens:sync', { stdio: 'inherit' });
    console.log('✅ Tokens built successfully');
  } catch (error) {
    console.error('❌ Failed to build tokens:', error.message);
    process.exit(1);
  }

  // Verify token files exist
  const requiredTokenFiles = [
    'packages/ui-components/src/tokens/generated/tokens.css',
    'packages/ui-components/src/tokens/generated/tokens.js',
    'tokens/primitives.json'
  ];

  for (const file of requiredTokenFiles) {
    if (!fs.existsSync(file)) {
      console.error(`❌ Required token file missing: ${file}`);
      process.exit(1);
    }
  }

  // Launch a browser to warm up and verify the app is working
  console.log('🌐 Warming up test browser...');
  const browser = await chromium.launch();
  const page = await browser.newPage();
  
  try {
    // Check if the development server is running
    const baseURL = process.env.SCOUT_BASE_URL || 'http://localhost:3002';
    await page.goto(baseURL, { waitUntil: 'networkidle', timeout: 30000 });
    
    // Verify tokens are loaded
    const tokensLoaded = await page.evaluate(() => {
      const root = getComputedStyle(document.documentElement);
      return Array.from(root).some(prop => prop.startsWith('--color'));
    });

    if (!tokensLoaded) {
      console.error('❌ Design tokens not found in DOM');
      process.exit(1);
    }

    console.log('✅ Design tokens verified in DOM');
    
  } catch (error) {
    console.error('❌ Failed to connect to development server:', error.message);
    console.error('💡 Make sure to run "npm run dev" before running tests');
    process.exit(1);
  } finally {
    await browser.close();
  }

  console.log('✅ Global setup completed successfully');
}

module.exports = globalSetup;