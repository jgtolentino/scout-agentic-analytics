const { chromium } = require('playwright');

async function testCompleteDashboard() {
  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();

  try {
    console.log('🚀 Testing Complete Suqi Dashboard at https://suqi-public.vercel.app/');

    // Test main dashboard
    console.log('📍 Testing main dashboard...');
    await page.goto('https://suqi-public.vercel.app/', { waitUntil: 'networkidle' });
    await page.screenshot({ path: 'main-dashboard.png', fullPage: true });

    // Test all dashboard pages
    const dashboardPages = [
      '/consumer-behavior',
      '/competitive-analysis',
      '/geographical-intelligence',
      '/transaction-trends',
      '/consumer-profiling',
      '/product-mix'
    ];

    for (const dashboardPage of dashboardPages) {
      try {
        console.log(`📊 Testing ${dashboardPage}...`);
        await page.goto(`https://suqi-public.vercel.app${dashboardPage}`, { waitUntil: 'networkidle' });

        // Check for 404 errors
        const is404 = await page.locator('text=404').isVisible().catch(() => false);
        const isNotFound = await page.locator('text=This page could not be found').isVisible().catch(() => false);

        if (is404 || isNotFound) {
          console.log(`❌ ${dashboardPage}: 404 Not Found`);
        } else {
          console.log(`✅ ${dashboardPage}: Loaded successfully`);

          // Take screenshot
          const filename = dashboardPage.replace('/', '').replace('-', '_') + '.png';
          await page.screenshot({ path: filename, fullPage: true });
          console.log(`📸 Screenshot saved: ${filename}`);
        }

        await page.waitForTimeout(1000);
      } catch (error) {
        console.log(`❌ ${dashboardPage}: ${error.message}`);
      }
    }

    // Test API endpoints specifically
    console.log('🔌 Testing API endpoints...');
    const apiEndpoints = [
      { url: '/api/scout/kpis', name: 'KPIs' },
      { url: '/api/scout/behavior', name: 'Behavior Analytics' },
      { url: '/api/scout/transactions', name: 'Transactions' },
      { url: '/api/scout/trends', name: 'Trends' }
    ];

    for (const endpoint of apiEndpoints) {
      try {
        const response = await page.request.get(`https://suqi-public.vercel.app${endpoint.url}`);
        console.log(`📊 ${endpoint.name} (${endpoint.url}): ${response.status()} ${response.statusText()}`);

        if (response.ok()) {
          const data = await response.json();
          console.log(`   Success: ${data.success ? '✅' : '❌'}`);
          if (data.error) console.log(`   Error: ${data.error}`);
          if (data.data) console.log(`   Data keys: ${Object.keys(data.data).join(', ')}`);
        } else {
          console.log(`   Failed: ${response.status()} ${response.statusText()}`);
        }
      } catch (error) {
        console.log(`❌ ${endpoint.name}: ${error.message}`);
      }
    }

    // Test navigation functionality
    console.log('🧭 Testing navigation...');
    await page.goto('https://suqi-public.vercel.app/', { waitUntil: 'networkidle' });

    // Check if navigation menu exists
    const navItems = await page.locator('nav a, [role="navigation"] a').count().catch(() => 0);
    console.log(`📋 Navigation items found: ${navItems}`);

    // Check for any console errors
    let errorCount = 0;
    page.on('console', msg => {
      if (msg.type() === 'error') {
        console.log(`⚠️ Console error: ${msg.text()}`);
        errorCount++;
      }
    });

    await page.waitForTimeout(3000);
    console.log(`📊 Total console errors: ${errorCount}`);

    console.log('✅ Dashboard testing completed!');

  } catch (error) {
    console.error('❌ Test failed:', error.message);
  } finally {
    await browser.close();
  }
}

testCompleteDashboard();