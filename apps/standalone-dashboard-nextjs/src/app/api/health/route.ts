import { NextResponse } from 'next/server';

export async function GET() {
  try {
    const healthChecks = {
      status: 'ok',
      timestamp: new Date().toISOString(),
      services: {} as Record<string, any>,
      environment: {
        nodeEnv: process.env.NODE_ENV,
        dataSource: process.env.NEXT_PUBLIC_DATA_SOURCE || 'azure',
        miEnabled: process.env.MI_ENABLED === '1',
        hasAzureSqlServer: !!process.env.AZURE_SQL_SERVER,
        hasAzureSqlDatabase: !!process.env.AZURE_SQL_DATABASE,
      }
    };

    // Test Azure SQL Database connection (server-side only)
    if (process.env.AZURE_SQL_SERVER && process.env.AZURE_SQL_DATABASE) {
      try {
        const { checkDatabaseHealth } = await import('@/lib/db');
        const dbHealth = await checkDatabaseHealth();
        healthChecks.services.azureSQL = dbHealth;
      } catch (error) {
        healthChecks.services.azureSQL = {
          connected: false,
          error: error instanceof Error ? error.message : 'Unknown database error'
        };
      }
    } else {
      healthChecks.services.azureSQL = {
        connected: false,
        error: 'Azure SQL credentials not configured'
      };
    }

    // Test Azure Functions availability
    const azureFunctionBase = process.env.NEXT_PUBLIC_AZURE_FUNCTION_BASE;
    if (azureFunctionBase) {
      try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 5000);

        const response = await fetch(`${azureFunctionBase}/health`, {
          method: 'GET',
          signal: controller.signal,
          headers: {
            'Accept': 'application/json',
            ...(process.env.NEXT_PUBLIC_AZURE_FUNCTION_KEY && {
              'x-functions-key': process.env.NEXT_PUBLIC_AZURE_FUNCTION_KEY
            })
          }
        });

        clearTimeout(timeoutId);

        healthChecks.services.azureFunctions = {
          connected: response.ok,
          status: response.status,
          url: azureFunctionBase
        };
      } catch (error) {
        healthChecks.services.azureFunctions = {
          connected: false,
          error: error instanceof Error ? error.message : 'Unknown Azure Functions error'
        };
      }
    } else {
      healthChecks.services.azureFunctions = {
        connected: false,
        error: 'Azure Functions URL not configured'
      };
    }

    // Determine overall health
    const allServicesHealthy = Object.values(healthChecks.services).every(
      service => service.connected === true
    );

    const status = allServicesHealthy ? 200 : 503;
    healthChecks.status = allServicesHealthy ? 'healthy' : 'degraded';

    return NextResponse.json(healthChecks, { status });

  } catch (error) {
    return NextResponse.json({
      status: 'error',
      timestamp: new Date().toISOString(),
      error: error instanceof Error ? error.message : 'Unknown health check error'
    }, { status: 500 });
  }
}

// Handle other HTTP methods
export async function POST() {
  return NextResponse.json({ error: 'Method not allowed' }, { status: 405 });
}

export async function PUT() {
  return NextResponse.json({ error: 'Method not allowed' }, { status: 405 });
}

export async function DELETE() {
  return NextResponse.json({ error: 'Method not allowed' }, { status: 405 });
}