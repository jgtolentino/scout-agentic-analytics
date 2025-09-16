"use client";

import { useState } from "react";
import SideNav from "@/components/SideNav";
import CollapsibleFilterPanel from "@/components/CollapsibleFilterPanel";
import FloatingAssistant from "@/components/ai/FloatingAssistant";
import { Toaster } from "react-hot-toast";

interface LayoutClientProps {
  children: React.ReactNode;
}

export default function LayoutClient({ children }: LayoutClientProps) {
  const [isSidebarCollapsed, setIsSidebarCollapsed] = useState(false);
  const [isFiltersCollapsed, setIsFiltersCollapsed] = useState(false);

  return (
    <>
      {/* Skip Navigation Link */}
      <a 
        href="#main-content" 
        className="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 bg-orange-500 text-white px-4 py-2 rounded z-50"
      >
        Skip to main content
      </a>
      
      <div className="app-shell-collapsible">
        {/* Left Sidebar - Navigation */}
        <aside className="sidebar-nav" role="navigation" aria-label="Main navigation">
          <SideNav 
            isCollapsed={isSidebarCollapsed}
            onToggle={() => setIsSidebarCollapsed(!isSidebarCollapsed)}
          />
        </aside>
        
        {/* Main Content Area */}
        <main id="main-content" className="main-content" role="main">
          {children}
        </main>
        
        {/* Right Sidebar - Filters */}
        <aside className="sidebar-filters" role="region" aria-label="Filter controls">
          <CollapsibleFilterPanel 
            isCollapsed={isFiltersCollapsed}
            onToggle={() => setIsFiltersCollapsed(!isFiltersCollapsed)}
          />
        </aside>
      </div>
      
      <FloatingAssistant />
      
      <Toaster
        position="top-right"
        toastOptions={{
          duration: 4000,
          style: {
            background: '#363636',
            color: '#fff',
          },
          success: {
            style: {
              background: '#10b981',
            },
          },
          error: {
            style: {
              background: '#ef4444',
            },
          },
        }}
      />
    </>
  );
}