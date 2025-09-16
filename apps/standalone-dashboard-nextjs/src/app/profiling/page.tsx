"use client";

import React from 'react';
import PageFrame from '@/components/PageFrame';
import { Card } from '@/components/AmazonCard';
import PlotlyAmazon from '@/components/charts/PlotlyAmazon';

export default function Profiling() {
  return (
    <PageFrame title="Consumer Profiling">
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <Card>
          <div style={{ height: 300 }}>
            <PlotlyAmazon
              data={[{
                type: 'pie',
                hole: 0.5,
                labels: ['Female', 'Male', 'Other'],
                values: [51.5, 46, 2.5],
                textinfo: 'label+percent'
              }]}
              layout={{ title: 'Gender' }}
            />
          </div>
        </Card>

        <Card>
          <div style={{ height: 300 }}>
            <PlotlyAmazon
              data={[{
                type: 'bar',
                x: ['18–24', '25–34', '35–44', '45–54', '55–64', '65+'],
                y: [770, 1800, 1200, 680, 370, 160]
              }]}
              layout={{ title: 'Age' }}
            />
          </div>
        </Card>

        <Card>
          <div style={{ height: 300 }}>
            <PlotlyAmazon
              data={[{
                type: 'bar',
                orientation: 'h',
                y: ['<25k', '$25–49k', '$50–74k', '$75–99k', '$100–149k', '>$150k'],
                x: [690, 1200, 1100, 760, 790, 460]
              }]}
              layout={{ title: 'Household Income' }}
            />
          </div>
        </Card>

        <Card className="lg:col-span-3">
          <div style={{ height: 350 }}>
            <PlotlyAmazon
              data={[{
                type: 'bar',
                orientation: 'h',
                y: ['HS or less', 'HS/GED', "Bachelor's", 'Graduate', 'Prefer not to say'],
                x: [46, 1900, 2200, 870, 32]
              }]}
              layout={{ title: 'Education' }}
            />
          </div>
        </Card>
      </div>
    </PageFrame>
  );
}