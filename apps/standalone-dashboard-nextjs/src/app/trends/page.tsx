"use client";

import React from 'react';
import { useRouter } from 'next/navigation';
import PageFrame from '@/components/PageFrame';
import { Card, Skeleton, ErrorBox } from '@/components/AmazonCard';
import { DynamicPlotlyAmazon } from '@/components/charts/DynamicPlotly';
import { useSafeData } from '@/lib/useSafeData';
import { useDrillHandler, DRILL_CONFIGS } from '@/lib/drillHandler';

export default function Trends() {
  const router = useRouter();
  const { handleDrill } = useDrillHandler();
  const { data: trendData, loading, error } = useSafeData(
    () => fetch('/api/trends').then(r => r.json()),
    {
      transactions: { x: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'], y: [420, 380, 440, 390, 460, 510] },
      seasonal: { x: ['Q1', 'Q2', 'Q3', 'Q4'], y: [1240, 1350, 980, 1580] }
    }
  );

  return (
    <PageFrame title="Transaction Trends">
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card>
          <div style={{ height: 360 }}>
            {loading ? (
              <Skeleton className="h-full" />
            ) : error ? (
              <ErrorBox message={error} />
            ) : (
              <DynamicPlotlyAmazon
                data={[{
                  type: 'scatter',
                  mode: 'lines+markers',
                  x: trendData.transactions.x,
                  y: trendData.transactions.y,
                  name: 'Monthly Transactions'
                }]}
                layout={{ title: 'Transaction Volume (6M)' }}
              />
            )}
          </div>
        </Card>

        <Card>
          <div style={{ height: 360 }}>
            <DynamicPlotlyAmazon
              data={[{
                type: 'bar',
                x: trendData.seasonal.x,
                y: trendData.seasonal.y,
                name: 'Quarterly Revenue'
              }]}
              layout={{ title: 'Seasonal Performance' }}
              drillable={true}
              onPlotlyClick={(data) => handleDrill(data.points[0].x, DRILL_CONFIGS.daypartToBehavior, '/trends')}
            />
          </div>
        </Card>

        <Card className="lg:col-span-2">
          <div style={{ height: 400 }}>
            <DynamicPlotlyAmazon
              data={[
                {
                  type: 'scatter',
                  mode: 'lines',
                  x: ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Week 5', 'Week 6'],
                  y: [85, 92, 78, 95, 88, 102],
                  name: 'Revenue',
                  line: { color: '#f79500' }
                },
                {
                  type: 'scatter',
                  mode: 'lines',
                  x: ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Week 5', 'Week 6'],
                  y: [45, 52, 38, 58, 48, 62],
                  name: 'Units',
                  yaxis: 'y2',
                  line: { color: '#146eb4' }
                }
              ]}
              layout={{
                title: 'Revenue vs Units (Weekly)',
                yaxis: { title: 'Revenue (₱K)' },
                yaxis2: { title: 'Units (K)', overlaying: 'y', side: 'right' }
              }}
            />
          </div>
        </Card>
      </div>
    </PageFrame>
  );
}