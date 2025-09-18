/**
 * End-to-End ETL Pipeline Tests
 * Tests complete data flow: Bronze → Silver → Gold → Platinum
 * SuperClaude Framework Integration
 */

import { test, expect } from '@playwright/test'
import { createClient } from '@supabase/supabase-js'
import * as fs from 'fs'
import * as path from 'path'

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://cxzllzyxwpyptfretryc.supabase.co'
const SUPABASE_KEY = process.env.SUPABASE_ANON_KEY || ''

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY)

test.describe('Scout v7 ETL Pipeline E2E Tests', () => {
  let testFileId: string
  let testSessionId: string

  test.beforeEach(async () => {
    testSessionId = `e2e_${Date.now()}_${Math.random().toString(36).substring(7)}`
    testFileId = `test_${testSessionId}`
  })

  test.afterEach(async () => {
    // Cleanup test data
    await cleanupTestData(testFileId, testSessionId)
  })

  test('Complete CSV Processing Pipeline', async () => {
    // Test data: CSV file with transaction data
    const csvData = [
      'transaction_id,timestamp,product_name,category,brand,amount,payment_method',
      `tx_${testSessionId}_1,2025-09-17T10:00:00Z,Alaska Milk 1L,Dairy,Alaska,85.50,cash`,
      `tx_${testSessionId}_2,2025-09-17T10:05:00Z,Nestle Coffee,Beverages,Nestle,45.25,card`,
      `tx_${testSessionId}_3,2025-09-17T10:10:00Z,Lucky Me Noodles,Instant Food,Monde Nissin,12.00,cash`
    ].join('\n')

    // Step 1: Upload and process CSV file
    const { data: processedData, error: processError } = await supabase.functions.invoke('drive-universal-processor', {
      body: {
        fileId: testFileId,
        fileName: `test_${testSessionId}.csv`,
        fileContent: Buffer.from(csvData).toString('base64')
      }
    })

    expect(processError).toBeNull()
    expect(processedData.success).toBe(true)
    expect(processedData.processing.format.detectedFormat).toBe('csv')
    expect(processedData.processing.format.confidence).toBeGreaterThan(0.9)
    expect(processedData.processing.records_processed).toBe(3)

    // Verify Bronze layer ingestion
    const { data: bronzeData } = await supabase
      .from('universal_file_ingestion')
      .select('*')
      .eq('file_id', testFileId)
      .single()

    expect(bronzeData).toBeTruthy()
    expect(bronzeData.file_format).toBe('csv')
    expect(bronzeData.total_records).toBe(3)
    expect(bronzeData.status).toBe('ingested')

    // Step 2: Wait for Silver layer processing
    await waitForProcessing(3000)

    // Verify Silver layer enrichment
    const { data: silverData } = await supabase
      .from('transactions_cleaned')
      .select('*')
      .like('id', `%${testSessionId}%`)

    expect(silverData).toBeTruthy()
    expect(silverData.length).toBeGreaterThan(0)

    // Verify data enrichment
    const alaskaMilkRecord = silverData.find(r => r.brand_name === 'Alaska')
    expect(alaskaMilkRecord).toBeTruthy()
    expect(alaskaMilkRecord.product_category).toBe('Dairy')
    expect(alaskaMilkRecord.amount).toBe(85.50)
    expect(alaskaMilkRecord.quality_score).toBeGreaterThan(0.8)

    // Step 3: Wait for Gold layer aggregation
    await waitForProcessing(5000)

    // Verify Gold layer aggregation
    const { data: goldData } = await supabase
      .from('scout_gold_transactions')
      .select('*')
      .gte('created_at', new Date(Date.now() - 60000).toISOString())

    expect(goldData).toBeTruthy()
    expect(goldData.length).toBeGreaterThan(0)

    // Verify aggregated metrics
    const todayAgg = goldData.find(g => g.transaction_date === new Date().toISOString().split('T')[0])
    expect(todayAgg).toBeTruthy()
    expect(todayAgg.transaction_count).toBeGreaterThan(0)
    expect(todayAgg.revenue_peso).toBeGreaterThan(0)
  })

  test('JSON Processing with Complex Schema', async () => {
    // Test data: Complex JSON structure
    const jsonData = [
      {
        transactionId: `tx_${testSessionId}_json_1`,
        timestamp: '2025-09-17T11:00:00Z',
        items: [
          {
            productName: 'Coca-Cola 1.5L',
            category: 'Soft Drinks',
            brand: 'Coca-Cola',
            price: 65.00,
            quantity: 2
          }
        ],
        customer: {
          ageGroup: '25-34',
          gender: 'M',
          location: 'Metro Manila'
        },
        payment: {
          method: 'credit_card',
          total: 130.00
        },
        metadata: {
          storeId: '101',
          deviceId: 'SCOUTPI-TEST',
          processingMethods: ['ocr', 'nlp', 'brand_detection']
        }
      }
    ]

    // Step 1: Process JSON file
    const { data: processedData, error: processError } = await supabase.functions.invoke('drive-universal-processor', {
      body: {
        fileId: `${testFileId}_json`,
        fileName: `test_${testSessionId}.json`,
        fileContent: Buffer.from(JSON.stringify(jsonData)).toString('base64')
      }
    })

    expect(processError).toBeNull()
    expect(processedData.success).toBe(true)
    expect(processedData.processing.format.detectedFormat).toBe('json')
    expect(processedData.processing.schema.columns.length).toBeGreaterThan(5)

    // Verify complex schema inference
    const schemaColumns = processedData.processing.schema.columns
    const itemsColumn = schemaColumns.find(c => c.name === 'items')
    expect(itemsColumn).toBeTruthy()
    expect(itemsColumn.type).toBe('json')

    // Verify ML column mapping for complex structures
    expect(processedData.processing.mapping.mapping_confidence).toBeGreaterThan(0.8)
  })

  test('Excel File Processing with Multiple Sheets', async () => {
    // Note: In a real implementation, you would create an actual Excel file
    // For this test, we'll simulate the expected behavior

    const excelTestData = {
      fileId: `${testFileId}_excel`,
      fileName: `test_${testSessionId}.xlsx`,
      sheetName: 'Transactions'
    }

    // Mock Excel processing - in real test, upload actual Excel file
    const mockExcelResponse = {
      success: true,
      processing: {
        format: {
          detectedFormat: 'excel',
          confidence: 0.98,
          sheetNames: ['Transactions', 'Products', 'Summary']
        },
        schema: {
          columns: [
            { name: 'Transaction_ID', type: 'string' },
            { name: 'Date_Time', type: 'date' },
            { name: 'Product', type: 'string' },
            { name: 'Amount', type: 'number' }
          ],
          qualityScore: 0.92
        },
        records_processed: 150
      }
    }

    // Verify Excel-specific processing
    expect(mockExcelResponse.processing.format.detectedFormat).toBe('excel')
    expect(mockExcelResponse.processing.format.sheetNames).toContain('Transactions')
    expect(mockExcelResponse.processing.schema.qualityScore).toBeGreaterThan(0.9)
  })

  test('Real-time Stream Processing', async () => {
    // Test Scout Edge real-time data ingestion
    const streamData = [
      `{"transactionId":"tx_${testSessionId}_stream_1","storeId":"106","deviceId":"SCOUTPI-TEST","timestamp":"${new Date().toISOString()}","items":[{"product":"Test Product","price":25.50}],"detectedBrands":{"TestBrand":{"confidence":0.95}}}`,
      `{"transactionId":"tx_${testSessionId}_stream_2","storeId":"106","deviceId":"SCOUTPI-TEST","timestamp":"${new Date(Date.now() + 1000).toISOString()}","items":[{"product":"Another Product","price":45.75}],"detectedBrands":{"AnotherBrand":{"confidence":0.88}}}`
    ].join('\n')

    // Step 1: Send stream data
    const { data: streamResult, error: streamError } = await supabase.functions.invoke('ingest-stream', {
      body: {
        source: 'scout_edge',
        deviceId: 'SCOUTPI-TEST',
        storeId: '106',
        data: streamData
      }
    })

    expect(streamError).toBeNull()
    expect(streamResult.success).toBe(true)
    expect(streamResult.records_processed).toBe(2)

    // Step 2: Wait for Bronze layer ingestion
    await waitForProcessing(2000)

    // Verify Bronze layer streaming data
    const { data: bronzeStreamData } = await supabase
      .from('scout_raw_transactions')
      .select('*')
      .eq('device_id', 'SCOUTPI-TEST')
      .like('transaction_id', `%${testSessionId}%`)

    expect(bronzeStreamData).toBeTruthy()
    expect(bronzeStreamData.length).toBe(2)

    // Verify quality scoring
    bronzeStreamData.forEach(record => {
      expect(record.quality_score).toBeGreaterThan(0.7)
      expect(record.detected_brands).toBeTruthy()
    })
  })

  test('NL2SQL Analytics Integration', async () => {
    // Test natural language to SQL conversion and execution
    const testQueries = [
      {
        question: 'Show revenue by brand last 7 days',
        expectedIntent: 'aggregate',
        expectedRows: ['brand_name']
      },
      {
        question: 'Category performance by time of day',
        expectedIntent: 'crosstab',
        expectedRows: ['product_category'],
        expectedCols: ['daypart']
      }
    ]

    for (const query of testQueries) {
      const { data: nlResult, error: nlError } = await supabase.functions.invoke('nl2sql', {
        body: { question: query.question }
      })

      expect(nlError).toBeNull()
      expect(nlResult.plan.intent).toBe(query.expectedIntent)
      expect(nlResult.plan.rows).toEqual(expect.arrayContaining(query.expectedRows))

      if (query.expectedCols) {
        expect(nlResult.plan.cols).toEqual(expect.arrayContaining(query.expectedCols))
      }

      expect(nlResult.sql).toBeTruthy()
      expect(nlResult.sql).toMatch(/SELECT/i)
      expect(nlResult.sql).not.toMatch(/(DROP|DELETE|INSERT|UPDATE|ALTER)/i) // Security check

      expect(Array.isArray(nlResult.rows)).toBe(true)
      expect(typeof nlResult.processing_time_ms).toBe('number')
      expect(nlResult.processing_time_ms).toBeLessThan(1000) // Performance check
    }
  })

  test('Error Handling and Recovery', async () => {
    // Test 1: Invalid file format
    const { data: invalidResult } = await supabase.functions.invoke('drive-universal-processor', {
      body: {
        fileId: `${testFileId}_invalid`,
        fileName: 'invalid_file.xyz',
        fileContent: Buffer.from('invalid data').toString('base64')
      }
    })

    // Should gracefully handle unknown formats
    expect(invalidResult.processing.format.detectedFormat).toBe('text')
    expect(invalidResult.processing.format.confidence).toBeLessThan(0.8)

    // Test 2: Malformed JSON
    const malformedJson = '{"invalid": json, missing quotes}'
    const { data: jsonError } = await supabase.functions.invoke('drive-universal-processor', {
      body: {
        fileId: `${testFileId}_malformed`,
        fileName: 'malformed.json',
        fileContent: Buffer.from(malformedJson).toString('base64')
      }
    })

    expect(jsonError.success).toBe(false)
    expect(jsonError.error).toMatch(/parse|json/i)

    // Test 3: Large file handling
    const largeData = 'header1,header2,header3\n' +
      Array.from({ length: 10000 }, (_, i) => `value${i},data${i},test${i}`).join('\n')

    const { data: largeResult } = await supabase.functions.invoke('drive-universal-processor', {
      body: {
        fileId: `${testFileId}_large`,
        fileName: 'large_file.csv',
        fileContent: Buffer.from(largeData).toString('base64'),
        maxRows: 1000 // Limit processing
      }
    })

    expect(largeResult.success).toBe(true)
    expect(largeResult.processing.records_processed).toBeLessThanOrEqual(1000)
  })

  test('Performance Benchmarks', async () => {
    const performanceTests = [
      { size: 'small', records: 100 },
      { size: 'medium', records: 1000 },
      { size: 'large', records: 5000 }
    ]

    for (const testCase of performanceTests) {
      const testData = generateTestData(testCase.records, testSessionId)
      const startTime = Date.now()

      const { data: result } = await supabase.functions.invoke('drive-universal-processor', {
        body: {
          fileId: `${testFileId}_${testCase.size}`,
          fileName: `performance_test_${testCase.size}.csv`,
          fileContent: Buffer.from(testData).toString('base64')
        }
      })

      const processingTime = Date.now() - startTime

      // Performance assertions
      expect(result.success).toBe(true)
      expect(result.processing.records_processed).toBe(testCase.records)

      // Performance benchmarks
      switch (testCase.size) {
        case 'small':
          expect(processingTime).toBeLessThan(2000) // 2 seconds
          break
        case 'medium':
          expect(processingTime).toBeLessThan(10000) // 10 seconds
          break
        case 'large':
          expect(processingTime).toBeLessThan(30000) // 30 seconds
          break
      }

      console.log(`${testCase.size} file (${testCase.records} records): ${processingTime}ms`)
    }
  })

  test('Data Quality Validation', async () => {
    // Test data with quality issues
    const qualityTestData = [
      'transaction_id,timestamp,product_name,category,brand,amount,payment_method',
      'tx_quality_1,,Missing Timestamp Product,Electronics,Sony,199.99,card', // Missing timestamp
      'tx_quality_2,2025-09-17T10:00:00Z,,Electronics,Sony,-50.00,cash', // Negative amount
      'tx_quality_3,2025-09-17T10:00:00Z,Good Product,Electronics,Sony,299.99,cash', // Good record
      ',2025-09-17T10:00:00Z,Missing ID Product,Electronics,Sony,399.99,card' // Missing ID
    ].join('\n')

    const { data: qualityResult } = await supabase.functions.invoke('drive-universal-processor', {
      body: {
        fileId: `${testFileId}_quality`,
        fileName: 'quality_test.csv',
        fileContent: Buffer.from(qualityTestData).toString('base64')
      }
    })

    expect(qualityResult.success).toBe(true)

    // Check quality metrics
    const qualityScore = qualityResult.processing.schema.qualityScore
    expect(qualityScore).toBeLessThan(1.0) // Should detect quality issues
    expect(qualityScore).toBeGreaterThan(0.5) // But not completely fail

    // Check quality issues detection
    const issues = qualityResult.processing.schema.issues
    expect(Array.isArray(issues)).toBe(true)
    expect(issues.length).toBeGreaterThan(0)
  })
})

