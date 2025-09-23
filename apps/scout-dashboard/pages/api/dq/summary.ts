import { NextApiRequest, NextApiResponse } from 'next'
import { azureScoutClient } from '../../../lib/azure-client'

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' })
  }

  // Set no-cache headers
  res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate')
  res.setHeader('Content-Type', 'application/json')

  try {
    // Get real data quality summary from Azure SQL
    const result = await azureScoutClient.getDataQualitySummary()

    return res.status(200).json(result)

  } catch (error) {
    console.error('Data quality summary error:', error)

    return res.status(500).json({
      ok: false,
      error: 'Data quality check failed',
      message: error instanceof Error ? error.message : 'Unknown error',
      timestamp: new Date().toISOString()
    })
  }
}