import { URL } from 'url';
import dns from 'dns/promises';

interface SecurityConfig {
  enableInternet: boolean;
  allowedDomains: string[];
  maxFileSize?: number;
  blockedPaths?: string[];
  sensitivePatterns?: RegExp[];
}

interface ValidationResult {
  allowed: boolean;
  reason?: string;
}

export class SecuritySandbox {
  private config: SecurityConfig;
  private actionLog: Map<string, number>;
  private rateLimits: Map<string, { max: number; window: number }>;

  constructor(config: SecurityConfig) {
    this.config = {
      maxFileSize: 10 * 1024 * 1024, // 10MB default
      blockedPaths: [
        '/etc/passwd',
        '/etc/shadow',
        '~/.ssh',
        '~/.aws',
        '~/.config',
        '/root',
      ],
      sensitivePatterns: [
        /password[\s]*[:=]/i,
        /api[_-]?key[\s]*[:=]/i,
        /secret[\s]*[:=]/i,
        /token[\s]*[:=]/i,
        /private[_-]?key/i,
      ],
      ...config,
    };

    this.actionLog = new Map();
    this.rateLimits = new Map([
      ['screenshot', { max: 60, window: 60000 }], // 60 per minute
      ['click', { max: 100, window: 60000 }],     // 100 per minute
      ['type', { max: 50, window: 60000 }],       // 50 per minute
      ['key', { max: 100, window: 60000 }],       // 100 per minute
    ]);
  }

  async validateAction(action: string, params: any): Promise<void> {
    // Check rate limits
    this.checkRateLimit(action);

    // Validate based on action type
    switch (action) {
      case 'computer_use':
        await this.validateComputerUse(params);
        break;
      
      case 'type_text':
      case 'type':
        this.validateTextInput(params.text);
        break;
      
      case 'navigate_url':
        await this.validateUrl(params.url);
        break;
      
      case 'file_access':
        this.validateFilePath(params.path);
        break;
    }

    // Log action
    this.logAction(action, params);
  }

  private checkRateLimit(action: string): void {
    const limit = this.rateLimits.get(action);
    if (!limit) return;

    const now = Date.now();
    const key = `${action}:${Math.floor(now / limit.window)}`;
    const count = this.actionLog.get(key) || 0;

    if (count >= limit.max) {
      throw new Error(
        `Rate limit exceeded for ${action}: ${limit.max} per ${limit.window}ms`
      );
    }

    this.actionLog.set(key, count + 1);
  }

  private async validateComputerUse(params: any): Promise<void> {
    const { task } = params;
    
    // Check for suspicious patterns in task description
    const suspiciousPatterns = [
      /download.*malware/i,
      /hack.*system/i,
      /steal.*data/i,
      /delete.*system.*files/i,
      /format.*drive/i,
      /access.*bank.*account/i,
      /social.*security.*number/i,
    ];

    for (const pattern of suspiciousPatterns) {
      if (pattern.test(task)) {
        throw new Error(`Task contains potentially harmful instructions`);
      }
    }
  }

  private validateTextInput(text: string): void {
    if (!text) return;

    // Check for sensitive data patterns
    for (const pattern of this.config.sensitivePatterns!) {
      if (pattern.test(text)) {
        throw new Error(
          `Text input contains potentially sensitive information`
        );
      }
    }

    // Check for SQL injection patterns
    const sqlPatterns = [
      /;\s*DROP\s+TABLE/i,
      /;\s*DELETE\s+FROM/i,
      /UNION\s+SELECT/i,
      /OR\s+1\s*=\s*1/i,
    ];

    for (const pattern of sqlPatterns) {
      if (pattern.test(text)) {
        throw new Error(`Text input contains potentially harmful SQL`);
      }
    }
  }

  private async validateUrl(url: string): Promise<void> {
    if (!this.config.enableInternet) {
      throw new Error(`Internet access is disabled`);
    }

    try {
      const parsedUrl = new URL(url);
      const hostname = parsedUrl.hostname;

      // Check if domain is in allowlist
      if (this.config.allowedDomains.length > 0) {
        const allowed = this.config.allowedDomains.some(domain => {
          return hostname === domain || hostname.endsWith(`.${domain}`);
        });

        if (!allowed) {
          throw new Error(
            `Domain ${hostname} is not in the allowed domains list`
          );
        }
      }

      // Block private IP ranges
      const ip = await this.resolveHostname(hostname);
      if (this.isPrivateIP(ip)) {
        throw new Error(`Access to private IP addresses is blocked`);
      }

      // Block suspicious ports
      const blockedPorts = [22, 23, 445, 3389, 5900, 5901];
      const port = parseInt(parsedUrl.port);
      if (port && blockedPorts.includes(port)) {
        throw new Error(`Access to port ${port} is blocked`);
      }
    } catch (error) {
      if (error.message.includes('Invalid URL')) {
        throw new Error(`Invalid URL format: ${url}`);
      }
      throw error;
    }
  }

  private validateFilePath(path: string): void {
    if (!path) return;

    // Normalize path
    const normalizedPath = path.replace(/^~/, '/home/user');

    // Check blocked paths
    for (const blockedPath of this.config.blockedPaths!) {
      if (normalizedPath.startsWith(blockedPath)) {
        throw new Error(`Access to ${path} is blocked for security reasons`);
      }
    }

    // Block path traversal attempts
    if (path.includes('../') || path.includes('..\\')) {
      throw new Error(`Path traversal attempts are blocked`);
    }
  }

  private async resolveHostname(hostname: string): Promise<string> {
    try {
      const addresses = await dns.resolve4(hostname);
      return addresses[0];
    } catch {
      // If DNS resolution fails, return the hostname
      return hostname;
    }
  }

  private isPrivateIP(ip: string): boolean {
    const parts = ip.split('.').map(Number);
    if (parts.length !== 4) return false;

    // Check private IP ranges
    return (
      // 10.0.0.0/8
      parts[0] === 10 ||
      // 172.16.0.0/12
      (parts[0] === 172 && parts[1] >= 16 && parts[1] <= 31) ||
      // 192.168.0.0/16
      (parts[0] === 192 && parts[1] === 168) ||
      // 127.0.0.0/8 (localhost)
      parts[0] === 127 ||
      // 169.254.0.0/16 (link-local)
      (parts[0] === 169 && parts[1] === 254)
    );
  }

  private logAction(action: string, params: any): void {
    console.error(`[Security] Action: ${action}`, {
      timestamp: new Date().toISOString(),
      params: this.sanitizeParams(params),
    });
  }

  private sanitizeParams(params: any): any {
    if (typeof params !== 'object' || !params) return params;

    const sanitized = { ...params };
    
    // Redact sensitive fields
    const sensitiveFields = ['password', 'token', 'key', 'secret'];
    for (const field of sensitiveFields) {
      if (field in sanitized) {
        sanitized[field] = '[REDACTED]';
      }
    }

    return sanitized;
  }

  getActionStats(): Record<string, number> {
    const stats: Record<string, number> = {};
    
    for (const [key, count] of this.actionLog.entries()) {
      const [action] = key.split(':');
      stats[action] = (stats[action] || 0) + count;
    }

    return stats;
  }

  clearOldLogs(): void {
    const now = Date.now();
    const maxAge = 3600000; // 1 hour

    for (const [key] of this.actionLog.entries()) {
      const [, timestamp] = key.split(':');
      const window = parseInt(timestamp) * 60000; // Convert back to ms
      
      if (now - window > maxAge) {
        this.actionLog.delete(key);
      }
    }
  }
}