// Unified Sari-Sari Expert Bot - Consolidated from 3 variants
// Real-time Philippine Retail Analytics with configurable modes
// Powered by Groq for ultra-fast inference + Claude fallback
// Integrates Project Scout transaction data + baseline inference

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Configuration flags for different modes
interface ExpertConfig {
  mode: 'basic' | 'enhanced' | 'advanced'
  use_groq?: boolean
  use_claude_fallback?: boolean
  include_real_data?: boolean
  confidence_threshold?: number
}

interface UnifiedQuery {
  query?: string
  payment_amount?: number
  change_given?: number
  time_of_day?: string
  customer_behavior?: string
  visible_products?: string[]
  filters?: {
    store_type?: string[]
    region?: string[]
    date_range?: {
      start: string
      end: string
    }
    brands?: string[]
    min_amount?: number
    max_amount?: number
  }
  include_data?: boolean
  stream?: boolean
  config?: ExpertConfig
  account_id?: string
  store_id?: string
}

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

// Expert System Prompts by Mode
const EXPERT_PROMPTS = {
  basic: `You are an expert on Philippine sari-sari stores and retail analytics. You have deep knowledge of:

1. **Sari-Sari Store Operations**: Inventory management, cash flow, customer relationships, credit systems (utang), pricing strategies
2. **Philippine Retail Market**: FMCG trends, brand preferences, regional differences, seasonal patterns
3. **TBWA Client Products**: Alaska, Oishi, Champion, Del Monte, Winston performance in sari-sari stores
4. **Local Consumer Behavior**: Tingi culture, brand loyalty, price sensitivity, payment preferences (cash, GCash, utang)
5. **Business Insights**: Profit margins, fast-moving items, slow movers, optimal product mix

Always consider the Filipino context: barangay dynamics, suki relationships, and local preferences.`,

  enhanced: `You are an expert on Philippine sari-sari stores with access to REAL data from 18,000+ transactions. You analyze:

1. **Real Transaction Patterns**: Actual purchase behaviors, basket compositions, payment methods
2. **Filipino Cultural Context**: Real customer phrases like "Pabili po", "May stock po ba?", politeness markers
3. **Buyer Personas from Real Data**:
   - Juan (Rural Male Worker): Yosi, softdrinks, cash payments
   - Maria (Urban Housewife): Family items, cooking ingredients, GCash user
   - Carlo (Young Professional): Energy drinks, digital payments
   - Lola Rosa (Elderly): Small purchases, always cash
4. **Substitution Patterns**: Real success rates when products are out of stock
5. **TBWA Brand Performance**: Actual market share vs competitors from real data

You provide insights based on REAL data, not theoretical assumptions.`,

  advanced: `You are a sari-sari retail analyst. Provide concise, actionable answers with ROI-ranked recommendations.`
}

// Baseline inference for advanced mode
function baselineInference(inp: UnifiedQuery) {
  const total_spent = Number(((inp.payment_amount || 0) - (inp.change_given || 0)).toFixed(2))
  const hints = (inp.visible_products || []).join(", ").toLowerCase() + " " + (inp.customer_behavior || "").toLowerCase()
  const likely_products = []
  
  if (hints.includes("coke")) likely_products.push("Coke Zero 500ml")
  if (hints.includes("cigarette") || hints.includes("yosi")) likely_products.push("Marlboro Lights stick")
  
  const confidence = likely_products.length ? 0.78 : 0.6
  const persona = hints.includes("male") ? "Juan - Rural Male Worker" : "Maria - Urban Housewife"
  const persona_conf = hints.includes("male") ? 0.82 : 0.7
  const recs = [{ 
    title: "Move cigarettes near Coke Zero", 
    revenue_potential: 450, 
    roi: "173%", 
    timeline: "immediate" 
  }]
  
  return {
    inferred_transaction: { total_spent, likely_products, confidence_score: confidence },
    persona_analysis: { persona, confidence: persona_conf },
    recommendations: recs
  }
}

// Get real transaction context for enhanced mode
async function getRealTransactionContext(filters: UnifiedQuery['filters'], spent_amount?: number) {
  let query = supabase
    .from('scout_transactions')
    .select(`
      transaction_id,
      transaction_date,
      total_amount,
      payment_method,
      store:master_stores!inner(
        store_name,
        store_type,
        city,
        region
      ),
      items:scout_transaction_items!inner(
        quantity,
        unit_price,
        brand:master_brands!inner(
          brand_name,
          is_tbwa_client
        )
      )
    `)
    .order('transaction_date', { ascending: false })
    .limit(50)

  // Filter by amount range if inferring transaction
  if (spent_amount !== undefined) {
    query = query
      .gte('total_amount', spent_amount - 5)
      .lte('total_amount', spent_amount + 5)
  }

  // Apply filters
  if (filters?.store_type?.length) {
    query = query.in('store.store_type', filters.store_type)
  }

  if (filters?.region?.length) {
    query = query.in('store.region', filters.region)
  }

  if (filters?.date_range) {
    query = query
      .gte('transaction_date', filters.date_range.start)
      .lte('transaction_date', filters.date_range.end)
  }

  if (filters?.min_amount) {
    query = query.gte('total_amount', filters.min_amount)
  }

  if (filters?.max_amount) {
    query = query.lte('total_amount', filters.max_amount)
  }

  const { data, error } = await query

  if (error) throw error
  return data
}

