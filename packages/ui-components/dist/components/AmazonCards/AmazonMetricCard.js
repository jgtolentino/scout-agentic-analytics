import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { amazonTokens } from '../../tokens/amazon-design-tokens';
export const AmazonMetricCard = ({ title, value, icon, id, className = '', variant = 'default', }) => {
    const cardStyle = {
        border: `1px solid ${amazonTokens.colors.border}`,
        borderRadius: amazonTokens.borderRadius.card,
        textAlign: 'left',
        boxShadow: amazonTokens.shadows.card,
        backgroundColor: amazonTokens.colors.cardBackground,
        marginBottom: amazonTokens.spacing.medium,
    };
    const cardBodyStyle = {
        padding: variant === 'compact' ? '15px' : amazonTokens.components.card.padding,
        color: amazonTokens.colors.textPrimary,
    };
    const iconStyle = {
        fontSize: variant === 'compact' ? '20px' : amazonTokens.components.icon.size,
        marginRight: variant === 'compact' ? '15px' : amazonTokens.components.icon.marginRight,
        marginBottom: variant === 'compact' ? '10px' : amazonTokens.components.icon.marginBottom,
        color: amazonTokens.colors.primary,
    };
    const titleStyle = {
        whiteSpace: 'nowrap',
        fontSize: variant === 'compact' ? '16px' : amazonTokens.typography.fontSize.subtitleSmall,
        fontWeight: amazonTokens.typography.fontWeight.normal,
        margin: 0,
        marginBottom: '0.5rem',
    };
    const valueStyle = {
        fontSize: variant === 'compact' ? '18px' : '24px',
        fontWeight: amazonTokens.typography.fontWeight.bold,
        margin: 0,
        color: amazonTokens.colors.textPrimary,
    };
    return (_jsx("div", { className: `amazon-metric-card ${className}`, style: cardStyle, id: id, children: _jsxs("div", { style: cardBodyStyle, children: [_jsxs("div", { style: {
                        display: 'flex',
                        alignItems: 'center',
                    }, children: [_jsx("i", { className: `fas ${icon}`, style: iconStyle }), _jsx("h3", { style: titleStyle, children: title })] }), _jsx("h4", { style: valueStyle, children: typeof value === 'number' ? value.toLocaleString() : value })] }) }));
};
