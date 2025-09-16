"use client";

import React, { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import clsx from 'clsx';

const navItems = [
  { href: '/', label: 'Executive Overview', icon: '📊', short: 'Exec' },
  { href: '/trends', label: 'Transaction Trends', icon: '📈', short: 'Trends' },
  { href: '/product-mix', label: 'Product Mix', icon: '🛍️', short: 'Products' },
  { href: '/behavior', label: 'Consumer Behavior', icon: '👥', short: 'Behavior' },
  { href: '/profiling', label: 'Consumer Profiling', icon: '🎯', short: 'Profile' },
  { href: '/journey', label: 'Journey Analytics', icon: '🛤️', short: 'Journey' },
  { href: '/competition', label: 'Competitive Analysis', icon: '⚔️', short: 'Compete' },
  { href: '/geography', label: 'Geographic Intelligence', icon: '🌍', short: 'Geo' },
  { href: '/etl', label: 'ETL Management', icon: '⚙️', short: 'ETL' },
];

interface SideNavProps {
  isCollapsed: boolean;
  onToggle: () => void;
}

export default function SideNav({ isCollapsed, onToggle }: SideNavProps) {
  const pathname = usePathname();

  return (
    <nav className={clsx(
      "bg-white rounded-lg border border-gray-200 shadow-sm transition-all duration-300 relative",
      isCollapsed ? "w-16" : "w-60"
    )}>
      {/* Toggle Button */}
      <button
        onClick={onToggle}
        className="absolute -right-3 top-6 bg-white border border-gray-200 rounded-full w-6 h-6 flex items-center justify-center shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-orange-500 z-10"
        aria-label={isCollapsed ? "Expand sidebar" : "Collapse sidebar"}
      >
        <svg
          className={clsx("w-3 h-3 transition-transform text-gray-600", isCollapsed && "rotate-180")}
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
        </svg>
      </button>

      <div className="p-4">
        {/* Header */}
        <div className={clsx("mb-6 overflow-hidden", isCollapsed && "text-center")}>
          {!isCollapsed ? (
            <>
              <h2 className="text-lg font-semibold text-gray-900">Scout v7.1</h2>
              <p className="text-sm text-gray-500">Analytics Dashboard</p>
            </>
          ) : (
            <div className="text-center">
              <div className="text-lg font-bold text-orange-600">S</div>
              <div className="text-xs text-gray-500">v7</div>
            </div>
          )}
        </div>
        
        {/* Navigation Items */}
        <ul className="space-y-2">
          {navItems.map((item) => {
            const isActive = pathname === item.href;
            return (
              <li key={item.href}>
                <Link
                  href={item.href}
                  className={clsx(
                    "flex items-center gap-3 px-3 py-2 rounded-md text-sm font-medium transition-colors relative group",
                    isActive
                      ? "bg-orange-50 text-orange-700 border-l-4 border-orange-500"
                      : "text-gray-700 hover:bg-gray-50 hover:text-gray-900",
                    isCollapsed && "justify-center"
                  )}
                  title={isCollapsed ? item.label : undefined}
                >
                  <span className="text-lg flex-shrink-0">{item.icon}</span>
                  {!isCollapsed && (
                    <span className="truncate">{item.label}</span>
                  )}
                  
                  {/* Tooltip for collapsed state */}
                  {isCollapsed && (
                    <div className="absolute left-full ml-2 px-2 py-1 bg-gray-900 text-white text-xs rounded opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none whitespace-nowrap z-50">
                      {item.label}
                    </div>
                  )}
                </Link>
              </li>
            );
          })}
        </ul>
        
        {/* Footer */}
        {!isCollapsed && (
          <div className="mt-8 pt-4 border-t border-gray-200">
            <div className="text-xs text-gray-500">
              Amazon Challenge Theme
            </div>
          </div>
        )}
      </div>
    </nav>
  );
}