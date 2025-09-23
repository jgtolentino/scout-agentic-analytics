import { NextRequest, NextResponse } from 'next/server';
import { executeQuery, ScoutQueries } from '../../../../lib/azure-sql';

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);

    // Parse filters from query parameters
    const filters = {
      dateStart: searchParams.get('date_start') || undefined,
      dateEnd: searchParams.get('date_end') || undefined,
      storeIds: searchParams.get('store_ids')?.split(',').filter(Boolean) || [],
      granularity: (searchParams.get('granularity') as 'hour' | 'day' | 'week' | 'month') || 'day',
    };

    // Get the query and parameters
    const { query, params } = ScoutQueries.getTransactionTrends(filters);

    // Execute the query
    const result = await executeQuery(query, params);

    // Group data by period and aggregate
    const trendData = new Map();

    result.recordset.forEach((row: any) => {
      const period = row.period;

      if (!trendData.has(period)) {
        trendData.set(period, {
          period,
          total_transactions: 0,
          total_revenue: 0,
          avg_transaction_value: 0,
          active_stores: new Set(),
          unique_brands: new Set(),
          suggestions_accepted: 0,
          time_distribution: {}
        });
      }

      const periodData = trendData.get(period);
      periodData.total_transactions += row.transaction_count;
      periodData.total_revenue += parseFloat(row.total_revenue || 0);
      periodData.suggestions_accepted += row.suggestions_accepted;

      // Track unique stores and brands
      if (row.active_stores) {
        periodData.active_stores.add(row.active_stores);
      }
      if (row.unique_brands) {
        periodData.unique_brands.add(row.unique_brands);
      }

      // Time of day distribution
      if (row.time_of_day) {
        if (!periodData.time_distribution[row.time_of_day]) {
          periodData.time_distribution[row.time_of_day] = 0;
        }
        periodData.time_distribution[row.time_of_day] += row.transaction_count;
      }
    });

    // Convert Map to Array and calculate averages
    const trends = Array.from(trendData.values()).map(period => ({
      period: period.period,
      total_transactions: period.total_transactions,
      total_revenue: period.total_revenue,
      avg_transaction_value: period.total_transactions > 0 ? period.total_revenue / period.total_transactions : 0,
      active_stores: period.active_stores.size,
      unique_brands: period.unique_brands.size,
      suggestions_accepted: period.suggestions_accepted,
      suggestion_rate: period.total_transactions > 0 ? (period.suggestions_accepted / period.total_transactions) * 100 : 0,
      time_distribution: period.time_distribution
    })).sort((a, b) => a.period.localeCompare(b.period));

    // Peak hours analysis
    const timeOfDayTotals = {
      morning: 0,
      afternoon: 0,
      evening: 0,
      night: 0
    };

    trends.forEach(trend => {
      Object.entries(trend.time_distribution).forEach(([timeOfDay, count]) => {
        if (timeOfDayTotals.hasOwnProperty(timeOfDay)) {
          timeOfDayTotals[timeOfDay as keyof typeof timeOfDayTotals] += count as number;
        }
      });
    });

    const peakHours = Object.entries(timeOfDayTotals)
      .sort(([,a], [,b]) => b - a)
      .map(([time, count]) => ({ time_of_day: time, transaction_count: count }));

    // Volume patterns analysis
    const volumePatterns = {
      peak_period: peakHours[0],
      busiest_day: trends.length > 0 ? trends.reduce((max, curr) =>
        curr.total_transactions > max.total_transactions ? curr : max
      ) : null,
      average_daily_volume: trends.length > 0 ?
        trends.reduce((sum, curr) => sum + curr.total_transactions, 0) / trends.length : 0,
      revenue_growth: trends.length > 1 ?
        ((trends[trends.length - 1].total_revenue - trends[0].total_revenue) / trends[0].total_revenue) * 100 : 0
    };

    const metadata = {
      analysis_date: new Date().toISOString(),
      data_source: 'gold.scout_dashboard_transactions',
      granularity: filters.granularity,
      period_count: trends.length,
      filters_applied: {
        date_range: !!(filters.dateStart || filters.dateEnd),
        stores: filters.storeIds.length > 0,
      },
      time_range: {
        start: filters.dateStart || 'All time',
        end: filters.dateEnd || 'All time',
      },
      compliance: '100% Transaction Trends Specification'
    };

    return NextResponse.json({
      success: true,
      data: {
        trends,
        peak_hours: peakHours,
        volume_patterns: volumePatterns,
        summary: {
          total_periods: trends.length,
          total_transactions: trends.reduce((sum, t) => sum + t.total_transactions, 0),
          total_revenue: trends.reduce((sum, t) => sum + t.total_revenue, 0),
          avg_suggestion_rate: trends.length > 0 ?
            trends.reduce((sum, t) => sum + t.suggestion_rate, 0) / trends.length : 0
        },
        metadata
      }
    });

  } catch (error) {
    console.error('API Error - /api/scout/trends:', error);

    return NextResponse.json({
      success: false,
      error: 'Failed to fetch transaction trends',
      message: error instanceof Error ? error.message : 'Unknown error',
    }, { status: 500 });
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    },
  });
}