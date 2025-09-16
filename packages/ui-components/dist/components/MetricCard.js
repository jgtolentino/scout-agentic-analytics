import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { TrendingUp, TrendingDown, Minus } from 'lucide-react';
import { clsx } from 'clsx';
export default function MetricCard({ title, value, change, trend = 'neutral', prefix = '', suffix = '', subtitle, icon, className, size = 'md', showProgressBar = false, progressValue, variant = 'default' }) {
    const trendConfig = {
        up: {
            color: 'text-green-600',
            bg: 'bg-green-100',
            icon: TrendingUp
        },
        down: {
            color: 'text-red-600',
            bg: 'bg-red-100',
            icon: TrendingDown
        },
        neutral: {
            color: 'text-gray-600',
            bg: 'bg-gray-100',
            icon: Minus
        }
    };
    const sizeConfig = {
        sm: {
            card: 'p-3',
            title: 'text-xs',
            value: 'text-lg',
            change: 'text-xs',
            icon: 12
        },
        md: {
            card: 'p-4',
            title: 'text-sm',
            value: 'text-2xl',
            change: 'text-sm',
            icon: 14
        },
        lg: {
            card: 'p-6',
            title: 'text-base',
            value: 'text-3xl',
            change: 'text-base',
            icon: 16
        }
    };
    const config = sizeConfig[size];
    const trendTheme = trendConfig[trend];
    const TrendIcon = trendTheme.icon;
    const cardClasses = clsx('bg-white rounded-lg border border-gray-200 shadow-sm hover:shadow-md transition-shadow duration-200', config.card, className);
    const renderCompact = () => (_jsx("div", { className: cardClasses, children: _jsxs("div", { className: "flex items-center justify-between", children: [_jsxs("div", { className: "flex-1", children: [_jsxs("div", { className: "flex items-center gap-2", children: [icon && _jsx("div", { className: "text-gray-400", children: icon }), _jsx("p", { className: clsx('font-medium text-gray-600', config.title), children: title })] }), _jsxs("p", { className: clsx('font-bold text-gray-900 mt-1', config.value), children: [prefix, value, suffix] })] }), change && (_jsxs("div", { className: clsx('flex items-center gap-1 px-2 py-1 rounded-full', trendTheme.bg), children: [_jsx(TrendIcon, { size: config.icon, className: trendTheme.color }), _jsx("span", { className: clsx('font-medium', trendTheme.color, config.change), children: change })] }))] }) }));
    const renderDefault = () => (_jsxs("div", { className: cardClasses, children: [_jsxs("div", { className: "flex items-start justify-between", children: [_jsxs("div", { className: "flex-1", children: [_jsxs("div", { className: "flex items-center gap-2", children: [icon && _jsx("div", { className: "text-gray-400", children: icon }), _jsx("p", { className: clsx('font-medium text-gray-600', config.title), children: title })] }), _jsxs("p", { className: clsx('font-bold text-gray-900 mt-2', config.value), children: [prefix, value, suffix] }), subtitle && (_jsx("p", { className: "text-xs text-gray-500 mt-1", children: subtitle }))] }), change && (_jsxs("div", { className: clsx('flex items-center gap-1 px-2.5 py-0.5 rounded-full', trendTheme.bg), children: [_jsx(TrendIcon, { size: config.icon, className: trendTheme.color }), _jsx("span", { className: clsx('font-medium', trendTheme.color, config.change), children: change })] }))] }), showProgressBar && (_jsx("div", { className: "mt-4 w-full bg-gray-200 rounded-full h-1.5", children: _jsx("div", { className: "bg-blue-500 h-1.5 rounded-full transition-all duration-500", style: { width: `${progressValue || Math.random() * 40 + 60}%` } }) }))] }));
    const renderDetailed = () => (_jsxs("div", { className: cardClasses, children: [_jsxs("div", { className: "flex items-start justify-between mb-3", children: [icon && _jsx("div", { className: "text-gray-400", children: icon }), change && (_jsxs("div", { className: clsx('flex items-center gap-1 px-2.5 py-0.5 rounded-full', trendTheme.bg), children: [_jsx(TrendIcon, { size: config.icon, className: trendTheme.color }), _jsx("span", { className: clsx('font-medium', trendTheme.color, config.change), children: change })] }))] }), _jsxs("div", { className: "space-y-2", children: [_jsx("p", { className: clsx('font-medium text-gray-600', config.title), children: title }), _jsxs("p", { className: clsx('font-bold text-gray-900', config.value), children: [prefix, value, suffix] }), subtitle && (_jsx("p", { className: "text-sm text-gray-500", children: subtitle }))] }), showProgressBar && (_jsxs("div", { className: "mt-4 space-y-1", children: [_jsxs("div", { className: "flex justify-between text-xs text-gray-500", children: [_jsx("span", { children: "Progress" }), _jsxs("span", { children: [progressValue || Math.floor(Math.random() * 40 + 60), "%"] })] }), _jsx("div", { className: "w-full bg-gray-200 rounded-full h-2", children: _jsx("div", { className: "bg-blue-500 h-2 rounded-full transition-all duration-500", style: { width: `${progressValue || Math.random() * 40 + 60}%` } }) })] }))] }));
    switch (variant) {
        case 'compact':
            return renderCompact();
        case 'detailed':
            return renderDetailed();
        default:
            return renderDefault();
    }
}
