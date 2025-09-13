// Zoho Ecosystem Integration for Agentic Document Extractor
// Supports Zoho Invoice, Books, CRM, Expense, and Inventory

export interface ZohoConfig {
  client_id: string
  client_secret: string
  refresh_token: string
  organization_id?: string
  region: 'com' | 'eu' | 'in' | 'au' | 'jp'
}

export interface ZohoInvoiceData {
  customer_name: string
  customer_id?: string
  invoice_number?: string
  date: string
  due_date?: string
  line_items: Array<{
    item_id?: string
    name: string
    description?: string
    quantity: number
    rate: number
    tax_id?: string
  }>
  discount?: number
  adjustment?: number
  notes?: string
  terms?: string
  template_id?: string
}

export class ZohoIntegration {
  private config: ZohoConfig
  private accessToken: string | null = null
  private tokenExpiry: Date | null = null

  constructor(config: ZohoConfig) {
    this.config = config
  }

  private getBaseUrl(): string {
    const regionMap = {
      'com': 'https://www.zohoapis.com',
      'eu': 'https://www.zohoapis.eu', 
      'in': 'https://www.zohoapis.in',
      'au': 'https://www.zohoapis.com.au',
      'jp': 'https://www.zohoapis.jp'
    }
    return regionMap[this.config.region] || regionMap['com']
  }

  private async refreshAccessToken(): Promise<string> {
    const response = await fetch('https://accounts.zoho.com/oauth/v2/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: new URLSearchParams({
        refresh_token: this.config.refresh_token,
        client_id: this.config.client_id,
        client_secret: this.config.client_secret,
        grant_type: 'refresh_token'
      })
    })

    const data = await response.json()
    
    if (!response.ok) {
      throw new Error(`Zoho token refresh failed: ${data.error}`)
    }

    this.accessToken = data.access_token
    this.tokenExpiry = new Date(Date.now() + (data.expires_in * 1000))
    
    return this.accessToken
  }

  private async getAccessToken(): Promise<string> {
    if (!this.accessToken || !this.tokenExpiry || new Date() >= this.tokenExpiry) {
      return await this.refreshAccessToken()
    }
    return this.accessToken
  }

  private async makeZohoRequest(endpoint: string, method: string = 'GET', body?: any): Promise<any> {
    const token = await this.getAccessToken()
    const url = `${this.getBaseUrl()}${endpoint}`
    
    const headers: HeadersInit = {
      'Authorization': `Zoho-oauthtoken ${token}`,
      'Content-Type': 'application/json'
    }

    if (this.config.organization_id) {
      headers['X-com-zoho-invoice-organizationid'] = this.config.organization_id
    }

    const response = await fetch(url, {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined
    })

    const data = await response.json()
    
    if (!response.ok) {
      throw new Error(`Zoho API error: ${data.message || response.statusText}`)
    }

    return data
  }

  // ZOHO INVOICE INTEGRATION
  async createInvoice(invoiceData: ZohoInvoiceData): Promise<any> {
    // First, ensure customer exists
    const customer = await this.findOrCreateCustomer(invoiceData.customer_name)
    
    const invoicePayload = {
      customer_id: customer.customer_id,
      invoice_number: invoiceData.invoice_number,
      date: invoiceData.date,
      due_date: invoiceData.due_date,
      line_items: invoiceData.line_items.map(item => ({
        item_id: item.item_id,
        name: item.name,
        description: item.description || item.name,
        quantity: item.quantity,
        rate: item.rate,
        tax_id: item.tax_id
      })),
      discount: invoiceData.discount || 0,
      adjustment: invoiceData.adjustment || 0,
      notes: invoiceData.notes || '',
      terms: invoiceData.terms || '',
      template_id: invoiceData.template_id
    }

    return await this.makeZohoRequest('/invoice/v3/invoices', 'POST', invoicePayload)
  }

  async findOrCreateCustomer(customerName: string, customerData?: any): Promise<any> {
    // Search for existing customer
    try {
      const searchResponse = await this.makeZohoRequest(
        `/invoice/v3/contacts?contact_name=${encodeURIComponent(customerName)}`
      )
      
      if (searchResponse.contacts && searchResponse.contacts.length > 0) {
        return searchResponse.contacts[0]
      }
    } catch (error) {
      console.log('Customer search failed, will create new:', error)
    }

    // Create new customer
    const customerPayload = {
      contact_name: customerName,
      contact_type: 'customer',
      ...customerData
    }

    const createResponse = await this.makeZohoRequest('/invoice/v3/contacts', 'POST', customerPayload)
    return createResponse.contact
  }

  async createItem(itemData: { name: string, rate: number, description?: string }): Promise<any> {
    const itemPayload = {
      name: itemData.name,
      rate: itemData.rate,
      description: itemData.description || itemData.name,
      account_id: '460000000000318003' // Default sales account
    }

    return await this.makeZohoRequest('/invoice/v3/items', 'POST', itemPayload)
  }

  // ZOHO BOOKS INTEGRATION  
  async createBill(billData: any): Promise<any> {
    return await this.makeZohoRequest('/books/v3/bills', 'POST', billData)
  }

  async createExpense(expenseData: any): Promise<any> {
    return await this.makeZohoRequest('/books/v3/expenses', 'POST', expenseData)
  }

  // ZOHO CRM INTEGRATION
  async createLead(leadData: any): Promise<any> {
    const crmPayload = {
      data: [leadData],
      trigger: ['approval', 'workflow', 'blueprint']
    }
    
    return await this.makeZohoRequest('/crm/v2/Leads', 'POST', crmPayload)
  }

  async createContact(contactData: any): Promise<any> {
    const crmPayload = {
      data: [contactData],
      trigger: ['approval', 'workflow', 'blueprint']
    }
    
    return await this.makeZohoRequest('/crm/v2/Contacts', 'POST', crmPayload)
  }

  // ZOHO EXPENSE INTEGRATION
  async submitExpense(expenseData: any): Promise<any> {
    return await this.makeZohoRequest('/expense/v1/expenses', 'POST', expenseData)
  }

  // ZOHO INVENTORY INTEGRATION
  async updateInventory(itemId: string, quantity: number): Promise<any> {
    const inventoryPayload = {
      quantity_on_hand: quantity
    }
    
    return await this.makeZohoRequest(`/inventory/v1/items/${itemId}`, 'PUT', inventoryPayload)
  }

  // WORKFLOW AUTOMATION
  async processDocumentWorkflow(extractedData: any, documentType: string): Promise<any> {
    const results: any = {}

    try {
      switch (documentType) {
        case 'invoice':
          // Create invoice in Zoho Invoice
          const invoice = await this.createInvoice({
            customer_name: extractedData.vendor_info.name,
            date: extractedData.financial_data.due_date || new Date().toISOString().split('T')[0],
            due_date: extractedData.financial_data.due_date,
            line_items: extractedData.line_items.map((item: any) => ({
              name: item.description,
              quantity: item.quantity || 1,
              rate: item.unit_price || item.total
            }))
          })
          results.zoho_invoice = invoice

          // Create contact in CRM if new vendor
          const crmContact = await this.createContact({
            Last_Name: extractedData.vendor_info.name,
            Email: extractedData.vendor_info.email,
            Phone: extractedData.vendor_info.phone,
            Mailing_Street: extractedData.vendor_info.address
          })
          results.zoho_crm = crmContact
          break

        case 'receipt':
          // Submit as expense in Zoho Expense
          const expense = await this.submitExpense({
            date: extractedData.financial_data.due_date || new Date().toISOString().split('T')[0],
            merchant: extractedData.vendor_info.name,
            amount: extractedData.financial_data.total_amount,
            description: 'Auto-extracted from receipt',
            category_id: '460000000000318007' // Default category
          })
          results.zoho_expense = expense
          break

        case 'purchase_order':
          // Create bill in Zoho Books
          const bill = await this.createBill({
            vendor_name: extractedData.vendor_info.name,
            date: extractedData.financial_data.due_date,
            line_items: extractedData.line_items
          })
          results.zoho_books = bill
          break
      }

      return results
    } catch (error) {
      console.error('Zoho workflow processing failed:', error)
      throw error
    }
  }
}

