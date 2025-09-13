// Agentic Document Field Extractor
// High-precision extraction for invoices, receipts, forms with ERP integration
// Optimized for Odoo, SAP, QuickBooks, and other accounting systems

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { ZohoIntegration, formatForZohoInvoice, type ZohoConfig } from './zoho-integrations.ts'

interface DocumentField {
  field_name: string
  value: string | number | Date
  confidence: number
  bounding_box?: { x: number, y: number, width: number, height: number }
  data_type: 'text' | 'number' | 'date' | 'currency' | 'email' | 'phone'
  validation_status: 'valid' | 'invalid' | 'needs_review'
}

interface ExtractionResult {
  document_id: string
  document_type: 'invoice' | 'receipt' | 'purchase_order' | 'contract' | 'form'
  vendor_info: {
    name?: string
    address?: string
    tax_id?: string
    email?: string
    phone?: string
  }
  financial_data: {
    total_amount?: number
    subtotal?: number
    tax_amount?: number
    currency?: string
    payment_terms?: string
    due_date?: Date
  }
  line_items: Array<{
    description: string
    quantity?: number
    unit_price?: number
    total?: number
    tax_rate?: number
  }>
  extracted_fields: DocumentField[]
  confidence_score: number
  processing_time_ms: number
  embedding_vector: number[]
  erp_ready: boolean
}

class AgenticExtractor {
  private supabase: any
  private openaiKey: string

  constructor() {
    this.supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
    this.openaiKey = Deno.env.get('OPENAI_API_KEY') ?? ''
  }

  async extractDocumentFields(
    fileBuffer: Uint8Array, 
    fileName: string,
    documentType?: string
  ): Promise<ExtractionResult> {
    const startTime = Date.now()
    
    try {
      // Step 1: OCR Processing with layout analysis
      const ocrResult = await this.performAdvancedOCR(fileBuffer, fileName)
      
      // Step 2: Intelligent document type detection
      const detectedType = documentType || await this.detectDocumentType(ocrResult.text, fileName)
      
      // Step 3: Field extraction using specialized prompts
      const extractedFields = await this.performFieldExtraction(ocrResult, detectedType)
      
      // Step 4: Validate and clean extracted data
      const validatedFields = await this.validateFields(extractedFields, detectedType)
      
      // Step 5: Structure data for ERP systems
      const structuredData = await this.structureForERP(validatedFields, detectedType)
      
      // Step 6: Generate embeddings for semantic search
      const embedding = await this.generateEmbedding(ocrResult.text)
      
      // Step 7: Calculate confidence score
      const confidenceScore = this.calculateConfidenceScore(validatedFields, ocrResult)

      const result: ExtractionResult = {
        document_id: crypto.randomUUID(),
        document_type: detectedType as any,
        vendor_info: structuredData.vendor,
        financial_data: structuredData.financial,
        line_items: structuredData.lineItems,
        extracted_fields: validatedFields,
        confidence_score: confidenceScore,
        processing_time_ms: Date.now() - startTime,
        embedding_vector: embedding,
        erp_ready: confidenceScore > 0.85
      }

      // Store in Supabase for audit and retrieval
      await this.storeExtractionResult(result, fileBuffer)
      
      return result

    } catch (error) {
      throw new Error(`Extraction failed: ${error.message}`)
    }
  }

