'use client';

import React from 'react';
import { Card } from './AmazonCard';

interface InsightItem {
  title: string;
  description: string;
  confidence: number;
  impact: 'high' | 'medium' | 'low';
  actionable: boolean;
}

interface MindsDBInsightsProps {
  insights: InsightItem[];
  loading?: boolean;
}

export default function MindsDBInsights({ insights, loading = false }: MindsDBInsightsProps) {
  const defaultInsights: InsightItem[] = [
    {
      title: 'Revenue Growth Opportunity',
      description: 'Beverage category shows 15% growth potential in NCR region based on seasonal patterns and competitor analysis.',
      confidence: 87,
      impact: 'high',
      actionable: true
    },
    {
      title: 'Inventory Optimization',
      description: 'Peak demand for snacks occurs Tuesday-Thursday 2-4pm. Consider adjusting stock levels.',
      confidence: 92,
      impact: 'medium',
      actionable: true
    },
    {
      title: 'Competitive Risk',
      description: 'Brand X gaining market share in personal care segment. Monitor pricing strategies.',
      confidence: 76,
      impact: 'medium',
      actionable: false
    }
  ];

  const displayInsights = insights.length > 0 ? insights : defaultInsights;

  const getImpactColor = (impact: string) => {
    switch (impact) {
      case 'high': return 'text-red-600 bg-red-50';
      case 'medium': return 'text-yellow-600 bg-yellow-50';
      case 'low': return 'text-green-600 bg-green-50';
      default: return 'text-gray-600 bg-gray-50';
    }
  };

  const getConfidenceColor = (confidence: number) => {
    if (confidence >= 80) return 'bg-green-500';
    if (confidence >= 60) return 'bg-yellow-500';
    return 'bg-red-500';
  };

  if (loading) {
    return (
      <Card>
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <h3 className="text-lg font-semibold text-gray-900">AI Insights</h3>
            <div className="flex items-center gap-2 text-blue-600">
              <div className="w-4 h-4 border-2 border-blue-200 border-t-blue-600 rounded-full animate-spin"></div>
              <span className="text-xs">Analyzing...</span>
            </div>
          </div>
          
          {[1, 2, 3].map(i => (
            <div key={i} className="animate-pulse">
              <div className="h-4 bg-gray-200 rounded w-3/4 mb-2"></div>
              <div className="h-3 bg-gray-200 rounded w-full mb-1"></div>
              <div className="h-3 bg-gray-200 rounded w-2/3"></div>
            </div>
          ))}
        </div>
      </Card>
    );
  }

  return (
    <Card>
      <div className="space-y-4">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div>
            <h3 className="text-lg font-semibold text-gray-900">AI Insights</h3>
            <p className="text-sm text-gray-500">Powered by MindsDB ML models</p>
          </div>
          <div className="flex items-center gap-1 px-2 py-1 bg-blue-50 text-blue-700 rounded-full text-xs font-medium">
            <span>🧠</span>
            <span>AI</span>
          </div>
        </div>

        {/* Insights List */}
        <div className="space-y-4">
          {displayInsights.map((insight, index) => (
            <div key={index} className="border-l-4 border-orange-200 pl-4 space-y-2">
              <div className="flex items-start justify-between">
                <h4 className="font-medium text-gray-900">{insight.title}</h4>
                <div className="flex items-center gap-2">
                  <span className={`px-2 py-1 rounded-full text-xs font-medium ${getImpactColor(insight.impact)}`}>
                    {insight.impact}
                  </span>
                  {insight.actionable && (
                    <span className="px-2 py-1 bg-green-100 text-green-800 rounded-full text-xs font-medium">
                      Actionable
                    </span>
                  )}
                </div>
              </div>
              
              <p className="text-sm text-gray-600">{insight.description}</p>
              
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className="text-xs text-gray-500">Confidence:</span>
                  <div className="w-20 bg-gray-200 rounded-full h-2">
                    <div 
                      className={`h-2 rounded-full transition-all duration-300 ${getConfidenceColor(insight.confidence)}`}
                      style={{ width: `${insight.confidence}%` }}
                    />
                  </div>
                  <span className="text-xs font-medium">{insight.confidence}%</span>
                </div>
              </div>
            </div>
          ))}
        </div>

        {/* Footer */}
        <div className="text-xs text-gray-500 border-t border-gray-100 pt-3 flex justify-between">
          <span>Last updated: {new Date().toLocaleTimeString()}</span>
          <span>Refresh: Auto (5min)</span>
        </div>
      </div>
    </Card>
  );
}