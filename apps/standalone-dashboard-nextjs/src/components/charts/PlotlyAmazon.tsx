"use client";

import dynamic from "next/dynamic";
import React, { useCallback } from "react";
import ExportButton from "@/components/ExportButton";
import { useDrillHandler } from "@/lib/hooks";

// Dynamically import Plotly to avoid SSR issues
const Plot = dynamic(() => import("react-plotly.js"), { 
  ssr: false,
  loading: () => (
    <div className="w-full h-full flex items-center justify-center bg-gray-50 rounded-lg">
      <div className="text-sm text-gray-500">Loading chart...</div>
    </div>
  )
});

export interface DrillConfig {
  enabled: boolean;
  type: 'category' | 'brand' | 'sku' | 'region' | 'province' | 'city' | 'store' | 'segment' | 'cohort';
  valueField?: string; // Field to extract drill value from
  labelField?: string; // Field to extract drill label from
  customHandler?: (point: any, drillType: string) => void;
}

export type PlotlyAmazonProps = {
  data: any[];
  layout?: any;
  config?: any;
  className?: string;
  onPlotlyClick?: (data: any) => void;
  drillable?: boolean;
  exportable?: boolean;
  title?: string;
  drillConfig?: DrillConfig;
  height?: number;
};

export default function PlotlyAmazon({ 
  data, 
  layout = {}, 
  config = {}, 
  className = "",
  onPlotlyClick,
  drillable = false,
  exportable = false,
  title,
  drillConfig,
  height = 400
}: PlotlyAmazonProps) {
  const { handleDrillDown } = useDrillHandler();

  // Enhanced click handler with universal drill-down support
  const handleUniversalClick = useCallback((event: any) => {
    // First, call custom click handler if provided
    if (onPlotlyClick) {
      onPlotlyClick(event);
    }

    // Then handle drill-down if enabled
    if (drillConfig?.enabled && event.points && event.points.length > 0) {
      const point = event.points[0];
      
      // Custom drill handler takes precedence
      if (drillConfig.customHandler) {
        drillConfig.customHandler(point, drillConfig.type);
        return;
      }

      // Auto-extract drill values from point data
      let drillValue: string | undefined;
      let drillLabel: string | undefined;

      if (drillConfig.valueField && point.data && point.data[drillConfig.valueField]) {
        drillValue = point.data[drillConfig.valueField];
      } else if (point.x) {
        drillValue = String(point.x);
      } else if (point.label) {
        drillValue = String(point.label);
      }

      if (drillConfig.labelField && point.data && point.data[drillConfig.labelField]) {
        drillLabel = point.data[drillConfig.labelField];
      } else if (point.x) {
        drillLabel = String(point.x);
      } else if (point.label) {
        drillLabel = String(point.label);
      }

      if (drillValue) {
        handleDrillDown(drillConfig.type, drillValue, drillLabel || drillValue);
      }
    }
    // Fallback to legacy drillable behavior
    else if (drillable && onPlotlyClick && event.points && event.points.length > 0) {
      onPlotlyClick(event);
    }
  }, [onPlotlyClick, drillConfig, drillable, handleDrillDown]);

  const amazonThemeLayout: any = {
    autosize: true,
    height: height,
    margin: { l: 40, r: 20, t: 40, b: 40 },
    paper_bgcolor: "rgba(0,0,0,0)",
    plot_bgcolor: "rgba(0,0,0,0)",
    font: { 
      family: "Inter, system-ui, -apple-system, 'Segoe UI', Roboto", 
      color: "#2b2b2b" 
    },
    colorway: [
      '#f79500', // Amazon orange
      '#232f3e', // Amazon dark
      '#146eb4', // Amazon blue
      '#ff9900', // Amazon accent
      '#37475a', // Dark gray
      '#8c4bff', // Purple
      '#00d4aa', // Teal
      '#ff6b6b'  // Red
    ],
    // Add drill-down hint if enabled
    ...(drillConfig?.enabled && {
      annotations: [
        ...(layout.annotations || []),
        {
          x: 1,
          y: 1,
          xref: 'paper',
          yref: 'paper',
          text: '💡 Click to drill down',
          showarrow: false,
          font: { size: 10, color: '#6b7280' },
          bgcolor: 'rgba(255,255,255,0.8)',
          bordercolor: '#d1d5db',
          borderwidth: 1,
          xanchor: 'right',
          yanchor: 'top'
        }
      ]
    }),
    ...layout,
  };

  const defaultConfig: any = {
    displayModeBar: exportable || drillConfig?.enabled,
    responsive: true,
    showTips: false,
    staticPlot: false,
    displaylogo: false,
    modeBarButtonsToRemove: ['pan2d', 'lasso2d', 'select2d'],
    ...(exportable && {
      toImageButtonOptions: {
        format: 'png' as const,
        filename: title ? `${title.toLowerCase().replace(/\s+/g, '_')}_${Date.now()}` : `chart_${Date.now()}`,
        height: 600,
        width: 1000,
        scale: 2,
      }
    }),
    ...config
  };

  // Use universal click handler if drill config is enabled, otherwise use legacy behavior
  const handleClick = (drillConfig?.enabled || drillable) ? handleUniversalClick : undefined;

  return (
    <div className={`w-full h-full ${className} relative`} data-chart>
      {exportable && title && (
        <div className="absolute top-2 right-2 z-10">
          <ExportButton chartData={data} chartTitle={title} />
        </div>
      )}
      <Plot
        data={data}
        layout={amazonThemeLayout}
        config={defaultConfig}
        style={{ width: "100%", height: "100%" }}
        useResizeHandler={true}
        onClick={handleClick}
      />
    </div>
  );
}