  private async performAdvancedOCR(fileBuffer: Uint8Array, fileName: string) {
    // Use existing ocr-parser function or implement advanced OCR
    const formData = new FormData()
    formData.append('file', new Blob([fileBuffer]), fileName)

    const response = await fetch(
      `${Deno.env.get('SUPABASE_URL')}/functions/v1/ocr-parser`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${Deno.env.get('SUPABASE_ANON_KEY')}`
        },
        body: formData
      }
    )

    if (!response.ok) {
      throw new Error(`OCR failed: ${response.statusText}`)
    }

    return await response.json()
  }

  private async detectDocumentType(text: string, fileName: string): Promise<string> {
    const prompt = `
Analyze this document text and filename to determine the document type.
Return ONLY one of: invoice, receipt, purchase_order, contract, form

Text: ${text.substring(0, 1000)}
Filename: ${fileName}

Document type:`

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.openaiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'gpt-4-turbo-preview',
        messages: [{ role: 'user', content: prompt }],
        max_tokens: 10,
        temperature: 0.1
      })
    })

    const result = await response.json()
    return result.choices[0].message.content.trim().toLowerCase()
  }

  private async performFieldExtraction(ocrResult: any, documentType: string): Promise<DocumentField[]> {
    const extractionPrompts = {
      invoice: `
Extract these fields from the invoice text with high precision:
- vendor_name: Company issuing the invoice
- vendor_address: Full address of vendor
- vendor_tax_id: Tax ID/VAT number
- invoice_number: Invoice reference number
- invoice_date: Date of invoice
- due_date: Payment due date
- subtotal: Amount before tax
- tax_amount: Tax/VAT amount
- total_amount: Total amount due
- currency: Currency code (PHP, USD, EUR, etc.)
- payment_terms: Payment terms/conditions

For each field, provide:
1. field_name
2. value (exact as found)
3. confidence (0-1)
4. data_type

Return as JSON array.`,

      receipt: `
Extract these fields from the receipt text:
- merchant_name: Store/business name
- merchant_address: Business address
- receipt_number: Receipt/transaction number
- date: Transaction date
- time: Transaction time
- total_amount: Total paid
- tax_amount: Tax amount if shown
- payment_method: Cash, card, etc.
- cashier: Cashier name/ID if shown

Return as JSON array with field_name, value, confidence, data_type.`,

      purchase_order: `
Extract these fields from the purchase order:
- po_number: Purchase order number
- vendor_name: Supplier name
- buyer_name: Purchasing company
- po_date: Order date
- delivery_date: Required delivery date
- total_amount: Total order value
- currency: Currency code
- shipping_address: Delivery address
- payment_terms: Payment terms

Return as JSON array with field_name, value, confidence, data_type.`
    }

    const prompt = extractionPrompts[documentType] || extractionPrompts.invoice
    const fullPrompt = `${prompt}\n\nDocument text:\n${ocrResult.text}`

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.openaiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'gpt-4-turbo-preview',
        messages: [{ role: 'user', content: fullPrompt }],
        max_tokens: 2000,
        temperature: 0.1
      })
    })

    const result = await response.json()
    
    try {
      const extracted = JSON.parse(result.choices[0].message.content)
      return extracted.map((field: any) => ({
        ...field,
        validation_status: 'needs_review' as const
      }))
    } catch (e) {
      console.error('Failed to parse extraction result:', e)
      return []
    }
  }

  private async validateFields(fields: DocumentField[], documentType: string): Promise<DocumentField[]> {
    return fields.map(field => {
      let isValid = true
      let cleanedValue = field.value

      switch (field.data_type) {
        case 'currency':
        case 'number':
          // Clean and validate numeric values
          const numStr = String(field.value).replace(/[^\d.,\-]/g, '')
          const num = parseFloat(numStr.replace(',', ''))
          if (!isNaN(num)) {
            cleanedValue = num
          } else {
            isValid = false
          }
          break

        case 'date':
          // Parse and validate dates
          const date = new Date(String(field.value))
          if (date.getTime()) {
            cleanedValue = date
          } else {
            isValid = false
          }
          break

        case 'email':
          // Validate email format
          const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
          isValid = emailRegex.test(String(field.value))
          break

        case 'phone':
          // Clean phone numbers
          cleanedValue = String(field.value).replace(/[^\d+\-\s\(\)]/g, '')
          break
      }

      return {
        ...field,
        value: cleanedValue,
        validation_status: isValid && field.confidence > 0.7 ? 'valid' : 
                         isValid ? 'needs_review' : 'invalid'
      }
    })
  }

  private async structureForERP(fields: DocumentField[], documentType: string) {
    const fieldMap = new Map(fields.map(f => [f.field_name, f.value]))

    return {
      vendor: {
        name: fieldMap.get('vendor_name') || fieldMap.get('merchant_name'),
        address: fieldMap.get('vendor_address') || fieldMap.get('merchant_address'),
        tax_id: fieldMap.get('vendor_tax_id'),
        email: fieldMap.get('vendor_email'),
        phone: fieldMap.get('vendor_phone')
      },
      financial: {
        total_amount: fieldMap.get('total_amount'),
        subtotal: fieldMap.get('subtotal'),
        tax_amount: fieldMap.get('tax_amount'),
        currency: fieldMap.get('currency') || 'PHP',
        payment_terms: fieldMap.get('payment_terms'),
        due_date: fieldMap.get('due_date')
      },
      lineItems: this.extractLineItems(fields)
    }
  }

  private extractLineItems(fields: DocumentField[]) {
    // Extract line items from fields
    // This would be more sophisticated in production
    return []
  }

  private async generateEmbedding(text: string): Promise<number[]> {
    const response = await fetch('https://api.openai.com/v1/embeddings', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.openaiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'text-embedding-3-small',
        input: text.substring(0, 8000) // Limit input size
      })
    })

    const result = await response.json()
    return result.data[0].embedding
  }

  private calculateConfidenceScore(fields: DocumentField[], ocrResult: any): number {
    if (fields.length === 0) return 0

    const validFields = fields.filter(f => f.validation_status === 'valid')
    const avgConfidence = fields.reduce((sum, f) => sum + f.confidence, 0) / fields.length
    const validityRatio = validFields.length / fields.length

    // Weight: 60% field confidence, 40% validity ratio
    return (avgConfidence * 0.6) + (validityRatio * 0.4)
  }

  private async storeExtractionResult(result: ExtractionResult, fileBuffer: Uint8Array) {
    // Store extraction result in Supabase
    const { error } = await this.supabase
      .from('document_extractions')
      .insert({
        document_id: result.document_id,
        document_type: result.document_type,
        vendor_info: result.vendor_info,
        financial_data: result.financial_data,
        line_items: result.line_items,
        extracted_fields: result.extracted_fields,
        confidence_score: result.confidence_score,
        processing_time_ms: result.processing_time_ms,
        embedding: result.embedding_vector,
        erp_ready: result.erp_ready,
        created_at: new Date()
      })

    if (error) {
      console.error('Failed to store extraction result:', error)
    }

    // Store file in Supabase Storage
    await this.supabase.storage
      .from('documents')
      .upload(`extractions/${result.document_id}.pdf`, fileBuffer)
  }

  // ERP Integration Methods
  async pushToOdoo(extractionResult: ExtractionResult, odooConfig: any) {
    if (!extractionResult.erp_ready) {
      throw new Error('Document not ready for ERP integration')
    }

    const odooData = this.formatForOdoo(extractionResult)
    
    const response = await fetch(`${odooConfig.url}/api/v1/invoices`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${odooConfig.token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(odooData)
    })

    return response.json()
  }

  async pushToZoho(extractionResult: ExtractionResult, zohoConfig: ZohoConfig) {
    if (!extractionResult.erp_ready) {
      throw new Error('Document not ready for Zoho integration')
    }

    const zohoIntegration = new ZohoIntegration(zohoConfig)
    
    try {
      // Process different document types with Zoho workflow
      const result = await zohoIntegration.processDocumentWorkflow(
        extractionResult, 
        extractionResult.document_type
      )

      // Log the integration in our audit trail
      await this.supabase
        .from('extraction_audit_log')
        .insert({
          extraction_id: extractionResult.document_id,
          action: 'zoho_integration',
          details: {
            zoho_result: result,
            document_type: extractionResult.document_type,
            confidence_score: extractionResult.confidence_score
          },
          system_component: 'zoho_integration'
        })

      return result
    } catch (error) {
      console.error('Zoho integration failed:', error)
      
      // Log the error
      await this.supabase
        .from('extraction_audit_log')
        .insert({
          extraction_id: extractionResult.document_id,
          action: 'zoho_integration_failed',
          details: {
            error: error.message,
            document_type: extractionResult.document_type
          },
          system_component: 'zoho_integration'
        })

      throw error
    }
  }

  async pushToQuickBooks(extractionResult: ExtractionResult, qbConfig: any) {
    const qbData = this.formatForQuickBooks(extractionResult)
    
    const response = await fetch(`${qbConfig.baseUrl}/v3/company/${qbConfig.companyId}/bill`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${qbConfig.accessToken}`,
        'Accept': 'application/json',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(qbData)
    })

