import { NextApiRequest } from 'next'

export interface SecurityConfig {
  rateLimitRequestsPerMinute: number
  sessionTimeoutMinutes: number
  sessionRefreshThresholdMinutes: number
  auditLogRetentionDays: number
  maxQueryComplexity: number
  apiRequestTimeoutMs: number
  enableAIInsights: boolean
  enableExportFeatures: boolean
  enableAdvancedAnalytics: boolean
  enableRealTimeUpdates: boolean
}

export class SecurityManager {
  private static config: SecurityConfig = {
    rateLimitRequestsPerMinute: parseInt(process.env.RATE_LIMIT_REQUESTS_PER_MINUTE || '100'),
    sessionTimeoutMinutes: parseInt(process.env.SESSION_TIMEOUT_MINUTES || '60'),
    sessionRefreshThresholdMinutes: parseInt(process.env.SESSION_REFRESH_THRESHOLD_MINUTES || '15'),
    auditLogRetentionDays: parseInt(process.env.AUDIT_LOG_RETENTION_DAYS || '90'),
    maxQueryComplexity: parseInt(process.env.MAX_QUERY_COMPLEXITY || '1000'),
    apiRequestTimeoutMs: parseInt(process.env.API_REQUEST_TIMEOUT_MS || '30000'),
    enableAIInsights: process.env.ENABLE_AI_INSIGHTS === 'true',
    enableExportFeatures: process.env.ENABLE_EXPORT_FEATURES === 'true',
    enableAdvancedAnalytics: process.env.ENABLE_ADVANCED_ANALYTICS === 'true',
    enableRealTimeUpdates: process.env.ENABLE_REAL_TIME_UPDATES === 'true'
  }

  // Rate limiting state (in production, use Redis or database)
  private static rateLimitStore = new Map<string, { count: number; resetTime: number }>()

  /**
   * Check if request is within rate limits
   */
  static checkRateLimit(req: NextApiRequest): { allowed: boolean; remaining: number; resetTime: number } {
    const clientIP = this.getClientIP(req)
    const now = Date.now()
    const windowMs = 60 * 1000 // 1 minute window

    const key = `rate_limit:${clientIP}`
    const current = this.rateLimitStore.get(key)

    if (!current || now > current.resetTime) {
      // New window or expired window
      const resetTime = now + windowMs
      this.rateLimitStore.set(key, { count: 1, resetTime })
      return {
        allowed: true,
        remaining: this.config.rateLimitRequestsPerMinute - 1,
        resetTime
      }
    }

    if (current.count >= this.config.rateLimitRequestsPerMinute) {
      // Rate limit exceeded
      return {
        allowed: false,
        remaining: 0,
        resetTime: current.resetTime
      }
    }

    // Increment counter
    current.count++
    this.rateLimitStore.set(key, current)

    return {
      allowed: true,
      remaining: this.config.rateLimitRequestsPerMinute - current.count,
      resetTime: current.resetTime
    }
  }

  /**
   * Get client IP address from request
   */
  static getClientIP(req: NextApiRequest): string {
    const forwarded = req.headers['x-forwarded-for']
    const ip = (typeof forwarded === 'string' ? forwarded.split(',')[0] : forwarded?.[0]) ||
               req.headers['x-real-ip'] ||
               req.connection.remoteAddress ||
               '127.0.0.1'

    return Array.isArray(ip) ? ip[0] : ip
  }

