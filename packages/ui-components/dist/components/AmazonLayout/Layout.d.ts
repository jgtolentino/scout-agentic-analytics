/**
 * Amazon Dashboard Layout Component
 * Complete layout system migrated from Dash to Next.js
 */
import React from 'react';
import { SidebarProps } from './Sidebar';
export interface AmazonLayoutProps {
    sidebar: SidebarProps;
    children: React.ReactNode;
    className?: string;
}
export declare const AmazonLayout: React.FC<AmazonLayoutProps>;