// Helper function to format extraction data for Zoho
export function formatForZohoInvoice(extractedData: any): ZohoInvoiceData {
  return {
    customer_name: extractedData.vendor_info.name || 'Unknown Customer',
    invoice_number: extractedData.extracted_fields.find((f: any) => f.field_name === 'invoice_number')?.value,
    date: extractedData.financial_data.due_date || new Date().toISOString().split('T')[0],
    due_date: extractedData.financial_data.due_date,
    line_items: extractedData.line_items.map((item: any) => ({
      name: item.description || 'Service',
      quantity: item.quantity || 1,
      rate: item.unit_price || item.total || 0,
      description: item.description
    })),
    notes: `Auto-generated from extracted document. Confidence: ${(extractedData.confidence_score * 100).toFixed(1)}%`,
    terms: extractedData.financial_data.payment_terms || 'Net 30'
  }
}

// Configuration helper for different Zoho regions
export const ZOHO_REGIONS = {
  GLOBAL: 'com',
  EUROPE: 'eu', 
  INDIA: 'in',
  AUSTRALIA: 'au',
  JAPAN: 'jp'
} as const

// Default Zoho API scopes needed
export const REQUIRED_SCOPES = [
  'ZohoInvoice.invoices.CREATE',
  'ZohoInvoice.contacts.CREATE',
  'ZohoInvoice.items.CREATE',
  'ZohoBooks.bills.CREATE',
  'ZohoBooks.expenses.CREATE',
  'ZohoCRM.modules.leads.CREATE',
  'ZohoCRM.modules.contacts.CREATE',
  'ZohoExpense.expenses.CREATE',
  'ZohoInventory.items.UPDATE'
]