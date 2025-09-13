// Stockbot-style financial data adapter for Scout Dashboard
// Transforms financial data without requiring Groq API

export interface StockbotDataAdapter {
  transformFinancialData(rawData: any): FinancialDataset;
  generateChartConfig(dataType: string, preferences?: ChartPreferences): ChartConfig;
  adaptToScoutFormat(stockbotData: any): ScoutCompatibleData;
}

export interface FinancialDataset {
  timeseries: TimeSeriesData[];
  metrics: FinancialMetrics;
  signals: TradingSignals;
  recommendations: string[];
}

export interface TimeSeriesData {
  timestamp: string;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
  indicators?: {
    sma?: number;
    ema?: number;
    rsi?: number;
    macd?: number;
  };
}

export interface FinancialMetrics {
  marketCap: number;
  peRatio: number;
  dividend: number;
  beta: number;
  volatility: number;
  volume24h: number;
  changePercent: number;
  trend: 'bullish' | 'bearish' | 'neutral';
}

export interface TradingSignals {
  signal: 'buy' | 'sell' | 'hold';
  confidence: number;
  reasons: string[];
  targetPrice?: number;
  stopLoss?: number;
}

export interface ChartPreferences {
  timeframe?: '1D' | '1W' | '1M' | '3M' | '1Y';
  chartType?: 'candlestick' | 'line' | 'bar' | 'area';
  indicators?: string[];
  theme?: 'light' | 'dark';
}

export interface ChartConfig {
  type: string;
  data: any[];
  options: {
    responsive: boolean;
    maintainAspectRatio: boolean;
    plugins: any;
    scales: any;
  };
}

export interface ScoutCompatibleData {
  rpc: string;
  path?: string;
  data: any;
  metadata: {
    source: 'stockbot-adapter';
    timestamp: string;
    dataType: string;
  };
}

/**
 * Main Stockbot adapter class
 */
export class StockbotAdapter implements StockbotDataAdapter {
  
  /**
   * Transform raw financial data into structured format
   */
  transformFinancialData(rawData: any): FinancialDataset {
    // Handle various data source formats
    if (Array.isArray(rawData)) {
      return this.transformArrayData(rawData);
    } else if (rawData.quotes || rawData.chart) {
      return this.transformYahooFinanceFormat(rawData);
    } else if (rawData.candles) {
      return this.transformAlphaVantageFormat(rawData);
    } else {
      return this.transformGenericFormat(rawData);
    }
  }

  private transformArrayData(data: any[]): FinancialDataset {
    const timeseries = data.map(item => ({
      timestamp: item.date || item.timestamp || new Date().toISOString(),
      open: parseFloat(item.open || item.o || 0),
      high: parseFloat(item.high || item.h || 0),
      low: parseFloat(item.low || item.l || 0),
      close: parseFloat(item.close || item.c || 0),
      volume: parseInt(item.volume || item.v || 0),
      indicators: this.calculateIndicators(item)
    }));

    return {
      timeseries,
      metrics: this.calculateMetrics(timeseries),
      signals: this.generateSignals(timeseries),
      recommendations: this.generateRecommendations(timeseries)
    };
  }

  private transformYahooFinanceFormat(data: any): FinancialDataset {
    const quotes = data.chart?.result?.[0]?.indicators?.quote?.[0] || {};
    const timestamps = data.chart?.result?.[0]?.timestamp || [];
    
    const timeseries = timestamps.map((timestamp: number, index: number) => ({
      timestamp: new Date(timestamp * 1000).toISOString(),
      open: quotes.open?.[index] || 0,
      high: quotes.high?.[index] || 0,
      low: quotes.low?.[index] || 0,
      close: quotes.close?.[index] || 0,
      volume: quotes.volume?.[index] || 0
    }));

    return {
      timeseries,
      metrics: this.calculateMetrics(timeseries),
      signals: this.generateSignals(timeseries),
      recommendations: this.generateRecommendations(timeseries)
    };
  }

