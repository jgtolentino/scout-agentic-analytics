import { NextRequest, NextResponse } from 'next/server';
import { verifyJWT } from '@/lib/auth';

export interface AuthenticatedRequest extends NextRequest {
  user?: {
    id: string;
    email: string;
    name: string;
    tenantId: string;
    roles: string[];
  };
}

export async function authMiddleware(req: NextRequest): Promise<NextResponse | null> {
  const path = req.nextUrl.pathname;

  // Skip auth for public endpoints
  const publicPaths = [
    '/api/health',
    '/api/catalog/qa',
    '/login',
    '/signup',
    '/api/auth/callback'
  ];

  if (publicPaths.some(p => path.startsWith(p))) {
    return null; // Continue without auth
  }

  try {
    // Extract token from Authorization header or cookie
    const authHeader = req.headers.get('authorization');
    const token = authHeader?.replace('Bearer ', '') ||
                  req.cookies.get('auth-token')?.value;

    if (!token) {
      return NextResponse.json(
        { error: 'Unauthorized', message: 'Authentication token required' },
        { status: 401 }
      );
    }

    // Verify JWT token (implementation in lib/auth.ts)
    const user = await verifyJWT(token);

    if (!user) {
      return NextResponse.json(
        { error: 'Unauthorized', message: 'Invalid or expired token' },
        { status: 401 }
      );
    }

    // Add user to request context
    (req as AuthenticatedRequest).user = user;

    // Set tenant context for database RLS
    const response = NextResponse.next();
    response.headers.set('X-Tenant-ID', user.tenantId);
    response.headers.set('X-User-ID', user.id);

    return null; // Continue with request

  } catch (error) {
    console.error('Auth middleware error:', error);
    return NextResponse.json(
      { error: 'Unauthorized', message: 'Authentication failed' },
      { status: 401 }
    );
  }
}

// Azure AD B2C configuration
export const azureADConfig = {
  clientId: process.env.AZURE_AD_CLIENT_ID!,
  clientSecret: process.env.AZURE_AD_CLIENT_SECRET!,
  tenantId: process.env.AZURE_AD_TENANT_ID!,
  redirectUri: process.env.AZURE_AD_REDIRECT_URI!,
  scope: 'https://graph.microsoft.com/.default',
  authority: `https://login.microsoftonline.com/${process.env.AZURE_AD_TENANT_ID}`
};

// Role-based access patterns
export const rolePermissions = {
  admin: ['read', 'write', 'delete', 'manage_users', 'manage_tenants'],
  analyst: ['read', 'write', 'export_data'],
  viewer: ['read'],
  api_user: ['read', 'write']
} as const;

export type Role = keyof typeof rolePermissions;
export type Permission = typeof rolePermissions[Role][number];