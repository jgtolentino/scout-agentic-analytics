// Simplified auth service for Azure migration - no authentication required for now
export interface UserProfile {
  id: string
  user_id: string
  email: string
  full_name?: string
  role: 'admin' | 'analyst' | 'viewer' | 'guest'
  permissions: string[]
  allowed_stores?: number[]
  allowed_brands?: string[]
  created_at: string
  updated_at: string
  last_login_at?: string
  is_active: boolean
  default_date_range?: string
  preferred_timezone?: string
  dashboard_config?: Record<string, any>
}

export class AuthService {
  async logUserAction(
    userId: string,
    action: string,
    resourceType?: string,
    resourceId?: string,
    details?: Record<string, any>
  ): Promise<void> {
    // Simplified logging for Azure migration
    console.log('User action:', { userId, action, resourceType, resourceId, details })
  }

  hasPermission(userPermissions: string[], requiredPermission: string): boolean {
    return userPermissions.includes(requiredPermission)
  }

  canAccessStore(allowedStores: number[] | null, storeId: number): boolean {
    if (!allowedStores) return true // null means access to all stores
    return allowedStores.includes(storeId)
  }

  canAccessBrand(allowedBrands: string[] | null, brand: string): boolean {
    if (!allowedBrands) return true // null means access to all brands
    return allowedBrands.includes(brand)
  }

  // Permission checking utilities
  static readonly PERMISSIONS = {
    SCOUT_READ: 'scout_read',
    SCOUT_WRITE: 'scout_write',
    SCOUT_ADMIN: 'scout_admin',
    ANALYTICS_ADVANCED: 'analytics_advanced',
    EXPORT_DATA: 'export_data',
    AI_INSIGHTS: 'ai_insights',
    STORE_MANAGEMENT: 'store_management',
    BRAND_MANAGEMENT: 'brand_management',
    USER_MANAGEMENT: 'user_management'
  } as const

  static readonly ROLES = {
    ADMIN: 'admin',
    ANALYST: 'analyst',
    VIEWER: 'viewer',
    GUEST: 'guest'
  } as const

  // Role-based permission defaults
  static getDefaultPermissions(role: string): string[] {
    switch (role) {
      case AuthService.ROLES.ADMIN:
        return Object.values(AuthService.PERMISSIONS)
      case AuthService.ROLES.ANALYST:
        return [
          AuthService.PERMISSIONS.SCOUT_READ,
          AuthService.PERMISSIONS.SCOUT_WRITE,
          AuthService.PERMISSIONS.ANALYTICS_ADVANCED,
          AuthService.PERMISSIONS.EXPORT_DATA,
          AuthService.PERMISSIONS.AI_INSIGHTS
        ]
      case AuthService.ROLES.VIEWER:
        return [
          AuthService.PERMISSIONS.SCOUT_READ,
          AuthService.PERMISSIONS.ANALYTICS_ADVANCED
        ]
      case AuthService.ROLES.GUEST:
        return [AuthService.PERMISSIONS.SCOUT_READ]
      default:
        return [AuthService.PERMISSIONS.SCOUT_READ]
    }
  }

  // Security headers for API requests
  static getSecurityHeaders(userProfile: UserProfile): Record<string, string> {
    return {
      'X-User-ID': userProfile.user_id,
      'X-User-Role': userProfile.role,
      'X-User-Permissions': JSON.stringify(userProfile.permissions),
      'X-Request-ID': crypto.randomUUID(),
      'X-Timestamp': new Date().toISOString()
    }
  }

  // Validate API request authorization
  static validateAPIAccess(
    userProfile: UserProfile,
    requiredPermissions: string[] = [AuthService.PERMISSIONS.SCOUT_READ]
  ): { authorized: boolean; missingPermissions: string[] } {
    const missingPermissions = requiredPermissions.filter(
      permission => !userProfile.permissions.includes(permission)
    )

    return {
      authorized: missingPermissions.length === 0 && userProfile.is_active,
      missingPermissions
    }
  }
}

export const authService = new AuthService()