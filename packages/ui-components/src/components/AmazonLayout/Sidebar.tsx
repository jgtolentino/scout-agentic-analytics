/**
 * Amazon Dashboard Sidebar Component
 * Migrated from Dash to React/Next.js
 */

import React from 'react';
import { amazonTokens } from '../../tokens/amazon-design-tokens';

export interface SidebarProps {
  logo?: {
    src: string;
    alt: string;
    width?: number;
    height?: number;
  };
  navigation: Array<{
    label: string;
    href: string;
    icon?: string;
  }>;
  footer?: {
    createdBy?: {
      name: string;
      href: string;
    };
    dataSource?: {
      name: string;
      href: string;
    };
  };
  className?: string;
}

export const Sidebar: React.FC<SidebarProps> = ({
  logo = {
    src: '/amazon.svg',
    alt: 'Amazon',
    height: 35,
  },
  navigation,
  footer,
  className = '',
}) => {
  const [pathname, setPathname] = React.useState('/');

  return (
    <div
      className={`sidebar ${className}`}
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        bottom: 0,
        width: amazonTokens.layout.sidebar.width,
        padding: amazonTokens.layout.sidebar.padding,
        backgroundColor: amazonTokens.colors.sidebarBackground,
        fontFamily: amazonTokens.typography.fontFamily,
      }}
    >
      {/* Logo Section */}
      <div
        className="sidebar-logo"
        style={{
          marginTop: '1rem',
          display: 'flex',
          alignItems: 'center',
        }}
      >
        {logo && (
          <img
            src={logo.src}
            alt={logo.alt}
            width={logo.width}
            height={logo.height || 35}
            style={{ height: '35px', width: 'auto' }}
          />
        )}
      </div>

      <hr style={{ margin: '1rem 0' }} />

      {/* Navigation */}
      <nav className="nav-pills">
        {navigation.map((item, index) => {
          const isActive = pathname === item.href;
          return (
            <a
              key={index}
              href={item.href}
              className={`nav-link ${isActive ? 'active' : ''}`}
              style={{
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
              }}
              onClick={(e) => {
                e.preventDefault();
                setPathname(item.href);
                // Trigger custom navigation event
                window.dispatchEvent(new CustomEvent('navigate', { detail: item.href }));
              }}
            >
              {item.icon && (
                <i
                  className={`fas ${item.icon}`}
                  style={{ marginRight: '0.5rem' }}
                />
              )}
              {item.label}
            </a>
          );
        })}
      </nav>

      {/* Footer */}
      {footer && (
        <div
          className="subtitle-sidebar"
          style={{
            position: 'absolute',
            bottom: '10px',
            width: 'calc(100% - 2rem)',
            fontSize: amazonTokens.typography.fontSize.sidebar,
            color: amazonTokens.colors.textPrimary,
          }}
        >
          {footer.createdBy && (
            <div style={{ marginBottom: '0.5rem' }}>
              <span>Created by </span>
              <a
                href={footer.createdBy.href}
                target="_blank"
                rel="noopener noreferrer"
                style={{
                  color: amazonTokens.colors.textPrimary,
                  fontWeight: amazonTokens.typography.fontWeight.bold,
                  textDecoration: 'none',
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.color = amazonTokens.colors.primary;
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.color = amazonTokens.colors.textPrimary;
                }}
              >
                {footer.createdBy.name}
              </a>
            </div>
          )}
          
          {footer.dataSource && (
            <div>
              <span>Data Source </span>
              <a
                href={footer.dataSource.href}
                target="_blank"
                rel="noopener noreferrer"
                style={{
                  color: amazonTokens.colors.textPrimary,
                  fontWeight: amazonTokens.typography.fontWeight.bold,
                  textDecoration: 'none',
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.color = amazonTokens.colors.primary;
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.color = amazonTokens.colors.textPrimary;
                }}
              >
                {footer.dataSource.name}
              </a>
            </div>
          )}
        </div>
      )}

      <style>{`
        @media (max-width: ${amazonTokens.layout.breakpoints.mobile}) {
          .sidebar {
            width: ${amazonTokens.layout.sidebar.mobileWidth} !important;
          }
        }
      `}</style>
    </div>
  );
};