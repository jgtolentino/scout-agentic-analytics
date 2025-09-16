import React from 'react';
import { clsx } from 'clsx';

export interface LoadingSpinnerProps {
  size?: 'sm' | 'md' | 'lg' | 'xl';
  color?: 'primary' | 'secondary' | 'white' | 'gray';
  className?: string;
  label?: string;
}

export default function LoadingSpinner({ 
  size = 'md', 
  color = 'primary', 
  className,
  label 
}: LoadingSpinnerProps) {
  const sizeConfig = {
    sm: 'w-4 h-4',
    md: 'w-6 h-6',
    lg: 'w-8 h-8',
    xl: 'w-12 h-12'
  };

  const colorConfig = {
    primary: 'text-blue-600',
    secondary: 'text-gray-600',
    white: 'text-white',
    gray: 'text-gray-400'
  };

  const spinnerClasses = clsx(
    'animate-spin',
    sizeConfig[size],
    colorConfig[color],
    className
  );

  return (
    <div className="flex items-center justify-center">
      <div className="flex flex-col items-center gap-2">
        <svg 
          className={spinnerClasses} 
          fill="none" 
          viewBox="0 0 24 24"
          aria-hidden="true"
        >
          <circle 
            cx="12" 
            cy="12" 
            r="10" 
            stroke="currentColor" 
            strokeWidth="4"
            className="opacity-25"
          />
          <path 
            fill="currentColor"
            className="opacity-75" 
            d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
          />
        </svg>
        
        {label && (
          <p className={clsx(
            'text-sm font-medium',
            color === 'white' ? 'text-white' : 'text-gray-600'
          )}>
            {label}
          </p>
        )}
      </div>
    </div>
  );
}