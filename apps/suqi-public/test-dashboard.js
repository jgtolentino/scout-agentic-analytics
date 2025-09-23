const { chromium } = require('playwright');

async function testSuqiDashboard() {
  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();

  try {
    console.log('🚀 Testing Suqi Public Dashboard at https://suqi-public.vercel.app/');

    // Navigate to the dashboard
    console.log('📍 Navigating to dashboard...');
    await page.goto('https://suqi-public.vercel.app/', { waitUntil: 'networkidle' });

    // Take screenshot
    await page.screenshot({ path: 'suqi-dashboard-homepage.png', fullPage: true });
    console.log('📸 Screenshot saved: suqi-dashboard-homepage.png');

    // Check page title
    const title = await page.title();
    console.log('📋 Page title:', title);

    // Check for authentication barriers
    const authRequired = await page.locator('text=Authentication Required').isVisible().catch(() => false);
    if (authRequired) {
      console.log('🔒 Authentication required - dashboard is protected');
      return;
    }

    // Check if dashboard loaded successfully
    const dashboardHeader = await page.locator('h1:has-text("Consumer Behavior Analytics")').isVisible().catch(() => false);
    if (dashboardHeader) {
      console.log('✅ Consumer Behavior Analytics dashboard loaded');
    } else {
      console.log('❌ Dashboard header not found');
    }

    // Test API endpoints
    console.log('🔌 Testing API endpoints...');

    const endpoints = [
      '/api/scout/kpis',
      '/api/scout/behavior',
      '/api/scout/transactions',
      '/api/scout/trends'
    ];

    for (const endpoint of endpoints) {
      try {
        const response = await page.request.get(`https://suqi-public.vercel.app${endpoint}`);
        console.log(`📊 ${endpoint}: ${response.status()} ${response.statusText()}`);

        if (response.ok()) {
          const data = await response.json();
          console.log(`   Success: ${data.success ? '✅' : '❌'}`);
          if (data.error) console.log(`   Error: ${data.error}`);
        }
      } catch (error) {
        console.log(`❌ ${endpoint}: ${error.message}`);
      }
    }

    // Check for KPI cards
    console.log('📈 Checking dashboard components...');
    const kpiCards = await page.locator('[data-testid="kpi-card"], .bg-white:has-text("Conversion Rate")').count().catch(() => 0);
    console.log(`📊 KPI cards found: ${kpiCards}`);

    // Check for purchase funnel
    const purchaseFunnel = await page.locator('text=Customer Purchase Journey').isVisible().catch(() => false);
    console.log(`🎯 Purchase funnel: ${purchaseFunnel ? '✅ Found' : '❌ Not found'}`);

    // Check for request methods chart
    const requestMethods = await page.locator('text=Request Methods').isVisible().catch(() => false);
    console.log(`📋 Request methods: ${requestMethods ? '✅ Found' : '❌ Not found'}`);

    // Check console errors
    const errors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
      }
    });

    // Wait a bit to catch any errors
    await page.waitForTimeout(3000);

    if (errors.length > 0) {
      console.log('⚠️ Console errors:');
      errors.forEach(error => console.log(`   ${error}`));
    } else {
      console.log('✅ No console errors detected');
    }

    // Performance metrics
    const metrics = await page.evaluate(() => {
      const navigation = performance.getEntriesByType('navigation')[0];
      return {
        loadTime: Math.round(navigation.loadEventEnd - navigation.fetchStart),
        domContentLoaded: Math.round(navigation.domContentLoadedEventEnd - navigation.fetchStart),
        firstPaint: performance.getEntriesByName('first-paint')[0]?.startTime || 0
      };
    });

    console.log('⚡ Performance metrics:');
    console.log(`   Load time: ${metrics.loadTime}ms`);
    console.log(`   DOM ready: ${metrics.domContentLoaded}ms`);
    console.log(`   First paint: ${Math.round(metrics.firstPaint)}ms`);

  } catch (error) {
    console.error('❌ Test failed:', error.message);
  } finally {
    await browser.close();
  }
}

testSuqiDashboard();