    return response.json()
  }

  private formatForOdoo(result: ExtractionResult) {
    return {
      partner_name: result.vendor_info.name,
      invoice_date: result.financial_data.due_date,
      amount_total: result.financial_data.total_amount,
      currency_id: result.financial_data.currency,
      invoice_line_ids: result.line_items.map(item => ({
        name: item.description,
        quantity: item.quantity || 1,
        price_unit: item.unit_price || item.total
      }))
    }
  }

  private formatForQuickBooks(result: ExtractionResult) {
    return {
      VendorRef: { name: result.vendor_info.name },
      TxnDate: result.financial_data.due_date,
      TotalAmt: result.financial_data.total_amount,
      Line: result.line_items.map((item, index) => ({
        Id: String(index + 1),
        Amount: item.total || item.unit_price,
        DetailType: "ItemBasedExpenseLineDetail",
        ItemBasedExpenseLineDetail: {
          ItemRef: { name: item.description },
          Qty: item.quantity || 1,
          UnitPrice: item.unit_price
        }
      }))
    }
  }
}

serve(async (req) => {
  try {
    if (req.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 })
    }

    const formData = await req.formData()
    const file = formData.get('file') as File
    const documentType = formData.get('document_type') as string
    const erpSystem = formData.get('erp_system') as string
    const erpConfig = formData.get('erp_config') as string

    if (!file) {
      return new Response('No file provided', { status: 400 })
    }

    const fileBuffer = new Uint8Array(await file.arrayBuffer())
    const extractor = new AgenticExtractor()
    
    const result = await extractor.extractDocumentFields(
      fileBuffer,
      file.name,
      documentType
    )

    // Optional: Push to ERP/Business system
    if (erpSystem && erpConfig && result.erp_ready) {
      const config = JSON.parse(erpConfig)
      
      if (erpSystem === 'odoo') {
        const erpResult = await extractor.pushToOdoo(result, config)
        result.erp_integrations = [{ system: 'odoo', result: erpResult, timestamp: new Date() }]
      } else if (erpSystem === 'quickbooks') {
        const erpResult = await extractor.pushToQuickBooks(result, config)
        result.erp_integrations = [{ system: 'quickbooks', result: erpResult, timestamp: new Date() }]
      } else if (erpSystem === 'zoho') {
        const zohoResult = await extractor.pushToZoho(result, config)
        result.erp_integrations = [{ system: 'zoho', result: zohoResult, timestamp: new Date() }]
      }
    }

    return new Response(JSON.stringify(result), {
      headers: { 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('Extraction error:', error)
    return new Response(
      JSON.stringify({ error: error.message }), 
      { 
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      }
    )
  }
})