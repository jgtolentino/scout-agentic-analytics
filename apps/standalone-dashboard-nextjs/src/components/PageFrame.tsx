"use client";

import React from 'react';
import Breadcrumbs from './Breadcrumbs';

interface PageFrameProps {
  title: string;
  children: React.ReactNode;
}

export default function PageFrame({ title, children }: PageFrameProps) {
  return (
    <div className="space-y-6">
      <div className="space-y-4">
        <Breadcrumbs />
        <div className="border-b border-gray-200 pb-4">
          <h1 className="text-2xl font-bold text-gray-900">{title}</h1>
        </div>
      </div>
      <div className="space-y-6">
        {children}
      </div>
    </div>
  );
}