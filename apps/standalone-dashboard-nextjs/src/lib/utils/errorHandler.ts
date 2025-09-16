'use client';

// Comprehensive error handling utilities

export interface ErrorContext {
  component?: string;
  action?: string;
  userId?: string;
  timestamp?: string;
  url?: string;
  userAgent?: string;
  additionalData?: Record<string, any>;
}

export interface AppError {
  message: string;
  code?: string;
  type: 'network' | 'validation' | 'permission' | 'server' | 'client' | 'unknown';
  context?: ErrorContext;
  originalError?: Error;
  recoverable?: boolean;
  retryable?: boolean;
}

// Error types
export class NetworkError extends Error implements AppError {
  type: 'network' = 'network';
  code?: string;
  context?: ErrorContext;
  originalError?: Error;
  recoverable = true;
  retryable = true;

  constructor(message: string, code?: string, context?: ErrorContext) {
    super(message);
    this.name = 'NetworkError';
    this.code = code;
    this.context = context;
  }
}

export class ValidationError extends Error implements AppError {
  type: 'validation' = 'validation';
  code?: string;
  context?: ErrorContext;
  originalError?: Error;
  recoverable = true;
  retryable = false;

  constructor(message: string, code?: string, context?: ErrorContext) {
    super(message);
    this.name = 'ValidationError';
    this.code = code;
    this.context = context;
  }
}

export class PermissionError extends Error implements AppError {
  type: 'permission' = 'permission';
  code?: string;
  context?: ErrorContext;
  originalError?: Error;
  recoverable = false;
  retryable = false;

  constructor(message: string, code?: string, context?: ErrorContext) {
    super(message);
    this.name = 'PermissionError';
    this.code = code;
    this.context = context;
  }
}

// Error Logger
export class ErrorLogger {
  private static instance: ErrorLogger;
  private errors: AppError[] = [];
  private maxErrors = 100;

  static getInstance(): ErrorLogger {
    if (!ErrorLogger.instance) {
      ErrorLogger.instance = new ErrorLogger();
    }
    return ErrorLogger.instance;
  }

  // Log error with context
  log(error: Error | AppError, context?: ErrorContext): void {
    const appError: AppError = this.normalizeError(error, context);
    
    // Add to local storage
    this.errors.push(appError);
    if (this.errors.length > this.maxErrors) {
      this.errors.shift();
    }

    // Console logging with appropriate level
    if (appError.type === 'permission' || appError.type === 'server') {
      console.error('Application Error:', appError);
    } else if (appError.type === 'network') {
      console.warn('Network Error:', appError);
    } else {
      console.log('Application Event:', appError);
    }

    // Send to external logging service in production
    if (process.env.NODE_ENV === 'production') {
      this.sendToLoggingService(appError);
    }
  }

  private normalizeError(error: Error | AppError, context?: ErrorContext): AppError {
    if (this.isAppError(error)) {
      return {
        ...error,
        context: { ...error.context, ...context }
      };
    }

    // Convert regular Error to AppError
    return {
      message: error.message,
      type: 'unknown',
      context: {
        timestamp: new Date().toISOString(),
        url: typeof window !== 'undefined' ? window.location.href : '',
        userAgent: typeof navigator !== 'undefined' ? navigator.userAgent : '',
        ...context
      },
      originalError: error,
      recoverable: true,
      retryable: false
    };
  }

  private isAppError(error: any): error is AppError {
    return error && typeof error.type === 'string';
  }

