import { getSecretOrEnv, SCOUT_SECRETS } from './keyVault';

// Telemetry events and metrics
export interface TelemetryEvent {
  name: string;
  timestamp: Date;
  properties: Record<string, any>;
  measurements?: Record<string, number>;
  user?: {
    id: string;
    tenantId: string;
  };
  session?: {
    id: string;
  };
}

export interface MetricData {
  name: string;
  value: number;
  timestamp: Date;
  dimensions?: Record<string, string>;
  unit?: string;
}

export interface LogEntry {
  level: 'debug' | 'info' | 'warn' | 'error' | 'critical';
  message: string;
  timestamp: Date;
  properties?: Record<string, any>;
  error?: Error;
  context?: {
    userId?: string;
    tenantId?: string;
    sessionId?: string;
    requestId?: string;
    operationId?: string;
  };
}

// Application Insights integration
export class ApplicationInsightsClient {
  private connectionString: string | null = null;
  private isInitialized: boolean = false;

  constructor() {
    this.initialize();
  }

  private async initialize(): Promise<void> {
    try {
      this.connectionString = await getSecretOrEnv(
        'APPLICATION_INSIGHTS_CONNECTION_STRING',
        'APPLICATIONINSIGHTS_CONNECTION_STRING'
      );

      if (this.connectionString) {
        this.isInitialized = true;
        console.log('Application Insights initialized');
      } else {
        console.warn('Application Insights connection string not found');
      }

    } catch (error) {
      console.error('Failed to initialize Application Insights:', error);
    }
  }

  async trackEvent(event: TelemetryEvent): Promise<void> {
    if (!this.isInitialized) return;

    try {
      // In a real implementation, you would use the Application Insights SDK
      // For now, we'll log to console in development
      if (process.env.NODE_ENV === 'development') {
        console.log('AI Event:', {
          name: event.name,
          properties: event.properties,
          measurements: event.measurements,
          timestamp: event.timestamp
        });
      }

      // Production implementation would use:
      // const appInsights = require('applicationinsights');
      // appInsights.defaultClient.trackEvent({
      //   name: event.name,
      //   properties: event.properties,
      //   measurements: event.measurements
      // });

    } catch (error) {
      console.error('Failed to track event:', error);
    }
  }

  async trackMetric(metric: MetricData): Promise<void> {
    if (!this.isInitialized) return;

    try {
      if (process.env.NODE_ENV === 'development') {
        console.log('AI Metric:', {
          name: metric.name,
          value: metric.value,
          dimensions: metric.dimensions,
          timestamp: metric.timestamp
        });
      }

      // Production implementation would use Application Insights SDK

    } catch (error) {
      console.error('Failed to track metric:', error);
    }
  }

  async trackTrace(log: LogEntry): Promise<void> {
    if (!this.isInitialized) return;

    try {
      if (process.env.NODE_ENV === 'development') {
        console.log(`AI Log [${log.level.toUpperCase()}]:`, {
          message: log.message,
          properties: log.properties,
          context: log.context,
          timestamp: log.timestamp
        });
      }

      // Production implementation would use Application Insights SDK

    } catch (error) {
      console.error('Failed to track trace:', error);
    }
  }

  async trackException(error: Error, context?: any): Promise<void> {
    if (!this.isInitialized) return;

    try {
      if (process.env.NODE_ENV === 'development') {
        console.error('AI Exception:', {
          error: {
            name: error.name,
            message: error.message,
            stack: error.stack
          },
          context,
          timestamp: new Date()
        });
      }

      // Production implementation would use Application Insights SDK

    } catch (err) {
      console.error('Failed to track exception:', err);
    }
  }
}

// Scout-specific monitoring
export class ScoutMonitoring {
  private appInsights: ApplicationInsightsClient;
  private metrics: Map<string, MetricData[]> = new Map();

  constructor() {
    this.appInsights = new ApplicationInsightsClient();
  }

  // API request monitoring
  async trackAPIRequest(
    method: string,
    endpoint: string,
    statusCode: number,
    duration: number,
    context: {
      userId?: string;
      tenantId?: string;
      requestId?: string;
    }
  ): Promise<void> {
    const event: TelemetryEvent = {
      name: 'API_Request',
      timestamp: new Date(),
      properties: {
        method,
        endpoint,
        statusCode,
        success: statusCode < 400,
        ...context
      },
      measurements: {
        duration
      },
      user: context.userId ? {
        id: context.userId,
        tenantId: context.tenantId || 'unknown'
      } : undefined
    };

    await this.appInsights.trackEvent(event);

    // Track as metric
    await this.trackMetric('api.request.duration', duration, {
      method,
      endpoint,
      status: statusCode.toString()
    });

    await this.trackMetric('api.request.count', 1, {
      method,
      endpoint,
      status: statusCode.toString()
    });
  }

