import { NextRequest, NextResponse } from 'next/server';
import { getScoutMonitoring } from '@/lib/monitoring';
import { getScoutCache } from '@/lib/redis';
import { authMiddleware } from '@/middleware/auth';
import { rbacMiddleware } from '@/middleware/rbac';

export const runtime = 'nodejs';

export async function GET(req: NextRequest) {
  // Apply authentication and authorization
  const authResult = await authMiddleware(req);
  if (authResult) return authResult;

  const rbacResult = await rbacMiddleware({ requiredPermission: 'read' })(req);
  if (rbacResult) return rbacResult;

  try {
    const { searchParams } = req.nextUrl;
    const timeRange = parseInt(searchParams.get('timeRange') || '3600000'); // 1 hour default
    const format = searchParams.get('format') || 'json'; // json or prometheus

    const monitoring = getScoutMonitoring();
    const cache = getScoutCache();

    // Get system metrics
    const metrics = await collectMetrics(monitoring, cache, timeRange);

    // Format response
    if (format === 'prometheus') {
      const prometheusFormat = formatPrometheusMetrics(metrics);
      return new Response(prometheusFormat, {
        headers: { 'Content-Type': 'text/plain' }
      });
    }

    return NextResponse.json({
      timestamp: new Date().toISOString(),
      timeRange,
      metrics
    });

  } catch (error) {
    console.error('Metrics endpoint error:', error);
    return NextResponse.json(
      { error: 'Failed to collect metrics' },
      { status: 500 }
    );
  }
}

async function collectMetrics(monitoring: any, cache: any, timeRange: number) {
  const now = Date.now();

  return {
    // API Performance Metrics
    api: {
      requests: {
        total: monitoring.getMetricSummary('api.request.count', timeRange),
        duration: monitoring.getMetricSummary('api.request.duration', timeRange),
        errors: monitoring.getMetricSummary('error.count', timeRange)
      },
      endpoints: {
        semantic: monitoring.getMetricSummary('semantic.query.duration', timeRange),
        geo: monitoring.getMetricSummary('geo.export.duration', timeRange),
        askSuqi: monitoring.getMetricSummary('suqi.interaction.count', timeRange)
      }
    },

    // Cache Metrics
    cache: {
      stats: await cache.getStats(),
      performance: {
        hitRate: calculateHitRate(await cache.getStats()),
        responseTime: monitoring.getMetricSummary('cache.response.time', timeRange)
      }
    },

    // Business Metrics
    business: {
      usage: {
        activeUsers: monitoring.getMetricSummary('business.usage.active_users', timeRange),
        queriesPerUser: monitoring.getMetricSummary('business.usage.queries_per_user', timeRange),
        dataExports: monitoring.getMetricSummary('business.usage.data_exports', timeRange)
      },
      engagement: {
        sessionDuration: monitoring.getMetricSummary('business.engagement.session_duration', timeRange),
        repeatUsers: monitoring.getMetricSummary('business.engagement.repeat_users', timeRange),
        featureAdoption: monitoring.getMetricSummary('business.engagement.feature_adoption', timeRange)
      }
    },

    // Data Quality Metrics
    dataQuality: {
      parity: monitoring.getMetricSummary('data.quality.score', timeRange),
      completeness: monitoring.getMetricSummary('data.completeness', timeRange),
      freshness: monitoring.getMetricSummary('data.freshness', timeRange),
      accuracy: monitoring.getMetricSummary('data.accuracy', timeRange)
    },

    // System Health Metrics
    system: {
      health: monitoring.getMetricSummary('health.status', timeRange),
      responseTime: monitoring.getMetricSummary('health.responseTime', timeRange),
      uptime: process.uptime(),
      memory: getMemoryMetrics(),
      errors: {
        total: monitoring.getMetricSummary('error.count', timeRange),
        byType: getErrorMetricsByType(monitoring, timeRange),
        bySeverity: getErrorMetricsBySeverity(monitoring, timeRange)
      }
    },

    // Security Metrics
    security: {
      authentication: {
        attempts: monitoring.getMetricSummary('auth.attempts', timeRange),
        failures: monitoring.getMetricSummary('auth.failures', timeRange),
        success: monitoring.getMetricSummary('auth.success', timeRange)
      },
      rateLimit: {
        blocked: monitoring.getMetricSummary('ratelimit.blocked', timeRange),
        allowed: monitoring.getMetricSummary('ratelimit.allowed', timeRange)
      },
      tenantIsolation: {
        violations: monitoring.getMetricSummary('security.tenant.violations', timeRange),
        accessAttempts: monitoring.getMetricSummary('security.tenant.access', timeRange)
      }
    },

    // Ask Suqi Metrics
    askSuqi: {
      interactions: monitoring.getMetricSummary('suqi.interaction.count', timeRange),
      confidence: monitoring.getMetricSummary('suqi.confidence', timeRange),
      successRate: monitoring.getMetricSummary('suqi.success.rate', timeRange),
      intents: getAskSuqiIntentMetrics(monitoring, timeRange)
    }
  };
}

function calculateHitRate(stats: any): number {
  if (!stats || stats.hits + stats.misses === 0) return 0;
  return (stats.hits / (stats.hits + stats.misses)) * 100;
}

function getMemoryMetrics() {
  const memUsage = process.memoryUsage();
  return {
    rss: Math.round(memUsage.rss / 1024 / 1024), // MB
    heapUsed: Math.round(memUsage.heapUsed / 1024 / 1024), // MB
    heapTotal: Math.round(memUsage.heapTotal / 1024 / 1024), // MB
    external: Math.round(memUsage.external / 1024 / 1024), // MB
    arrayBuffers: Math.round(memUsage.arrayBuffers / 1024 / 1024) // MB
  };
}

