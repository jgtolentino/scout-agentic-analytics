import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
/**
 * ErrorBoundary Component
 * Error boundary for Scout dashboard components
 */
import { Component } from 'react';
export class ErrorBoundary extends Component {
    constructor(props) {
        super(props);
        this.state = { hasError: false };
    }
    static getDerivedStateFromError(error) {
        return { hasError: true, error };
    }
    componentDidCatch(error, errorInfo) {
        console.error('ErrorBoundary caught an error:', error, errorInfo);
        if (this.props.onError) {
            this.props.onError(error, errorInfo);
        }
    }
    render() {
        if (this.state.hasError) {
            if (this.props.fallback) {
                return this.props.fallback;
            }
            return (_jsxs("div", { style: {
                    padding: '24px',
                    backgroundColor: '#fef2f2',
                    border: '1px solid #fecaca',
                    borderRadius: '8px',
                    color: '#dc2626',
                }, children: [_jsx("h3", { style: { margin: '0 0 16px 0', fontSize: '18px', fontWeight: 600 }, children: "Something went wrong" }), _jsx("p", { style: { margin: '0 0 16px 0', fontSize: '14px' }, children: "An error occurred while rendering this component." }), process.env.NODE_ENV === 'development' && this.state.error && (_jsxs("details", { style: { fontSize: '12px', fontFamily: 'monospace' }, children: [_jsx("summary", { children: "Error details" }), _jsx("pre", { style: { marginTop: '8px', whiteSpace: 'pre-wrap' }, children: this.state.error.toString() })] })), _jsx("button", { onClick: () => this.setState({ hasError: false, error: undefined }), style: {
                            padding: '8px 16px',
                            backgroundColor: '#dc2626',
                            color: 'white',
                            border: 'none',
                            borderRadius: '4px',
                            cursor: 'pointer',
                            fontSize: '14px',
                        }, children: "Try again" })] }));
        }
        return this.props.children;
    }
}
