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
      brands: searchParams.get('brands')?.split(',').filter(Boolean) || [],
      categories: searchParams.get('categories')?.split(',').filter(Boolean) || [],
      limit: parseInt(searchParams.get('limit') || '1000'),
      offset: parseInt(searchParams.get('offset') || '0'),
    };

    // Get the query and parameters
    const { query, params } = ScoutQueries.getTransactions(filters);

    // Execute the query
    const result = await executeQuery(query, params);

    // Transform the data to match the frontend expectations
    const transformedData = result.recordset.map((record: any) => ({
      // Core transaction data
      id: record.id,
      store_id: record.store_id,
      timestamp: record.timestamp,
      time_of_day: record.time_of_day,

      // Location object
      location: {
        barangay: record.location_barangay,
        city: record.location_city,
        province: record.location_province,
        region: record.location_region,
      },

      // Product data
      product_category: record.product_category,
      brand_name: record.brand_name,
      sku: record.sku,
      units_per_transaction: record.units_per_transaction,
      peso_value: parseFloat(record.peso_value),

      // Basket data
      basket_size: record.basket_size,
      combo_basket: JSON.parse(record.combo_basket || '[]'),

      // Behavior data
      request_mode: record.request_mode,
      request_type: record.request_type,
      suggestion_accepted: record.suggestion_accepted,

      // Demographics
      gender: record.gender,
      age_bracket: record.age_bracket,

      // Substitution data
      substitution_event: {
        occurred: record.substitution_occurred,
        from: record.substitution_from,
        to: record.substitution_to,
        reason: record.substitution_reason,
      },

      // Additional metrics
      duration_seconds: record.duration_seconds,
      campaign_influenced: record.campaign_influenced,
      handshake_score: parseFloat(record.handshake_score),
      is_tbwa_client: record.is_tbwa_client,
      payment_method: record.payment_method,
      customer_type: record.customer_type,
      store_type: record.store_type,
      economic_class: record.economic_class,
    }));

    // Calculate metadata
    const metadata = {
      total_records: result.recordset.length,
      limit: filters.limit,
      offset: filters.offset,
      filters_applied: {
        date_range: !!(filters.dateStart || filters.dateEnd),
        stores: filters.storeIds.length > 0,
        brands: filters.brands.length > 0,
        categories: filters.categories.length > 0,
      },
      data_source: 'gold.scout_dashboard_transactions',
      compliance: '100% Data Dictionary Specification',
      last_updated: new Date().toISOString(),
    };

    return NextResponse.json({
      success: true,
      data: transformedData,
      metadata,
    });

  } catch (error) {
    console.error('API Error - /api/scout/transactions:', error);

    return NextResponse.json({
      success: false,
      error: 'Failed to fetch transactions',
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