# API Versioning Guide

## Overview

This application implements a comprehensive API versioning strategy to ensure backward compatibility while enabling new features and improvements.

## Versioning Strategy

### URL Path Versioning
- **Format**: `/api/{version}/endpoint`
- **Examples**:
  - `/api/v1/users`
  - `/api/v2/users`
  - `/api/legacy/users`

### Header-Based Versioning
- **Header**: `API-Version` or `X-API-Version`
- **Example**: `API-Version: v2`

### Default Behavior
- If no version is specified, defaults to `v1`
- Latest stable version: `v2`

## Available Versions

### Version 1 (v1) - Stable
- **Status**: Supported
- **Features**: Basic CRUD, Authentication, Data operations
- **Rate Limit**: 100 requests per 15 minutes

### Version 2 (v2) - Latest
- **Status**: Supported
- **Features**: Everything in v1 + Analytics, AI Chat, Real-time updates
- **Rate Limit**: 200 requests per 15 minutes
- **New Endpoints**: `/api/v2/analytics`, `/api/v2/ai-chat`

### Legacy Version - Deprecated
- **Status**: Deprecated (Sunset: 2024-12-31)
- **Features**: Basic operations only
- **Rate Limit**: 50 requests per 15 minutes
- **Warning**: Will be removed after sunset date

## Implementation

### Middleware Configuration

The API versioning is handled by Next.js middleware:

```typescript
// /apps/web/src/middleware.ts
const API_VERSIONS = {
  v1: { supported: true, deprecated: false },
  v2: { supported: true, deprecated: false },
  legacy: { supported: true, deprecated: true, sunset: '2024-12-31' }
};
```

### Creating Versioned Endpoints

Use the `withApiVersion` wrapper:

```typescript
import { withApiVersion, versionedResponse } from '@/lib/api/versioning';

export const GET = withApiVersion(async (req, version) => {
  // Version-specific logic
  const data = version === 'v2' 
    ? await getEnhancedData() 
    : await getBasicData();
    
  return Response.json(versionedResponse(data, version));
});
```

### Client Usage

#### JavaScript/TypeScript Client

```typescript
import { ApiClient } from '@/lib/api/client';

// Create versioned client
const api = new ApiClient({ version: 'v2' });

// Make requests
const users = await api.get('/users');
const newUser = await api.post('/users', { name: 'John' });
```

#### React Hook

```typescript
import { useApiClient } from '@/lib/api/client';

function MyComponent() {
  const { get, post, loading, error } = useApiClient('v2');
  
  const fetchUsers = async () => {
    const users = await get('/users');
    // Handle users
  };
}
```

#### cURL Examples

```bash
# Using URL path
curl https://api.example.com/api/v2/users

# Using header
curl -H "API-Version: v2" https://api.example.com/api/users
```

## Response Format

All versioned responses follow this structure:

```json
{
  "version": "v2",
  "data": {
    // Response data
  },
  "metadata": {
    "timestamp": "2024-01-20T10:00:00Z",
    "deprecated": false
  }
}
```

### Error Response

```json
{
  "version": "v1",
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input",
    "details": []
  },
  "metadata": {
    "timestamp": "2024-01-20T10:00:00Z"
  }
}
```

## Headers

### Response Headers

- `X-API-Version`: Current API version used
- `X-API-Latest-Version`: Latest available version
- `X-API-Deprecated`: `true` if using deprecated version
- `X-API-Deprecation-Date`: Sunset date for deprecated versions
- `Warning`: Deprecation warning message
- `X-RateLimit-Limit`: Rate limit for current version
- `X-RateLimit-Window`: Rate limit time window

### Request Headers

- `API-Version`: Specify desired API version
- `Accept-Version`: Alternative header for version

## Migration

### Data Migration Endpoint

```bash
POST /api/migration
{
  "data": { /* your data */ },
  "fromVersion": "v1",
  "toVersion": "v2"
}
```

### Migration Rules

#### Legacy → v1
- Adds version metadata
- Normalizes field names

#### v1 → v2
- Adds metadata wrapper
- Enables new features
- Transforms data structure

## Version Discovery

### List Available Versions

```bash
GET /api/versions

Response:
{
  "versions": [
    {
      "version": "v1",
      "supported": true,
      "deprecated": false,
      "features": ["basic", "auth", "data"],
      "current": true
    },
    {
      "version": "v2",
      "supported": true,
      "deprecated": false,
      "features": ["basic", "auth", "data", "analytics", "ai"],
      "latest": true
    }
  ],
  "default": "v1",
  "latest": "v2"
}
```

## Best Practices

### For API Providers

1. **Always version from the start** - Even if you only have v1
2. **Announce deprecations early** - Give users time to migrate
3. **Maintain compatibility** - Don't break existing endpoints
4. **Document changes** - Clear migration guides
5. **Use semantic versioning** - Major versions for breaking changes

### For API Consumers

1. **Specify version explicitly** - Don't rely on defaults
2. **Monitor deprecation warnings** - Plan migrations early
3. **Test with latest version** - Stay current with features
4. **Handle version errors** - Graceful fallbacks
5. **Use client libraries** - Automatic version handling

## Deprecation Process

1. **Announcement** - 6 months before sunset
2. **Warning Headers** - Added to all responses
3. **Console Warnings** - In client libraries
4. **Email Notifications** - To registered developers
5. **Sunset** - Version becomes unavailable

## Feature Availability by Version

| Feature | Legacy | v1 | v2 |
|---------|--------|----|----|
| Basic CRUD | ✅ | ✅ | ✅ |
| Authentication | ❌ | ✅ | ✅ |
| Advanced Filters | ❌ | ✅ | ✅ |
| Batch Operations | ❌ | ✅ | ✅ |
| Analytics | ❌ | ❌ | ✅ |
| AI Chat | ❌ | ❌ | ✅ |
| Real-time Updates | ❌ | ❌ | ✅ |
| Webhooks | ❌ | ❌ | ✅ |

## Testing

### Version-Specific Tests

```typescript
describe('API Versioning', () => {
  test('v1 returns basic data', async () => {
    const res = await fetch('/api/v1/users');
    expect(res.headers.get('X-API-Version')).toBe('v1');
  });
  
  test('v2 includes enhanced features', async () => {
    const res = await fetch('/api/v2/users');
    const data = await res.json();
    expect(data.data[0]).toHaveProperty('analytics');
  });
  
  test('legacy shows deprecation warning', async () => {
    const res = await fetch('/api/legacy/users');
    expect(res.headers.get('X-API-Deprecated')).toBe('true');
  });
});
```

## Monitoring

Track version usage:
- Request counts by version
- Deprecation warning views
- Migration endpoint usage
- Version-specific error rates

## FAQ

**Q: Can I use multiple versions in one application?**
A: Yes, but it's recommended to standardize on one version.

**Q: What happens after sunset date?**
A: The version returns 410 Gone status with migration instructions.

**Q: How do I know which version to use?**
A: Use the latest stable version (v2) for new applications.

**Q: Can I request features from v2 in v1?**
A: No, features are version-specific. Upgrade to access new features.