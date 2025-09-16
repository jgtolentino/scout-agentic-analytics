"use client";

import React from 'react';
import { useRouter } from 'next/navigation';
import PageFrame from '@/components/PageFrame';
import { Card, KPI, Skeleton, ErrorBox } from '@/components/AmazonCard';
import { DynamicPlotlyAmazon } from '@/components/charts/DynamicPlotly';
import { useSafeData } from '@/lib/useSafeData';
import { useDrillHandler, DRILL_CONFIGS } from '@/lib/drillHandler';

export default function Executive() {
  const router = useRouter();
  const { handleDrill } = useDrillHandler();
  
  const { data: trend, loading: trendLoading, error: trendError } = useSafeData(
    () => fetch('/api/trend').then(r => r.json()),
    { x: ['Jan', 'Feb', 'Mar', 'Apr'], y: [3.5, 3.2, 3.6, 3.3] }
  );

  const bars = ['Personal Care', 'Beverages', 'Household', 'Snacks', 'Tobacco'];
  const values = [59, 52, 50, 48, 47];

  return (
    <PageFrame title="Executive Overview">
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <KPI label="Purchases" value={(1850717).toLocaleString()} hint="Demo fallback" />
        <KPI label="Total Spend" value="₱ 44,053,400" />
        <KPI label="Top Category" value="Beverages" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <Card className="lg:col-span-2">
          <div style={{ height: 360 }}>
            {trendLoading ? (
              <Skeleton className="h-full" />
            ) : trendError ? (
              <ErrorBox message={trendError} />
            ) : (
              <DynamicPlotlyAmazon
                data={[{ type: 'bar', x: trend.x, y: trend.y }]}
                layout={{ title: 'Total Monthly Spend' }}
                exportable={true}
                title="Total Monthly Spend"
              />
            )}
          </div>
        </Card>

        <Card>
          <div style={{ height: 360 }}>
            <DynamicPlotlyAmazon
              data={[{
                type: 'treemap',
                labels: ['Beverages', 'Snacks', 'Household', 'Personal Care', 'Tobacco'],
                parents: ['', '', '', '', ''],
                values: [87619, 38256, 27267, 26913, 22734]
              }]}
              layout={{ title: 'Top Purchase Categories' }}
              drillable={true}
              onPlotlyClick={(data) => handleDrill(data.points[0].label, DRILL_CONFIGS.categoryToProductMix, '/')}
              exportable={true}
              title="Top Purchase Categories"
            />
          </div>
        </Card>

        <Card className="lg:col-span-3">
          <div style={{ height: 400 }}>
            <DynamicPlotlyAmazon
              data={[{
                type: 'bar',
                orientation: 'h',
                x: values,
                y: bars,
                hovertemplate: '%{y}: %{x}%<extra></extra>'
              }]}
              layout={{ title: 'Category Performance' }}
              drillable={true}
              onPlotlyClick={(data) => handleDrill(data.points[0].y, DRILL_CONFIGS.categoryToProductMix, '/')}
              exportable={true}
              title="Category Performance"
            />
          </div>
          <div className="flex gap-2 mt-4">
            <button 
              className="px-4 py-2 bg-orange-500 text-white rounded-md hover:bg-orange-600 transition-colors"
              onClick={() => router.push('/competition')}
            >
              See Competitive Analysis
            </button>
            <button 
              className="px-4 py-2 bg-orange-500 text-white rounded-md hover:bg-orange-600 transition-colors"
              onClick={() => router.push('/product-mix?category=Beverages')}
            >
              Drill: Beverages in Product Mix
            </button>
          </div>
        </Card>
      </div>
    </PageFrame>
  );
}
