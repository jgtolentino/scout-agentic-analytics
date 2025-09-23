# Scout v7 Dashboard Security Guide

## Overview

The Scout v7 Analytics Dashboard implements comprehensive security measures to protect sensitive retail analytics data and ensure compliance with industry standards.

## Authentication & Authorization

### Authentication Methods
- **Email/Password**: Standard username/password authentication via Supabase Auth
- **Google OAuth**: Single sign-on with Google Workspace accounts
- **Session Management**: Secure session handling with automatic expiration

### Authorization Model
- **Role-Based Access Control (RBAC)**: Four distinct user roles with graduated permissions
- **Row-Level Security (RLS)**: Database-level access controls
- **Resource-Level Permissions**: Fine-grained access to specific stores and brands

### User Roles

#### Admin
- Full system access and user management
- **Permissions**: All permissions including `user_management`, `scout_admin`
- **Access**: All stores, all brands, all features

#### Analyst
- Advanced analytics and data export capabilities
- **Permissions**: `scout_read`, `scout_write`, `analytics_advanced`, `export_data`, `ai_insights`
- **Access**: Configurable store/brand restrictions

#### Viewer
- Read-only access to dashboards and analytics
- **Permissions**: `scout_read`, `analytics_advanced`
- **Access**: Configurable store/brand restrictions

#### Guest
- Limited read-only access
- **Permissions**: `scout_read` only
- **Access**: Specific store/brand restrictions required

### Permission Types
- `scout_read`: Read Scout transaction data
- `scout_write`: Modify Scout data
- `scout_admin`: Administrative functions
- `analytics_advanced`: Advanced analytics features
- `export_data`: Data export capabilities
- `ai_insights`: AI-powered insights access
- `store_management`: Store configuration
- `brand_management`: Brand configuration
- `user_management`: Manage other users

## Security Features

### Rate Limiting
- **API Rate Limits**: 100 requests per minute per IP address (configurable)
- **Progressive Throttling**: Sliding window rate limiting
- **Automatic Cleanup**: Expired rate limit entries are cleaned up automatically

### Request Validation
- **Query Sanitization**: Input validation and XSS prevention
- **Complexity Scoring**: Prevents overly complex queries that could impact performance
- **Origin Validation**: CSRF protection through origin/referer checking
- **Parameter Limits**: Caps on query size and complexity

### Security Headers
- **Content Security Policy (CSP)**: Prevents XSS and code injection
- **X-Frame-Options**: Prevents clickjacking attacks
- **HSTS**: Enforces HTTPS connections
- **X-Content-Type-Options**: Prevents MIME sniffing
- **Referrer Policy**: Controls referrer information leakage

### Data Access Controls
- **Store-Level Access**: Users can be restricted to specific stores
- **Brand-Level Access**: Users can be restricted to specific brands
- **Query Filtering**: Automatic application of access restrictions to all queries
- **Audit Logging**: All data access is logged with user context

### Session Security
- **Secure Cookies**: HttpOnly, Secure, and SameSite cookie attributes
- **Session Timeout**: Configurable session expiration (default: 60 minutes)
- **Session Refresh**: Automatic token refresh for active sessions
- **Concurrent Session Limits**: Optional limits on concurrent sessions per user

## Security Monitoring

### Audit Logging
All user actions are logged with the following information:
- User ID and role
- Action performed
- Resource accessed
- IP address and user agent
- Timestamp and request ID
- Query parameters and results

### Security Events
The system monitors and logs security events including:
- **Failed Authentication**: Login attempts with invalid credentials
- **Rate Limit Exceeded**: Users hitting API rate limits
- **Invalid Origin**: Requests from unauthorized domains
- **Permission Denied**: Access attempts to restricted resources
- **Query Complexity Exceeded**: Overly complex queries blocked
- **Suspicious Activity**: Unusual access patterns or behavior

### Event Severity Levels
- **Critical**: Immediate security threats requiring urgent response
- **High**: Significant security issues requiring prompt attention
- **Medium**: Moderate security concerns for monitoring
- **Low**: Informational security events for awareness

## Configuration

### Environment Variables