  private transformAlphaVantageFormat(data: any): FinancialDataset {
    const candles = data.candles || data['Time Series (Daily)'] || {};
    
    const timeseries = Object.entries(candles).map(([date, values]: [string, any]) => ({
      timestamp: new Date(date).toISOString(),
      open: parseFloat(values['1. open'] || values.open || 0),
      high: parseFloat(values['2. high'] || values.high || 0),
      low: parseFloat(values['3. low'] || values.low || 0),
      close: parseFloat(values['4. close'] || values.close || 0),
      volume: parseInt(values['5. volume'] || values.volume || 0)
    }));

    return {
      timeseries: timeseries.sort((a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime()),
      metrics: this.calculateMetrics(timeseries),
      signals: this.generateSignals(timeseries),
      recommendations: this.generateRecommendations(timeseries)
    };
  }

  private transformGenericFormat(data: any): FinancialDataset {
    // Fallback for generic data formats
    const timeseries = [{
      timestamp: new Date().toISOString(),
      open: data.price || data.open || 100,
      high: (data.price || data.open || 100) * 1.05,
      low: (data.price || data.open || 100) * 0.95,
      close: data.price || data.close || 100,
      volume: data.volume || 1000000
    }];

    return {
      timeseries,
      metrics: this.calculateMetrics(timeseries),
      signals: this.generateSignals(timeseries),
      recommendations: this.generateRecommendations(timeseries)
    };
  }

  /**
   * Calculate technical indicators
   */
  private calculateIndicators(item: any): any {
    return {
      sma: this.calculateSMA([item.close], 5)[0],
      ema: this.calculateEMA([item.close], 5)[0],
      rsi: this.calculateRSI([item.close], 14)[0] || 50,
      macd: 0 // Simplified for demo
    };
  }

  /**
   * Calculate financial metrics from time series
   */
  private calculateMetrics(timeseries: TimeSeriesData[]): FinancialMetrics {
    if (timeseries.length === 0) {
      return {
        marketCap: 0,
        peRatio: 0,
        dividend: 0,
        beta: 1,
        volatility: 0,
        volume24h: 0,
        changePercent: 0,
        trend: 'neutral'
      };
    }

    const latest = timeseries[timeseries.length - 1];
    const previous = timeseries[timeseries.length - 2] || latest;
    
    const changePercent = ((latest.close - previous.close) / previous.close) * 100;
    const prices = timeseries.map(t => t.close);
    const volatility = this.calculateVolatility(prices);

    return {
      marketCap: latest.close * latest.volume,
      peRatio: 15.5, // Mock P/E ratio
      dividend: 2.3, // Mock dividend yield
      beta: 1.2, // Mock beta
      volatility,
      volume24h: timeseries.slice(-24).reduce((sum, t) => sum + t.volume, 0),
      changePercent,
      trend: changePercent > 2 ? 'bullish' : changePercent < -2 ? 'bearish' : 'neutral'
    };
  }

  /**
   * Generate trading signals based on price action and indicators
   */
  private generateSignals(timeseries: TimeSeriesData[]): TradingSignals {
    if (timeseries.length < 2) {
      return {
        signal: 'hold',
        confidence: 0.5,
        reasons: ['Insufficient data for analysis']
      };
    }

    const latest = timeseries[timeseries.length - 1];
    const previous = timeseries[timeseries.length - 2];
    const changePercent = ((latest.close - previous.close) / previous.close) * 100;
    
    let signal: 'buy' | 'sell' | 'hold';
    let confidence: number;
    let reasons: string[] = [];

    // Simple signal generation logic
    if (changePercent > 5) {
      signal = 'buy';
      confidence = 0.75;
      reasons.push('Strong upward momentum detected');
      reasons.push(`Price increased by ${changePercent.toFixed(2)}%`);
    } else if (changePercent < -5) {
      signal = 'sell';
      confidence = 0.70;
      reasons.push('Strong downward momentum detected');
      reasons.push(`Price decreased by ${Math.abs(changePercent).toFixed(2)}%`);
    } else {
      signal = 'hold';
      confidence = 0.60;
      reasons.push('Price movement within normal range');
      reasons.push('No clear directional signal');
    }

    // Add volume analysis
    const avgVolume = timeseries.slice(-5).reduce((sum, t) => sum + t.volume, 0) / 5;
    if (latest.volume > avgVolume * 1.5) {
      confidence += 0.1;
      reasons.push('Above-average volume confirms signal');
    }

    return {
      signal,
      confidence: Math.min(confidence, 1.0),
      reasons,
      targetPrice: signal === 'buy' ? latest.close * 1.1 : signal === 'sell' ? latest.close * 0.9 : undefined,
      stopLoss: signal === 'buy' ? latest.close * 0.95 : signal === 'sell' ? latest.close * 1.05 : undefined
    };
  }

  /**
   * Generate text recommendations
   */
  private generateRecommendations(timeseries: TimeSeriesData[]): string[] {
    if (timeseries.length === 0) return ['No data available for recommendations'];

    const latest = timeseries[timeseries.length - 1];
    const previous = timeseries[timeseries.length - 2] || latest;
    const changePercent = ((latest.close - previous.close) / previous.close) * 100;

    const recommendations = [];

    if (changePercent > 3) {
      recommendations.push('Consider taking partial profits if you have a long position');
      recommendations.push('Monitor for potential resistance levels');
    } else if (changePercent < -3) {
      recommendations.push('Look for support levels for potential entry points');
      recommendations.push('Consider dollar-cost averaging for long-term positions');
    } else {
      recommendations.push('Wait for clearer directional signals');
      recommendations.push('Consider setting up alerts for breakout levels');
    }

    // Volume-based recommendations
    const avgVolume = timeseries.slice(-5).reduce((sum, t) => sum + t.volume, 0) / 5;
    if (latest.volume > avgVolume * 2) {
      recommendations.push('High volume suggests institutional interest');
    } else if (latest.volume < avgVolume * 0.5) {
      recommendations.push('Low volume indicates lack of conviction');
    }

    return recommendations;
  }

  /**
   * Generate chart configuration for different visualization types
   */
  generateChartConfig(dataType: string, preferences: ChartPreferences = {}): ChartConfig {
    const {
      chartType = 'line',
      theme = 'light',
      indicators = []
    } = preferences;

    const baseConfig = {
      type: chartType,
      data: [],
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: true,
            position: 'top' as const,
          },
          tooltip: {
            mode: 'index' as const,
            intersect: false,
          },
        },
        scales: {
          x: {
            display: true,
            title: {
              display: true,
              text: 'Time'
            }
          },
          y: {
            display: true,
            title: {
              display: true,
              text: 'Price (₱)'
            }
          }
        }
      }
    };

    // Customize based on data type
    switch (dataType) {
      case 'candlestick':
        return {
          ...baseConfig,
          type: 'candlestick',
          options: {
            ...baseConfig.options,
            plugins: {
              ...baseConfig.options.plugins,
              candlestick: {
                bodyColor: '#26a69a',
                bodyColorDown: '#ef5350',
                borderColor: '#26a69a',
                borderColorDown: '#ef5350'
              }
            }
          }
        };

      case 'volume':
        return {
          ...baseConfig,
          type: 'bar',
          options: {
            ...baseConfig.options,
            scales: {
              ...baseConfig.options.scales,
              y: {
                ...baseConfig.options.scales.y,
                title: {
                  display: true,
                  text: 'Volume'
                }
              }
            }
          }
        };

      default:
        return baseConfig;
    }
  }

  /**
   * Adapt stockbot data to Scout's V7 format
   */
  adaptToScoutFormat(stockbotData: any): ScoutCompatibleData {
    const financialDataset = this.transformFinancialData(stockbotData);
    
    return {
      rpc: 'financial_data_processed',
      path: 'data',
      data: {
        timeseries: financialDataset.timeseries,
        metrics: financialDataset.metrics,
        signals: financialDataset.signals,
        recommendations: financialDataset.recommendations,
        // Scout-specific formatting
        peso_value: financialDataset.timeseries[financialDataset.timeseries.length - 1]?.close || 0,
        txn_count: financialDataset.timeseries.length,
        trend_direction: financialDataset.metrics.trend,
        confidence_score: financialDataset.signals.confidence
      },
      metadata: {
        source: 'stockbot-adapter',
        timestamp: new Date().toISOString(),
        dataType: 'financial_timeseries'
      }
    };
  }

  // Helper methods for technical analysis
  private calculateSMA(prices: number[], period: number): number[] {
    const result = [];
    for (let i = period - 1; i < prices.length; i++) {
      const sum = prices.slice(i - period + 1, i + 1).reduce((a, b) => a + b, 0);
      result.push(sum / period);
    }
    return result;
  }

  private calculateEMA(prices: number[], period: number): number[] {
    const result = [];
    const multiplier = 2 / (period + 1);
    let ema = prices[0];
    
    result.push(ema);
    
    for (let i = 1; i < prices.length; i++) {
      ema = (prices[i] * multiplier) + (ema * (1 - multiplier));
      result.push(ema);
    }
    
    return result;
  }

  private calculateRSI(prices: number[], period: number): number[] {
    if (prices.length < period + 1) return [50]; // Default neutral RSI
    
    const gains = [];
    const losses = [];
    
    for (let i = 1; i < prices.length; i++) {
      const change = prices[i] - prices[i - 1];
      gains.push(change > 0 ? change : 0);
      losses.push(change < 0 ? Math.abs(change) : 0);
    }
    
    const avgGain = gains.slice(0, period).reduce((a, b) => a + b, 0) / period;
    const avgLoss = losses.slice(0, period).reduce((a, b) => a + b, 0) / period;
    
    const rs = avgGain / avgLoss;
    const rsi = 100 - (100 / (1 + rs));
    
    return [rsi];
  }

  private calculateVolatility(prices: number[]): number {
    if (prices.length < 2) return 0;
    
    const returns = [];
    for (let i = 1; i < prices.length; i++) {
      returns.push((prices[i] - prices[i - 1]) / prices[i - 1]);
    }
    
    const mean = returns.reduce((a, b) => a + b, 0) / returns.length;
    const variance = returns.reduce((sum, ret) => sum + Math.pow(ret - mean, 2), 0) / returns.length;
    
    return Math.sqrt(variance) * Math.sqrt(252) * 100; // Annualized volatility as percentage
  }
}

// Export singleton instance
export const stockbotAdapter = new StockbotAdapter();

// Utility functions for easy integration
export function adaptYahooFinanceData(data: any): ScoutCompatibleData {
  return stockbotAdapter.adaptToScoutFormat(data);
}

export function adaptAlphaVantageData(data: any): ScoutCompatibleData {
  return stockbotAdapter.adaptToScoutFormat(data);
}

export function generateStockChartConfig(preferences?: ChartPreferences): ChartConfig {
  return stockbotAdapter.generateChartConfig('candlestick', preferences);
}