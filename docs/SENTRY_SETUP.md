# Sentry Integration Setup Guide

## Overview
Sentry is integrated for comprehensive error tracking, performance monitoring, and user experience insights across both frontend and backend.

## Environment Variables

### Required Variables

```bash
# Sentry DSN - Get this from your Sentry project settings
NEXT_PUBLIC_SENTRY_DSN=https://your-dsn@sentry.io/project-id

# Sentry Build Configuration (for source map upload)
SENTRY_ORG=your-org-slug
SENTRY_PROJECT=scout-dashboard-web
SENTRY_AUTH_TOKEN=your-auth-token

# Optional: Control Sentry in development
SENTRY_SEND_IN_DEV=false
```

### Environment-Specific Configuration

#### Development (.env.local)
```bash
# Sentry DSN (use development project)
NEXT_PUBLIC_SENTRY_DSN=https://dev-dsn@sentry.io/dev-project-id
SENTRY_SEND_IN_DEV=false  # Disable in dev by default

# Build tools (optional in dev)
SENTRY_ORG=tbwa
SENTRY_PROJECT=scout-dashboard-dev
```

#### Production (.env.production)
```bash
# Production Sentry DSN
NEXT_PUBLIC_SENTRY_DSN=https://prod-dsn@sentry.io/prod-project-id

# Build configuration for source maps
SENTRY_ORG=tbwa
SENTRY_PROJECT=scout-dashboard-web
SENTRY_AUTH_TOKEN=your-production-auth-token
```

## Sentry Project Setup

### 1. Create Sentry Account & Projects

1. Sign up at [sentry.io](https://sentry.io)
2. Create organization: `tbwa`
3. Create projects:
   - `scout-dashboard-web` (Production)
   - `scout-dashboard-dev` (Development)

### 2. Configure Projects

#### Error Tracking Settings:
- **Data Scrubbing**: Enable for sensitive data
- **IP Address**: Don't store full IP addresses
- **Session Replay**: Enable with privacy controls
- **Performance**: Enable with 10% sampling in production

#### Alert Rules:
- **New Issues**: Slack/Email notifications
- **Performance**: Alert on P95 > 3s
- **Error Rate**: Alert on >1% error rate
- **Custom**: API endpoint failures

### 3. Generate Auth Token

1. Go to Settings > Auth Tokens
2. Create token with scopes:
   - `project:releases`
   - `project:write`
   - `org:read`
3. Save as `SENTRY_AUTH_TOKEN`

## Testing Sentry Integration

### Local Testing

1. **Start the application**:
   ```bash
   npm run dev
   ```

2. **Test endpoints**:
   ```bash
   # Test basic functionality
   curl http://localhost:3000/api/test/sentry

   # Test error capture
   curl http://localhost:3000/api/test/sentry?type=error

   # Test performance monitoring
   curl http://localhost:3000/api/test/sentry?type=performance

   # Test user context
   curl http://localhost:3000/api/test/sentry?type=user

   # Test POST error
   curl -X POST http://localhost:3000/api/test/sentry \
     -H "Content-Type: application/json" \
     -d '{"test_error": true}'
   ```

### Production Verification

1. **Deploy to Vercel**:
   ```bash
   vercel --prod
   ```

2. **Verify Sentry Dashboard**:
   - Check Issues tab for captured errors
   - Check Performance tab for transactions
   - Check User Feedback for session replays

## Configuration Details

### Client-Side Configuration
Location: `sentry.client.config.ts`
- **Performance Monitoring**: 10% sampling in production
- **Session Replay**: 10% sampling, 100% on errors
- **Privacy Controls**: Mask inputs, filter sensitive data

### Server-Side Configuration
Location: `sentry.server.config.ts`
- **API Route Monitoring**: All routes instrumented
- **Database Query Monitoring**: Supabase queries tracked
- **Error Context**: Request/response data captured

### Edge Runtime Configuration
Location: `sentry.edge.config.ts`
- **Middleware Integration**: Request/response tracking
- **Rate Limiting**: Sentry-monitored rate limits
- **Authentication**: Auth failure tracking

## Features Enabled

### ✅ Error Tracking
- **Automatic**: Unhandled exceptions captured
- **Manual**: Custom error boundaries
- **Context**: User, request, and performance data

### ✅ Performance Monitoring
- **Core Web Vitals**: LCP, FID, CLS tracking
- **API Performance**: Response times and failures
- **Database Queries**: Slow query detection

### ✅ User Experience
- **Session Replay**: Visual debugging of user sessions
- **User Context**: Authentication and user journey
- **Custom Events**: Business logic tracking

### ✅ Developer Experience
- **Source Maps**: Readable stack traces in production
- **Breadcrumbs**: Detailed event trails
- **Alerts**: Real-time issue notifications

## Privacy & Security

### Data Scrubbing Rules:
```javascript
// Automatically scrubbed fields:
- password
- token
- auth
- secret
- key
- api_key
- access_token
- refresh_token
```

### Network Security:
- **CSP Integration**: Sentry domains allowed
- **Tunnel Route**: `/monitoring/tunnel` for bypassing ad-blockers
- **HTTPS Only**: All Sentry communication encrypted

## Monitoring Checklist

### Pre-Deployment:
- [ ] Environment variables configured
- [ ] Sentry project created and configured
- [ ] Test endpoints returning success
- [ ] Source maps uploading correctly
- [ ] Alert rules configured

### Post-Deployment:
- [ ] Errors appearing in Sentry dashboard
- [ ] Performance data being captured
- [ ] User sessions recording (if enabled)
- [ ] Alert notifications working
- [ ] Team access configured

## Troubleshooting

### Common Issues:

1. **No events in Sentry**:
   - Check `NEXT_PUBLIC_SENTRY_DSN` is set
   - Verify DSN is correct format
   - Check browser console for Sentry errors

2. **Source maps not working**:
   - Verify `SENTRY_AUTH_TOKEN` has correct permissions
   - Check build logs for upload errors
   - Ensure `SENTRY_ORG` and `SENTRY_PROJECT` match

3. **Performance data missing**:
   - Check `tracesSampleRate` setting
   - Verify performance monitoring is enabled in project
   - Check for CSP blocking Sentry requests

4. **Session replays not recording**:
   - Check `replaysSessionSampleRate` > 0
   - Verify privacy settings aren't too restrictive
   - Check for network blocking of Sentry domains

### Debug Commands:

```bash
# Check Sentry CLI configuration
npx @sentry/cli --version

# Test auth token
npx @sentry/cli auth token --org tbwa

# Upload source maps manually
npx @sentry/cli releases files VERSION upload-sourcemaps ./build

# Test DSN connectivity
curl -X POST 'https://sentry.io/api/PROJECT_ID/store/' \
  -H 'X-Sentry-Auth: Sentry sentry_key=KEY' \
  -H 'Content-Type: application/json' \
  -d '{"message": "Test message"}'
```

## Integration with Other Tools

### Vercel Analytics:
- Events forwarded to both Sentry and Vercel
- Performance metrics correlated
- Deployment tracking integrated

### Supabase:
- Database errors captured
- Auth failures tracked
- RLS violations monitored

### Playwright Tests:
- Test failures captured in Sentry
- Performance regression alerts
- E2E error tracking

## Support Resources

- [Sentry Documentation](https://docs.sentry.io/)
- [Next.js Integration Guide](https://docs.sentry.io/platforms/javascript/guides/nextjs/)
- [Performance Monitoring](https://docs.sentry.io/platforms/javascript/performance/)
- [Session Replay](https://docs.sentry.io/platforms/javascript/session-replay/)