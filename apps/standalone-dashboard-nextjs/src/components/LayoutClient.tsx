"use client";

import { useState } from "react";
import { AmazonLayout } from "@scout/ui-components";
import CollapsibleFilterPanel from "@/components/CollapsibleFilterPanel";
import FloatingAssistant from "@/components/ai/FloatingAssistant";
import { Toaster } from "react-hot-toast";
import { amazonTokens } from "@scout/ui-components";

interface LayoutClientProps {
  children: React.ReactNode;
}

export default function LayoutClient({ children }: LayoutClientProps) {
  const [isFiltersCollapsed, setIsFiltersCollapsed] = useState(false);

  const sidebarConfig = {
    logo: {
      src: "/scout-logo.svg",
      alt: "Scout Analytics",
      height: 35,
    },
    navigation: [
      {
        label: "Transaction Trends",
        href: "/transaction-trends",
        icon: "fa-chart-line"
      },
      {
        label: "Product Mix & SKU",
        href: "/product-mix",
        icon: "fa-box"
      },
      {
        label: "Customer Demographics", 
        href: "/demographics",
        icon: "fa-users"
      },
      {
        label: "Performance Metrics",
        href: "/performance",
        icon: "fa-tachometer-alt"
      },
      {
        label: "Analytics Dashboard",
        href: "/dashboard",
        icon: "fa-chart-bar"
      }
    ],
    footer: {
      createdBy: {
        name: "TBWA Scout Team",
        href: "https://github.com/tbwa/scout-v7"
      },
      dataSource: {
        name: "Scout Analytics Platform",
        href: "https://scout.tbwa.com"
      }
    }
  };

  return (
    <>
      {/* Skip Navigation Link */}
      <a 
        href="#main-content" 
        className="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 z-50"
        style={{
          backgroundColor: amazonTokens.colors.primary,
          color: '#fff',
          padding: '8px 16px',
          borderRadius: amazonTokens.borderRadius.input,
        }}
      >
        Skip to main content
      </a>
      
      {/* Amazon Layout with Scout Content */}
      <AmazonLayout sidebar={sidebarConfig}>
        <div className="scout-content-wrapper">
          {/* Main Dashboard Content */}
          <main id="main-content" role="main">
            {children}
          </main>
          
          {/* Filters Panel (floating overlay for Amazon layout) */}
          <div 
            className={`filters-overlay ${isFiltersCollapsed ? 'collapsed' : 'expanded'}`}
            style={{
              position: 'fixed',
              top: '20px',
              right: '20px',
              zIndex: 1000,
              maxWidth: '300px',
              backgroundColor: amazonTokens.colors.cardBackground,
              borderRadius: amazonTokens.borderRadius.card,
              boxShadow: amazonTokens.shadows.card,
              border: `1px solid ${amazonTokens.colors.border}`,
              transition: 'transform 0.3s ease',
              transform: isFiltersCollapsed ? 'translateX(100%)' : 'translateX(0)',
            }}
          >
            <CollapsibleFilterPanel 
              isCollapsed={isFiltersCollapsed}
              onToggle={() => setIsFiltersCollapsed(!isFiltersCollapsed)}
            />
          </div>
        </div>
      </AmazonLayout>
      
      <FloatingAssistant />
      
      <Toaster
        position="top-right"
        toastOptions={{
          duration: 4000,
          style: {
            background: amazonTokens.colors.textSecondary,
            color: '#fff',
            fontFamily: amazonTokens.typography.fontFamily,
          },
          success: {
            style: {
              background: amazonTokens.colors.primary,
            },
          },
          error: {
            style: {
              background: amazonTokens.colors.textDanger,
            },
          },
        }}
      />
    </>
  );
}