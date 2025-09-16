"use client";

import React from 'react';
import { useRouter } from 'next/navigation';
import PageFrame from '@/components/PageFrame';
import { Card } from '@/components/AmazonCard';
import { 
  DynamicPlotlyAmazon,
  DynamicParetoCombo,
  DynamicChordSubstitutions
} from '@/components/charts/DynamicPlotly';
import ComparePill from '@/components/ui/ComparePill';
import { useDrillHandler, useFilters, useSKUCounts, useParetoCategories, useBasketPairs } from '@/lib/hooks';

export default function ProductMix() {
  const router = useRouter();
  const { handleDrillDown } = useDrillHandler();
  const { filters } = useFilters();

  // Data hooks
  const { data: skuData, isLoading: skuLoading, error: skuError } = useSKUCounts(filters);
  const { data: paretoData, isLoading: paretoLoading, error: paretoError } = useParetoCategories(filters);
  const { data: basketData, isLoading: basketLoading, error: basketError } = useBasketPairs(filters, 15);

  return (
    <PageFrame title="Product Mix Analysis">
      {/* Compare Mode */}
      <div className="mb-6">
        <ComparePill entityType="category" />
      </div>

      {/* SKU Counters */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
        <Card>
          <div className="p-6 text-center">
            <div className="text-3xl font-bold text-blue-600 mb-2">
              {skuLoading ? '...' : skuData?.total?.toLocaleString() || '0'}
            </div>
            <div className="text-sm font-medium text-gray-700 mb-1">Total SKUs</div>
            <div className="text-xs text-gray-500">All product variants</div>
          </div>
        </Card>

        <Card>
          <div className="p-6 text-center">
            <div className="text-3xl font-bold text-green-600 mb-2">
              {skuLoading ? '...' : skuData?.active?.toLocaleString() || '0'}
            </div>
            <div className="text-sm font-medium text-gray-700 mb-1">Active SKUs</div>
            <div className="text-xs text-gray-500">
              {skuData && !skuLoading ? `${((skuData.active / skuData.total) * 100).toFixed(1)}% of total` : 'Currently selling'}
            </div>
          </div>
        </Card>

        <Card>
          <div className="p-6 text-center">
            <div className="text-3xl font-bold text-purple-600 mb-2">
              {skuLoading ? '...' : skuData?.new?.toLocaleString() || '0'}
            </div>
            <div className="text-sm font-medium text-gray-700 mb-1">New SKUs</div>
            <div className="text-xs text-gray-500">
              {skuData && !skuLoading ? `${((skuData.new / skuData.total) * 100).toFixed(1)}% of total` : 'Last 30 days'}
            </div>
          </div>
        </Card>
      </div>

      {/* Charts Grid */}
      <div className="grid grid-cols-1 xl:grid-cols-2 gap-6 mb-6">
        {/* Category Distribution */}
        <Card>
          <div style={{ height: 400 }}>
            <DynamicPlotlyAmazon
              data={[{
                type: 'pie',
                labels: ['Beverages', 'Snacks', 'Household', 'Personal Care', 'Tobacco'],
                values: [35, 25, 18, 12, 10],
                hole: 0.4
              }]}
              layout={{ title: 'Category Distribution' }}
              drillConfig={{
                enabled: true,
                type: 'category'
              }}
              height={400}
              exportable={true}
              title="Category Distribution"
            />
          </div>
        </Card>

        {/* Price Segment Performance */}
        <Card>
          <div style={{ height: 400 }}>
            <DynamicPlotlyAmazon
              data={[{
                type: 'bar',
                x: ['Premium', 'Mid-range', 'Budget'],
                y: [42, 38, 20],
                name: 'Price Segment',
                marker: { color: ['#f79500', '#146eb4', '#37475a'] }
              }]}
              layout={{ 
                title: 'Price Segment Performance',
                xaxis: { title: 'Price Segment' },
                yaxis: { title: 'Performance Score' }
              }}
              drillConfig={{
                enabled: true,
                type: 'segment'
              }}
              height={400}
              exportable={true}
              title="Price Segment Performance"
            />
          </div>
        </Card>
      </div>

      {/* Pareto Analysis */}
      <div className="mb-6">
        <Card>
          <DynamicParetoCombo 
            data={paretoData || []}
            title="Category Pareto Analysis (80/20 Rule)"
            height={450}
            loading={paretoLoading}
            error={paretoError}
          />
        </Card>
      </div>

      {/* Brand Performance Matrix */}
      <div className="grid grid-cols-1 xl:grid-cols-2 gap-6 mb-6">
        <Card className="xl:col-span-2">
          <div style={{ height: 450 }}>
            <DynamicPlotlyAmazon
              data={[{
                type: 'scatter',
                mode: 'markers',
                x: [45, 35, 25, 20, 15, 12, 8, 6, 4, 2],
                y: [22, 18, 15, 12, 8, 6, 4, 3, 2, 1],
                text: ['Coca-Cola', 'Pepsi', 'Sprite', 'Royal', 'Sarsi', 'Mountain Dew', 'Fanta', '7-Up', 'Mirinda', 'Others'],
                marker: { 
                  size: [25, 22, 18, 15, 12, 10, 8, 6, 4, 2],
                  sizemode: 'diameter',
                  color: ['#dc2626', '#2563eb', '#16a34a', '#7c3aed', '#ea580c', '#0891b2', '#c2410c', '#4338ca', '#be123c', '#6b7280']
                },
                hovertemplate: '<b>%{text}</b><br>Market Share: %{x}%<br>Growth Rate: %{y}%<extra></extra>'
              }]}
              layout={{ 
                title: 'Brand Performance Matrix (Share vs Growth)',
                xaxis: { title: 'Market Share (%)' },
                yaxis: { title: 'Growth Rate (%)' }
              }}
              drillConfig={{
                enabled: true,
                type: 'brand'
              }}
              height={450}
              exportable={true}
              title="Brand Performance Matrix"
            />
          </div>
        </Card>
      </div>

      {/* Market Basket Analysis */}
      <div className="mb-6">
        <Card>
          <DynamicChordSubstitutions 
            data={basketData || []}
            title="Category Association Analysis"
            height={500}
            loading={basketLoading}
            error={basketError}
            minSupport={0.005}
            minLift={1.2}
          />
        </Card>
      </div>
    </PageFrame>
  );
}