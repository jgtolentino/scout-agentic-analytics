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