/**
 * NarrativeAgent - Business Intelligence Storytelling
 * Scout v7.1 Agentic Analytics Platform
 * 
 * Generates executive summaries and business intelligence narratives,
 * transforming data insights into actionable business stories with
 * multilingual support and competitive intelligence integration.
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import OpenAI from 'https://esm.sh/openai@4.0.0'

// =============================================================================
// TYPES & INTERFACES
// =============================================================================

interface NarrativeAgentRequest {
  data_insights: DataInsight[]
  chart_context?: ChartSpecification[]
  narrative_style: {
    audience: 'executive' | 'analyst' | 'store_manager'
    tone: 'formal' | 'conversational' | 'urgent'
    length: 'brief' | 'standard' | 'detailed'
    language: 'en' | 'fil'
  }
  business_context: {
    current_period: DateRange
    comparison_period?: DateRange
    strategic_focus?: string[]
  }
  user_context: {
    tenant_id: string
    role: 'executive' | 'store_manager' | 'analyst'
  }
}

interface NarrativeAgentResponse {
  executive_summary: NarrativeBlock
  key_insights: InsightBlock[]
  actionable_recommendations: Recommendation[]
  competitive_intelligence: CompetitiveInsight[]
  narrative_metadata: {
    confidence_level: number
    data_coverage: number
    insight_quality: 'high' | 'medium' | 'low'
    processing_time_ms: number
    language_detected: string
    tone_consistency: number
  }
}

interface DataInsight {
  type: 'trend' | 'anomaly' | 'correlation' | 'ranking' | 'performance'
  title: string
  description: string
  confidence: number
  impact_level: 'high' | 'medium' | 'low'
  data_source: string
  metrics: {
    primary_value: number | string
    secondary_value?: number | string
    change_percentage?: number
    trend_direction?: 'up' | 'down' | 'stable'
  }
  context: {
    time_period: string
    entities: string[]
    dimensions: string[]
  }
}

interface ChartSpecification {
  chart_type: string
  title: string
  key_metrics: string[]
  insights: string[]
}

interface NarrativeBlock {
  title: string
  content: string
  key_points: string[]
  call_to_action?: string
  reading_time_minutes: number
}

interface InsightBlock {
  headline: string
  description: string
  supporting_data: string[]
  business_impact: string
  priority: 'high' | 'medium' | 'low'
  categories: string[]
}

interface Recommendation {
  title: string
  description: string
  rationale: string
  priority: 'critical' | 'high' | 'medium' | 'low'
  effort_level: 'low' | 'medium' | 'high'
  timeline: string
  expected_impact: string
  success_metrics: string[]
  responsible_parties: string[]
}

interface CompetitiveInsight {
  competitor: string
  insight_type: 'market_share' | 'pricing' | 'product_launch' | 'performance'
  summary: string
  business_implications: string
  recommended_response: string
  urgency: 'immediate' | 'short_term' | 'long_term'
}

interface DateRange {
  start: string
  end: string
}

// =============================================================================
// NARRATIVE GENERATION ENGINE
// =============================================================================

class NarrativeGenerationEngine {
  private openai: OpenAI
  private supabase: any

  constructor(openaiKey: string, supabaseUrl: string, supabaseKey: string) {
    this.openai = new OpenAI({ apiKey: openaiKey })
    this.supabase = createClient(supabaseUrl, supabaseKey)
  }

  async generateExecutiveSummary(
    insights: DataInsight[],
    style: NarrativeAgentRequest['narrative_style'],
    context: NarrativeAgentRequest['business_context']
  ): Promise<NarrativeBlock> {
    
    const prompt = this.buildExecutiveSummaryPrompt(insights, style, context)
    
    try {
      const response = await this.openai.chat.completions.create({
        model: "gpt-4",
        messages: [
          {
            role: "system",
            content: this.getSystemPrompt(style)
          },
          {
            role: "user", 
            content: prompt
          }
        ],
        temperature: style.tone === 'formal' ? 0.3 : 0.7,
        max_tokens: this.getMaxTokens(style.length)
      })

      const content = response.choices[0]?.message?.content || ''
      
      return {
        title: this.generateSummaryTitle(style, context),
        content,
        key_points: this.extractKeyPoints(content),
        call_to_action: this.generateCallToAction(insights, style),
        reading_time_minutes: this.estimateReadingTime(content)
      }
      
    } catch (error) {
      console.error('Executive summary generation error:', error)
      return this.getFallbackSummary(insights, style, context)
    }
  }

  async generateKeyInsights(
    insights: DataInsight[],
    style: NarrativeAgentRequest['narrative_style']
  ): Promise<InsightBlock[]> {
    
    const prioritizedInsights = this.prioritizeInsights(insights)
    const insightBlocks: InsightBlock[] = []
    
    for (const insight of prioritizedInsights.slice(0, 5)) { // Top 5 insights
      try {
        const block = await this.generateSingleInsight(insight, style)
        insightBlocks.push(block)
      } catch (error) {
        console.error(`Error generating insight for ${insight.title}:`, error)
        // Continue with other insights
      }
    }
    
    return insightBlocks
  }

  async generateRecommendations(
    insights: DataInsight[],
    style: NarrativeAgentRequest['narrative_style'],
    context: NarrativeAgentRequest['business_context']
  ): Promise<Recommendation[]> {
    
    const actionableInsights = insights.filter(i => 
      i.impact_level === 'high' && i.confidence > 0.7
    )
    
    const recommendations: Recommendation[] = []
    
    for (const insight of actionableInsights.slice(0, 4)) { // Max 4 recommendations
      try {
        const recommendation = await this.generateSingleRecommendation(insight, style, context)
        recommendations.push(recommendation)
      } catch (error) {
        console.error(`Error generating recommendation for ${insight.title}:`, error)
      }
    }
    
    return recommendations.sort((a, b) => this.getPriorityScore(b.priority) - this.getPriorityScore(a.priority))
  }

  private buildExecutiveSummaryPrompt(
    insights: DataInsight[],
    style: NarrativeAgentRequest['narrative_style'],
    context: NarrativeAgentRequest['business_context']
  ): string {
    
    const insightsSummary = insights
      .filter(i => i.confidence > 0.6)
      .map(i => `- ${i.title}: ${i.description} (${i.impact_level} impact)`)
      .join('\n')
    
    const periodInfo = this.formatPeriodInfo(context.current_period, context.comparison_period)
    const focusAreas = context.strategic_focus?.join(', ') || 'general performance'
    
    const basePrompt = `
Generate an executive summary for Scout retail analytics platform.

CONTEXT:
- Analysis Period: ${periodInfo}
- Strategic Focus: ${focusAreas}
- Audience: ${style.audience}
- Tone: ${style.tone}
- Length: ${style.length}
- Language: ${style.language}

KEY INSIGHTS:
${insightsSummary}

REQUIREMENTS:
- Start with overall performance assessment
- Highlight 2-3 most critical insights
- Include competitive positioning if relevant
- End with strategic outlook
- Use ${style.language === 'fil' ? 'Filipino' : 'English'} business terminology
- Maintain ${style.tone} tone throughout
- Target ${style.length} length (${this.getLengthGuidance(style.length)})
`

    if (style.language === 'fil') {
      return basePrompt + `
FILIPINO LANGUAGE GUIDELINES:
- Use Filipino business terms naturally mixed with English
- Maintain professional Filipino business communication style
- Include cultural context where appropriate
- Use "po" and "ninyo" appropriately for formal tone
`
    }
    
    return basePrompt
  }

  private getSystemPrompt(style: NarrativeAgentRequest['narrative_style']): string {
    const basePrompt = `You are a senior business analyst specializing in retail analytics and Filipino market insights. You transform data insights into compelling business narratives.`
    
    const audiencePrompts = {
      executive: `Focus on strategic implications, market positioning, and actionable insights for C-level decision making.`,
      analyst: `Provide detailed analysis with methodology, statistical significance, and technical insights.`,
      store_manager: `Emphasize operational insights, actionable recommendations, and practical implementation steps.`
    }
    
    const tonePrompts = {
      formal: `Maintain professional, authoritative tone with precise business language.`,
      conversational: `Use accessible, engaging language while maintaining business credibility.`,
      urgent: `Convey urgency and importance while remaining professional and solution-focused.`
    }
    
    const languagePrompt = style.language === 'fil' ? 
      `Write in Filipino with natural code-switching to English for business terms. Understand Filipino business culture and communication patterns.` :
      `Write in clear, professional English suitable for international business communication.`
    
    return `${basePrompt} ${audiencePrompts[style.audience]} ${tonePrompts[style.tone]} ${languagePrompt}`
  }

  private async generateSingleInsight(
    insight: DataInsight,
    style: NarrativeAgentRequest['narrative_style']
  ): Promise<InsightBlock> {
    
    const prompt = `
Generate a detailed insight block for: ${insight.title}

INSIGHT DATA:
- Description: ${insight.description}
- Confidence: ${(insight.confidence * 100).toFixed(0)}%
- Impact Level: ${insight.impact_level}
- Primary Value: ${insight.metrics.primary_value}
- Change: ${insight.metrics.change_percentage ? `${insight.metrics.change_percentage}%` : 'N/A'}
- Trend: ${insight.metrics.trend_direction || 'N/A'}
- Entities: ${insight.context.entities.join(', ')}

REQUIREMENTS:
- Create compelling headline (max 80 characters)
- Explain business significance
- Provide supporting data context
- Assess business impact
- Suggest priority level
- Language: ${style.language}
- Tone: ${style.tone}

Format as JSON with: headline, description, supporting_data[], business_impact, priority, categories[]
`

    try {
      const response = await this.openai.chat.completions.create({
        model: "gpt-4",
        messages: [
          { role: "system", content: this.getSystemPrompt(style) },
          { role: "user", content: prompt }
        ],
        temperature: 0.4,
        max_tokens: 500
      })

      const content = response.choices[0]?.message?.content || '{}'
      const parsed = this.parseJSONSafely(content)
      
      return {
        headline: parsed.headline || insight.title,
        description: parsed.description || insight.description,
        supporting_data: parsed.supporting_data || [
          `Primary metric: ${insight.metrics.primary_value}`,
          `Confidence level: ${(insight.confidence * 100).toFixed(0)}%`
        ],
        business_impact: parsed.business_impact || `${insight.impact_level} impact on business performance`,
        priority: parsed.priority || insight.impact_level,
        categories: parsed.categories || insight.context.entities
      }
      
    } catch (error) {
      return this.getFallbackInsight(insight)
    }
  }

  private async generateSingleRecommendation(
    insight: DataInsight,
    style: NarrativeAgentRequest['narrative_style'],
    context: NarrativeAgentRequest['business_context']
  ): Promise<Recommendation> {
    
    const prompt = `
Generate actionable recommendation based on insight: ${insight.title}

INSIGHT CONTEXT:
- ${insight.description}
- Impact: ${insight.impact_level}
- Confidence: ${(insight.confidence * 100).toFixed(0)}%
- Trend: ${insight.metrics.trend_direction}

BUSINESS CONTEXT:
- Period: ${this.formatPeriodInfo(context.current_period, context.comparison_period)}
- Focus Areas: ${context.strategic_focus?.join(', ') || 'general performance'}
- Audience: ${style.audience}

REQUIREMENTS:
- Specific, actionable recommendation
- Clear rationale based on data
- Priority level (critical/high/medium/low)
- Effort estimation (low/medium/high)
- Timeline for implementation
- Expected impact description
- Success metrics to track
- Responsible parties
- Language: ${style.language}

Format as JSON with all required fields.
`

    try {
      const response = await this.openai.chat.completions.create({
        model: "gpt-4",
        messages: [
          { role: "system", content: this.getSystemPrompt(style) },
          { role: "user", content: prompt }
        ],
        temperature: 0.5,
        max_tokens: 600
      })

      const content = response.choices[0]?.message?.content || '{}'
      const parsed = this.parseJSONSafely(content)
      
      return {
        title: parsed.title || `Address ${insight.title}`,
        description: parsed.description || `Recommendation based on ${insight.title}`,
        rationale: parsed.rationale || insight.description,
        priority: parsed.priority || this.mapImpactToPriority(insight.impact_level),
        effort_level: parsed.effort_level || 'medium',
        timeline: parsed.timeline || '1-3 months',
        expected_impact: parsed.expected_impact || `Improve ${insight.context.entities[0]} performance`,
        success_metrics: parsed.success_metrics || [`Monitor ${insight.metrics.primary_value}`],
        responsible_parties: parsed.responsible_parties || [style.audience]
      }
      
    } catch (error) {
      return this.getFallbackRecommendation(insight, style)
    }
  }

  // Helper methods
  private prioritizeInsights(insights: DataInsight[]): DataInsight[] {
    return insights.sort((a, b) => {
      const scoreA = this.calculateInsightScore(a)
      const scoreB = this.calculateInsightScore(b)
      return scoreB - scoreA
    })
  }

  private calculateInsightScore(insight: DataInsight): number {
    const impactScores = { high: 3, medium: 2, low: 1 }
    const typeScores = { 
      anomaly: 3, 
      trend: 2.5, 
      correlation: 2, 
      performance: 1.5, 
      ranking: 1 
    }
    
    return (impactScores[insight.impact_level] * 0.4) + 
           (insight.confidence * 0.4) + 
           (typeScores[insight.type] * 0.2)
  }

  private extractKeyPoints(content: string): string[] {
    // Extract bullet points or numbered items
    const bulletRegex = /^[•\-\*]\s+(.+)$/gm
    const numberedRegex = /^\d+\.\s+(.+)$/gm
    
    const bullets = [...content.matchAll(bulletRegex)].map(match => match[1].trim())
    const numbered = [...content.matchAll(numberedRegex)].map(match => match[1].trim())
    
    const keyPoints = [...bullets, ...numbered]
    
    // If no bullet points found, extract sentences with key indicators
    if (keyPoints.length === 0) {
      const sentences = content.split(/[.!?]+/).filter(s => s.trim().length > 20)
      const keyIndicators = ['increased', 'decreased', 'improved', 'declined', 'significant', 'notable', 'critical']
      
      const importantSentences = sentences.filter(sentence => 
        keyIndicators.some(indicator => sentence.toLowerCase().includes(indicator))
      )
      
      return importantSentences.slice(0, 3).map(s => s.trim())
    }
    
    return keyPoints.slice(0, 5) // Max 5 key points
  }

  private generateCallToAction(
    insights: DataInsight[],
    style: NarrativeAgentRequest['narrative_style']
  ): string {
    const highImpactInsights = insights.filter(i => i.impact_level === 'high').length
    
    if (style.language === 'fil') {
      if (highImpactInsights > 2) {
        return "Kailangan nating kumilos ngayon sa mga critical insights na ito para ma-maintain ang competitive advantage."
      } else if (highImpactInsights > 0) {
        return "I-review natin ang recommendations at gumawa ng action plan para sa susunod na quarter."
      } else {
        return "Magpatuloy tayo sa monitoring at mag-focus sa continuous improvement initiatives."
      }
    } else {
      if (highImpactInsights > 2) {
        return "Immediate action is required on these critical insights to maintain competitive advantage."
      } else if (highImpactInsights > 0) {
        return "Review recommendations and develop action plans for next quarter implementation."
      } else {
        return "Continue monitoring performance and focus on continuous improvement initiatives."
      }
    }
  }

  private formatPeriodInfo(current: DateRange, comparison?: DateRange): string {
    const currentStr = `${current.start} to ${current.end}`
    if (comparison) {
      return `${currentStr} vs ${comparison.start} to ${comparison.end}`
    }
    return currentStr
  }

  private getLengthGuidance(length: string): string {
    const guidance = {
      brief: '150-250 words, 2-3 paragraphs',
      standard: '300-500 words, 3-4 paragraphs',
      detailed: '500-800 words, 4-6 paragraphs'
    }
    return guidance[length as keyof typeof guidance] || guidance.standard
  }

  private getMaxTokens(length: string): number {
    const tokens = { brief: 400, standard: 800, detailed: 1200 }
    return tokens[length as keyof typeof tokens] || tokens.standard
  }

  private estimateReadingTime(content: string): number {
    const wordsPerMinute = 200
    const wordCount = content.split(/\s+/).length
    return Math.max(1, Math.round(wordCount / wordsPerMinute))
  }

  private generateSummaryTitle(
    style: NarrativeAgentRequest['narrative_style'],
    context: NarrativeAgentRequest['business_context']
  ): string {
    const period = new Date(context.current_period.end).toLocaleDateString('en-US', { 
      month: 'short', 
      year: 'numeric' 
    })
    
    if (style.language === 'fil') {
      return `Executive Summary - ${period} Performance`
    }
    
    return `Executive Summary - ${period} Performance Analysis`
  }

  private getPriorityScore(priority: string): number {
    const scores = { critical: 4, high: 3, medium: 2, low: 1 }
    return scores[priority as keyof typeof scores] || 1
  }

  private mapImpactToPriority(impact: string): 'critical' | 'high' | 'medium' | 'low' {
    const mapping = { high: 'high', medium: 'medium', low: 'low' }
    return mapping[impact as keyof typeof mapping] || 'medium'
  }

  private parseJSONSafely(content: string): any {
    try {
      // Try to extract JSON from markdown code blocks
      const jsonMatch = content.match(/```(?:json)?\s*(\{[\s\S]*?\})\s*```/)
      if (jsonMatch) {
        return JSON.parse(jsonMatch[1])
      }
      
      // Try to parse as direct JSON
      return JSON.parse(content)
    } catch {
      // Return empty object if parsing fails
      return {}
    }
  }

  private getFallbackSummary(
    insights: DataInsight[],
    style: NarrativeAgentRequest['narrative_style'],
    context: NarrativeAgentRequest['business_context']
  ): NarrativeBlock {
    const highImpactInsights = insights.filter(i => i.impact_level === 'high')
    const period = this.formatPeriodInfo(context.current_period, context.comparison_period)
    
    const content = style.language === 'fil' ? 
      `Performance Summary para sa ${period}:\n\nNagkaroon tayo ng ${insights.length} key insights, kasama ang ${highImpactInsights.length} high-impact findings. Nakita natin ang mga significant changes sa business metrics at market position. Kailangan natin mag-focus sa actionable recommendations para ma-improve ang performance sa susunod na period.` :
      `Performance summary for ${period}:\n\nWe identified ${insights.length} key insights, including ${highImpactInsights.length} high-impact findings. Analysis reveals significant changes in business metrics and market position. Focus should be on implementing actionable recommendations to improve performance in the upcoming period.`
    
    return {
      title: this.generateSummaryTitle(style, context),
      content,
      key_points: insights.slice(0, 3).map(i => i.title),
      call_to_action: this.generateCallToAction(insights, style),
      reading_time_minutes: 2
    }
  }

  private getFallbackInsight(insight: DataInsight): InsightBlock {
    return {
      headline: insight.title,
      description: insight.description,
      supporting_data: [
        `Primary value: ${insight.metrics.primary_value}`,
        `Confidence: ${(insight.confidence * 100).toFixed(0)}%`,
        `Impact level: ${insight.impact_level}`
      ],
      business_impact: `This insight has ${insight.impact_level} impact on business performance`,
      priority: insight.impact_level as 'high' | 'medium' | 'low',
      categories: insight.context.entities
    }
  }

  private getFallbackRecommendation(
    insight: DataInsight,
    style: NarrativeAgentRequest['narrative_style']
  ): Recommendation {
    return {
      title: `Address ${insight.title}`,
      description: `Take action based on ${insight.title} findings`,
      rationale: insight.description,
      priority: this.mapImpactToPriority(insight.impact_level),
      effort_level: 'medium',
      timeline: '1-3 months',
      expected_impact: `Improve performance in ${insight.context.entities[0]}`,
      success_metrics: [`Monitor ${insight.context.entities[0]} metrics`],
      responsible_parties: [style.audience]
    }
  }
}

// =============================================================================
// COMPETITIVE INTELLIGENCE ENGINE
// =============================================================================

class CompetitiveIntelligenceEngine {
  private supabase: any

  constructor(supabase: any) {
    this.supabase = supabase
  }

  async generateCompetitiveInsights(
    insights: DataInsight[],
    tenantId: string,
    style: NarrativeAgentRequest['narrative_style']
  ): Promise<CompetitiveInsight[]> {
    
    try {
      // Extract brands and competitors from insights
      const relevantBrands = this.extractBrandsFromInsights(insights)
      
      if (relevantBrands.length === 0) return []
      
      // Fetch competitive data
      const competitiveData = await this.fetchCompetitiveData(relevantBrands, tenantId)
      
      // Generate narrative insights
      const narrativeInsights = await this.generateNarrativeInsights(competitiveData, style)
      
      return narrativeInsights.slice(0, 3) // Top 3 competitive insights
      
    } catch (error) {
      console.error('Competitive intelligence generation error:', error)
      return []
    }
  }

  private extractBrandsFromInsights(insights: DataInsight[]): string[] {
    const brands = new Set<string>()
    
    insights.forEach(insight => {
      insight.context.entities.forEach(entity => {
        // Check if entity looks like a brand name (capitalized)
        if (entity && entity[0] === entity[0].toUpperCase()) {
          brands.add(entity)
        }
      })
    })
    
    return Array.from(brands)
  }

  private async fetchCompetitiveData(brands: string[], tenantId: string): Promise<any[]> {
    const { data, error } = await this.supabase
      .from('competitor_analysis')
      .select('*')
      .eq('tenant_id', tenantId)
      .in('competitor_name', brands)
      .order('analysis_date', { ascending: false })
      .limit(10)

    if (error) {
      console.error('Competitive data fetch error:', error)
      return []
    }

    return data || []
  }

  private async generateNarrativeInsights(
    competitiveData: any[],
    style: NarrativeAgentRequest['narrative_style']
  ): Promise<CompetitiveInsight[]> {
    
    const insights: CompetitiveInsight[] = []
    
    // Group by competitor
    const groupedData = this.groupByCompetitor(competitiveData)
    
    for (const [competitor, data] of Object.entries(groupedData)) {
      const insight = this.generateCompetitorInsight(competitor, data as any[], style)
      if (insight) {
        insights.push(insight)
      }
    }
    
    return insights
  }

  private groupByCompetitor(data: any[]): Record<string, any[]> {
    return data.reduce((groups, item) => {
      const competitor = item.competitor_name
      if (!groups[competitor]) {
        groups[competitor] = []
      }
      groups[competitor].push(item)
      return groups
    }, {})
  }

  private generateCompetitorInsight(
    competitor: string,
    data: any[],
    style: NarrativeAgentRequest['narrative_style']
  ): CompetitiveInsight | null {
    
    if (data.length === 0) return null
    
    // Find most recent and relevant insight
    const latestInsight = data[0]
    
    // Generate summary based on insight type
    const summary = this.generateCompetitorSummary(competitor, latestInsight, style)
    const implications = this.generateBusinessImplications(latestInsight, style)
    const response = this.generateRecommendedResponse(latestInsight, style)
    
    return {
      competitor,
      insight_type: latestInsight.insight_type || 'performance',
      summary,
      business_implications: implications,
      recommended_response: response,
      urgency: this.determineUrgency(latestInsight)
    }
  }

  private generateCompetitorSummary(
    competitor: string,
    insight: any,
    style: NarrativeAgentRequest['narrative_style']
  ): string {
    
    const baseTemplate = style.language === 'fil' ?
      `Si ${competitor} ay nag-${insight.insight_type} sa recent period. ${insight.insight_description}` :
      `${competitor} has shown ${insight.insight_type} activity in the recent period. ${insight.insight_description}`
    
    return baseTemplate
  }

  private generateBusinessImplications(
    insight: any,
    style: NarrativeAgentRequest['narrative_style']
  ): string {
    
    const confidence = insight.confidence_score || 0.5
    
    if (style.language === 'fil') {
      if (confidence > 0.8) {
        return "Malaking impact ito sa aming market position at kailangan nating mag-adjust ng strategy."
      } else {
        return "May potential impact sa market share at dapat nating i-monitor ang developments."
      }
    } else {
      if (confidence > 0.8) {
        return "This has significant implications for our market position and requires strategic adjustment."
      } else {
        return "Potential impact on market share warrants close monitoring of developments."
      }
    }
  }

  private generateRecommendedResponse(
    insight: any,
    style: NarrativeAgentRequest['narrative_style']
  ): string {
    
    const responseTemplates = {
      fil: {
        market_share: "I-strengthen natin ang competitive positioning at mag-focus sa differentiation.",
        pricing: "Review natin ang pricing strategy at i-assess ang impact sa profitability.",
        product_launch: "Mag-accelerate tayo ng innovation pipeline at i-enhance ang product offerings.",
        performance: "I-benchmark natin ang performance metrics at i-identify ang improvement opportunities."
      },
      en: {
        market_share: "Strengthen competitive positioning and focus on differentiation strategies.",
        pricing: "Review pricing strategy and assess impact on profitability margins.",
        product_launch: "Accelerate innovation pipeline and enhance product offerings.",
        performance: "Benchmark performance metrics and identify improvement opportunities."
      }
    }
    
    const templates = responseTemplates[style.language] || responseTemplates.en
    const insightType = insight.insight_type || 'performance'
    
    return templates[insightType as keyof typeof templates] || templates.performance
  }

  private determineUrgency(insight: any): 'immediate' | 'short_term' | 'long_term' {
    const confidence = insight.confidence_score || 0.5
    const recency = new Date().getTime() - new Date(insight.analysis_date || new Date()).getTime()
    const daysOld = recency / (1000 * 60 * 60 * 24)
    
    if (confidence > 0.8 && daysOld < 7) {
      return 'immediate'
    } else if (confidence > 0.6 && daysOld < 30) {
      return 'short_term'
    } else {
      return 'long_term'
    }
  }
}

// =============================================================================
// MAIN NARRATIVE AGENT
// =============================================================================

class NarrativeAgent {
  static async process(request: NarrativeAgentRequest): Promise<NarrativeAgentResponse> {
    const startTime = Date.now()
    
    try {
      const openaiKey = Deno.env.get('OPENAI_API_KEY')!
      const supabaseUrl = Deno.env.get('SUPABASE_URL')!
      const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY')!
      
      const narrativeEngine = new NarrativeGenerationEngine(openaiKey, supabaseUrl, supabaseKey)
      const competitiveEngine = new CompetitiveIntelligenceEngine(
        createClient(supabaseUrl, supabaseKey)
      )
      
      // 1. Generate executive summary
      const executiveSummary = await narrativeEngine.generateExecutiveSummary(
        request.data_insights,
        request.narrative_style,
        request.business_context
      )
      
      // 2. Generate key insights
      const keyInsights = await narrativeEngine.generateKeyInsights(
        request.data_insights,
        request.narrative_style
      )
      
      // 3. Generate actionable recommendations
      const recommendations = await narrativeEngine.generateRecommendations(
        request.data_insights,
        request.narrative_style,
        request.business_context
      )
      
      // 4. Generate competitive intelligence
      const competitiveInsights = await competitiveEngine.generateCompetitiveInsights(
        request.data_insights,
        request.user_context.tenant_id,
        request.narrative_style
      )
      
      // 5. Calculate metadata
      const metadata = this.calculateMetadata(
        request.data_insights,
        executiveSummary,
        keyInsights,
        recommendations,
        request.narrative_style,
        Date.now() - startTime
      )
      
      return {
        executive_summary: executiveSummary,
        key_insights: keyInsights,
        actionable_recommendations: recommendations,
        competitive_intelligence: competitiveInsights,
        narrative_metadata: metadata
      }
      
    } catch (error) {
      return {
        executive_summary: {
          title: 'Analysis Summary',
          content: 'Unable to generate comprehensive narrative due to processing error.',
          key_points: ['Analysis completed with limitations'],
          reading_time_minutes: 1
        },
        key_insights: [],
        actionable_recommendations: [],
        competitive_intelligence: [],
        narrative_metadata: {
          confidence_level: 0.2,
          data_coverage: 0.3,
          insight_quality: 'low',
          processing_time_ms: Date.now() - startTime,
          language_detected: request.narrative_style.language,
          tone_consistency: 0.5
        }
      }
    }
  }

  private static calculateMetadata(
    insights: DataInsight[],
    summary: NarrativeBlock,
    keyInsights: InsightBlock[],
    recommendations: Recommendation[],
    style: NarrativeAgentRequest['narrative_style'],
    processingTime: number
  ) {
    
    // Calculate confidence level based on input data quality
    const avgConfidence = insights.reduce((sum, insight) => sum + insight.confidence, 0) / insights.length
    
    // Calculate data coverage based on successful generation
    const expectedComponents = 4 // summary, insights, recommendations, competitive
    const actualComponents = [
      summary.content.length > 50,
      keyInsights.length > 0,
      recommendations.length > 0,
      true // Always count basic processing as successful
    ].filter(Boolean).length
    
    const dataCoverage = actualComponents / expectedComponents
    
    // Determine insight quality
    const highQualityInsights = insights.filter(i => i.confidence > 0.7 && i.impact_level === 'high').length
    const insightQuality = highQualityInsights > 2 ? 'high' : 
                          highQualityInsights > 0 ? 'medium' : 'low'
    
    // Calculate tone consistency (simplified)
    const toneConsistency = summary.content.length > 100 ? 0.9 : 0.7
    
    return {
      confidence_level: avgConfidence,
      data_coverage: dataCoverage,
      insight_quality: insightQuality as 'high' | 'medium' | 'low',
      processing_time_ms: processingTime,
      language_detected: style.language,
      tone_consistency: toneConsistency
    }
  }
}

// =============================================================================
// EDGE FUNCTION HANDLER
// =============================================================================

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
      }
    })
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' }
    })
  }

  try {
    const request: NarrativeAgentRequest = await req.json()
    
    // Validate required fields
    if (!request.data_insights || !request.narrative_style || !request.business_context || !request.user_context?.tenant_id) {
      return new Response(JSON.stringify({ 
        error: 'Missing required fields: data_insights, narrative_style, business_context, user_context.tenant_id' 
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    const response = await NarrativeAgent.process(request)
    
    return new Response(JSON.stringify(response), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      }
    })
    
  } catch (error) {
    return new Response(JSON.stringify({ 
      error: 'Internal server error',
      details: error.message 
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})