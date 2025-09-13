/**
 * ChartVisionAgent - Intelligent Chart Selection and Data Visualization
 * Scout v7.1 Agentic Analytics Platform
 * 
 * Transforms data insights into compelling visual narratives with intelligent
 * chart type recommendation, accessibility compliance, and responsive design.
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

// =============================================================================
// TYPES & INTERFACES
// =============================================================================

interface ChartVisionAgentRequest {
  query_results: SQLResultSet
  visualization_intent?: 'trend' | 'comparison' | 'distribution' | 'correlation' | 'composition'
  audience_context?: {
    executive_summary?: boolean
    technical_detail?: boolean
    presentation_mode?: boolean
  }
  brand_guidelines?: DesignSystemContext
  user_context: {
    tenant_id: string
    role: 'executive' | 'store_manager' | 'analyst'
  }
}

interface ChartVisionAgentResponse {
  chart_specifications: ChartSpecification[]
  data_transformations: TransformationStep[]
  accessibility_metadata: AccessibilityConfig
  responsive_breakpoints: BreakpointConfig[]
  recommendation_metadata: {
    confidence_score: number
    chart_rationale: string
    alternative_options: string[]
    processing_time_ms: number
  }
}

interface SQLResultSet {
  columns: ColumnMetadata[]
  rows: Record<string, any>[]
  total_rows: number
  query_metadata: {
    execution_time_ms: number
    data_sources: string[]
  }
}

interface ColumnMetadata {
  name: string
  type: 'string' | 'number' | 'date' | 'boolean'
  nullable: boolean
  distinct_values?: number
  min_value?: number | string
  max_value?: number | string
  sample_values?: any[]
}

interface ChartSpecification {
  chart_type: 'line' | 'bar' | 'pie' | 'scatter' | 'heatmap' | 'treemap' | 'funnel' | 'area' | 'combo'
  chart_config: {
    x_axis: AxisConfig
    y_axis: AxisConfig
    grouping?: GroupingConfig
    series?: SeriesConfig[]
  }
  styling: ChartStyling
  interactions: InteractionConfig
  layout: LayoutConfig
}

interface AxisConfig {
  column: string
  label: string
  format?: string
  scale?: 'linear' | 'log' | 'time' | 'categorical'
  domain?: [number | string, number | string]
  tick_interval?: string | number
}

interface GroupingConfig {
  column: string
  label: string
  color_scheme: string[]
  max_groups?: number
}

interface SeriesConfig {
  name: string
  type: 'line' | 'bar' | 'area'
  y_column: string
  color: string
  style?: 'solid' | 'dashed' | 'dotted'
}

interface ChartStyling {
  color_palette: string[]
  theme: 'light' | 'dark' | 'auto'
  font_family: string
  font_sizes: Record<string, number>
  spacing: Record<string, number>
  brand_compliance: boolean
}

interface InteractionConfig {
  tooltip_enabled: boolean
  zoom_enabled: boolean
  pan_enabled: boolean
  brush_selection: boolean
  click_actions: ClickAction[]
}

interface ClickAction {
  trigger: 'click' | 'hover' | 'double_click'
  action: 'drill_down' | 'filter' | 'highlight' | 'navigate'
  target?: string
}

interface LayoutConfig {
  width: string | number
  height: string | number
  margin: { top: number; right: number; bottom: number; left: number }
  legend: LegendConfig
  title: TitleConfig
}

interface LegendConfig {
  position: 'top' | 'bottom' | 'left' | 'right' | 'none'
  orientation: 'horizontal' | 'vertical'
  wrap_length?: number
}

interface TitleConfig {
  text: string
  subtitle?: string
  alignment: 'left' | 'center' | 'right'
  font_size: number
}

interface TransformationStep {
  operation: 'aggregate' | 'filter' | 'sort' | 'pivot' | 'calculate' | 'format'
  description: string
  parameters: Record<string, any>
  output_columns: string[]
}

interface AccessibilityConfig {
  wcag_level: 'AA' | 'AAA'
  color_blind_safe: boolean
  high_contrast_mode: boolean
  screen_reader_support: boolean
  keyboard_navigation: boolean
  alt_text: string
  data_table_fallback: boolean
}

interface BreakpointConfig {
  breakpoint: 'mobile' | 'tablet' | 'desktop' | 'large'
  min_width: number
  chart_config_override: Partial<ChartSpecification>
}

interface DesignSystemContext {
  primary_colors: string[]
  secondary_colors: string[]
  font_stack: string[]
  spacing_scale: number[]
  border_radius: number
  brand_name: string
}

// =============================================================================
// CHART TYPE RECOMMENDATION ENGINE
// =============================================================================

class ChartTypeRecommendationEngine {
  static recommend(
    data: SQLResultSet,
    intent?: string,
    audience?: ChartVisionAgentRequest['audience_context']
  ): { type: ChartSpecification['chart_type']; confidence: number; rationale: string; alternatives: string[] } {
    
    const analysis = this.analyzeDataCharacteristics(data)
    const recommendations = this.applyDecisionMatrix(analysis, intent, audience)
    
    return this.selectBestRecommendation(recommendations)
  }

  private static analyzeDataCharacteristics(data: SQLResultSet) {
    const columns = data.columns
    const rows = data.rows
    
    return {
      numeric_columns: columns.filter(c => c.type === 'number').length,
      categorical_columns: columns.filter(c => c.type === 'string').length,
      date_columns: columns.filter(c => c.type === 'date').length,
      total_columns: columns.length,
      row_count: rows.length,
      has_time_series: this.hasTimeSeries(columns),
      has_hierarchical_data: this.hasHierarchicalData(columns),
      has_geographic_data: this.hasGeographicData(columns),
      cardinality_analysis: this.analyzeCardinality(columns, rows),
      value_ranges: this.analyzeValueRanges(columns, rows)
    }
  }

  private static hasTimeSeries(columns: ColumnMetadata[]): boolean {
    return columns.some(c => 
      c.type === 'date' || 
      c.name.toLowerCase().includes('date') ||
      c.name.toLowerCase().includes('time') ||
      c.name.toLowerCase().includes('period')
    )
  }

  private static hasHierarchicalData(columns: ColumnMetadata[]): boolean {
    const hierarchicalIndicators = ['category', 'subcategory', 'parent', 'child', 'level']
    return columns.some(c => 
      hierarchicalIndicators.some(indicator => c.name.toLowerCase().includes(indicator))
    )
  }

  private static hasGeographicData(columns: ColumnMetadata[]): boolean {
    const geoIndicators = ['location', 'region', 'city', 'country', 'state', 'lat', 'lng', 'longitude', 'latitude']
    return columns.some(c => 
      geoIndicators.some(indicator => c.name.toLowerCase().includes(indicator))
    )
  }

  private static analyzeCardinality(columns: ColumnMetadata[], rows: Record<string, any>[]): Record<string, number> {
    const cardinality: Record<string, number> = {}
    
    columns.forEach(column => {
      if (column.distinct_values !== undefined) {
        cardinality[column.name] = column.distinct_values
      } else {
        // Calculate cardinality from sample data
        const uniqueValues = new Set(rows.map(row => row[column.name]))
        cardinality[column.name] = uniqueValues.size
      }
    })
    
    return cardinality
  }

  private static analyzeValueRanges(columns: ColumnMetadata[], rows: Record<string, any>[]): Record<string, any> {
    const ranges: Record<string, any> = {}
    
    columns.filter(c => c.type === 'number').forEach(column => {
      const values = rows.map(row => parseFloat(row[column.name])).filter(v => !isNaN(v))
      if (values.length > 0) {
        ranges[column.name] = {
          min: Math.min(...values),
          max: Math.max(...values),
          range: Math.max(...values) - Math.min(...values),
          has_zeros: values.includes(0),
          all_positive: values.every(v => v >= 0)
        }
      }
    })
    
    return ranges
  }

  private static applyDecisionMatrix(
    analysis: any,
    intent?: string,
    audience?: ChartVisionAgentRequest['audience_context']
  ) {
    const recommendations: Array<{ type: string; score: number; rationale: string }> = []

    // Time series data → Line chart
    if (analysis.has_time_series && analysis.numeric_columns >= 1) {
      recommendations.push({
        type: 'line',
        score: 0.9,
        rationale: 'Time series data with numeric values - line chart shows trends over time effectively'
      })
      
      if (analysis.numeric_columns > 1) {
        recommendations.push({
          type: 'area',
          score: 0.8,
          rationale: 'Multiple time series - area chart shows cumulative trends and comparisons'
        })
      }
    }

    // Categorical comparison → Bar chart
    if (analysis.categorical_columns >= 1 && analysis.numeric_columns >= 1) {
      const categoricalColumn = analysis.cardinality_analysis
      const maxCardinality = Math.max(...Object.values(categoricalColumn))
      
      if (maxCardinality <= 10) {
        recommendations.push({
          type: 'bar',
          score: 0.85,
          rationale: 'Categorical data with manageable categories - bar chart enables clear comparisons'
        })
      } else if (maxCardinality <= 50) {
        recommendations.push({
          type: 'treemap',
          score: 0.75,
          rationale: 'High cardinality categorical data - treemap handles many categories efficiently'
        })
      }
    }

    // Part-to-whole relationships → Pie chart
    if (analysis.categorical_columns === 1 && analysis.numeric_columns === 1) {
      const cardinality = Object.values(analysis.cardinality_analysis)[0] as number
      if (cardinality <= 7 && cardinality >= 2) {
        recommendations.push({
          type: 'pie',
          score: 0.7,
          rationale: 'Single categorical variable with few categories - pie chart shows proportions clearly'
        })
      }
    }

    // Correlation analysis → Scatter plot
    if (analysis.numeric_columns >= 2 && analysis.row_count >= 10) {
      recommendations.push({
        type: 'scatter',
        score: 0.8,
        rationale: 'Multiple numeric variables - scatter plot reveals correlations and patterns'
      })
    }

    // Matrix data → Heatmap
    if (analysis.categorical_columns >= 2 && analysis.numeric_columns >= 1) {
      recommendations.push({
        type: 'heatmap',
        score: 0.75,
        rationale: 'Two categorical dimensions with numeric values - heatmap shows intensity patterns'
      })
    }

    // Funnel analysis
    if (this.detectFunnelPattern(analysis)) {
      recommendations.push({
        type: 'funnel',
        score: 0.85,
        rationale: 'Sequential process data detected - funnel chart shows conversion stages'
      })
    }

    // Adjust scores based on intent
    if (intent) {
      this.applyIntentModifiers(recommendations, intent)
    }

    // Adjust scores based on audience
    if (audience) {
      this.applyAudienceModifiers(recommendations, audience)
    }

    return recommendations
  }

  private static detectFunnelPattern(analysis: any): boolean {
    // Look for funnel indicators in column names
    const funnelKeywords = ['funnel', 'conversion', 'stage', 'step', 'phase', 'process']
    const columnNames = Object.keys(analysis.cardinality_analysis).map(name => name.toLowerCase())
    
    return funnelKeywords.some(keyword => 
      columnNames.some(name => name.includes(keyword))
    )
  }

  private static applyIntentModifiers(recommendations: any[], intent: string) {
    const intentModifiers = {
      'trend': { 'line': 0.2, 'area': 0.15 },
      'comparison': { 'bar': 0.2, 'heatmap': 0.1 },
      'distribution': { 'scatter': 0.15, 'heatmap': 0.1 },
      'correlation': { 'scatter': 0.25, 'line': 0.1 },
      'composition': { 'pie': 0.2, 'treemap': 0.15 }
    }

    const modifiers = intentModifiers[intent as keyof typeof intentModifiers] || {}
    
    recommendations.forEach(rec => {
      const boost = modifiers[rec.type as keyof typeof modifiers] || 0
      rec.score = Math.min(rec.score + boost, 1.0)
    })
  }

  private static applyAudienceModifiers(recommendations: any[], audience: any) {
    // Executive audience prefers simple, clear charts
    if (audience.executive_summary) {
      const executiveBoosts = { 'bar': 0.1, 'line': 0.1, 'pie': 0.05 }
      const executivePenalties = { 'scatter': -0.1, 'heatmap': -0.05 }
      
      recommendations.forEach(rec => {
        const boost = executiveBoosts[rec.type as keyof typeof executiveBoosts] || 0
        const penalty = executivePenalties[rec.type as keyof typeof executivePenalties] || 0
        rec.score = Math.max(rec.score + boost + penalty, 0.1)
      })
    }

    // Technical detail allows for more complex visualizations
    if (audience.technical_detail) {
      const technicalBoosts = { 'scatter': 0.1, 'heatmap': 0.1, 'treemap': 0.05 }
      
      recommendations.forEach(rec => {
        const boost = technicalBoosts[rec.type as keyof typeof technicalBoosts] || 0
        rec.score = Math.min(rec.score + boost, 1.0)
      })
    }

    // Presentation mode favors visually impactful charts
    if (audience.presentation_mode) {
      const presentationBoosts = { 'bar': 0.1, 'area': 0.1, 'treemap': 0.05 }
      const presentationPenalties = { 'scatter': -0.05 }
      
      recommendations.forEach(rec => {
        const boost = presentationBoosts[rec.type as keyof typeof presentationBoosts] || 0
        const penalty = presentationPenalties[rec.type as keyof typeof presentationPenalties] || 0
        rec.score = Math.max(rec.score + boost + penalty, 0.1)
      })
    }
  }

  private static selectBestRecommendation(recommendations: any[]) {
    if (recommendations.length === 0) {
      return {
        type: 'bar' as const,
        confidence: 0.5,
        rationale: 'Default recommendation - bar chart is versatile for most data types',
        alternatives: ['line', 'pie']
      }
    }

    // Sort by score
    recommendations.sort((a, b) => b.score - a.score)
    
    const best = recommendations[0]
    const alternatives = recommendations.slice(1, 4).map(r => r.type)

    return {
      type: best.type as ChartSpecification['chart_type'],
      confidence: best.score,
      rationale: best.rationale,
      alternatives
    }
  }
}

// =============================================================================
// DATA TRANSFORMATION ENGINE
// =============================================================================

class DataTransformationEngine {
  static generateTransformations(
    data: SQLResultSet,
    chartType: ChartSpecification['chart_type'],
    chartConfig: ChartSpecification['chart_config']
  ): TransformationStep[] {
    
    const transformations: TransformationStep[] = []
    
    // 1. Data type conversions
    transformations.push(...this.generateTypeConversions(data, chartConfig))
    
    // 2. Aggregations (if needed)
    transformations.push(...this.generateAggregations(data, chartType, chartConfig))
    
    // 3. Filtering (if needed)
    transformations.push(...this.generateFilters(data, chartType))
    
    // 4. Sorting
    transformations.push(...this.generateSorting(data, chartType, chartConfig))
    
    // 5. Formatting
    transformations.push(...this.generateFormatting(data, chartConfig))
    
    return transformations.filter(t => t !== null)
  }

  private static generateTypeConversions(data: SQLResultSet, chartConfig: any): TransformationStep[] {
    const transformations: TransformationStep[] = []
    
    // Convert date strings to Date objects if needed
    const dateColumns = data.columns.filter(c => c.type === 'date')
    if (dateColumns.length > 0) {
      transformations.push({
        operation: 'format',
        description: 'Convert date strings to Date objects for proper time series handling',
        parameters: {
          columns: dateColumns.map(c => c.name),
          target_type: 'date'
        },
        output_columns: dateColumns.map(c => c.name)
      })
    }
    
    return transformations
  }

  private static generateAggregations(
    data: SQLResultSet,
    chartType: string,
    chartConfig: any
  ): TransformationStep[] {
    
    const transformations: TransformationStep[] = []
    
    // For pie charts, ensure we have aggregated data
    if (chartType === 'pie' && data.rows.length > 20) {
      const categoricalCol = data.columns.find(c => c.type === 'string')?.name
      const numericCol = data.columns.find(c => c.type === 'number')?.name
      
      if (categoricalCol && numericCol) {
        transformations.push({
          operation: 'aggregate',
          description: `Aggregate ${numericCol} by ${categoricalCol} for pie chart`,
          parameters: {
            group_by: categoricalCol,
            aggregations: { [numericCol]: 'sum' }
          },
          output_columns: [categoricalCol, numericCol]
        })
      }
    }
    
    return transformations
  }

  private static generateFilters(data: SQLResultSet, chartType: string): TransformationStep[] {
    const transformations: TransformationStep[] = []
    
    // Limit categories for pie charts
    if (chartType === 'pie') {
      const categoricalCol = data.columns.find(c => c.type === 'string')?.name
      if (categoricalCol) {
        const cardinality = data.columns.find(c => c.name === categoricalCol)?.distinct_values || 0
        
        if (cardinality > 7) {
          transformations.push({
            operation: 'filter',
            description: 'Limit to top 6 categories plus "Others" for pie chart readability',
            parameters: {
              method: 'top_n_plus_others',
              column: categoricalCol,
              n: 6,
              others_label: 'Others'
            },
            output_columns: data.columns.map(c => c.name)
          })
        }
      }
    }
    
    // Remove null/empty values
    transformations.push({
      operation: 'filter',
      description: 'Remove rows with null or empty key values',
      parameters: {
        method: 'remove_nulls',
        key_columns: [data.columns[0].name] // Usually the primary dimension
      },
      output_columns: data.columns.map(c => c.name)
    })
    
    return transformations
  }

  private static generateSorting(
    data: SQLResultSet,
    chartType: string,
    chartConfig: any
  ): TransformationStep[] {
    
    const transformations: TransformationStep[] = []
    
    // Sort by value for most chart types
    if (['bar', 'pie', 'treemap'].includes(chartType)) {
      const numericCol = data.columns.find(c => c.type === 'number')?.name
      if (numericCol) {
        transformations.push({
          operation: 'sort',
          description: `Sort by ${numericCol} in descending order for better visual impact`,
          parameters: {
            column: numericCol,
            direction: 'desc'
          },
          output_columns: data.columns.map(c => c.name)
        })
      }
    }
    
    // Sort by time for time series
    if (['line', 'area'].includes(chartType)) {
      const dateCol = data.columns.find(c => c.type === 'date')?.name
      if (dateCol) {
        transformations.push({
          operation: 'sort',
          description: `Sort by ${dateCol} in ascending order for time series`,
          parameters: {
            column: dateCol,
            direction: 'asc'
          },
          output_columns: data.columns.map(c => c.name)
        })
      }
    }
    
    return transformations
  }

  private static generateFormatting(data: SQLResultSet, chartConfig: any): TransformationStep[] {
    const transformations: TransformationStep[] = []
    
    // Format numeric values
    const numericColumns = data.columns.filter(c => c.type === 'number')
    numericColumns.forEach(col => {
      // Determine if this looks like currency
      const isCurrency = col.name.toLowerCase().includes('revenue') || 
                        col.name.toLowerCase().includes('price') ||
                        col.name.toLowerCase().includes('cost') ||
                        col.name.toLowerCase().includes('peso')
      
      if (isCurrency) {
        transformations.push({
          operation: 'format',
          description: `Format ${col.name} as Philippine Peso currency`,
          parameters: {
            column: col.name,
            format: 'currency',
            currency: 'PHP',
            locale: 'en-PH'
          },
          output_columns: [col.name]
        })
      }
    })
    
    return transformations
  }
}

// =============================================================================
// ACCESSIBILITY ENGINE
// =============================================================================

class AccessibilityEngine {
  static generateAccessibilityConfig(
    chartType: ChartSpecification['chart_type'],
    data: SQLResultSet,
    styling: ChartStyling
  ): AccessibilityConfig {
    
    return {
      wcag_level: 'AA',
      color_blind_safe: this.isColorBlindSafe(styling.color_palette),
      high_contrast_mode: this.hasHighContrast(styling.color_palette),
      screen_reader_support: true,
      keyboard_navigation: true,
      alt_text: this.generateAltText(chartType, data),
      data_table_fallback: true
    }
  }

  private static isColorBlindSafe(colors: string[]): boolean {
    // Simplified check - in production, would use proper color difference algorithms
    const colorBlindSafePalettes = [
      ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728'], // Tableau default
      ['#3366CC', '#DC3912', '#FF9900', '#109618'], // Google Charts
      ['#4285F4', '#34A853', '#FBBC04', '#EA4335']  // Google brand
    ]
    
    return colorBlindSafePalettes.some(palette => 
      colors.every(color => palette.includes(color))
    )
  }

  private static hasHighContrast(colors: string[]): boolean {
    // Simplified contrast check
    return colors.length <= 8 // Fewer colors generally means better contrast
  }

  private static generateAltText(chartType: string, data: SQLResultSet): string {
    const rowCount = data.rows.length
    const columnNames = data.columns.map(c => c.name).join(', ')
    
    const chartTypeDescriptions = {
      'line': 'Line chart showing trends over time',
      'bar': 'Bar chart comparing values across categories',
      'pie': 'Pie chart showing proportional breakdown',
      'scatter': 'Scatter plot showing correlation between variables',
      'heatmap': 'Heatmap showing intensity patterns',
      'treemap': 'Treemap showing hierarchical data',
      'funnel': 'Funnel chart showing sequential process',
      'area': 'Area chart showing cumulative trends'
    }
    
    const description = chartTypeDescriptions[chartType as keyof typeof chartTypeDescriptions] || 
                       `${chartType} chart`
    
    return `${description} with ${rowCount} data points. Columns: ${columnNames}.`
  }
}

// =============================================================================
// RESPONSIVE DESIGN ENGINE
// =============================================================================

class ResponsiveDesignEngine {
  static generateBreakpoints(
    baseChart: ChartSpecification,
    data: SQLResultSet
  ): BreakpointConfig[] {
    
    return [
      {
        breakpoint: 'mobile',
        min_width: 320,
        chart_config_override: this.getMobileOverrides(baseChart, data)
      },
      {
        breakpoint: 'tablet',
        min_width: 768,
        chart_config_override: this.getTabletOverrides(baseChart, data)
      },
      {
        breakpoint: 'desktop',
        min_width: 1024,
        chart_config_override: {} // Use base configuration
      },
      {
        breakpoint: 'large',
        min_width: 1440,
        chart_config_override: this.getLargeOverrides(baseChart, data)
      }
    ]
  }

  private static getMobileOverrides(baseChart: ChartSpecification, data: SQLResultSet): Partial<ChartSpecification> {
    return {
      layout: {
        ...baseChart.layout,
        width: '100%',
        height: 300,
        margin: { top: 20, right: 10, bottom: 60, left: 40 },
        legend: {
          ...baseChart.layout.legend,
          position: 'bottom',
          orientation: 'horizontal'
        }
      },
      styling: {
        ...baseChart.styling,
        font_sizes: {
          title: 14,
          axis_label: 10,
          tick_label: 9,
          legend: 9
        }
      }
    }
  }

  private static getTabletOverrides(baseChart: ChartSpecification, data: SQLResultSet): Partial<ChartSpecification> {
    return {
      layout: {
        ...baseChart.layout,
        width: '100%',
        height: 400,
        margin: { top: 30, right: 20, bottom: 50, left: 50 }
      },
      styling: {
        ...baseChart.styling,
        font_sizes: {
          title: 16,
          axis_label: 12,
          tick_label: 10,
          legend: 10
        }
      }
    }
  }

  private static getLargeOverrides(baseChart: ChartSpecification, data: SQLResultSet): Partial<ChartSpecification> {
    return {
      layout: {
        ...baseChart.layout,
        height: 600,
        margin: { top: 40, right: 40, bottom: 60, left: 80 }
      },
      styling: {
        ...baseChart.styling,
        font_sizes: {
          title: 20,
          axis_label: 14,
          tick_label: 12,
          legend: 12
        }
      }
    }
  }
}

// =============================================================================
// MAIN CHART VISION AGENT
// =============================================================================

class ChartVisionAgent {
  static async process(request: ChartVisionAgentRequest): Promise<ChartVisionAgentResponse> {
    const startTime = Date.now()
    
    try {
      // 1. Get chart type recommendation
      const recommendation = ChartTypeRecommendationEngine.recommend(
        request.query_results,
        request.visualization_intent,
        request.audience_context
      )
      
      // 2. Generate chart configuration
      const chartConfig = this.generateChartConfiguration(
        request.query_results,
        recommendation.type,
        request.brand_guidelines
      )
      
      // 3. Generate data transformations
      const transformations = DataTransformationEngine.generateTransformations(
        request.query_results,
        recommendation.type,
        chartConfig.chart_config
      )
      
      // 4. Generate accessibility configuration
      const accessibilityConfig = AccessibilityEngine.generateAccessibilityConfig(
        recommendation.type,
        request.query_results,
        chartConfig.styling
      )
      
      // 5. Generate responsive breakpoints
      const breakpoints = ResponsiveDesignEngine.generateBreakpoints(
        chartConfig,
        request.query_results
      )
      
      return {
        chart_specifications: [chartConfig],
        data_transformations: transformations,
        accessibility_metadata: accessibilityConfig,
        responsive_breakpoints: breakpoints,
        recommendation_metadata: {
          confidence_score: recommendation.confidence,
          chart_rationale: recommendation.rationale,
          alternative_options: recommendation.alternatives,
          processing_time_ms: Date.now() - startTime
        }
      }
      
    } catch (error) {
      return {
        chart_specifications: [],
        data_transformations: [],
        accessibility_metadata: {
          wcag_level: 'AA',
          color_blind_safe: false,
          high_contrast_mode: false,
          screen_reader_support: false,
          keyboard_navigation: false,
          alt_text: 'Chart generation failed',
          data_table_fallback: true
        },
        responsive_breakpoints: [],
        recommendation_metadata: {
          confidence_score: 0,
          chart_rationale: `Error: ${error.message}`,
          alternative_options: [],
          processing_time_ms: Date.now() - startTime
        }
      }
    }
  }

  private static generateChartConfiguration(
    data: SQLResultSet,
    chartType: ChartSpecification['chart_type'],
    brandGuidelines?: DesignSystemContext
  ): ChartSpecification {
    
    const columns = data.columns
    
    // Determine axes based on chart type and data structure
    const { xAxis, yAxis, grouping } = this.determineAxesConfiguration(columns, chartType)
    
    // Generate styling based on brand guidelines
    const styling = this.generateStyling(brandGuidelines)
    
    // Generate interactions
    const interactions = this.generateInteractions(chartType)
    
    // Generate layout
    const layout = this.generateLayout(chartType, data)
    
    return {
      chart_type: chartType,
      chart_config: {
        x_axis: xAxis,
        y_axis: yAxis,
        grouping
      },
      styling,
      interactions,
      layout
    }
  }

  private static determineAxesConfiguration(columns: ColumnMetadata[], chartType: string) {
    // Find the best columns for X and Y axes
    const dateColumns = columns.filter(c => c.type === 'date')
    const stringColumns = columns.filter(c => c.type === 'string')
    const numberColumns = columns.filter(c => c.type === 'number')
    
    let xAxis: AxisConfig
    let yAxis: AxisConfig
    let grouping: GroupingConfig | undefined
    
    // Default axis configuration based on chart type
    switch (chartType) {
      case 'line':
      case 'area':
        xAxis = {
          column: dateColumns[0]?.name || stringColumns[0]?.name || columns[0].name,
          label: this.formatLabel(dateColumns[0]?.name || stringColumns[0]?.name || columns[0].name),
          scale: dateColumns[0] ? 'time' : 'categorical'
        }
        yAxis = {
          column: numberColumns[0]?.name || columns[1].name,
          label: this.formatLabel(numberColumns[0]?.name || columns[1].name),
          scale: 'linear'
        }
        break
        
      case 'bar':
        xAxis = {
          column: stringColumns[0]?.name || columns[0].name,
          label: this.formatLabel(stringColumns[0]?.name || columns[0].name),
          scale: 'categorical'
        }
        yAxis = {
          column: numberColumns[0]?.name || columns[1].name,
          label: this.formatLabel(numberColumns[0]?.name || columns[1].name),
          scale: 'linear'
        }
        break
        
      case 'scatter':
        xAxis = {
          column: numberColumns[0]?.name || columns[0].name,
          label: this.formatLabel(numberColumns[0]?.name || columns[0].name),
          scale: 'linear'
        }
        yAxis = {
          column: numberColumns[1]?.name || columns[1].name,
          label: this.formatLabel(numberColumns[1]?.name || columns[1].name),
          scale: 'linear'
        }
        // Use third column for grouping if available
        if (stringColumns.length > 0) {
          grouping = {
            column: stringColumns[0].name,
            label: this.formatLabel(stringColumns[0].name),
            color_scheme: this.getDefaultColors(),
            max_groups: 10
          }
        }
        break
        
      default:
        xAxis = {
          column: columns[0].name,
          label: this.formatLabel(columns[0].name),
          scale: columns[0].type === 'date' ? 'time' : 'categorical'
        }
        yAxis = {
          column: columns[1]?.name || columns[0].name,
          label: this.formatLabel(columns[1]?.name || columns[0].name),
          scale: 'linear'
        }
    }
    
    return { xAxis, yAxis, grouping }
  }

  private static formatLabel(columnName: string): string {
    return columnName
      .split('_')
      .map(word => word.charAt(0).toUpperCase() + word.slice(1))
      .join(' ')
  }

  private static getDefaultColors(): string[] {
    return [
      '#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd',
      '#8c564b', '#e377c2', '#7f7f7f', '#bcbd22', '#17becf'
    ]
  }

  private static generateStyling(brandGuidelines?: DesignSystemContext): ChartStyling {
    return {
      color_palette: brandGuidelines?.primary_colors || this.getDefaultColors(),
      theme: 'light',
      font_family: brandGuidelines?.font_stack?.[0] || 'Inter, system-ui, sans-serif',
      font_sizes: {
        title: 18,
        axis_label: 12,
        tick_label: 10,
        legend: 11
      },
      spacing: {
        padding: 16,
        margin: 20,
        legend_gap: 8
      },
      brand_compliance: !!brandGuidelines
    }
  }

  private static generateInteractions(chartType: string): InteractionConfig {
    return {
      tooltip_enabled: true,
      zoom_enabled: ['line', 'area', 'scatter'].includes(chartType),
      pan_enabled: ['line', 'area', 'scatter'].includes(chartType),
      brush_selection: ['scatter'].includes(chartType),
      click_actions: [
        {
          trigger: 'click',
          action: 'highlight',
          target: 'series'
        }
      ]
    }
  }

  private static generateLayout(chartType: string, data: SQLResultSet): LayoutConfig {
    return {
      width: '100%',
      height: 500,
      margin: { top: 40, right: 30, bottom: 50, left: 60 },
      legend: {
        position: 'right',
        orientation: 'vertical',
        wrap_length: 20
      },
      title: {
        text: this.generateTitle(chartType, data),
        alignment: 'left',
        font_size: 18
      }
    }
  }

  private static generateTitle(chartType: string, data: SQLResultSet): string {
    const firstColumn = data.columns[0]?.name || 'Data'
    const secondColumn = data.columns[1]?.name || 'Values'
    
    const chartTypeNames = {
      'line': 'Trend',
      'bar': 'Comparison',
      'pie': 'Distribution',
      'scatter': 'Correlation',
      'heatmap': 'Pattern',
      'treemap': 'Hierarchy',
      'funnel': 'Conversion',
      'area': 'Cumulative Trend'
    }
    
    const chartTypeName = chartTypeNames[chartType as keyof typeof chartTypeNames] || 'Analysis'
    
    return `${this.formatLabel(secondColumn)} by ${this.formatLabel(firstColumn)}`
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
    const request: ChartVisionAgentRequest = await req.json()
    
    // Validate required fields
    if (!request.query_results || !request.user_context?.tenant_id) {
      return new Response(JSON.stringify({ 
        error: 'Missing required fields: query_results, user_context.tenant_id' 
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    const response = await ChartVisionAgent.process(request)
    
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