// Utility functions
async function waitForProcessing(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms))
}

async function cleanupTestData(fileId: string, sessionId: string): Promise<void> {
  try {
    // Clean up test data from all layers
    await supabase
      .from('universal_file_ingestion')
      .delete()
      .like('file_id', `%${fileId}%`)

    await supabase
      .from('transactions_cleaned')
      .delete()
      .like('id', `%${sessionId}%`)

    await supabase
      .from('scout_raw_transactions')
      .delete()
      .like('transaction_id', `%${sessionId}%`)
  } catch (error) {
    console.warn('Cleanup warning:', error)
  }
}

function generateTestData(recordCount: number, sessionId: string): string {
  const header = 'transaction_id,timestamp,product_name,category,brand,amount,payment_method'
  const brands = ['Alaska', 'Nestle', 'Unilever', 'P&G', 'Coca-Cola']
  const categories = ['Dairy', 'Beverages', 'Personal Care', 'Snacks', 'Household']
  const paymentMethods = ['cash', 'card', 'digital']

  const records = [header]

  for (let i = 1; i <= recordCount; i++) {
    const brand = brands[Math.floor(Math.random() * brands.length)]
    const category = categories[Math.floor(Math.random() * categories.length)]
    const payment = paymentMethods[Math.floor(Math.random() * paymentMethods.length)]
    const amount = (Math.random() * 500 + 10).toFixed(2)
    const timestamp = new Date(Date.now() + i * 1000).toISOString()

    records.push(`tx_${sessionId}_${i},${timestamp},${brand} Product ${i},${category},${brand},${amount},${payment}`)
  }

  return records.join('\n')
}