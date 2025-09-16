import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
/**
 * Amazon Dashboard Sidebar Component
 * Migrated from Dash to React/Next.js
 */
import React from 'react';
import { amazonTokens } from '../../tokens/amazon-design-tokens';
export const Sidebar = ({ logo = {
    src: '/amazon.svg',
    alt: 'Amazon',
    height: 35,
}, navigation, footer, className = '', }) => {
    const [pathname, setPathname] = React.useState('/');
    return (_jsxs("div", { className: `sidebar ${className}`, style: {
            position: 'fixed',
            top: 0,
            left: 0,
            bottom: 0,
            width: amazonTokens.layout.sidebar.width,
            padding: amazonTokens.layout.sidebar.padding,
            backgroundColor: amazonTokens.colors.sidebarBackground,
            fontFamily: amazonTokens.typography.fontFamily,
        }, children: [_jsx("div", { className: "sidebar-logo", style: {
                    marginTop: '1rem',
                    display: 'flex',
                    alignItems: 'center',
                }, children: logo && (_jsx("img", { src: logo.src, alt: logo.alt, width: logo.width, height: logo.height || 35, style: { height: '35px', width: 'auto' } })) }), _jsx("hr", { style: { margin: '1rem 0' } }), _jsx("nav", { className: "nav-pills", children: navigation.map((item, index) => {
                    const isActive = pathname === item.href;
                    return (_jsxs("a", { href: item.href, className: `nav-link ${isActive ? 'active' : ''}`, style: {
                            display: 'block',
                            padding: '0.75rem 1rem',
                            color: amazonTokens.colors.textPrimary,
                            backgroundColor: isActive ? amazonTokens.colors.accent : 'transparent',
                            borderRadius: '0.375rem',
                            textDecoration: 'none',
                            marginBottom: '0.25rem',
                            fontSize: amazonTokens.typography.fontSize.body,
                            transition: 'background-color 0.15s ease',
                            cursor: 'pointer',
                        }, onClick: (e) => {
                            e.preventDefault();
                            setPathname(item.href);
                            // Trigger custom navigation event
                            window.dispatchEvent(new CustomEvent('navigate', { detail: item.href }));
                        }, children: [item.icon && (_jsx("i", { className: `fas ${item.icon}`, style: { marginRight: '0.5rem' } })), item.label] }, index));
                }) }), footer && (_jsxs("div", { className: "subtitle-sidebar", style: {
                    position: 'absolute',
                    bottom: '10px',
                    width: 'calc(100% - 2rem)',
                    fontSize: amazonTokens.typography.fontSize.sidebar,
                    color: amazonTokens.colors.textPrimary,
                }, children: [footer.createdBy && (_jsxs("div", { style: { marginBottom: '0.5rem' }, children: [_jsx("span", { children: "Created by " }), _jsx("a", { href: footer.createdBy.href, target: "_blank", rel: "noopener noreferrer", style: {
                                    color: amazonTokens.colors.textPrimary,
                                    fontWeight: amazonTokens.typography.fontWeight.bold,
                                    textDecoration: 'none',
                                }, onMouseEnter: (e) => {
                                    e.currentTarget.style.color = amazonTokens.colors.primary;
                                }, onMouseLeave: (e) => {
                                    e.currentTarget.style.color = amazonTokens.colors.textPrimary;
                                }, children: footer.createdBy.name })] })), footer.dataSource && (_jsxs("div", { children: [_jsx("span", { children: "Data Source " }), _jsx("a", { href: footer.dataSource.href, target: "_blank", rel: "noopener noreferrer", style: {
                                    color: amazonTokens.colors.textPrimary,
                                    fontWeight: amazonTokens.typography.fontWeight.bold,
                                    textDecoration: 'none',
                                }, onMouseEnter: (e) => {
                                    e.currentTarget.style.color = amazonTokens.colors.primary;
                                }, onMouseLeave: (e) => {
                                    e.currentTarget.style.color = amazonTokens.colors.textPrimary;
                                }, children: footer.dataSource.name })] }))] })), _jsx("style", { children: `
        @media (max-width: ${amazonTokens.layout.breakpoints.mobile}) {
          .sidebar {
            width: ${amazonTokens.layout.sidebar.mobileWidth} !important;
          }
        }
      ` })] }));
};