function getErrorMetricsByType(monitoring: any, timeRange: number) {
  const errorTypes = ['ValidationError', 'AuthenticationError', 'DatabaseError', 'NetworkError'];
  return errorTypes.reduce((acc, type) => {
    acc[type] = monitoring.getMetricSummary(`error.${type}`, timeRange);
    return acc;
  }, {} as any);
}

function getErrorMetricsBySeverity(monitoring: any, timeRange: number) {
  const severities = ['low', 'medium', 'high', 'critical'];
  return severities.reduce((acc, severity) => {
    acc[severity] = monitoring.getMetricSummary(`error.severity.${severity}`, timeRange);
    return acc;
  }, {} as any);
}

function getAskSuqiIntentMetrics(monitoring: any, timeRange: number) {
  const intents = [
    'semantic_query', 'geo_export', 'parity_check',
    'data_quality', 'general_question', 'help'
  ];
  return intents.reduce((acc, intent) => {
    acc[intent] = monitoring.getMetricSummary(`suqi.intent.${intent}`, timeRange);
    return acc;
  }, {} as any);
}

function formatPrometheusMetrics(metrics: any): string {
  const lines: string[] = [];
  const timestamp = Date.now();

  // Helper function to add metric
  const addMetric = (name: string, value: number, labels: Record<string, string> = {}) => {
    const labelStr = Object.entries(labels)
      .map(([k, v]) => `${k}="${v}"`)
      .join(',');

    lines.push(`${name}{${labelStr}} ${value} ${timestamp}`);
  };

  // API Metrics
  if (metrics.api?.requests?.total) {
    addMetric('scout_api_requests_total', metrics.api.requests.total.count);
    addMetric('scout_api_request_duration_seconds', metrics.api.requests.duration?.average || 0);
    addMetric('scout_api_errors_total', metrics.api.requests.errors?.count || 0);
  }

  // Cache Metrics
  if (metrics.cache?.stats) {
    addMetric('scout_cache_hits_total', metrics.cache.stats.hits);
    addMetric('scout_cache_misses_total', metrics.cache.stats.misses);
    addMetric('scout_cache_hit_rate_percent', metrics.cache.performance?.hitRate || 0);
  }

  // System Metrics
  if (metrics.system?.memory) {
    addMetric('scout_memory_usage_bytes', metrics.system.memory.rss * 1024 * 1024);
    addMetric('scout_heap_usage_bytes', metrics.system.memory.heapUsed * 1024 * 1024);
  }

  addMetric('scout_uptime_seconds', metrics.system?.uptime || 0);

  // Data Quality Metrics
  if (metrics.dataQuality?.parity) {
    addMetric('scout_data_quality_score', metrics.dataQuality.parity.latest || 0);
  }

  // Business Metrics
  if (metrics.business?.usage?.activeUsers) {
    addMetric('scout_active_users', metrics.business.usage.activeUsers.latest || 0);
  }

  // Ask Suqi Metrics
  if (metrics.askSuqi?.interactions) {
    addMetric('scout_suqi_interactions_total', metrics.askSuqi.interactions.count || 0);
    addMetric('scout_suqi_confidence_score', metrics.askSuqi.confidence?.average || 0);
  }

  // Security Metrics
  if (metrics.security?.authentication) {
    addMetric('scout_auth_attempts_total', metrics.security.authentication.attempts?.count || 0);
    addMetric('scout_auth_failures_total', metrics.security.authentication.failures?.count || 0);
  }

  return lines.join('\n') + '\n';
}

// Real-time metrics endpoint
export async function POST(req: NextRequest) {
  // Apply authentication
  const authResult = await authMiddleware(req);
  if (authResult) return authResult;

  const rbacResult = await rbacMiddleware({ requiredPermission: 'read' })(req);
  if (rbacResult) return rbacResult;

  try {
    const { metric, value, dimensions } = await req.json();

    if (!metric || value === undefined) {
      return NextResponse.json(
        { error: 'Metric name and value are required' },
        { status: 400 }
      );
    }

    const monitoring = getScoutMonitoring();
    await monitoring.trackMetric(metric, value, dimensions);

    return NextResponse.json({ success: true });

  } catch (error) {
    console.error('Custom metric tracking error:', error);
    return NextResponse.json(
      { error: 'Failed to track metric' },
      { status: 500 }
    );
  }
}

// Metrics aggregation endpoint
export async function PUT(req: NextRequest) {
  const authResult = await authMiddleware(req);
  if (authResult) return authResult;

  const rbacResult = await rbacMiddleware({ requiredRole: 'admin' })(req);
  if (rbacResult) return rbacResult;

  try {
    const { action } = await req.json();

    const monitoring = getScoutMonitoring();

    switch (action) {
      case 'reset_stats':
        // Reset monitoring statistics
        await monitoring.resetStats();
        return NextResponse.json({ success: true, message: 'Statistics reset' });

      case 'export_metrics':
        // Export metrics for backup
        const metrics = await collectMetrics(monitoring, getScoutCache(), 24 * 60 * 60 * 1000); // 24 hours
        return NextResponse.json({
          success: true,
          data: metrics,
          timestamp: new Date().toISOString()
        });

      default:
        return NextResponse.json(
          { error: 'Invalid action' },
          { status: 400 }
        );
    }

  } catch (error) {
    console.error('Metrics management error:', error);
    return NextResponse.json(
      { error: 'Failed to perform action' },
      { status: 500 }
    );
  }
}