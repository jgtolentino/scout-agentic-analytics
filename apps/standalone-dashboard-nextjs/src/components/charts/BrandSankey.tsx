'use client';

import { useState, useEffect, useMemo } from 'react';
import { useFilterBus } from '../../lib/store';
import { competitiveAPI, type BrandSwitchingData } from '../../lib/api/competitive';

interface BrandSankeyProps {
  height?: number;
  width?: number;
  showMetadata?: boolean;
  onNodeClick?: (brandId: string, value: number) => void;
  onLinkClick?: (source: string, target: string, value: number) => void;
}

interface SankeyNode {
  id: string;
  label: string;
  value: number;
  color: string;
  x: number;
  y: number;
  width: number;
  height: number;
}

interface SankeyLink {
  source: string;
  target: string;
  value: number;
  percentage: number;
  sourceX: number;
  sourceY: number;
  targetX: number;
  targetY: number;
  width: number;
  color: string;
}

export function BrandSankey({ 
  height = 500, 
  width = 800,
  showMetadata = true,
  onNodeClick,
  onLinkClick
}: BrandSankeyProps) {
  const { filters, updateFilters } = useFilterBus();
  const [data, setData] = useState<BrandSwitchingData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [hoveredElement, setHoveredElement] = useState<{ type: 'node' | 'link'; id: string } | null>(null);

  useEffect(() => {
    const fetchData = async () => {
      setLoading(true);
      setError(null);
      try {
        const result = await competitiveAPI.getBrandSwitching(filters);
        setData(result);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load switching data');
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [filters]);

  const sankeyLayout = useMemo(() => {
    if (!data) return { nodes: [], links: [] };

    const margin = { top: 20, right: 40, bottom: 20, left: 40 };
    const chartWidth = width - margin.left - margin.right;
    const chartHeight = height - margin.bottom - margin.top - (showMetadata ? 80 : 40);

    // Calculate node positions
    const nodeWidth = 20;
    const nodeSpacing = (chartHeight - data.nodes.length * 60) / (data.nodes.length - 1);
    
    const nodes: SankeyNode[] = data.nodes.map((node, index) => {
      const nodeHeight = Math.max(20, (node.value / Math.max(...data.nodes.map(n => n.value))) * 100);
      return {
        ...node,
        color: node.color || '#3B82F6',
        x: index < data.nodes.length / 2 ? margin.left : chartWidth - nodeWidth + margin.left,
        y: margin.top + index * (60 + nodeSpacing),
        width: nodeWidth,
        height: nodeHeight
      };
    });

    // Calculate link paths
    const links: SankeyLink[] = data.links.map(link => {
      const sourceNode = nodes.find(n => n.id === link.source);
      const targetNode = nodes.find(n => n.id === link.target);
      
      if (!sourceNode || !targetNode) {
        return {
          ...link,
          sourceX: 0,
          sourceY: 0,
          targetX: 0,
          targetY: 0,
          width: 0,
          color: '#E5E7EB'
        };
      }

      const linkWidth = Math.max(2, (link.value / Math.max(...data.links.map(l => l.value))) * 40);
      
      return {
        ...link,
        sourceX: sourceNode.x + sourceNode.width,
        sourceY: sourceNode.y + sourceNode.height / 2,
        targetX: targetNode.x,
        targetY: targetNode.y + targetNode.height / 2,
        width: linkWidth,
        color: `${sourceNode.color}60` // Add transparency
      };
    });

    return { nodes, links };
  }, [data, width, height, showMetadata]);

  const handleNodeClick = (node: SankeyNode) => {
    // Update global filters to focus on this brand
    updateFilters({ brand: node.id });
    
    // Notify parent component
    if (onNodeClick) {
      onNodeClick(node.id, node.value);
    }
  };

  const handleLinkClick = (link: SankeyLink) => {
    // Update filters to show switching from source to target
    updateFilters({ brand: link.source });
    
    // Notify parent component
    if (onLinkClick) {
      onLinkClick(link.source, link.target, link.value);
    }
  };

  const createCurvedPath = (link: SankeyLink): string => {
    const midX = (link.sourceX + link.targetX) / 2;
    return `M ${link.sourceX} ${link.sourceY} 
            C ${midX} ${link.sourceY}, ${midX} ${link.targetY}, ${link.targetX} ${link.targetY}`;
  };

  if (loading) {
    return (
      <div className="bg-white rounded-lg border border-gray-200 p-6" style={{ height, width }}>
        <div className="flex items-center justify-center h-full">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
          <span className="ml-2 text-gray-600">Loading switching data...</span>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-white rounded-lg border border-gray-200 p-6" style={{ height, width }}>
        <div className="flex items-center justify-center h-full text-red-600">
          <span>Error: {error instanceof Error ? error.message : String(error || 'Unknown error')}</span>
        </div>
      </div>
    );
  }

  if (!data || sankeyLayout.nodes.length === 0) {
    return (
      <div className="bg-white rounded-lg border border-gray-200 p-6" style={{ height, width }}>
        <div className="flex items-center justify-center h-full text-gray-500">
          <span>No switching data available</span>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg border border-gray-200 p-6" style={{ height, width }}>
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div>
          <h3 className="text-lg font-semibold text-gray-900">Brand Switching Flow</h3>
          <p className="text-sm text-gray-600">Customer migration patterns between brands</p>
        </div>
        {showMetadata && data.metadata && (
          <div className="text-right">
            <div className="text-sm text-gray-500">Retention Rate</div>
            <div className="text-xl font-bold text-gray-900">{data.metadata.retentionRate}%</div>
          </div>
        )}
      </div>

      {/* Sankey Diagram */}
      <div className="relative">
        <svg width={width - 48} height={height - (showMetadata ? 160 : 120)} className="overflow-visible">
          {/* Links */}
          <g className="links">
            {sankeyLayout.links.map((link, index) => (
              <g key={`link-${index}`}>
                <path
                  d={createCurvedPath(link)}
                  stroke={link.color}
                  strokeWidth={link.width}
                  fill="none"
                  className={`cursor-pointer transition-opacity duration-200 ${
                    hoveredElement?.type === 'link' && hoveredElement?.id === `${link.source}-${link.target}`
                      ? 'opacity-100'
                      : hoveredElement ? 'opacity-30' : 'opacity-70 hover:opacity-100'
                  }`}
                  onClick={() => handleLinkClick(link)}
                  onMouseEnter={() => setHoveredElement({ type: 'link', id: `${link.source}-${link.target}` })}
                  onMouseLeave={() => setHoveredElement(null)}
                />
              </g>
            ))}
          </g>

          {/* Nodes */}
          <g className="nodes">
            {sankeyLayout.nodes.map((node) => (
              <g key={node.id}>
                {/* Node Rectangle */}
                <rect
                  x={node.x}
                  y={node.y}
                  width={node.width}
                  height={node.height}
                  fill={node.color}
                  className={`cursor-pointer transition-opacity duration-200 ${
                    hoveredElement?.type === 'node' && hoveredElement?.id === node.id
                      ? 'opacity-100'
                      : hoveredElement ? 'opacity-50' : 'opacity-90 hover:opacity-100'
                  }`}
                  onClick={() => handleNodeClick(node)}
                  onMouseEnter={() => setHoveredElement({ type: 'node', id: node.id })}
                  onMouseLeave={() => setHoveredElement(null)}
                />
                
                {/* Node Label */}
                <text
                  x={node.x < width / 2 ? node.x - 8 : node.x + node.width + 8}
                  y={node.y + node.height / 2}
                  textAnchor={node.x < width / 2 ? 'end' : 'start'}
                  dominantBaseline="middle"
                  className="text-sm font-medium fill-gray-700 pointer-events-none"
                >
                  {node.label}
                </text>
                
                {/* Node Value */}
                <text
                  x={node.x < width / 2 ? node.x - 8 : node.x + node.width + 8}
                  y={node.y + node.height / 2 + 14}
                  textAnchor={node.x < width / 2 ? 'end' : 'start'}
                  dominantBaseline="middle"
                  className="text-xs fill-gray-500 pointer-events-none"
                >
                  {node.value.toLocaleString()}
                </text>
              </g>
            ))}
          </g>
        </svg>
      </div>

      {/* Legend & Metadata */}
      <div className="flex items-center justify-between pt-4 border-t border-gray-100">
        {/* Flow Legend */}
        <div className="flex items-center space-x-4">
          <div className="flex items-center space-x-2">
            <div className="w-4 h-1 bg-blue-400 rounded"></div>
            <span className="text-xs text-gray-500">Brand switching flow</span>
          </div>
          <div className="flex items-center space-x-2">
            <div className="w-4 h-4 bg-blue-600 rounded"></div>
            <span className="text-xs text-gray-500">Brand retention</span>
          </div>
        </div>

        {/* Metadata */}
        {showMetadata && data.metadata && (
          <div className="flex items-center space-x-6 text-xs text-gray-500">
            <div>
              <span className="font-medium">Total Switches:</span> {data.metadata.totalSwitches.toLocaleString()}
            </div>
            <div>
              <span className="font-medium">Top Switch:</span> {data.metadata.topSwitchingPair.from} → {data.metadata.topSwitchingPair.to} ({data.metadata.topSwitchingPair.percentage}%)
            </div>
          </div>
        )}
      </div>

      {/* Tooltip */}
      {hoveredElement && (
        <div className="absolute z-10 bg-gray-900 text-white text-xs rounded px-2 py-1 pointer-events-none">
          {hoveredElement.type === 'node' && (
            <div>
              <div className="font-medium">
                {sankeyLayout.nodes.find(n => n.id === hoveredElement.id)?.label}
              </div>
              <div className="text-gray-300">
                {sankeyLayout.nodes.find(n => n.id === hoveredElement.id)?.value.toLocaleString()} customers
              </div>
            </div>
          )}
          {hoveredElement.type === 'link' && (
            <div>
              {(() => {
                const [source, target] = hoveredElement.id.split('-');
                const link = sankeyLayout.links.find(l => l.source === source && l.target === target);
                return link ? (
                  <div>
                    <div className="font-medium">{source} → {target}</div>
                    <div className="text-gray-300">{link.value.toLocaleString()} switches ({link.percentage}%)</div>
                  </div>
                ) : null;
              })()}
            </div>
          )}
        </div>
      )}
    </div>
  );
}