  // Semantic query monitoring
  async trackSemanticQuery(
    query: {
      dimensions: string[];
      measures: string[];
      filters?: any;
    },
    result: {
      rowCount: number;
      executionTime: number;
      cacheHit: boolean;
    },
    context: {
      userId: string;
      tenantId: string;
      sessionId?: string;
    }
  ): Promise<void> {
    const event: TelemetryEvent = {
      name: 'Semantic_Query',
      timestamp: new Date(),
      properties: {
        dimensions: query.dimensions.join(','),
        measures: query.measures.join(','),
        filterCount: query.filters ? Object.keys(query.filters).length : 0,
        cacheHit: result.cacheHit,
        ...context
      },
      measurements: {
        rowCount: result.rowCount,
        executionTime: result.executionTime
      },
      user: {
        id: context.userId,
        tenantId: context.tenantId
      },
      session: context.sessionId ? { id: context.sessionId } : undefined
    };

    await this.appInsights.trackEvent(event);

    // Performance metrics
    await this.trackMetric('semantic.query.duration', result.executionTime, {
      tenantId: context.tenantId,
      cacheHit: result.cacheHit.toString()
    });

    await this.trackMetric('semantic.query.rows', result.rowCount, {
      tenantId: context.tenantId
    });
  }

  // Ask Suqi conversation monitoring
  async trackAskSuqiInteraction(
    interaction: {
      message: string;
      intent: string;
      confidence: number;
      success: boolean;
      executionTime: number;
      artifactCount: number;
    },
    context: {
      userId: string;
      tenantId: string;
      sessionId: string;
    }
  ): Promise<void> {
    const event: TelemetryEvent = {
      name: 'AskSuqi_Interaction',
      timestamp: new Date(),
      properties: {
        intent: interaction.intent,
        success: interaction.success,
        messageLength: interaction.message.length,
        ...context
      },
      measurements: {
        confidence: interaction.confidence,
        executionTime: interaction.executionTime,
        artifactCount: interaction.artifactCount
      },
      user: {
        id: context.userId,
        tenantId: context.tenantId
      },
      session: {
        id: context.sessionId
      }
    };

    await this.appInsights.trackEvent(event);

    // User engagement metrics
    await this.trackMetric('suqi.interaction.count', 1, {
      tenantId: context.tenantId,
      intent: interaction.intent,
      success: interaction.success.toString()
    });

    await this.trackMetric('suqi.confidence', interaction.confidence, {
      tenantId: context.tenantId,
      intent: interaction.intent
    });
  }

  // Data quality monitoring
  async trackDataQuality(
    check: {
      type: 'parity' | 'completeness' | 'consistency' | 'validity';
      passed: boolean;
      score: number;
      details: any;
    },
    context: {
      tenantId: string;
      dataSource?: string;
    }
  ): Promise<void> {
    const event: TelemetryEvent = {
      name: 'Data_Quality_Check',
      timestamp: new Date(),
      properties: {
        checkType: check.type,
        passed: check.passed,
        details: JSON.stringify(check.details),
        ...context
      },
      measurements: {
        qualityScore: check.score
      }
    };

    await this.appInsights.trackEvent(event);

    await this.trackMetric('data.quality.score', check.score, {
      tenantId: context.tenantId,
      checkType: check.type,
      dataSource: context.dataSource || 'unknown'
    });
  }

  // Performance monitoring
  async trackMetric(
    name: string,
    value: number,
    dimensions?: Record<string, string>
  ): Promise<void> {
    const metric: MetricData = {
      name,
      value,
      timestamp: new Date(),
      dimensions
    };

    await this.appInsights.trackMetric(metric);

    // Store for local aggregation
    const key = `${name}:${JSON.stringify(dimensions || {})}`;
    const metrics = this.metrics.get(key) || [];
    metrics.push(metric);

    // Keep only last 1000 data points per metric
    if (metrics.length > 1000) {
      metrics.splice(0, metrics.length - 1000);
    }

    this.metrics.set(key, metrics);
  }

