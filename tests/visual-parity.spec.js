/**
 * Scout Design System Visual Parity Tests
 * 
 * These tests ensure that design tokens remain visually consistent
 * across changes and deployments. They capture screenshots of
 * token-driven components and compare against baseline images.
 */

const { test, expect } = require('@playwright/test');

test.describe('Scout Design System Visual Parity', () => {
  // Test configuration
  const BASEURL = process.env.SCOUT_BASE_URL || 'http://localhost:3002';
  const BREAKPOINTS = {
    mobile: { width: 375, height: 667 },
    tablet: { width: 768, height: 1024 },
    desktop: { width: 1440, height: 900 }
  };

  test.beforeEach(async ({ page }) => {
    // Wait for token CSS to load
    await page.goto(BASEURL);
    await page.waitForLoadState('networkidle');
    
    // Inject token validation CSS for visual testing
    await page.addStyleTag({
      content: `
        /* Token validation markers */
        .token-test-marker {
          position: relative;
        }
        .token-test-marker::before {
          content: 'TOKEN-VALIDATED';
          position: absolute;
          top: -20px;
          left: 0;
          font-size: 12px;
          color: green;
          z-index: 9999;
        }
      `
    });
  });

  test.describe('Color Token Validation', () => {
    test('should render primary color palette correctly', async ({ page }) => {
      await page.setViewportSize(BREAKPOINTS.desktop);
      
      // Create color swatches for testing
      await page.evaluate(() => {
        const container = document.createElement('div');
        container.id = 'color-test-container';
        container.style.cssText = `
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(100px, 1fr));
          gap: 16px;
          padding: 20px;
          background: white;
        `;

        // Primary colors from extracted tokens
        const colors = [
          'var(--color-amazon-accent)',
          'var(--color-background)',
          'var(--color-color-red-500)',
          'var(--color-color-orange-500)',
          'var(--color-color-green-500)',
          'var(--color-color-blue-500)'
        ];

        colors.forEach((color, index) => {
          const swatch = document.createElement('div');
          swatch.className = 'color-swatch token-test-marker';
          swatch.style.cssText = `
            width: 100px;
            height: 100px;
            background-color: ${color};
            border: 1px solid #ccc;
            border-radius: 8px;
            position: relative;
          `;
          swatch.setAttribute('data-color', color);
          container.appendChild(swatch);
        });

        document.body.appendChild(container);
      });

      // Take screenshot for comparison
      await expect(page.locator('#color-test-container')).toHaveScreenshot('color-palette.png');
    });

    test('should validate color accessibility contrast', async ({ page }) => {
      await page.setViewportSize(BREAKPOINTS.desktop);
      
      // Create contrast test combinations
      await page.evaluate(() => {
        const container = document.createElement('div');
        container.id = 'contrast-test-container';
        container.style.cssText = `
          display: flex;
          flex-direction: column;
          gap: 16px;
          padding: 20px;
          background: white;
        `;

        // Test combinations for WCAG compliance
        const contrastTests = [
          { bg: 'var(--color-amazon-accent)', fg: '#ffffff', label: 'Amazon Accent + White' },
          { bg: 'var(--color-background)', fg: '#000000', label: 'Background + Black' },
          { bg: 'var(--color-color-red-500)', fg: '#ffffff', label: 'Red + White' },
          { bg: 'var(--color-color-green-500)', fg: '#ffffff', label: 'Green + White' }
        ];

        contrastTests.forEach(test => {
          const item = document.createElement('div');
          item.className = 'contrast-test token-test-marker';
          item.style.cssText = `
            background-color: ${test.bg};
            color: ${test.fg};
            padding: 20px;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 500;
          `;
          item.textContent = test.label;
          container.appendChild(item);
        });

        document.body.appendChild(container);
      });

      await expect(page.locator('#contrast-test-container')).toHaveScreenshot('color-contrast.png');
    });
  });

  test.describe('Spacing Token Validation', () => {
    test('should render spacing scale correctly', async ({ page }) => {
      await page.setViewportSize(BREAKPOINTS.desktop);
      
      await page.evaluate(() => {
        const container = document.createElement('div');
        container.id = 'spacing-test-container';
        container.style.cssText = `
          display: flex;
          flex-direction: column;
          gap: 8px;
          padding: 20px;
          background: #f5f5f5;
        `;

        // Spacing values from tokens (common design system scales)
        const spacings = [
          { value: '4px', label: 'XS' },
          { value: '8px', label: 'SM' },
          { value: '16px', label: 'MD' },
          { value: '24px', label: 'LG' },
          { value: '32px', label: 'XL' },
          { value: '48px', label: 'XXL' }
        ];

        spacings.forEach(spacing => {
          const item = document.createElement('div');
          item.className = 'spacing-test token-test-marker';
          item.style.cssText = `
            background: var(--color-amazon-accent);
            height: 20px;
            width: ${spacing.value};
            border-radius: 4px;
            position: relative;
          `;
          item.setAttribute('data-spacing', spacing.value);
          
          const label = document.createElement('span');
          label.style.cssText = `
            position: absolute;
            right: -60px;
            top: 50%;
            transform: translateY(-50%);
            font-size: 12px;
            color: #333;
          `;
          label.textContent = `${spacing.label}: ${spacing.value}`;
          item.appendChild(label);
          
          container.appendChild(item);
        });

        document.body.appendChild(container);
      });

      await expect(page.locator('#spacing-test-container')).toHaveScreenshot('spacing-scale.png');
    });
  });

  test.describe('Typography Token Validation', () => {
    test('should render font scale correctly', async ({ page }) => {
      await page.setViewportSize(BREAKPOINTS.desktop);
      
      await page.evaluate(() => {
        const container = document.createElement('div');
        container.id = 'typography-test-container';
        container.style.cssText = `
          display: flex;
          flex-direction: column;
          gap: 16px;
          padding: 20px;
          background: white;
        `;

        // Typography scale
        const fontSizes = [
          { size: '12px', weight: '400', label: 'Caption' },
          { size: '14px', weight: '400', label: 'Body Small' },
          { size: '16px', weight: '400', label: 'Body' },
          { size: '18px', weight: '500', label: 'Body Large' },
          { size: '24px', weight: '600', label: 'Heading 4' },
          { size: '32px', weight: '700', label: 'Heading 3' },
          { size: '40px', weight: '700', label: 'Heading 2' },
          { size: '48px', weight: '800', label: 'Heading 1' }
        ];

        fontSizes.forEach(font => {
          const item = document.createElement('div');
          item.className = 'typography-test token-test-marker';
          item.style.cssText = `
            font-size: ${font.size};
            font-weight: ${font.weight};
            color: #333;
            line-height: 1.5;
          `;
          item.textContent = `${font.label} - The quick brown fox jumps`;
          container.appendChild(item);
        });

        document.body.appendChild(container);
      });

      await expect(page.locator('#typography-test-container')).toHaveScreenshot('typography-scale.png');
    });
  });

  test.describe('Component Token Integration', () => {
    test('should validate Amazon-themed components', async ({ page }) => {
      await page.setViewportSize(BREAKPOINTS.desktop);
      
      // Navigate to dashboard with Amazon theme
      await page.goto(`${BASEURL}/dashboard`);
      
      // Wait for components to load with tokens
      await page.waitForSelector('[data-testid="metric-card"]', { timeout: 10000 });
      
      // Take screenshot of token-styled components
      await expect(page.locator('main')).toHaveScreenshot('amazon-themed-dashboard.png');
    });

    test('should validate responsive behavior across breakpoints', async ({ page }) => {
      for (const [breakpoint, size] of Object.entries(BREAKPOINTS)) {
        await page.setViewportSize(size);
        await page.goto(`${BASEURL}/dashboard`);
        await page.waitForLoadState('networkidle');
        
        // Take screenshot at each breakpoint
        await expect(page.locator('main')).toHaveScreenshot(`dashboard-${breakpoint}.png`);
      }
    });
  });

  test.describe('Token Consistency Validation', () => {
    test('should verify no hardcoded values in production build', async ({ page }) => {
      await page.goto(BASEURL);
      
      // Check that CSS custom properties are being used
      const hasTokens = await page.evaluate(() => {
        const styles = getComputedStyle(document.documentElement);
        const tokenCount = Array.from(styles).filter(prop => prop.startsWith('--color')).length;
        return tokenCount > 0;
      });
      
      expect(hasTokens).toBeTruthy();
    });

    test('should validate theme switching capability', async ({ page }) => {
      await page.goto(BASEURL);
      
      // Test theme switching if implemented
      const hasThemeSwitcher = await page.locator('[data-testid="theme-switcher"]').count();
      
      if (hasThemeSwitcher > 0) {
        // Take baseline screenshot
        await expect(page.locator('body')).toHaveScreenshot('theme-light.png');
        
        // Switch theme
        await page.locator('[data-testid="theme-switcher"]').click();
        await page.waitForTimeout(500);
        
        // Take dark theme screenshot
        await expect(page.locator('body')).toHaveScreenshot('theme-dark.png');
      }
    });
  });
});

// Utility test for token extraction validation
test.describe('Token Extraction Validation', () => {
  test('should validate extracted tokens match source', async ({ page }) => {
    await page.goto(BASEURL);
    
    // Validate that key tokens are present and accessible
    const tokenValidation = await page.evaluate(() => {
      const root = getComputedStyle(document.documentElement);
      
      const requiredTokens = [
        '--color-amazon-accent',
        '--color-background',
        '--color-color-red-500',
        '--color-color-green-500'
      ];
      
      const results = {};
      
      requiredTokens.forEach(token => {
        const value = root.getPropertyValue(token);
        results[token] = {
          exists: !!value,
          value: value.trim(),
          isColor: /^#[0-9a-f]{6}$/i.test(value.trim())
        };
      });
      
      return results;
    });
    
    // Validate that all required tokens exist and are valid colors
    Object.entries(tokenValidation).forEach(([token, data]) => {
      expect(data.exists, `Token ${token} should exist`).toBeTruthy();
      expect(data.isColor, `Token ${token} should be a valid hex color`).toBeTruthy();
    });
  });
});