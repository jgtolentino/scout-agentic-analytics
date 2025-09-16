/**
 * Amazon Dashboard Sidebar Component
 * Migrated from Dash to React/Next.js
 */
import React from 'react';
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
export declare const Sidebar: React.FC<SidebarProps>;