// Get aggregated insights
async function getAggregatedInsights(filters: UnifiedQuery['filters']) {
  // Top selling products
  const { data: topProducts } = await supabase
    .from('scout_transaction_items')
    .select(`
      brand:master_brands!inner(brand_name, is_tbwa_client),
      quantity,
      unit_price
    `)
    .limit(100)

  // Payment method distribution
  const { data: paymentMethods } = await supabase
    .from('scout_transactions')
    .select('payment_method')
    .limit(100)

  // Store performance
  const { data: storePerformance } = await supabase
    .from('scout_transactions')
    .select(`
      total_amount,
      store:master_stores!inner(store_type, region)
    `)
    .limit(100)

  return {
    topProducts: summarizeProducts(topProducts || []),
    paymentTrends: summarizePayments(paymentMethods || []),
    storeInsights: summarizeStores(storePerformance || [])
  }
}

function summarizeProducts(products: any[]) {
  const brandCounts = products.reduce((acc, item) => {
    const brand = item.brand?.brand_name || 'Unknown'
    acc[brand] = (acc[brand] || 0) + item.quantity
    return acc
  }, {})

  return Object.entries(brandCounts)
    .sort(([, a], [, b]) => (b as number) - (a as number))
    .slice(0, 5)
    .map(([brand, count]) => ({ brand, units_sold: count }))
}

function summarizePayments(payments: any[]) {
  const methodCounts = payments.reduce((acc, item) => {
    acc[item.payment_method] = (acc[item.payment_method] || 0) + 1
    return acc
  }, {})

  return methodCounts
}

function summarizeStores(stores: any[]) {
  const avgByType = stores.reduce((acc, item) => {
    const type = item.store?.store_type || 'unknown'
    if (!acc[type]) acc[type] = { total: 0, count: 0 }
    acc[type].total += item.total_amount
    acc[type].count += 1
    return acc
  }, {})

  return Object.entries(avgByType).map(([type, data]: [string, any]) => ({
    store_type: type,
    avg_transaction: (data.total / data.count).toFixed(2)
  }))
}

// Format context for LLM
function formatContextForLLM(transactions: any[], insights: any, mode: string) {
  if (mode === 'advanced') {
    return '' // Advanced mode uses minimal context
  }

  return `
CURRENT MARKET DATA:

Recent Transactions (Last 50):
- Total Value: ₱${transactions.reduce((sum, t) => sum + t.total_amount, 0).toFixed(2)}
- Average Basket: ₱${(transactions.reduce((sum, t) => sum + t.total_amount, 0) / transactions.length).toFixed(2)}
- Payment Methods: ${JSON.stringify(insights.paymentTrends)}

Top Products:
${insights.topProducts.map((p: any) => `- ${p.brand}: ${p.units_sold} units`).join('\n')}

Store Performance by Type:
${insights.storeInsights.map((s: any) => `- ${s.store_type}: ₱${s.avg_transaction} avg`).join('\n')}

TBWA vs Competitor Split:
- TBWA Brands: ${transactions.filter(t => t.items.some((i: any) => i.brand?.is_tbwa_client)).length} transactions
- Competitor Brands: ${transactions.filter(t => t.items.every((i: any) => !i.brand?.is_tbwa_client)).length} transactions
`
}