  // Error tracking
  async trackError(
    error: Error,
    context: {
      operation: string;
      userId?: string;
      tenantId?: string;
      requestId?: string;
      severity?: 'low' | 'medium' | 'high' | 'critical';
    }
  ): Promise<void> {
    const log: LogEntry = {
      level: 'error',
      message: error.message,
      timestamp: new Date(),
      properties: {
        operation: context.operation,
        errorName: error.name,
        stack: error.stack,
        severity: context.severity || 'medium'
      },
      error,
      context: {
        userId: context.userId,
        tenantId: context.tenantId,
        requestId: context.requestId
      }
    };

    await this.appInsights.trackTrace(log);
    await this.appInsights.trackException(error, context);

    // Error rate metrics
    await this.trackMetric('error.count', 1, {
      operation: context.operation,
      errorType: error.name,
      severity: context.severity || 'medium'
    });
  }

  // Business metrics
  async trackBusinessMetric(
    metric: {
      name: string;
      value: number;
      category: 'usage' | 'engagement' | 'performance' | 'quality';
    },
    context: {
      tenantId: string;
      userId?: string;
    }
  ): Promise<void> {
    const event: TelemetryEvent = {
      name: 'Business_Metric',
      timestamp: new Date(),
      properties: {
        metricName: metric.name,
        category: metric.category,
        ...context
      },
      measurements: {
        value: metric.value
      },
      user: context.userId ? {
        id: context.userId,
        tenantId: context.tenantId
      } : undefined
    };

    await this.appInsights.trackEvent(event);

    await this.trackMetric(`business.${metric.category}.${metric.name}`, metric.value, {
      tenantId: context.tenantId
    });
  }

  // Health check monitoring
  async trackHealthCheck(
    service: string,
    status: 'healthy' | 'unhealthy' | 'degraded',
    responseTime?: number,
    details?: any
  ): Promise<void> {
    const event: TelemetryEvent = {
      name: 'Health_Check',
      timestamp: new Date(),
      properties: {
        service,
        status,
        details: details ? JSON.stringify(details) : undefined
      },
      measurements: responseTime ? { responseTime } : undefined
    };

    await this.appInsights.trackEvent(event);

    await this.trackMetric('health.status', status === 'healthy' ? 1 : 0, {
      service
    });

    if (responseTime) {
      await this.trackMetric('health.responseTime', responseTime, {
        service
      });
    }
  }

  // Get metric summary
  getMetricSummary(name: string, timeRange: number = 3600000): {
    count: number;
    average: number;
    min: number;
    max: number;
    latest: number;
  } | null {
    const now = Date.now();
    const allMetrics = Array.from(this.metrics.entries())
      .filter(([key]) => key.startsWith(name))
      .flatMap(([, metrics]) => metrics)
      .filter(metric => now - metric.timestamp.getTime() <= timeRange);

    if (allMetrics.length === 0) {
      return null;
    }

    const values = allMetrics.map(m => m.value);
    return {
      count: values.length,
      average: values.reduce((sum, val) => sum + val, 0) / values.length,
      min: Math.min(...values),
      max: Math.max(...values),
      latest: values[values.length - 1]
    };
  }
}

// Alert management
export interface AlertRule {
  id: string;
  name: string;
  metric: string;
  condition: 'greater_than' | 'less_than' | 'equals' | 'not_equals';
  threshold: number;
  timeWindow: number; // in milliseconds
  severity: 'low' | 'medium' | 'high' | 'critical';
  enabled: boolean;
  notificationChannels: string[];
}

export class AlertManager {
  private rules: Map<string, AlertRule> = new Map();
  private monitoring: ScoutMonitoring;
  private lastAlerts: Map<string, Date> = new Map();
  private cooldownPeriod = 5 * 60 * 1000; // 5 minutes

  constructor(monitoring: ScoutMonitoring) {
    this.monitoring = monitoring;
    this.setupDefaultRules();
  }

