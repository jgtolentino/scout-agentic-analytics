"use client";

import React from 'react';
import PageFrame from '@/components/PageFrame';
import { Card } from '@/components/AmazonCard';
import PlotlyAmazon from '@/components/charts/PlotlyAmazon';

export default function Geography() {
  const regions = ['NCR', 'Luzon', 'Visayas', 'Mindanao'];
  const revenue = [920, 860, 540, 480];

  return (
    <PageFrame title="Geographic Intelligence">
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card>
          <div style={{ height: 360 }}>
            <PlotlyAmazon
              data={[{
                type: 'bar',
                x: revenue,
                y: regions,
                orientation: 'h'
              }]}
              layout={{ title: 'Regional Performance (₱K)' }}
            />
          </div>
        </Card>

        <Card>
          <div style={{ height: 360 }}>
            <PlotlyAmazon
              data={[{
                type: 'bar',
                x: ['Metro Manila', 'Cebu', 'Davao', 'Baguio', 'Iloilo'],
                y: [310, 210, 180, 130, 120]
              }]}
              layout={{ title: 'Top Cities' }}
            />
          </div>
        </Card>

        <Card className="lg:col-span-2">
          <div style={{ height: 400 }}>
            <PlotlyAmazon
              data={[{
                type: 'scatter',
                mode: 'markers',
                x: [121.0, 123.9, 125.6, 120.6, 122.5],
                y: [14.6, 10.3, 7.1, 16.4, 10.7],
                text: ['Manila', 'Cebu', 'Davao', 'Baguio', 'Iloilo'],
                marker: { size: [22, 18, 16, 12, 12] }
              }]}
              layout={{ title: 'Store/Outlet Footprint (demo)' }}
            />
          </div>
        </Card>
      </div>
    </PageFrame>
  );
}