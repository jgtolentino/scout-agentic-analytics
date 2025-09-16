import { jsx as _jsx, Fragment as _Fragment, jsxs as _jsxs } from "react/jsx-runtime";
export const LoadingSpinner = ({ size = 'medium', color = '#f79500', className = '', }) => {
    const sizeMap = {
        small: '16px',
        medium: '24px',
        large: '32px',
    };
    const spinnerStyle = {
        width: sizeMap[size],
        height: sizeMap[size],
        border: `2px solid #e5e7eb`,
        borderTop: `2px solid ${color}`,
        borderRadius: '50%',
        animation: 'spin 1s linear infinite',
    };
    return (_jsxs(_Fragment, { children: [_jsx("div", { className: `loading-spinner ${className}`, style: spinnerStyle }), _jsx("style", { children: `
        @keyframes spin {
          0% { transform: rotate(0deg); }
          100% { transform: rotate(360deg); }
        }
      ` })] }));
};
