/**
 * Amazon Dashboard Layout Component
 * Complete layout system migrated from Dash to Next.js
 */

import React from 'react';
import { Sidebar, SidebarProps } from './Sidebar';
import { amazonTokens } from '../../tokens/amazon-design-tokens';

export interface AmazonLayoutProps {
  sidebar: SidebarProps;
  children: React.ReactNode;
  className?: string;
}

export const AmazonLayout: React.FC<AmazonLayoutProps> = ({
  sidebar,
  children,
  className = '',
}) => {
  return (
    <div className={`amazon-layout ${className}`}>
      {/* Sidebar */}
      <Sidebar {...sidebar} />

      {/* Main Content */}
      <div
        className="content"
        style={{
          marginLeft: amazonTokens.spacing.contentMarginLeft,
          marginRight: amazonTokens.spacing.contentMarginRight,
          marginTop: amazonTokens.layout.content.marginTop,
          padding: amazonTokens.layout.content.padding,
          backgroundColor: amazonTokens.colors.background,
          display: 'flex',
          flexDirection: 'column',
          minHeight: '100vh',
          fontFamily: amazonTokens.typography.fontFamily,
        }}
      >
        <div className="page-content">
          {children}
        </div>
      </div>

      {/* Global Styles */}
      <style>{`
        body {
          font-family: ${amazonTokens.typography.fontFamily};
          background-color: ${amazonTokens.colors.background};
          margin: 0;
          padding: 0;
        }

        .title {
          font-size: ${amazonTokens.typography.fontSize.title};
          color: ${amazonTokens.colors.textPrimary};
          margin-bottom: 1rem;
        }

        .subtitle-medium {
          font-size: ${amazonTokens.typography.fontSize.subtitleMedium};
          color: ${amazonTokens.colors.textPrimary};
        }

        .subtitle-small {
          font-size: ${amazonTokens.typography.fontSize.subtitleSmall};
          color: ${amazonTokens.colors.textPrimary};
        }

        .subtitle-small-color {
          font-size: ${amazonTokens.typography.fontSize.subtitleColor};
          color: ${amazonTokens.colors.primaryDark};
        }

        @media (max-width: ${amazonTokens.layout.breakpoints.mobile}) {
          .content {
            margin-left: calc(${amazonTokens.layout.sidebar.mobileWidth} + 1rem) !important;
          }
        }

        /* FontAwesome Icons */
        .fa-list::before { content: "\\f03a"; }
        .fa-coins::before { content: "\\f51e"; }
        .fa-tags::before { content: "\\f02c"; }
        .fa-users::before { content: "\\f0c0"; }
        .fa-chart-bar::before { content: "\\f080"; }
        .fa-book::before { content: "\\f02d"; }
      `}</style>
    </div>
  );
};