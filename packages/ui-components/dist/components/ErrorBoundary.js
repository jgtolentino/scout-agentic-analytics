import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { Component } from 'react';
import { AlertTriangle, RefreshCw } from 'lucide-react';
export default class ErrorBoundary extends Component {
    constructor(props) {
        super(props);
        this.handleRetry = () => {
            this.setState({ hasError: false, error: undefined, errorInfo: undefined });
        };
        this.state = { hasError: false };
    }
    static getDerivedStateFromError(error) {
        return { hasError: true, error };
    }
    componentDidCatch(error, errorInfo) {
        this.setState({ error, errorInfo });
        // Call onError prop if provided
        if (this.props.onError) {
            this.props.onError(error, errorInfo);
        }
        // Log error in development
        if (process.env.NODE_ENV === 'development') {
            console.error('ErrorBoundary caught an error:', error, errorInfo);
        }
    }
    render() {
        if (this.state.hasError) {
            // Custom fallback UI if provided
            if (this.props.fallback) {
                return this.props.fallback;
            }
            // Default error UI
            return (_jsxs("div", { className: `flex flex-col items-center justify-center p-8 bg-red-50 border border-red-200 rounded-lg ${this.props.className || ''}`, children: [_jsxs("div", { className: "flex items-center gap-3 mb-4", children: [_jsx(AlertTriangle, { className: "w-6 h-6 text-red-500" }), _jsx("h2", { className: "text-lg font-semibold text-red-900", children: "Something went wrong" })] }), _jsx("p", { className: "text-red-700 mb-4 text-center max-w-md", children: "We encountered an unexpected error. Please try refreshing the component or contact support if the problem persists." }), process.env.NODE_ENV === 'development' && this.state.error && (_jsxs("details", { className: "mb-4 p-3 bg-red-100 rounded border border-red-300 max-w-2xl", children: [_jsx("summary", { className: "cursor-pointer font-medium text-red-800 mb-2", children: "Error Details (Development Only)" }), _jsxs("div", { className: "space-y-2 text-xs", children: [_jsxs("div", { children: [_jsx("strong", { children: "Error:" }), _jsx("pre", { className: "mt-1 p-2 bg-red-200 rounded text-red-900 overflow-auto", children: this.state.error.toString() })] }), this.state.errorInfo?.componentStack && (_jsxs("div", { children: [_jsx("strong", { children: "Component Stack:" }), _jsx("pre", { className: "mt-1 p-2 bg-red-200 rounded text-red-900 overflow-auto", children: this.state.errorInfo.componentStack })] }))] })] })), _jsxs("button", { onClick: this.handleRetry, className: "inline-flex items-center gap-2 px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 transition-colors focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2", children: [_jsx(RefreshCw, { className: "w-4 h-4" }), "Try Again"] })] }));
        }
        return this.props.children;
    }
}