// Claude fallback for advanced mode
async function claudeFallback(inp: UnifiedQuery, partial: any) {
  const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") || ""
  if (!ANTHROPIC_API_KEY) return partial

  const system = EXPERT_PROMPTS.advanced
  const user = `Given:
  - ₱${inp.payment_amount} payment, ₱${inp.change_given} change
  - Time: ${inp.time_of_day}
  - Behavior: ${inp.customer_behavior || "n/a"}
  - Visible: ${(inp.visible_products || []).join(", ") || "n/a"}
  Infer products, persona, and a single ROI-ranked recommendation.`

  const body = {
    model: "claude-3-5-sonnet-latest",
    max_tokens: 600,
    system,
    messages: [{ role: "user", content: user }]
  }

  const resp = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": ANTHROPIC_API_KEY,
      "anthropic-version": Deno.env.get("CLAUDE_VERSION") || "2023-06-01"
    },
    body: JSON.stringify(body)
  })

  if (!resp.ok) return partial
  const data = await resp.json()
  const text = (data?.content?.[0]?.text || "").toLowerCase()

  const out = { ...partial }
  if (text.includes("marlboro") && !out.inferred_transaction.likely_products.includes("Marlboro Lights stick")) {
    out.inferred_transaction.likely_products.push("Marlboro Lights stick")
  }
  out.inferred_transaction.confidence_score = Math.max(out.inferred_transaction.confidence_score, 0.8)
  return out
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const query: UnifiedQuery = await req.json()
    const config = query.config || { mode: 'basic' }

    // Advanced mode: baseline + Claude fallback
    if (config.mode === 'advanced') {
      const partial = baselineInference(query)
      
      let finalResult = partial
      if (config.use_claude_fallback !== false) {
        finalResult = await claudeFallback(query, partial)
      }

      // Write to Scout tables if in advanced mode
      if (query.store_id) {
        await supabase.from('scout_interactions').insert({
          store_id: query.store_id,
          account_id: query.account_id,
          query_type: 'inference',
          input_data: query,
          result_data: finalResult,
          confidence_score: finalResult.inferred_transaction.confidence_score
        })
      }

      return new Response(JSON.stringify({
        success: true,
        mode: 'advanced',
        result: finalResult
      }), { 
        headers: { 
          ...corsHeaders, 
          'Content-Type': 'application/json' 
        } 
      })
    }

    // Enhanced/Basic mode: Use real data + Groq/Claude
    let transactions = []
    let insights = {}
    let context = ''

    if (config.include_real_data !== false && config.mode !== 'advanced') {
      const spent_amount = query.payment_amount && query.change_given 
        ? query.payment_amount - query.change_given 
        : undefined

      transactions = await getRealTransactionContext(query.filters, spent_amount)
      insights = await getAggregatedInsights(query.filters)
      context = formatContextForLLM(transactions, insights, config.mode)
    }

    // Prepare messages for AI inference
    const systemPrompt = EXPERT_PROMPTS[config.mode] || EXPERT_PROMPTS.basic
    const userQuery = query.query || `Analyze transaction: ₱${query.payment_amount} payment, ₱${query.change_given} change at ${query.time_of_day}`
    
    const messages = [
      {
        role: 'system',
        content: systemPrompt
      },
      {
        role: 'user',
        content: `${userQuery}\n\nCONTEXT:\n${context}`
      }
    ]

    let answer = ''
    let usage = {}

    // Use Groq for ultra-fast inference (enhanced/basic modes)
    if (config.use_groq !== false && config.mode !== 'advanced') {
      const groqResponse = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${Deno.env.get('GROQ_API_KEY')}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: 'mixtral-8x7b-32768',
          messages: messages,
          temperature: 0.7,
          max_tokens: 1000,
          stream: query.stream || false
        }),
      })

      if (groqResponse.ok) {
        if (query.stream) {
          return new Response(groqResponse.body, {
            headers: {
              ...corsHeaders,
              'Content-Type': 'text/event-stream',
              'Cache-Control': 'no-cache',
              'Connection': 'keep-alive'
            }
          })
        }

        const result = await groqResponse.json()
        answer = result.choices?.[0]?.message?.content || 'No response generated'
        usage = result.usage || {}
      }
    }

    // Claude fallback if Groq failed or disabled
    if (!answer && config.use_claude_fallback !== false) {
      const claudeResponse = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': Deno.env.get('ANTHROPIC_API_KEY') || '',
          'anthropic-version': '2023-06-01'
        },
        body: JSON.stringify({
          model: 'claude-3-5-sonnet-latest',
          max_tokens: 1000,
          messages: messages
        })
      })

      if (claudeResponse.ok) {
        const result = await claudeResponse.json()
        answer = result.content?.[0]?.text || 'No response generated'
        usage = result.usage || {}
      }
    }

    // Log the query
    await supabase
      .from('sari_sari_queries')
      .insert({
        query: userQuery,
        filters: query.filters,
        response: answer,
        transaction_count: transactions.length,
        response_time_ms: usage.total_time || 0,
        mode: config.mode
      })

    return new Response(
      JSON.stringify({
        success: true,
        mode: config.mode,
        answer,
        context: {
          transactions_analyzed: transactions.length,
          insights: insights,
          filters_applied: query.filters
        },
        usage
      }),
      { 
        headers: { 
          ...corsHeaders, 
          'Content-Type': 'application/json' 
        } 
      }
    )

  } catch (error) {
    console.error('Unified Sari-Sari Expert error:', error)
    
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      { 
        status: 500,
        headers: { 
          ...corsHeaders, 
          'Content-Type': 'application/json' 
        } 
      }
    )
  }
})

// Deploy with:
// supabase functions deploy sari-sari-expert-unified
// supabase secrets set GROQ_API_KEY=gsk_...
// supabase secrets set ANTHROPIC_API_KEY=sk-...