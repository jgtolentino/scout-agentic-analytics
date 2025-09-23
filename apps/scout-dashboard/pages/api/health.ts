import { NextApiRequest, NextApiResponse } from 'next'

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' })
  }

  try {
    // Check Azure SQL environment variables
    const haveAzureSQL = !!(
      process.env.AZURE_SQL_SERVER &&
      process.env.AZURE_SQL_DATABASE &&
      process.env.AZURE_SQL_USER &&
      process.env.AZURE_SQL_PASSWORD
    )

    // Check client environment variables
    const haveClient = !!process.env.NEXT_PUBLIC_MAPBOX_TOKEN

    const health = {
      ok: haveAzureSQL,
      timestamp: new Date().toISOString(),
      deployment: process.env.VERCEL_URL || 'local',
      client_env: {
        mapbox: !!process.env.NEXT_PUBLIC_MAPBOX_TOKEN,
        mode: process.env.NEXT_PUBLIC_APP_MODE || 'production',
        schema: process.env.NEXT_PUBLIC_SCOUT_SCHEMA || 'scout',
      },
      server_env: {
        azure_sql_server: !!process.env.AZURE_SQL_SERVER,
        azure_sql_database: !!process.env.AZURE_SQL_DATABASE,
        azure_sql_user: !!process.env.AZURE_SQL_USER,
        azure_sql_password: !!process.env.AZURE_SQL_PASSWORD,
        scout_api: !!process.env.SCOUT_API_KEY
      },
      runtime: {
        node_version: process.version,
        vercel_region: process.env.VERCEL_REGION || null,
        vercel_env: process.env.VERCEL_ENV || null
      }
    }

    // Set appropriate cache headers
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate')
    res.setHeader('Content-Type', 'application/json')

    return res.status(200).json(health)

  } catch (error) {
    console.error('Health check error:', error)

    return res.status(500).json({
      ok: false,
      error: 'Health check failed',
      message: error instanceof Error ? error.message : 'Unknown error',
      timestamp: new Date().toISOString()
    })
  }
}

// Disable caching for this endpoint
export const config = {
  api: {
    externalResolver: true,
  },
}