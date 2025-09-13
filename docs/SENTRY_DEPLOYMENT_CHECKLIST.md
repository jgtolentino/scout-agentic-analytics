# Sentry Deployment Verification Checklist

## Pre-Deployment Verification

### Environment Configuration
- [ ] `NEXT_PUBLIC_SENTRY_DSN` set for target environment
- [ ] `SENTRY_ORG` configured (tbwa)
- [ ] `SENTRY_PROJECT` configured (scout-dashboard-web)
- [ ] `SENTRY_AUTH_TOKEN` has correct permissions
- [ ] Environment variables validated in `.env.example`

### Local Testing
- [ ] **Basic Functionality**: `curl localhost:3000/api/test/sentry` returns success
- [ ] **Error Capture**: `curl localhost:3000/api/test/sentry?type=error` triggers Sentry event
- [ ] **Performance**: `curl localhost:3000/api/test/sentry?type=performance` creates transaction
- [ ] **User Context**: `curl localhost:3000/api/test/sentry?type=user` sets user data
- [ ] **Frontend Errors**: React Error Boundary catches and reports errors
- [ ] **Console Verification**: No Sentry initialization errors in browser console

### Build Process
- [ ] Source maps generated during build process
- [ ] Sentry release created automatically
- [ ] Source maps uploaded to Sentry
- [ ] Build process completes without Sentry errors
- [ ] Production bundle includes Sentry SDK

## Deployment Verification

### Vercel Deployment
- [ ] Environment variables configured in Vercel dashboard
- [ ] Build logs show successful Sentry configuration
- [ ] Source map upload logs show success
- [ ] No build warnings related to Sentry
- [ ] Deployment completes successfully

### Production Testing
- [ ] **Production Test Endpoint**: `curl https://your-domain.com/api/test/sentry`
- [ ] **Error Tracking**: Trigger test error and verify in Sentry dashboard
- [ ] **Performance Data**: Check Sentry Performance tab for transactions
- [ ] **User Sessions**: Verify session replay data (if enabled)
- [ ] **CSP Compatibility**: No CSP violations in browser console

## Sentry Dashboard Verification

### Issues Tab
- [ ] Test errors appear within 30 seconds
- [ ] Error details include source code location
- [ ] Stack traces are readable (not minified)
- [ ] User context is attached to errors
- [ ] Breadcrumbs show user actions before error

### Performance Tab
- [ ] Page load transactions visible
- [ ] API endpoint transactions tracked
- [ ] Core Web Vitals data appearing
- [ ] Slow transactions flagged appropriately
- [ ] Performance trends showing data

### Releases Tab
- [ ] Latest deployment appears as new release
- [ ] Source maps associated with release
- [ ] Deploy information includes commit hash
- [ ] Previous releases tracked correctly

### Settings Verification
- [ ] **Data Scrubbing**: Sensitive fields masked
- [ ] **Sampling Rates**: Production rates applied (10%)
- [ ] **Retention**: Data retention policy set
- [ ] **Privacy**: IP address handling configured
- [ ] **Integrations**: Vercel integration active

## Alert Configuration

### Error Alerts
- [ ] **New Issues**: Alert triggered for new error types
- [ ] **Error Spike**: Alert for 10+ errors in 5 minutes  
- [ ] **Critical Errors**: Immediate alerts for 5xx API errors
- [ ] **User Impact**: Alert when >1% of users affected

### Performance Alerts
- [ ] **Slow Endpoints**: Alert when P95 > 3000ms
- [ ] **Core Web Vitals**: Alert on LCP > 2.5s or CLS > 0.1
- [ ] **Error Rate**: Alert when API error rate > 2%
- [ ] **Apdex Score**: Alert when user satisfaction < 0.8

### Team Notifications
- [ ] **Slack Integration**: Alerts sent to #alerts channel
- [ ] **Email Notifications**: Critical alerts to on-call team
- [ ] **Escalation**: Unresolved alerts escalate after 30min
- [ ] **Maintenance Windows**: Alerts muted during deployments

## Security & Privacy

### Data Protection
- [ ] **PII Scrubbing**: No personal data in error messages
- [ ] **Token Filtering**: Auth tokens not captured
- [ ] **Query Parameters**: Sensitive params scrubbed
- [ ] **Headers**: Authorization headers filtered

### Access Control
- [ ] **Team Access**: Only authorized team members have access
- [ ] **Project Permissions**: Appropriate role-based access
- [ ] **API Keys**: Scoped to minimum required permissions
- [ ] **Audit Logs**: User access tracked

## Performance Impact

### Bundle Size
- [ ] **Client Bundle**: Sentry adds <50KB to bundle size
- [ ] **Code Splitting**: Sentry loaded asynchronously where possible
- [ ] **Tree Shaking**: Unused Sentry features removed
- [ ] **Compression**: Gzip/Brotli reduces Sentry overhead

### Runtime Performance
- [ ] **Sampling**: Performance monitoring at 10% sampling
- [ ] **Memory Usage**: No significant memory leaks detected
- [ ] **Network Impact**: Sentry requests don't block user actions
- [ ] **Error Handling**: Error capture doesn't impact UX

## Monitoring Health

### Weekly Checks
- [ ] **Error Trends**: Review error rate trends
- [ ] **Performance**: Check P95 response times
- [ ] **User Experience**: Review Core Web Vitals
- [ ] **Alert Noise**: Fine-tune alert thresholds

### Monthly Reviews
- [ ] **Cost Analysis**: Review Sentry usage and costs
- [ ] **Data Retention**: Adjust retention based on usage
- [ ] **Team Training**: Update team on new Sentry features
- [ ] **Integration Updates**: Update Sentry SDK versions

## Rollback Plan

### Emergency Rollback
- [ ] **Feature Flag**: Disable Sentry via environment variable
- [ ] **Build Rollback**: Previous deployment without Sentry
- [ ] **CSP Update**: Remove Sentry domains from CSP
- [ ] **Monitoring**: Alternative monitoring in place

### Gradual Rollback
- [ ] **Reduce Sampling**: Lower performance sampling to 1%
- [ ] **Disable Replay**: Turn off session replay if causing issues
- [ ] **Filter Errors**: Add noise filters to reduce alert volume
- [ ] **Team Communication**: Notify team of rollback reasons

## Success Criteria

### Technical
- ✅ **Zero Errors**: No Sentry-related build or runtime errors
- ✅ **Performance**: <5% impact on Core Web Vitals
- ✅ **Reliability**: 99.9% successful error capture rate
- ✅ **Coverage**: All critical paths instrumented

### Business
- ✅ **MTTR**: Mean time to resolution improved by 50%
- ✅ **User Experience**: Proactive issue detection before user reports
- ✅ **Team Efficiency**: Developers spend less time debugging production issues
- ✅ **Product Quality**: Faster identification and resolution of UX problems

---

## Sign-off

### Technical Lead
- [ ] Code review completed
- [ ] Security review passed
- [ ] Performance testing completed
- [ ] Documentation reviewed

### DevOps
- [ ] Infrastructure ready
- [ ] Monitoring configured
- [ ] Alerts tested
- [ ] Runbooks updated

### Product Owner
- [ ] User impact assessed
- [ ] Privacy requirements met
- [ ] Business metrics defined
- [ ] Success criteria agreed

**Deployment Approved By**: _______________  
**Date**: _______________  
**Environment**: _______________