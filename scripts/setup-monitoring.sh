#!/bin/bash

# Script to set up monitoring with Vercel Analytics and Sentry

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "📊 Setting up monitoring and alerting..."

# Function to check if package is installed
check_package() {
    if npm list "$1" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Navigate to web app directory
cd apps/web

# Install Vercel Analytics
echo -e "\n${YELLOW}Installing Vercel Analytics...${NC}"
if ! check_package "@vercel/analytics"; then
    npm install @vercel/analytics@latest
    echo -e "${GREEN}✅ Vercel Analytics installed${NC}"
else
    echo "Vercel Analytics already installed"
fi

# Install Vercel Speed Insights
echo -e "\n${YELLOW}Installing Vercel Speed Insights...${NC}"
if ! check_package "@vercel/speed-insights"; then
    npm install @vercel/speed-insights@latest
    echo -e "${GREEN}✅ Vercel Speed Insights installed${NC}"
else
    echo "Vercel Speed Insights already installed"
fi

# Install Sentry
echo -e "\n${YELLOW}Installing Sentry...${NC}"
if ! check_package "@sentry/nextjs"; then
    # Use the Sentry wizard for automatic setup
    npx @sentry/wizard@latest -i nextjs --skip-connect
    echo -e "${GREEN}✅ Sentry installed${NC}"
else
    echo "Sentry already installed"
fi

# Create .env.example with monitoring variables
echo -e "\n${YELLOW}Creating monitoring environment variables template...${NC}"
cat >> .env.example << 'EOF'

# Monitoring Configuration
# Sentry
NEXT_PUBLIC_SENTRY_DSN=your_sentry_dsn_here
SENTRY_ORG=your_sentry_org
SENTRY_PROJECT=your_sentry_project
SENTRY_AUTH_TOKEN=your_sentry_auth_token

# Vercel Analytics (automatic when deployed to Vercel)
# No configuration needed - automatically injected by Vercel

# Optional: Send Sentry events in development
# SENTRY_SEND_IN_DEV=true
EOF

echo -e "${GREEN}✅ Environment template updated${NC}"

# Create monitoring dashboard component
echo -e "\n${YELLOW}Creating monitoring dashboard component...${NC}"
mkdir -p src/components/monitoring

cat > src/components/monitoring/MonitoringDashboard.tsx << 'EOF'
'use client';

import { useEffect, useState } from 'react';
import { events, trackWebVitals } from '@/lib/monitoring/vercel-analytics';
import { captureMessage, ErrorLevel } from '@/lib/monitoring/sentry';

interface WebVitalsData {
  FCP?: number;
  LCP?: number;
  CLS?: number;
  FID?: number;
  TTFB?: number;
}

export function MonitoringDashboard() {
  const [vitals, setVitals] = useState<WebVitalsData>({});
  const [eventCount, setEventCount] = useState(0);

  useEffect(() => {
    // Track web vitals
    if (typeof window !== 'undefined' && 'web-vital' in window) {
      (window as any).addEventListener('web-vital', (e: any) => {
        const { name, value } = e.detail;
        setVitals(prev => ({ ...prev, [name]: value }));
        trackWebVitals(e.detail);
      });
    }

    // Example: Track dashboard view
    events.dashboard.viewMetric('monitoring_dashboard');
    setEventCount(prev => prev + 1);
  }, []);

  const triggerTestError = () => {
    try {
      throw new Error('Test error from monitoring dashboard');
    } catch (error) {
      captureMessage('Test error triggered', ErrorLevel.Warning);
      events.error.boundary('Test error', 'MonitoringDashboard');
      setEventCount(prev => prev + 1);
    }
  };

  const triggerTestEvent = () => {
    events.feature.use('test_monitoring_event');
    captureMessage('Test event triggered', ErrorLevel.Info);
    setEventCount(prev => prev + 1);
  };

  return (
    <div className="p-6 bg-white rounded-lg shadow">
      <h2 className="text-2xl font-bold mb-4">Monitoring Dashboard</h2>
      
      <div className="grid grid-cols-2 gap-4 mb-6">
        <div className="p-4 bg-gray-50 rounded">
          <h3 className="font-semibold mb-2">Web Vitals</h3>
          <ul className="space-y-1 text-sm">
            <li>FCP: {vitals.FCP?.toFixed(2) || 'N/A'} ms</li>
            <li>LCP: {vitals.LCP?.toFixed(2) || 'N/A'} ms</li>
            <li>CLS: {vitals.CLS?.toFixed(4) || 'N/A'}</li>
            <li>FID: {vitals.FID?.toFixed(2) || 'N/A'} ms</li>
            <li>TTFB: {vitals.TTFB?.toFixed(2) || 'N/A'} ms</li>
          </ul>
        </div>
        
        <div className="p-4 bg-gray-50 rounded">
          <h3 className="font-semibold mb-2">Analytics</h3>
          <p className="text-sm">Events tracked: {eventCount}</p>
          <div className="mt-2 space-x-2">
            <button
              onClick={triggerTestEvent}
              className="px-3 py-1 bg-blue-500 text-white rounded text-sm hover:bg-blue-600"
            >
              Test Event
            </button>
            <button
              onClick={triggerTestError}
              className="px-3 py-1 bg-red-500 text-white rounded text-sm hover:bg-red-600"
            >
              Test Error
            </button>
          </div>
        </div>
      </div>
      
      <div className="text-xs text-gray-500">
        <p>Sentry: {process.env.NEXT_PUBLIC_SENTRY_DSN ? '✅ Configured' : '❌ Not configured'}</p>
        <p>Vercel Analytics: Automatically enabled when deployed</p>
      </div>
    </div>
  );
}
EOF

echo -e "${GREEN}✅ Monitoring dashboard component created${NC}"

# Create monitoring documentation
echo -e "\n${YELLOW}Creating monitoring documentation...${NC}"
cat > ../../docs/MONITORING.md << 'EOF'
# Monitoring and Alerting Setup

## Overview

This application uses Vercel Analytics and Sentry for comprehensive monitoring and error tracking.

## Vercel Analytics

### Automatic Setup
- Analytics are automatically enabled when deploying to Vercel
- No additional configuration required
- Includes Web Vitals tracking and custom events

### Custom Events
```typescript
import { events } from '@/lib/monitoring/vercel-analytics';

// Track user actions
events.auth.login('google');
events.dashboard.viewMetric('revenue');
events.data.create('user');
```

### Web Vitals
Automatically tracks:
- First Contentful Paint (FCP)
- Largest Contentful Paint (LCP)
- Cumulative Layout Shift (CLS)
- First Input Delay (FID)
- Time to First Byte (TTFB)

## Sentry Error Tracking

### Configuration
1. Create a Sentry account at https://sentry.io
2. Create a new project for your application
3. Add the DSN to your environment variables:
   ```
   NEXT_PUBLIC_SENTRY_DSN=your_sentry_dsn_here
   ```

### Features
- Automatic error capture
- Performance monitoring
- Session replay (for debugging)
- Custom error context
- User tracking

### Usage Examples
```typescript
import { captureException, captureMessage, ErrorLevel } from '@/lib/monitoring/sentry';

// Capture exceptions
try {
  await riskyOperation();
} catch (error) {
  captureException(error, {
    tags: { section: 'payment' },
    extra: { orderId: '123' }
  });
}

// Log messages
captureMessage('Payment processed successfully', ErrorLevel.Info);
```

## Monitoring Dashboard

Access the monitoring dashboard at `/monitoring` to view:
- Real-time Web Vitals
- Event tracking statistics
- Error rate monitoring
- Performance metrics

## Alerts Configuration

### Vercel Alerts
1. Go to your Vercel project dashboard
2. Navigate to Settings > Monitoring
3. Configure alerts for:
   - Error rate thresholds
   - Performance degradation
   - Traffic anomalies

### Sentry Alerts
1. In Sentry dashboard, go to Alerts
2. Create alert rules for:
   - Error frequency
   - Performance issues
   - Crash rate
   - Custom metrics

## Best Practices

1. **Error Handling**
   - Always use try-catch for async operations
   - Provide meaningful error context
   - Don't expose sensitive data in errors

2. **Performance Tracking**
   - Monitor key user journeys
   - Track API response times
   - Set performance budgets

3. **Custom Events**
   - Track business-critical actions
   - Monitor feature adoption
   - Measure conversion funnels

4. **User Privacy**
   - Mask sensitive data
   - Respect user privacy settings
   - Comply with GDPR/CCPA

## Troubleshooting

### Sentry not capturing errors
- Verify NEXT_PUBLIC_SENTRY_DSN is set
- Check browser console for Sentry initialization errors
- Ensure errors aren't filtered by beforeSend

### Missing Web Vitals
- Verify you're using Chrome/Edge (required for all metrics)
- Check if ad blockers are interfering
- Ensure Analytics script is loading

### High error rate
- Check Sentry dashboard for error patterns
- Review recent deployments
- Verify API endpoints are healthy
EOF

echo -e "${GREEN}✅ Monitoring documentation created${NC}"

# Update package.json scripts
echo -e "\n${YELLOW}Updating package.json scripts...${NC}"
cd ../..
npm pkg set scripts.monitor="open https://vercel.com/dashboard/analytics"
npm pkg set scripts.sentry="open https://sentry.io/organizations/your-org/projects/"

echo -e "\n${GREEN}🎉 Monitoring setup complete!${NC}"
echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Create a Sentry account and get your DSN"
echo "2. Add NEXT_PUBLIC_SENTRY_DSN to your .env.local"
echo "3. Deploy to Vercel to enable analytics"
echo "4. Configure alerts in both Vercel and Sentry dashboards"
echo "5. Test monitoring at /api/monitoring/sentry-example"
echo ""
echo "Run 'npm run monitor' to open Vercel Analytics"
echo "Run 'npm run sentry' to open Sentry dashboard"