  private setupDefaultRules(): void {
    const defaultRules: AlertRule[] = [
      {
        id: 'api_error_rate',
        name: 'High API Error Rate',
        metric: 'error.count',
        condition: 'greater_than',
        threshold: 10,
        timeWindow: 5 * 60 * 1000, // 5 minutes
        severity: 'high',
        enabled: true,
        notificationChannels: ['email', 'slack']
      },
      {
        id: 'response_time',
        name: 'High Response Time',
        metric: 'api.request.duration',
        condition: 'greater_than',
        threshold: 5000, // 5 seconds
        timeWindow: 10 * 60 * 1000, // 10 minutes
        severity: 'medium',
        enabled: true,
        notificationChannels: ['slack']
      },
      {
        id: 'data_quality',
        name: 'Data Quality Issue',
        metric: 'data.quality.score',
        condition: 'less_than',
        threshold: 0.95, // 95%
        timeWindow: 15 * 60 * 1000, // 15 minutes
        severity: 'high',
        enabled: true,
        notificationChannels: ['email', 'slack']
      }
    ];

    defaultRules.forEach(rule => this.rules.set(rule.id, rule));
  }

  async checkAlerts(): Promise<void> {
    for (const [ruleId, rule] of this.rules.entries()) {
      if (!rule.enabled) continue;

      // Check cooldown
      const lastAlert = this.lastAlerts.get(ruleId);
      if (lastAlert && Date.now() - lastAlert.getTime() < this.cooldownPeriod) {
        continue;
      }

      // Get metric data
      const summary = this.monitoring.getMetricSummary(rule.metric, rule.timeWindow);
      if (!summary) continue;

      // Check condition
      let triggered = false;
      const value = summary.average;

      switch (rule.condition) {
        case 'greater_than':
          triggered = value > rule.threshold;
          break;
        case 'less_than':
          triggered = value < rule.threshold;
          break;
        case 'equals':
          triggered = value === rule.threshold;
          break;
        case 'not_equals':
          triggered = value !== rule.threshold;
          break;
      }

      if (triggered) {
        await this.triggerAlert(rule, value, summary);
        this.lastAlerts.set(ruleId, new Date());
      }
    }
  }

  private async triggerAlert(rule: AlertRule, value: number, summary: any): Promise<void> {
    const alert = {
      ruleId: rule.id,
      ruleName: rule.name,
      metric: rule.metric,
      threshold: rule.threshold,
      actualValue: value,
      severity: rule.severity,
      timestamp: new Date(),
      summary
    };

    console.warn('ALERT TRIGGERED:', alert);

    // Track alert as event
    await this.monitoring.appInsights.trackEvent({
      name: 'Alert_Triggered',
      timestamp: new Date(),
      properties: {
        ruleId: rule.id,
        ruleName: rule.name,
        metric: rule.metric,
        severity: rule.severity,
        threshold: rule.threshold.toString(),
        actualValue: value.toString()
      }
    });

    // Send notifications
    for (const channel of rule.notificationChannels) {
      await this.sendNotification(channel, alert);
    }
  }

  private async sendNotification(channel: string, alert: any): Promise<void> {
    switch (channel) {
      case 'email':
        // Implementation would send email notification
        console.log(`[EMAIL ALERT] ${alert.ruleName}: ${alert.actualValue} vs ${alert.threshold}`);
        break;
      case 'slack':
        // Implementation would send Slack notification
        console.log(`[SLACK ALERT] ${alert.ruleName}: ${alert.actualValue} vs ${alert.threshold}`);
        break;
      default:
        console.log(`[${channel.toUpperCase()} ALERT] ${alert.ruleName}: ${alert.actualValue} vs ${alert.threshold}`);
    }
  }

  addRule(rule: AlertRule): void {
    this.rules.set(rule.id, rule);
  }

  removeRule(ruleId: string): void {
    this.rules.delete(ruleId);
  }

  updateRule(ruleId: string, updates: Partial<AlertRule>): void {
    const rule = this.rules.get(ruleId);
    if (rule) {
      this.rules.set(ruleId, { ...rule, ...updates });
    }
  }
}

// Global monitoring instance
let scoutMonitoring: ScoutMonitoring | null = null;
let alertManager: AlertManager | null = null;

export function getScoutMonitoring(): ScoutMonitoring {
  if (!scoutMonitoring) {
    scoutMonitoring = new ScoutMonitoring();
  }
  return scoutMonitoring;
}

export function getAlertManager(): AlertManager {
  if (!alertManager) {
    alertManager = new AlertManager(getScoutMonitoring());
  }
  return alertManager;
}

// Start monitoring
export function startMonitoring(): void {
  const alertMgr = getAlertManager();

  // Check alerts every minute
  setInterval(async () => {
    try {
      await alertMgr.checkAlerts();
    } catch (error) {
      console.error('Alert check failed:', error);
    }
  }, 60 * 1000);

  console.log('Scout monitoring started');
}