import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
export const MetricCard = ({ title, value, change, trend = 'neutral', variant = 'default', icon, prefix = '', }) => {
    const cardStyle = {
        backgroundColor: 'white',
        borderRadius: '8px',
        padding: variant === 'compact' ? '16px' : '24px',
        boxShadow: '0 1px 3px rgba(0, 0, 0, 0.1)',
        border: '1px solid #e5e7eb',
    };
    const titleStyle = {
        fontSize: '14px',
        fontWeight: 500,
        color: '#6b7280',
        marginBottom: '8px',
    };
    const valueStyle = {
        fontSize: variant === 'compact' ? '20px' : '24px',
        fontWeight: 'bold',
        color: '#111827',
        marginBottom: change ? '4px' : 0,
    };
    const changeStyle = {
        fontSize: '12px',
        fontWeight: 500,
        color: trend === 'up' ? '#10b981' : trend === 'down' ? '#ef4444' : '#6b7280',
    };
    return (_jsxs("div", { style: cardStyle, children: [icon && (_jsx("div", { style: { marginBottom: '8px', color: '#6b7280' }, children: icon })), _jsx("div", { style: titleStyle, children: title }), _jsxs("div", { style: valueStyle, children: [prefix, typeof value === 'number' ? value.toLocaleString() : value] }), change && (_jsxs("div", { style: changeStyle, children: [trend === 'up' ? '↗' : trend === 'down' ? '↘' : '→', " ", change] }))] }));
};
