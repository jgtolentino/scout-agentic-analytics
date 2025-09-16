"use client";

import React from 'react';
import PageFrame from '@/components/PageFrame';
import { Card } from '@/components/AmazonCard';
import { 
  DynamicPlotlyAmazon,
  DynamicBehaviorKPIs,
  DynamicRequestMethodsChart
} from '@/components/charts/DynamicPlotly';
import ComparePill from '@/components/ui/ComparePill';
import { useFilters, useBehaviorKPIs, useRequestMethods, useAcceptanceByMethod, useTopPaths } from '@/lib/hooks';

export default function Behavior() {
  const { filters } = useFilters();

  // Data hooks
  const { data: behaviorData, isLoading: behaviorLoading, error: behaviorError } = useBehaviorKPIs(filters);
  const { data: requestData, isLoading: requestLoading, error: requestError } = useRequestMethods(filters);
  const { data: acceptanceData, isLoading: acceptanceLoading, error: acceptanceError } = useAcceptanceByMethod(filters);
  const { data: pathsData, isLoading: pathsLoading, error: pathsError } = useTopPaths(filters);

  const hours = ['6a', '9a', '12p', '3p', '6p', '9p'];
  const dow = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const z = dow.map((_, r) => hours.map((_, c) => Math.round(40 + 20 * Math.sin((r + c) / 2))));

  return (
    <PageFrame title="Consumer Behavior">
      {/* Compare Mode */}
      <div className="mb-6">
        <ComparePill entityType="category" />
      </div>

      {/* Behavior KPIs */}
      <div className="mb-6">
        <Card>
          <DynamicBehaviorKPIs
            data={behaviorData || null}
            title="Customer Behavior KPIs"
            height={350}
            loading={behaviorLoading}
            error={behaviorError}
          />
        </Card>
      </div>

      {/* Request Methods Analysis */}
      <div className="mb-6">
        <Card>
          <DynamicRequestMethodsChart
            requestData={requestData || []}
            acceptanceData={acceptanceData || []}
            title="Request Methods & Acceptance Rates"
            height={450}
            loading={requestLoading || acceptanceLoading}
            error={requestError || acceptanceError}
          />
        </Card>
      </div>

      {/* Original Charts Enhanced */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <Card>
          <div style={{ height: 400 }}>
            <DynamicPlotlyAmazon
              data={[{
                type: 'heatmap',
                x: hours,
                y: dow,
                z: z,
                hovertemplate: '<b>%{y} %{x}</b><br>Transactions: %{z}<extra></extra>',
                colorscale: 'Viridis'
              }]}
              layout={{ 
                title: 'Hourly Transaction Heatmap',
                xaxis: { title: 'Time of Day' },
                yaxis: { title: 'Day of Week' }
              }}
              height={400}
              exportable={true}
              title="Hourly Transaction Heatmap"
            />
          </div>
        </Card>

        <Card>
          <div style={{ height: 400 }}>
            <DynamicPlotlyAmazon
              data={[{
                type: 'bar',
                x: ['Direct', 'Search', 'Social', 'Referral', 'Email'],
                y: [32, 28, 18, 14, 8],
                marker: {
                  color: ['#f79500', '#146eb4', '#37475a', '#8c4bff', '#00d4aa']
                },
                hovertemplate: '<b>%{x}</b><br>Share: %{y}%<extra></extra>'
              }]}
              layout={{ 
                title: 'Channel Mix (Share %)',
                xaxis: { title: 'Channel' },
                yaxis: { title: 'Share (%)' }
              }}
              drillConfig={{
                enabled: true,
                type: 'segment'
              }}
              height={400}
              exportable={true}
              title="Channel Mix"
            />
          </div>
        </Card>
      </div>

      {/* User Journey Analysis */}
      <div className="grid grid-cols-1 xl:grid-cols-2 gap-6 mb-6">
        {/* Top User Paths */}
        <Card>
          <div style={{ height: 400 }}>
            <DynamicPlotlyAmazon
              data={[{
                type: 'bar',
                orientation: 'h',
                x: Array.isArray(pathsData) ? pathsData.map(p => p.users) : [150, 120, 95, 80, 65],
                y: Array.isArray(pathsData) ? pathsData.map(p => p.path.length > 30 ? p.path.substring(0, 30) + '...' : p.path) : [
                  'Home → Search → Product → Cart',
                  'Home → Category → Product → Purchase', 
                  'Search → Filter → Compare → Cart',
                  'Category → Brand → Product → Cart',
                  'Home → Recommendations → Purchase'
                ],
                text: Array.isArray(pathsData) ? pathsData.map(p => `${p.conversion_rate.toFixed(1)}%`) : ['15.2%', '12.8%', '9.5%', '8.1%', '6.2%'],
                textposition: 'auto',
                marker: {
                  color: ['#10b981', '#3b82f6', '#f59e0b', '#8b5cf6', '#ef4444'],
                },
                hovertemplate: '<b>%{y}</b><br>Users: %{x}<br>Conversion: %{text}<extra></extra>'
              }]}
              layout={{ 
                title: 'Top User Journey Paths',
                xaxis: { title: 'Number of Users' },
                yaxis: { title: 'User Path' },
                margin: { l: 200 }
              }}
              height={400}
              exportable={true}
              title="Top User Journey Paths"
            />
          </div>
        </Card>

        {/* Enhanced Basket Analysis */}
        <Card>
          <div style={{ height: 400 }}>
            <DynamicPlotlyAmazon
              data={[{
                type: 'scatter',
                mode: 'markers',
                x: [120, 150, 190, 210, 260],
                y: [1.1, 1.2, 1.35, 1.42, 1.55],
                text: ['New', 'Repeat', 'Loyal', 'Promo', 'Whale'],
                marker: { 
                  size: [12, 16, 22, 18, 26],
                  color: ['#ef4444', '#f59e0b', '#10b981', '#3b82f6', '#8b5cf6'],
                  opacity: 0.8
                },
                hovertemplate: '<b>%{text}</b><br>Duration: %{x} min<br>Basket Size: %{y}<extra></extra>'
              }]}
              layout={{ 
                title: 'Customer Segments: Duration vs Basket Size',
                xaxis: { title: 'Visit Duration (min)' },
                yaxis: { title: 'Basket Size (items)' }
              }}
              drillConfig={{
                enabled: true,
                type: 'segment'
              }}
              height={400}
              exportable={true}
              title="Customer Segments Analysis"
            />
          </div>
        </Card>
      </div>

      {/* Engagement Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-4 mb-6">
        <Card>
          <div className="p-6 text-center">
            <div className="text-3xl font-bold text-blue-600 mb-2">2.4m</div>
            <div className="text-sm font-medium text-gray-700 mb-1">Page Views</div>
            <div className="text-xs text-gray-500">+12% vs last month</div>
          </div>
        </Card>

        <Card>
          <div className="p-6 text-center">
            <div className="text-3xl font-bold text-green-600 mb-2">3:45</div>
            <div className="text-sm font-medium text-gray-700 mb-1">Avg Session</div>
            <div className="text-xs text-gray-500">+8% vs last month</div>
          </div>
        </Card>

        <Card>
          <div className="p-6 text-center">
            <div className="text-3xl font-bold text-purple-600 mb-2">68%</div>
            <div className="text-sm font-medium text-gray-700 mb-1">Returning Users</div>
            <div className="text-xs text-gray-500">+5% vs last month</div>
          </div>
        </Card>

        <Card>
          <div className="p-6 text-center">
            <div className="text-3xl font-bold text-orange-600 mb-2">4.2</div>
            <div className="text-sm font-medium text-gray-700 mb-1">Pages/Session</div>
            <div className="text-xs text-gray-500">+15% vs last month</div>
          </div>
        </Card>
      </div>
    </PageFrame>
  );
}