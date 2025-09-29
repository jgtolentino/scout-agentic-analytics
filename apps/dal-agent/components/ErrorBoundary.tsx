import React from 'react'

interface ErrorBoundaryState {
  hasError: boolean
  error: Error | null
  errorInfo: React.ErrorInfo | null
}

interface ErrorBoundaryProps {
  children: React.ReactNode
  fallback?: React.ComponentType<{ error: Error; errorInfo: React.ErrorInfo }>
}

class ErrorBoundary extends React.Component<ErrorBoundaryProps, ErrorBoundaryState> {
  constructor(props: ErrorBoundaryProps) {
    super(props)
    this.state = {
      hasError: false,
      error: null,
      errorInfo: null
    }
  }

  static getDerivedStateFromError(error: Error): Partial<ErrorBoundaryState> {
    return {
      hasError: true,
      error
    }
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    this.setState({
      error,
      errorInfo
    })

    // Log error to console in development
    if (process.env.NODE_ENV === 'development') {
      console.error('ErrorBoundary caught an error:', error, errorInfo)
    }

    // In production, you might want to log to an error service
    if (process.env.NODE_ENV === 'production') {
      console.error('Scout Dashboard Error:', {
        error: error.message,
        stack: error.stack,
        componentStack: errorInfo.componentStack
      })
    }
  }

  render() {
    if (this.state.hasError) {
      // Custom fallback component
      if (this.props.fallback) {
        const FallbackComponent = this.props.fallback
        return (
          <FallbackComponent
            error={this.state.error!}
            errorInfo={this.state.errorInfo!}
          />
        )
      }

      // Default error UI
      return (
        <div className="min-h-screen bg-gray-50 flex flex-col justify-center py-12 sm:px-6 lg:px-8">
          <div className="sm:mx-auto sm:w-full sm:max-w-md">
            <div className="bg-white py-8 px-4 shadow sm:rounded-lg sm:px-10">
              <div className="text-center">
                <svg
                  className="mx-auto h-12 w-12 text-red-400"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  aria-hidden="true"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"
                  />
                </svg>
                <h2 className="mt-4 text-xl font-semibold text-gray-900">
                  Something went wrong
                </h2>
                <p className="mt-2 text-sm text-gray-600">
                  The Scout v7 Dashboard encountered an unexpected error.
                </p>

                {process.env.NODE_ENV === 'development' && this.state.error && (
                  <div className="mt-4 p-3 bg-red-50 border border-red-200 rounded-md text-left">
                    <p className="text-xs font-medium text-red-800 mb-2">
                      Development Error Details:
                    </p>
                    <pre className="text-xs text-red-700 overflow-auto max-h-40">
                      {this.state.error.message}
                      {this.state.error.stack}
                    </pre>
                  </div>
                )}
              </div>

              <div className="mt-6 space-y-4">
                <button
                  onClick={() => window.location.reload()}
                  className="w-full scout-button-primary"
                >
                  Reload Page
                </button>

                <a
                  href="/api/health"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="w-full scout-button-secondary text-center block"
                >
                  Check System Health
                </a>

                <div className="text-center">
                  <p className="text-xs text-gray-500">
                    If this issue persists, contact{' '}
                    <a
                      href="mailto:support@tbwa.com"
                      className="text-scout-primary hover:text-blue-500"
                    >
                      support@tbwa.com
                    </a>
                  </p>
                </div>
              </div>
            </div>
          </div>

          {/* Error Details for Development */}
          {process.env.NODE_ENV === 'development' && this.state.errorInfo && (
            <div className="mt-8 sm:mx-auto sm:w-full sm:max-w-4xl">
              <div className="bg-gray-900 py-4 px-6 shadow sm:rounded-lg">
                <h3 className="text-lg font-medium text-white mb-4">
                  Component Stack Trace
                </h3>
                <pre className="text-xs text-gray-300 overflow-auto max-h-60">
                  {this.state.errorInfo.componentStack}
                </pre>
              </div>
            </div>
          )}
        </div>
      )
    }

    return this.props.children
  }
}

export default ErrorBoundary

// Hook version for functional components
export const useErrorHandler = () => {
  return (error: Error, errorInfo?: React.ErrorInfo) => {
    console.error('React Error:', error, errorInfo)

    // In production, you might want to send to error tracking service
    if (process.env.NODE_ENV === 'production') {
      // Example: Sentry.captureException(error)
    }
  }
}