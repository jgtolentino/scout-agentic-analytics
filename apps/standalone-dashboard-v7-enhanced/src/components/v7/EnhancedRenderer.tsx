import React, { useState, useEffect } from 'react';
import { WIDGETS } from "../../components/widgets";

export function Grid({ children }: any) { 
  return <div className="grid grid-cols-12 gap-4">{children}</div>; 
}

export function Cell({ w = 12, h = 4, children }: any) { 
  const span = Math.min(12, Math.max(1, w));
  return (
    <div 
      className={`col-span-${span}`} 
      style={{ minHeight: h * 90 }}
    >
      {children}
    </div>
  ); 
}

// Mock RPC call
async function callRPC(rpcName: string, params: any) {
  await new Promise(resolve => setTimeout(resolve, 200));
  
  switch (rpcName) {
    case 'scout_ai_executive':
      return {
        kpi: { revenue: 125000, avgTicket: 85.50, orders: 1463, mom: 0.12 },
        trends: [
          { date: '2024-01', value: 95000 },
          { date: '2024-02', value: 110000 },
          { date: '2024-03', value: 125000 }
        ]
      };
      
    case 'financial_data_demo':
      return {
        timeseries: [
          { month: 'Jan', revenue: 4000, profit: 2400, volume: 1200000 },
          { month: 'Feb', revenue: 3000, profit: 1398, volume: 980000 },
          { month: 'Mar', revenue: 2000, profit: 9800, volume: 1500000 }
        ]
      };
      
    default:
      return { message: `Mock data for ${rpcName}` };
  }
}

export default function EnhancedV7Renderer({ pageId }: { pageId: string }) {
  const [cfg, setCfg] = useState<any>(null);
  const [data, setData] = useState<any>({});
  const [loading, setLoading] = useState<Record<number, boolean>>({});

  // Load configuration
  useEffect(() => {
    fetch('/config/scout-v7-complete.json')
      .then(res => res.json())
      .then(setCfg)
      .catch(console.error);
  }, []);

  // Data fetching
  useEffect(() => {
    if (!cfg) return;
    const page = cfg.pages?.find((p: any) => p.id === pageId);
    if (!page) return;
    
    (async () => {
      const blocks = page.layout?.filter((b: any) => b.data?.rpc) || [];
      const results = await Promise.all(blocks.map(async (b: any, i: number) => {
        setLoading(prev => ({ ...prev, [i]: true }));
        
        try {
          const out = await callRPC(b.data.rpc, {});
          return [i, out] as const;
        } catch (error) {
          console.error(`RPC call failed for block ${i}:`, error);
          return [i, { error: (error as Error).message }] as const;
        } finally {
          setLoading(prev => ({ ...prev, [i]: false }));
        }
      }));
      
      const map: any = {};
      results.forEach(([i, out]) => { map[i] = out; });
      setData(map);
    })();
  }, [cfg, pageId]);

  if (!cfg) {
    return (
      <div className="p-8 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin w-8 h-8 border-4 border-blue-500 border-t-transparent rounded-full mx-auto mb-4"></div>
          <div className="text-gray-600">Loading enhanced configuration...</div>
        </div>
      </div>
    );
  }
  
  const page = cfg.pages?.find((p: any) => p.id === pageId);
  if (!page) {
    return (
      <div className="p-8 text-center">
        <div className="text-6xl mb-4">📊</div>
        <div className="text-xl font-bold text-gray-800 mb-2">Page Not Found</div>
        <div className="text-gray-600">Page '{pageId}' not found in configuration</div>
        <div className="mt-4 text-sm text-gray-500">
          Available pages: {cfg.pages?.map((p: any) => p.id).join(', ')}
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 relative">
      {/* Page Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">{page.title}</h1>
          <div className="text-sm text-gray-500 mt-1">
            {page.description || `${page.layout?.length || 0} widgets • Enhanced with Figma & Stockbot integration`}
          </div>
        </div>
        
        {/* Loading indicator */}
        <div className="text-xs text-gray-500">
          {Object.values(loading).some(Boolean) && (
            <div className="flex items-center space-x-1">
              <div className="animate-spin w-3 h-3 border-2 border-blue-500 border-t-transparent rounded-full"></div>
              <span>Loading...</span>
            </div>
          )}
        </div>
      </div>
      
      {/* Main Content Grid */}
      <Grid>
        {page.layout?.map((block: any, i: number) => {
          const Widget = WIDGETS[block.widget as keyof typeof WIDGETS];
          if (!Widget) {
            return (
              <Cell key={i} w={block.w} h={block.h}>
                <div className="p-4 border-2 border-dashed border-red-200 rounded bg-red-50">
                  <div className="text-center text-red-600">
                    <div className="text-2xl mb-2">❌</div>
                    <div className="font-semibold">Unknown widget: {block.widget}</div>
                    <div className="text-sm mt-1">Check widget registry</div>
                  </div>
                </div>
              </Cell>
            );
          }
          
          let blockData = null;
          if (block.data?.rpc && data[i]) {
            const path = block.data.path;
            blockData = path ? data[i][path] : data[i];
          }
          
          return (
            <Cell key={i} w={block.w} h={block.h}>
              <div className="relative">
                {loading[i] && (
                  <div className="absolute inset-0 bg-white bg-opacity-75 flex items-center justify-center z-10 rounded">
                    <div className="text-center">
                      <div className="animate-spin w-6 h-6 border-2 border-blue-500 border-t-transparent rounded-full mx-auto mb-2"></div>
                      <div className="text-sm text-gray-600">Loading {block.widget}...</div>
                    </div>
                  </div>
                )}
                <Widget 
                  props={{
                    ...block.props,
                    title: block.props?.title || `${block.widget} (Block ${i + 1})`
                  }} 
                  data={blockData} 
                />
              </div>
            </Cell>
          );
        })}
      </Grid>
      
      {/* Development Info */}
      {process.env.NODE_ENV === 'development' && (
        <div className="mt-8 p-4 bg-gray-100 rounded border-t-4 border-blue-500">
          <h3 className="font-semibold text-gray-800 mb-2">Development Info</h3>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
            <div>
              <div className="font-medium text-gray-600">Page ID</div>
              <div className="text-gray-900">{pageId}</div>
            </div>
            <div>
              <div className="font-medium text-gray-600">Widgets</div>
              <div className="text-gray-900">{page.layout?.length || 0}</div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}