  /**
   * Sanitize query parameters to prevent injection attacks
   */
  static sanitizeQuery(query: Record<string, any>): Record<string, any> {
    const sanitized: Record<string, any> = {}

    for (const [key, value] of Object.entries(query)) {
      if (typeof value === 'string') {
        // Remove potentially dangerous characters
        sanitized[key] = value
          .replace(/[<>\"'%;()&+]/g, '')
          .trim()
          .substring(0, 1000) // Limit length
      } else if (Array.isArray(value)) {
        sanitized[key] = value
          .filter(item => typeof item === 'string')
          .map(item => item.replace(/[<>\"'%;()&+]/g, '').trim().substring(0, 100))
          .slice(0, 50) // Limit array size
      } else if (typeof value === 'number' && !isNaN(value)) {
        sanitized[key] = value
      }
    }

    return sanitized
  }

  /**
   * Validate request origin and referrer
   */
  static validateRequestOrigin(req: NextApiRequest): boolean {
    const origin = req.headers.origin
    const referer = req.headers.referer
    const host = req.headers.host

    // In development, allow any origin
    if (process.env.NODE_ENV === 'development') {
      return true
    }

    // Check if origin matches our domain
    if (origin) {
      const allowedOrigins = [
        `https://${host}`,
        'https://scout-v7-dashboard.vercel.app',
        'https://scout.tbwa.com'
      ]

      if (!allowedOrigins.includes(origin)) {
        return false
      }
    }

    // Check referer if present
    if (referer && !referer.startsWith(`https://${host}`)) {
      return false
    }

    return true
  }

  /**
   * Generate security headers for API responses
   */
  static getSecurityHeaders(): Record<string, string> {
    return {
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'DENY',
      'X-XSS-Protection': '1; mode=block',
      'Referrer-Policy': 'strict-origin-when-cross-origin',
      'Content-Security-Policy': [
        "default-src 'self'",
        "script-src 'self' 'unsafe-eval' 'unsafe-inline'",
        "style-src 'self' 'unsafe-inline'",
        "img-src 'self' data: https:",
        "font-src 'self' data:",
        "connect-src 'self' https://*.supabase.co https://*.supabase.io",
        "frame-ancestors 'none'"
      ].join('; '),
      'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
      'Permissions-Policy': [
        'camera=()',
        'microphone=()',
        'geolocation=()',
        'payment=()',
        'usb=()'
      ].join(', ')
    }
  }

  /**
   * Check if a feature is enabled for the user
   */
  static isFeatureEnabled(feature: keyof SecurityConfig, userRole: string = 'viewer'): boolean {
    const featureValue = this.config[feature]

    if (typeof featureValue !== 'boolean') {
      return true // Non-boolean features are always enabled
    }

    // Feature flags based on user roles
    if (!featureValue) {
      return false
    }

    switch (feature) {
      case 'enableAIInsights':
        return ['admin', 'analyst'].includes(userRole)
      case 'enableExportFeatures':
        return ['admin', 'analyst'].includes(userRole)
      case 'enableAdvancedAnalytics':
        return ['admin', 'analyst', 'viewer'].includes(userRole)
      case 'enableRealTimeUpdates':
        return true // Available to all authenticated users
      default:
        return true
    }
  }

  /**
   * Calculate query complexity score
   */
  static calculateQueryComplexity(filters: Record<string, any>, options: Record<string, any>): number {
    let complexity = 10 // Base complexity

    // Add complexity for filters
    Object.keys(filters).forEach(key => {
      const value = filters[key]
      if (Array.isArray(value)) {
        complexity += value.length * 2
      } else if (value) {
        complexity += 5
      }
    })

    // Add complexity for options
    if (options.limit && options.limit > 1000) {
      complexity += Math.floor(options.limit / 1000) * 10
    }

    if (options.sort_by) {
      complexity += 5
    }

    // Date range queries add complexity
    if (filters.date_range) {
      const start = new Date(filters.date_range.start)
      const end = new Date(filters.date_range.end)
      const daysDiff = Math.abs((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24))

      if (daysDiff > 90) {
        complexity += Math.floor(daysDiff / 30) * 5
      }
    }

    return complexity
  }

  /**
   * Validate query complexity
   */
  static validateQueryComplexity(filters: Record<string, any>, options: Record<string, any>): { valid: boolean; complexity: number; maxAllowed: number } {
    const complexity = this.calculateQueryComplexity(filters, options)
    const maxAllowed = this.config.maxQueryComplexity

    return {
      valid: complexity <= maxAllowed,
      complexity,
      maxAllowed
    }
  }

  /**
   * Generate request fingerprint for security monitoring
   */
  static generateRequestFingerprint(req: NextApiRequest): string {
    const components = [
      this.getClientIP(req),
      req.headers['user-agent'] || '',
      req.headers['accept-language'] || '',
      req.headers['accept-encoding'] || ''
    ]

    // Create a simple hash (in production, use crypto.createHash)
    const fingerprint = Buffer.from(components.join('|')).toString('base64')
    return fingerprint.substring(0, 32)
  }

  /**
   * Log security event
   */
  static async logSecurityEvent(
    event: string,
    severity: 'low' | 'medium' | 'high' | 'critical',
    details: Record<string, any>,
    req?: NextApiRequest
  ): Promise<void> {
    const logEntry = {
      timestamp: new Date().toISOString(),
      event,
      severity,
      details,
      client_ip: req ? this.getClientIP(req) : null,
      user_agent: req?.headers['user-agent'] || null,
      fingerprint: req ? this.generateRequestFingerprint(req) : null
    }

    // In production, send to logging service
    console.log('SECURITY_EVENT:', JSON.stringify(logEntry))
  }

  /**
   * Clean up expired rate limit entries
   */
  static cleanupRateLimitStore(): void {
    const now = Date.now()
    const entries = Array.from(this.rateLimitStore.entries())
    for (const [key, value] of entries) {
      if (now > value.resetTime) {
        this.rateLimitStore.delete(key)
      }
    }
  }
}

// Cleanup rate limit store every 5 minutes
if (typeof window === 'undefined') {
  setInterval(() => {
    SecurityManager.cleanupRateLimitStore()
  }, 5 * 60 * 1000)
}