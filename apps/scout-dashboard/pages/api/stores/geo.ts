import { NextApiRequest, NextApiResponse } from 'next'
import { azureScoutClient } from '../../../lib/azure-client'

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' })
  }

  // Set no-cache headers for live data
  res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate')
  res.setHeader('Content-Type', 'application/json')

  try {
    // Get real store geo data from Azure SQL
    const result = await azureScoutClient.getStoreGeoData()

    return res.status(200).json(result)

  } catch (error) {
    console.error('Store geo endpoint error:', error)

    return res.status(500).json({
      ok: false,
      error: 'Store geolocation data failed',
      message: error instanceof Error ? error.message : 'Unknown error',
      timestamp: new Date().toISOString()
    })
  }
}