#### Authentication
```bash
NEXT_PUBLIC_SUPABASE_URL=your_supabase_project_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key
NEXTAUTH_SECRET=your_nextauth_secret_here
```

#### Security Settings
```bash
RATE_LIMIT_REQUESTS_PER_MINUTE=100
SESSION_TIMEOUT_MINUTES=60
SESSION_REFRESH_THRESHOLD_MINUTES=15
MAX_QUERY_COMPLEXITY=1000
API_REQUEST_TIMEOUT_MS=30000
```

#### Audit & Logging
```bash
AUDIT_LOG_RETENTION_DAYS=90
AUDIT_LOG_LEVEL=info
LOG_LEVEL=info
```

#### Feature Flags
```bash
ENABLE_AI_INSIGHTS=true
ENABLE_EXPORT_FEATURES=true
ENABLE_ADVANCED_ANALYTICS=true
ENABLE_REAL_TIME_UPDATES=true
```

## Database Security

### Row-Level Security (RLS)
- **User Profiles**: Users can only access their own profile data
- **Admin Override**: Administrators can access all user profiles
- **Audit Logs**: Users can view their own audit logs, admins can view all

### Data Encryption
- **Data at Rest**: Supabase provides automatic encryption for stored data
- **Data in Transit**: All connections use TLS 1.2+ encryption
- **Sensitive Fields**: Additional encryption for sensitive data fields

### Database Access Controls
- **Service Role**: Limited service role key with restricted permissions
- **Anonymous Access**: Public (anon) key with minimal read-only access
- **Connection Pooling**: Secure connection pooling with authentication

## API Security

### Request Authentication
All API endpoints require valid authentication:
1. Session validation via Supabase Auth
2. User profile verification
3. Permission checking
4. Access restriction enforcement

### Response Security
- **Security Headers**: Comprehensive security headers on all responses
- **Error Handling**: Secure error responses without sensitive information
- **Rate Limit Headers**: Clear rate limiting information for clients
- **Request Tracking**: Unique request IDs for audit and debugging

### Input Validation
- **Query Parameter Sanitization**: Removal of potentially dangerous characters
- **Type Validation**: Strict type checking for all inputs
- **Length Limits**: Maximum lengths for strings and arrays
- **Range Validation**: Numeric range checking for amounts and dates

## Security Best Practices

### Development
- **Environment Separation**: Separate environments for development, staging, and production
- **Secret Management**: Secure storage and rotation of API keys and secrets
- **Code Review**: Security-focused code review process
- **Dependency Scanning**: Regular scanning for vulnerable dependencies

### Deployment
- **HTTPS Only**: All production traffic must use HTTPS
- **Security Headers**: Comprehensive security header implementation
- **CDN Security**: Proper CDN configuration with security features
- **Monitoring**: Real-time security monitoring and alerting

### Incident Response
- **Security Incidents**: Clear procedures for security incident response
- **User Notification**: Process for notifying users of security issues
- **Data Breach Response**: Compliance with data breach notification requirements
- **Forensic Logging**: Detailed logging for security investigation

## Compliance

### Data Protection
- **GDPR Compliance**: Privacy controls and data subject rights
- **Data Retention**: Configurable data retention policies
- **Data Minimization**: Collection of only necessary data
- **Purpose Limitation**: Data used only for specified purposes

### Industry Standards
- **OWASP Top 10**: Protection against common web vulnerabilities
- **ISO 27001**: Information security management best practices
- **SOC 2**: Service organization controls for security and availability

### Regular Security Reviews
- **Vulnerability Assessments**: Regular security vulnerability assessments
- **Penetration Testing**: Periodic penetration testing by security experts
- **Security Audits**: Comprehensive security audits and compliance reviews
- **Documentation Updates**: Regular updates to security documentation

## Security Contact

For security issues or concerns:
- **Security Team**: security@tbwa.com
- **Emergency Contact**: Available 24/7 for critical security incidents
- **Responsible Disclosure**: Coordinated vulnerability disclosure process

## Version History

- **v1.0.0**: Initial security implementation with RBAC, RLS, and audit logging
- **Future Versions**: Planned enhancements include advanced threat detection and ML-based anomaly detection