  private async sendToLoggingService(error: AppError): Promise<void> {
    try {
      // Replace with your logging service endpoint
      await fetch('/api/errors', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(error)
      });
    } catch (e) {
      console.error('Failed to send error to logging service:', e);
    }
  }

  // Get recent errors
  getErrors(): AppError[] {
    return [...this.errors];
  }

  // Clear error log
  clearErrors(): void {
    this.errors = [];
  }

  // Get error statistics
  getStats() {
    const errorsByType = this.errors.reduce((acc, error) => {
      acc[error.type] = (acc[error.type] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);

    return {
      total: this.errors.length,
      byType: errorsByType,
      recent: this.errors.slice(-10)
    };
  }
}

// Global error logger instance
export const errorLogger = ErrorLogger.getInstance();

// Error Boundary helper
export interface ErrorBoundaryState {
  hasError: boolean;
  error?: AppError;
  errorId?: string;
}

export function createErrorBoundaryState(): ErrorBoundaryState {
  return { hasError: false };
}

export function handleErrorBoundaryError(
  error: Error,
  errorInfo: React.ErrorInfo,
  component: string
): ErrorBoundaryState {
  const errorId = Math.random().toString(36).substr(2, 9);
  const appError: AppError = {
    message: error.message,
    type: 'client',
    context: {
      component,
      timestamp: new Date().toISOString(),
      additionalData: errorInfo
    },
    originalError: error,
    recoverable: true,
    retryable: true
  };

  errorLogger.log(appError);

  return {
    hasError: true,
    error: appError,
    errorId
  };
}

// Retry mechanism
export interface RetryOptions {
  maxRetries?: number;
  delay?: number;
  backoffMultiplier?: number;
  retryCondition?: (error: any) => boolean;
}

export async function withRetry<T>(
  operation: () => Promise<T>,
  options: RetryOptions = {}
): Promise<T> {
  const {
    maxRetries = 3,
    delay = 1000,
    backoffMultiplier = 2,
    retryCondition = () => true
  } = options;

  let lastError: any;

  for (let attempt = 1; attempt <= maxRetries + 1; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;
      
      if (attempt > maxRetries || !retryCondition(error)) {
        break;
      }

      const waitTime = delay * Math.pow(backoffMultiplier, attempt - 1);
      await new Promise(resolve => setTimeout(resolve, waitTime));
    }
  }

  throw lastError;
}

// Circuit breaker pattern
export class CircuitBreaker {
  private failures = 0;
  private lastFailureTime = 0;
  private state: 'closed' | 'open' | 'half-open' = 'closed';

  constructor(
    private failureThreshold: number = 5,
    private timeout: number = 60000
  ) {}

  async execute<T>(operation: () => Promise<T>): Promise<T> {
    if (this.state === 'open') {
      if (Date.now() - this.lastFailureTime > this.timeout) {
        this.state = 'half-open';
      } else {
        throw new NetworkError('Circuit breaker is open');
      }
    }

    try {
      const result = await operation();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  private onSuccess() {
    this.failures = 0;
    this.state = 'closed';
  }

  private onFailure() {
    this.failures++;
    this.lastFailureTime = Date.now();
    
    if (this.failures >= this.failureThreshold) {
      this.state = 'open';
    }
  }

  getState() {
    return {
      state: this.state,
      failures: this.failures,
      lastFailureTime: this.lastFailureTime
    };
  }
}

// User-friendly error messages
export function getUserFriendlyMessage(error: AppError): string {
  switch (error.type) {
    case 'network':
      return 'Connection issue. Please check your internet connection and try again.';
    case 'permission':
      return 'You don\'t have permission to perform this action.';
    case 'validation':
      return error.message || 'Please check your input and try again.';
    case 'server':
      return 'Server error. Please try again in a few minutes.';
    default:
      return 'Something went wrong. Please try again.';
  }
}

// React hook for error handling
export function useErrorHandler() {
  const handleError = (error: Error | AppError, context?: ErrorContext) => {
    errorLogger.log(error, context);
  };

  const handleAsyncError = async <T>(
    operation: () => Promise<T>,
    context?: ErrorContext
  ): Promise<T | null> => {
    try {
      return await operation();
    } catch (error) {
      handleError(error as Error, context);
      return null;
    }
  };

  return {
    handleError,
    handleAsyncError,
    getErrorStats: () => errorLogger.getStats()
  };
}

// Global error handlers
export function setupGlobalErrorHandlers(): void {
  // Unhandled promise rejections
  window.addEventListener('unhandledrejection', (event) => {
    errorLogger.log(new Error(event.reason), {
      component: 'global',
      action: 'unhandled_promise_rejection'
    });
  });

  // Global errors
  window.addEventListener('error', (event) => {
    errorLogger.log(event.error || new Error(event.message), {
      component: 'global',
      action: 'global_error',
      additionalData: {
        filename: event.filename,
        lineno: event.lineno,
        colno: event.colno
      }
    });
  });
}

// Initialize error handling
if (typeof window !== 'undefined') {
  setupGlobalErrorHandlers();
}