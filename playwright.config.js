/**
 * Playwright Configuration for Scout Design System Testing
 * 
 * Optimized for visual regression testing and token validation
 */

module.exports = {
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html'],
    ['json', { outputFile: 'test-results/results.json' }],
    ['junit', { outputFile: 'test-results/results.xml' }]
  ],
  
  use: {
    baseURL: process.env.SCOUT_BASE_URL || 'http://localhost:3002',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    
    // Visual testing optimizations
    launchOptions: {
      // Ensure consistent rendering
      args: [
        '--font-render-hinting=none',
        '--disable-font-subpixel-positioning',
        '--disable-skia-runtime-opts',
        '--run-all-compositor-stages-before-draw',
        '--disable-system-font-check',
        '--disable-font-subpixel-positioning'
      ]
    }
  },

  projects: [
    {
      name: 'chromium',
      use: { 
        ...require('@playwright/test').devices['Desktop Chrome'],
        // Force consistent rendering for visual tests
        deviceScaleFactor: 1,
        hasTouch: false
      },
    },

    {
      name: 'firefox',
      use: { 
        ...require('@playwright/test').devices['Desktop Firefox'],
        deviceScaleFactor: 1
      },
    },

    {
      name: 'webkit',
      use: { 
        ...require('@playwright/test').devices['Desktop Safari'],
        deviceScaleFactor: 1
      },
    },

    // Mobile testing for responsive token validation
    {
      name: 'Mobile Chrome',
      use: { 
        ...require('@playwright/test').devices['Pixel 5']
      },
    },

    {
      name: 'Mobile Safari',
      use: { 
        ...require('@playwright/test').devices['iPhone 12']
      },
    },

    // Tablet testing
    {
      name: 'Tablet',
      use: {
        ...require('@playwright/test').devices['iPad Pro'],
      },
    }
  ],

  // Visual comparison configuration
  expect: {
    // Threshold for visual differences (0-1, where 0 is identical)
    toHaveScreenshot: { 
      threshold: 0.05,  // Allow 5% difference for minor rendering variations
      mode: 'ci'       // Use CI mode for consistent baseline comparison
    },
    toMatchSnapshot: { 
      threshold: 0.05,
      mode: 'ci'
    }
  },

  // Development server configuration
  webServer: process.env.CI ? undefined : {
    command: 'npm run dev',
    url: 'http://localhost:3002',
    reuseExistingServer: !process.env.CI,
    timeout: 120000,
    stdout: 'pipe',
    stderr: 'pipe'
  },

  // Global setup and teardown
  globalSetup: './tests/global-setup.js',
  globalTeardown: './tests/global-teardown.js',

  // Output directories
  outputDir: 'test-results/',
  testDir: './tests'
};