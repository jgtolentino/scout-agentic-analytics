'use client';

import React from 'react';
import { useRouter } from 'next/navigation';
import { useFilterBus } from '@/lib/store';

export default function Breadcrumbs() {
  const router = useRouter();
  const { breadcrumbs, goToCrumb } = useFilterBus();

  if (breadcrumbs.length === 0) return null;

  const handleCrumbClick = (index: number) => {
    const crumb = breadcrumbs[index];
    goToCrumb(index);
    if (crumb.path && crumb.path !== window.location.pathname) {
      router.push(crumb.path);
    }
  };

  return (
    <div className="flex items-center gap-2 text-sm text-gray-600 py-2">
      <span className="text-xs font-medium text-gray-500">Path:</span>
      {breadcrumbs.map((crumb, index) => (
        <React.Fragment key={index}>
          {index > 0 && <span className="text-gray-400">→</span>}
          <button
            onClick={() => handleCrumbClick(index)}
            className="hover:text-orange-600 underline-offset-2 hover:underline transition-colors"
          >
            {crumb.label}
          </button>
        </React.Fragment>
      ))}
    </div>
  );
}