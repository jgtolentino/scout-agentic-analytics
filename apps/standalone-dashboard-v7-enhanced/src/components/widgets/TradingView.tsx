import React, { useEffect, useRef } from 'react';

interface TradingViewProps {
  props: {
    title?: string;
    symbol?: string;
    width?: number;
    height?: number;
    theme?: 'light' | 'dark';
    style?: string;
    locale?: string;
    toolbar_bg?: string;
    enable_publishing?: boolean;
    hide_top_toolbar?: boolean;
    hide_legend?: boolean;
    save_image?: boolean;
  };
  data?: any;
}

export const TradingView: React.FC<TradingViewProps> = ({ props = {}, data }) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const widgetRef = useRef<any>(null);

  useEffect(() => {
    // Check if TradingView library is available
    if (typeof window !== 'undefined' && (window as any).TradingView) {
      initializeTradingViewWidget();
    } else {
      // Load TradingView library dynamically
      loadTradingViewScript();
    }

    return () => {
      // Cleanup
      if (widgetRef.current) {
        try {
          widgetRef.current.remove();
        } catch (error) {
          console.warn('TradingView widget cleanup failed:', error);
        }
      }
    };
  }, [props.symbol, props.theme]);

  const loadTradingViewScript = () => {
    if (document.querySelector('script[src*="tradingview"]')) {
      return; // Script already loaded
    }

    const script = document.createElement('script');
    script.type = 'text/javascript';
    script.async = true;
    script.src = 'https://s3.tradingview.com/tv.js';
    script.onload = () => {
      initializeTradingViewWidget();
    };
    script.onerror = () => {
      console.error('Failed to load TradingView library');
    };
    document.head.appendChild(script);
  };

  const initializeTradingViewWidget = () => {
    if (!containerRef.current || !(window as any).TradingView) return;

    // Clear existing widget
    if (containerRef.current) {
      containerRef.current.innerHTML = '';
    }

    try {
      widgetRef.current = new (window as any).TradingView.widget({
        autosize: true,
        symbol: props.symbol || 'PSE:JFC', // Default to Jollibee Foods Corporation
        interval: 'D',
        timezone: 'Asia/Manila',
        theme: props.theme || 'light',
        style: props.style || '1',
        locale: props.locale || 'en',
        toolbar_bg: props.toolbar_bg || '#f1f3f6',
        enable_publishing: props.enable_publishing || false,
        allow_symbol_change: true,
        container_id: containerRef.current?.id || 'tradingview_widget',
        hide_top_toolbar: props.hide_top_toolbar || false,
        hide_legend: props.hide_legend || false,
        save_image: props.save_image !== false,
        studies: [
          'MASimple@tv-basicstudies', // Moving Average
          'RSI@tv-basicstudies',      // Relative Strength Index
        ],
        show_popup_button: true,
        popup_width: '1000',
        popup_height: '650',
      });
    } catch (error) {
      console.error('TradingView widget initialization failed:', error);
    }
  };

  // Generate unique ID for the container
  const containerId = `tradingview_${Math.random().toString(36).substr(2, 9)}`;

  return (
    <div className="p-4 border rounded-lg bg-white">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-lg font-semibold text-gray-800">
          {props.title || `${props.symbol || 'PSE:JFC'} Trading Chart`}
        </h3>
        <div className="flex items-center space-x-2">
          <span className="text-xs text-gray-500">Powered by</span>
          <img
            src="data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTAwIiBoZWlnaHQ9IjI0IiB2aWV3Qm94PSIwIDAgMTAwIDI0IiBmaWxsPSJub25lIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPgo8cGF0aCBkPSJNMTIuNSA4LjVIMTVWN0gxMi41VjguNVoiIGZpbGw9IiMxOTc5REYiLz4KPHBhdGggZD0iTTE3LjUgOC41SDE1VjdIMTcuNVY4LjVaIiBmaWxsPSIjMTk3OURGIi8+CjxwYXRoIGQ9Ik0xNyA0SDdWMTlIMTdWNFoiIHN0cm9rZT0iIzE5NzlERiIgc3Ryb2tlLXdpZHRoPSIyIiBmaWxsPSJub25lIi8+CjwvZz4KPC9zdmc+"
            alt="TradingView"
            className="h-4 opacity-60"
          />
        </div>
      </div>

      {/* TradingView Widget Container */}
      <div className="relative">
        <div
          id={containerId}
          ref={containerRef}
          className="w-full h-96 bg-gray-50 rounded border-2 border-dashed border-gray-200"
          style={{ minHeight: '400px' }}
        >
          {/* Loading state */}
          <div className="flex items-center justify-center h-full">
            <div className="text-center">
              <div className="animate-spin w-8 h-8 border-4 border-blue-500 border-t-transparent rounded-full mx-auto mb-3"></div>
              <div className="text-sm text-gray-600">Loading TradingView Chart...</div>
              <div className="text-xs text-gray-500 mt-1">
                Symbol: {props.symbol || 'PSE:JFC'}
              </div>
            </div>
          </div>
        </div>

        {/* Fallback content if TradingView fails */}
        <div className="absolute inset-0 bg-white rounded border hidden" id={`${containerId}_fallback`}>
          <div className="p-4">
            <div className="text-center text-gray-600">
              <div className="text-4xl mb-2">📈</div>
              <div className="text-lg font-medium mb-2">Chart Unavailable</div>
              <div className="text-sm">
                Unable to load TradingView widget. Please check your connection or try refreshing the page.
              </div>
              <div className="mt-4">
                <button
                  onClick={() => window.location.reload()}
                  className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors text-sm"
                >
                  Refresh Page
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Widget Info */}
      <div className="mt-4 text-xs text-gray-500 border-t pt-3">
        <div className="grid grid-cols-2 gap-4">
          <div>
            <strong>Symbol:</strong> {props.symbol || 'PSE:JFC'}
          </div>
          <div>
            <strong>Theme:</strong> {props.theme || 'Light'}
          </div>
          <div>
            <strong>Timezone:</strong> Asia/Manila
          </div>
          <div>
            <strong>Interval:</strong> Daily
          </div>
        </div>
      </div>
    </div>
  );
};

// Enhanced TradingView component with Scout data integration
export const ScoutTradingView: React.FC<{
  scoutData?: any;
  symbol?: string;
  title?: string;
}> = ({ scoutData, symbol, title }) => {
  return (
    <div className="space-y-4">
      {/* Scout Data Summary */}
      {scoutData && (
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <h4 className="font-semibold text-blue-900 mb-2">Scout Analytics Integration</h4>
          <div className="grid grid-cols-3 gap-4 text-sm">
            <div>
              <div className="text-blue-700 font-medium">Volume</div>
              <div className="text-blue-900">{scoutData.volume?.toLocaleString() || 'N/A'}</div>
            </div>
            <div>
              <div className="text-blue-700 font-medium">Trend</div>
              <div className="text-blue-900">{scoutData.trend || 'Neutral'}</div>
            </div>
            <div>
              <div className="text-blue-700 font-medium">Signal</div>
              <div className="text-blue-900">{scoutData.signal || 'Hold'}</div>
            </div>
          </div>
        </div>
      )}

      {/* TradingView Widget */}
      <TradingView
        props={{
          symbol: symbol || 'PSE:JFC',
          title: title || 'Market Analysis',
          theme: 'light',
          save_image: true,
          hide_legend: false,
        }}
      />
    </div>
  );
};