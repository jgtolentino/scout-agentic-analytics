/**
 * LoadingSpinner Component
 * Simple loading spinner for Scout dashboard
 */
import React from 'react';
export interface LoadingSpinnerProps {
    size?: 'small' | 'medium' | 'large';
    color?: string;
    className?: string;
}
export declare const LoadingSpinner: React.FC<LoadingSpinnerProps>;
