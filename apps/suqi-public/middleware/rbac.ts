import { NextRequest, NextResponse } from 'next/server';
import { AuthenticatedRequest, Role, Permission, rolePermissions } from './auth';

export interface RBACOptions {
  requiredRole?: Role;
  requiredPermission?: Permission;
  requiredPermissions?: Permission[];
  allowSelf?: boolean; // Allow if user is accessing their own resources
  tenantIsolation?: boolean; // Enforce tenant-level access
}

export function rbacMiddleware(options: RBACOptions = {}) {
  return async (req: AuthenticatedRequest): Promise<NextResponse | null> => {
    const { user } = req;

    if (!user) {
      return NextResponse.json(
        { error: 'Forbidden', message: 'Authentication required for this resource' },
        { status: 403 }
      );
    }

    // Check role-based access
    if (options.requiredRole && !hasRole(user.roles, options.requiredRole)) {
      return NextResponse.json(
        {
          error: 'Forbidden',
          message: `Role '${options.requiredRole}' required for this resource`,
          userRole: user.roles
        },
        { status: 403 }
      );
    }

    // Check permission-based access
    if (options.requiredPermission && !hasPermission(user.permissions, options.requiredPermission)) {
      return NextResponse.json(
        {
          error: 'Forbidden',
          message: `Permission '${options.requiredPermission}' required for this resource`,
          userPermissions: user.permissions
        },
        { status: 403 }
      );
    }

    // Check multiple permissions (user must have ALL)
    if (options.requiredPermissions && !hasAllPermissions(user.permissions, options.requiredPermissions)) {
      return NextResponse.json(
        {
          error: 'Forbidden',
          message: `Permissions [${options.requiredPermissions.join(', ')}] required for this resource`,
          userPermissions: user.permissions
        },
        { status: 403 }
      );
    }

    // Check self-access (user accessing their own resources)
    if (options.allowSelf && isSelfAccess(req, user.id)) {
      return null; // Allow access
    }

    // Tenant isolation check
    if (options.tenantIsolation && !validateTenantAccess(req, user.tenantId)) {
      return NextResponse.json(
        {
          error: 'Forbidden',
          message: 'Access denied: insufficient tenant permissions',
          userTenant: user.tenantId
        },
        { status: 403 }
      );
    }

    return null; // Access granted
  };
}

// Helper functions
function hasRole(userRoles: string[], requiredRole: Role): boolean {
  return userRoles.includes(requiredRole);
}

function hasPermission(userPermissions: string[], requiredPermission: Permission): boolean {
  return userPermissions.includes(requiredPermission);
}

function hasAllPermissions(userPermissions: string[], requiredPermissions: Permission[]): boolean {
  return requiredPermissions.every(permission => userPermissions.includes(permission));
}

function isSelfAccess(req: AuthenticatedRequest, userId: string): boolean {
  const { pathname, searchParams } = req.nextUrl;

  // Check URL path for user ID
  if (pathname.includes(`/users/${userId}`) || pathname.includes(`/user/${userId}`)) {
    return true;
  }

  // Check query parameters
  const targetUserId = searchParams.get('userId') || searchParams.get('user_id');
  return targetUserId === userId;
}

function validateTenantAccess(req: AuthenticatedRequest, userTenantId: string): boolean {
  const { searchParams } = req.nextUrl;

  // Check if request specifies a tenant
  const requestedTenant = searchParams.get('tenant') ||
                          searchParams.get('tenantId') ||
                          req.headers.get('X-Tenant-ID');

  if (!requestedTenant) {
    return true; // No specific tenant requested
  }

  return requestedTenant === userTenantId;
}

// Predefined RBAC middleware configurations
export const adminOnly = rbacMiddleware({ requiredRole: 'admin' });

export const analystOrAdmin = rbacMiddleware({
  requiredPermissions: ['read', 'write']
});

export const readOnly = rbacMiddleware({
  requiredPermission: 'read'
});

export const dataExport = rbacMiddleware({
  requiredPermission: 'export_data'
});

export const userManagement = rbacMiddleware({
  requiredPermission: 'manage_users'
});

export const tenantManagement = rbacMiddleware({
  requiredPermission: 'manage_tenants'
});

export const selfOrAdmin = rbacMiddleware({
  allowSelf: true,
  requiredRole: 'admin'
});

export const tenantIsolated = rbacMiddleware({
  tenantIsolation: true
});

// API route protection decorator
export function protectRoute(options: RBACOptions) {
  return function(handler: Function) {
    return async function(req: AuthenticatedRequest, ...args: any[]) {
      const rbacCheck = rbacMiddleware(options);
      const authResult = await rbacCheck(req);

      if (authResult) {
        return authResult; // Return the error response
      }

      return handler(req, ...args);
    };
  };
}

// Resource-based access control
export interface ResourceAccess {
  resourceType: string;
  resourceId: string;
  action: 'read' | 'write' | 'delete';
  tenantId?: string;
  ownerId?: string;
}

export function checkResourceAccess(
  user: { id: string; tenantId: string; permissions: string[] },
  resource: ResourceAccess
): boolean {
  // Admin can access everything
  if (user.permissions.includes('manage_tenants')) {
    return true;
  }

  // Check tenant isolation
  if (resource.tenantId && resource.tenantId !== user.tenantId) {
    return false;
  }

  // Check ownership
  if (resource.ownerId && resource.ownerId === user.id) {
    return true;
  }

  // Check action permissions
  const actionPermissions = {
    read: 'read',
    write: 'write',
    delete: 'delete'
  };

  return user.permissions.includes(actionPermissions[resource.action]);
}

// Database query filtering for RLS
export function buildTenantFilter(user: { tenantId: string; permissions: string[] }): string {
  // Super admin can see all tenants
  if (user.permissions.includes('manage_tenants')) {
    return ''; // No filter
  }

  // Regular users only see their tenant data
  return `AND tenant_id = '${user.tenantId}'`;
}

// Audit logging for access control
export interface AccessLog {
  userId: string;
  tenantId: string;
  resource: string;
  action: string;
  allowed: boolean;
  timestamp: Date;
  ip?: string;
  userAgent?: string;
}

export function logAccess(req: AuthenticatedRequest, resource: string, action: string, allowed: boolean): void {
  const logEntry: AccessLog = {
    userId: req.user?.id || 'anonymous',
    tenantId: req.user?.tenantId || 'unknown',
    resource,
    action,
    allowed,
    timestamp: new Date(),
    ip: req.headers.get('x-forwarded-for') || req.headers.get('x-real-ip') || 'unknown',
    userAgent: req.headers.get('user-agent') || 'unknown'
  };

  // Log to your audit system
  console.log('Access Log:', logEntry);

  // In production, send to audit service
  // await auditService.log(logEntry);
}