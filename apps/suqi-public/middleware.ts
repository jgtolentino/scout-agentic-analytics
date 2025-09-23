import { NextRequest, NextResponse } from 'next/server';
import { authMiddleware } from './middleware/auth';
import { rbacMiddleware, readOnly, analystOrAdmin, adminOnly } from './middleware/rbac';
import {
  apiRateLimit,
  authRateLimit,
  semanticQueryRateLimit,
  geoExportRateLimit,
  askSuqiRateLimit,
  developmentBypass
} from './middleware/rateLimit';

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // Development bypass for rate limiting
  if (developmentBypass(request)) {
    console.log(`[DEV] Bypassing middleware for: ${pathname}`);
  }

  try {
    // Health check endpoints - no middleware
    if (pathname.startsWith('/api/health')) {
      return NextResponse.next();
    }

    // Public endpoints - rate limiting only
    if (pathname.startsWith('/api/catalog/qa')) {
      if (!developmentBypass(request)) {
        const rateLimitResult = await apiRateLimit(request);
        if (rateLimitResult) return rateLimitResult;
      }
      return NextResponse.next();
    }

    // Authentication endpoints - special rate limiting
    if (pathname.startsWith('/api/auth')) {
      if (!developmentBypass(request)) {
        const rateLimitResult = await authRateLimit(request);
        if (rateLimitResult) return rateLimitResult;
      }
      return NextResponse.next();
    }

    // All other API routes require authentication
    if (pathname.startsWith('/api/')) {
      // Apply authentication middleware
      const authResult = await authMiddleware(request);
      if (authResult) return authResult;

      // Apply endpoint-specific middleware
      const middlewareResult = await applyEndpointMiddleware(request);
      if (middlewareResult) return middlewareResult;
    }

    // Continue to next middleware or route handler
    return NextResponse.next();

  } catch (error) {
    console.error('Middleware error:', error);

    // Return generic error to avoid exposing internal details
    return NextResponse.json(
      { error: 'Internal Server Error' },
      { status: 500 }
    );
  }
}

async function applyEndpointMiddleware(request: NextRequest): Promise<NextResponse | null> {
  const { pathname } = request.nextUrl;

  // Skip rate limiting in development
  const shouldApplyRateLimit = !developmentBypass(request);

  // Ask Suqi endpoints
  if (pathname.startsWith('/api/ask')) {
    // Rate limiting
    if (shouldApplyRateLimit) {
      const rateLimitResult = await askSuqiRateLimit(request);
      if (rateLimitResult) return rateLimitResult;
    }

    // RBAC - analysts and admins can use Ask Suqi
    const rbacResult = await analystOrAdmin(request);
    if (rbacResult) return rbacResult;

    return null;
  }

  // Semantic query endpoints
  if (pathname.startsWith('/api/semantic')) {
    // Rate limiting
    if (shouldApplyRateLimit) {
      const rateLimitResult = await semanticQueryRateLimit(request);
      if (rateLimitResult) return rateLimitResult;
    }

    // RBAC - read access required
    const rbacResult = await readOnly(request);
    if (rbacResult) return rbacResult;

    return null;
  }

  // Geo export endpoints
  if (pathname.startsWith('/api/geo')) {
    // Rate limiting
    if (shouldApplyRateLimit) {
      const rateLimitResult = await geoExportRateLimit(request);
      if (rateLimitResult) return rateLimitResult;
    }

    // RBAC - analysts and admins can export geo data
    const rbacResult = await analystOrAdmin(request);
    if (rbacResult) return rbacResult;

    return null;
  }

  // Admin endpoints
  if (pathname.startsWith('/api/admin')) {
    // Rate limiting
    if (shouldApplyRateLimit) {
      const rateLimitResult = await apiRateLimit(request);
      if (rateLimitResult) return rateLimitResult;
    }

    // RBAC - admin only
    const rbacResult = await adminOnly(request);
    if (rbacResult) return rbacResult;

    return null;
  }

  // Parity check endpoints
  if (pathname.startsWith('/api/parity')) {
    // Rate limiting
    if (shouldApplyRateLimit) {
      const rateLimitResult = await apiRateLimit(request);
      if (rateLimitResult) return rateLimitResult;
    }

    // RBAC - analysts and admins
    const rbacResult = await analystOrAdmin(request);
    if (rbacResult) return rbacResult;

    return null;
  }

  // Sync endpoints
  if (pathname.startsWith('/api/sync')) {
    // Rate limiting
    if (shouldApplyRateLimit) {
      const rateLimitResult = await apiRateLimit(request);
      if (rateLimitResult) return rateLimitResult;
    }

    // RBAC - admin only for sync operations
    const rbacResult = await adminOnly(request);
    if (rbacResult) return rbacResult;

    return null;
  }

  // Default API rate limiting for all other endpoints
  if (shouldApplyRateLimit) {
    const rateLimitResult = await apiRateLimit(request);
    if (rateLimitResult) return rateLimitResult;
  }

  // Default RBAC - read access required
  const rbacResult = await readOnly(request);
  if (rbacResult) return rbacResult;

  return null;
}

// Configuration for Next.js middleware
export const config = {
  matcher: [
    /*
     * Match all request paths except:
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico (favicon file)
     * - Public files (public folder)
     */
    '/((?!_next/static|_next/image|favicon.ico|public/).*)',
  ],
};

// Middleware helpers for development and testing
export function createTestRequest(
  url: string,
  options: {
    method?: string;
    headers?: Record<string, string>;
    userId?: string;
    tenantId?: string;
    roles?: string[];
  } = {}
): NextRequest {
  const { method = 'GET', headers = {}, userId, tenantId, roles = [] } = options;

  const req = new NextRequest(url, { method, headers });

  // Add test user context
  if (userId) {
    req.headers.set('x-user-id', userId);
  }
  if (tenantId) {
    req.headers.set('x-tenant-id', tenantId);
  }
  if (roles.length > 0) {
    req.headers.set('x-user-roles', roles.join(','));
  }

  return req;
}

// Middleware bypass for system health checks
export function bypassMiddleware(request: NextRequest): boolean {
  const { pathname } = request.nextUrl;

  // System endpoints that should bypass all middleware
  const systemPaths = [
    '/api/health',
    '/api/system/status',
    '/api/metrics',
    '/_next/',
    '/favicon.ico'
  ];

  return systemPaths.some(path => pathname.startsWith(path));
}

// Request logging for audit and debugging
export function logRequest(request: NextRequest, response?: NextResponse): void {
  const { method, url } = request;
  const userAgent = request.headers.get('user-agent') || 'unknown';
  const ip = request.headers.get('x-forwarded-for') ||
            request.headers.get('x-real-ip') ||
            'unknown';

  const userId = request.headers.get('x-user-id') || 'anonymous';
  const tenantId = request.headers.get('x-tenant-id') || 'unknown';

  const logEntry = {
    timestamp: new Date().toISOString(),
    method,
    url,
    userId,
    tenantId,
    ip,
    userAgent,
    status: response?.status || 'pending'
  };

  // In development, log to console
  if (process.env.NODE_ENV === 'development') {
    console.log('Request:', logEntry);
  }

  // In production, send to monitoring service
  // await monitoringService.logRequest(logEntry);
}