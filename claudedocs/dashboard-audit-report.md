# Dashboard Consolidation Audit Report

## Current State Analysis

### Vite Dashboard (standalone-dashboard-v7-enhanced)
- **Components**: 33 TypeScript React components
- **Framework**: React 18.2.0 + Vite 5.0.8
- **State Management**: Zustand + custom dataStore
- **Visualization**: Plotly, Recharts, D3, React-Plotly
- **Styling**: Tailwind CSS 3.4.0

### Next.js Dashboard (standalone-dashboard-nextjs)  
- **Components**: 38 TypeScript React components
- **Framework**: Next.js 15.5.3 + React 19.1.0
- **State Management**: React Query + Zustand
- **Visualization**: Plotly, React-Plotly, custom charts
- **Styling**: Tailwind CSS 4.0

## Component Analysis

### Unique to Vite App (Migration Required):
1. **Core Dashboard Components**:
   - `ConsumerBehavior.tsx` - Behavior analytics dashboard
   - `ConsumerProfiling.tsx` - Demographics and profiling
   - `CompetitiveAnalysis.tsx` - Competition insights
   - `GeographicAnalysis.tsx` - Location-based analytics
   - `DashboardOverview.tsx` - Executive summary
   - `TransactionTrends.tsx` - Transaction analytics
   - `ProductMixSKU.tsx` - Product mix analysis

2. **AI/Chat Components**:
   - `ScoutAIAssistant.tsx` - AI chat interface
   - `AssistantPanel.tsx` - Assistant panel wrapper

3. **Chart Renderers**:
   - `ChartRenderer.tsx` - Generic chart wrapper
   - `AdHocChartRenderer.tsx` - Dynamic chart creation
   - `v7/Renderer.tsx` - V7-specific renderer
   - `v7/EnhancedRenderer.tsx` - Enhanced rendering logic

4. **Layout Components**:
   - `Sidebar.tsx` - Navigation sidebar
   - `TopNav.tsx` - Top navigation
   - `Dashboard.tsx` - Main dashboard container

### Unique to Next.js App (Keep/Enhance):
1. **ETL Components**:
   - `ETLDashboardViewer.tsx` - ETL monitoring
   - `ETLStatusCard.tsx` - Pipeline status
   - `ETLMirrorControls.tsx` - Data mirroring
   - `ETLExportForm.tsx` - Export controls

2. **Advanced Charts**:
   - `ChordSubstitutions.tsx` - Brand substitution flows
   - `CohortRetention.tsx` - Customer retention analysis  
   - `JourneyFunnel.tsx` - Customer journey mapping
   - `BrandSankey.tsx` - Brand flow diagrams
   - `PhilippinesMap.tsx` - Geographic visualization

3. **AI/ML Components**:
   - `FloatingAssistant.tsx` - Floating AI interface
   - `MindsDBInsights.tsx` - ML predictions
   - `ForecastCard.tsx` - Forecasting components

4. **Infrastructure**:
   - `LayoutClient.tsx` - Client-side layout
   - `CollapsibleFilterPanel.tsx` - Advanced filtering

### Overlapping Components (Consolidate):
1. **Basic Charts**: Both have similar bar, line, pie charts
2. **UI Components**: Both have metric cards, filters
3. **Export/Tools**: Both have export functionality
4. **Navigation**: Similar sidebar/nav patterns

## Dependencies Analysis

### Vite Dependencies to Migrate:
```json
{
  "plotly.js": "^2.27.1",
  "react": "^18.2.0", 
  "react-dom": "^18.2.0",
  "recharts": "^2.10.4",
  "zustand": "^4.4.7",
  "tailwindcss": "^3.4.0"
}
```

### Next.js Dependencies to Keep:
```json
{
  "next": "15.5.3",
  "react": "19.1.0",
  "react-dom": "19.1.0", 
  "@tanstack/react-query": "5.87.4",
  "zustand": "5.0.8",
  "tailwindcss": "^4"
}
```

### Duplicate Dependencies:
- Plotly.js (both versions can be unified)
- React-Hot-Toast (keep single version)
- Zustand (upgrade Vite version)
- HTML2Canvas (keep single version)

## Migration Strategy

### Phase 2A: Component Library Setup
1. Create `/packages/ui-components` shared library
2. Extract common components (MetricCard, Charts, Filters)
3. Standardize on Next.js 15 + React 19

### Phase 2B: Dashboard Migration  
1. Port Vite dashboard components to Next.js structure
2. Migrate state management to unified pattern
3. Update data fetching to React Query

### Phase 2C: Cleanup
1. Remove duplicate dependencies
2. Consolidate styling approach
3. Update all imports and references

## Expected Benefits

### Performance:
- Single framework reduces bundle size
- Next.js 15 improved performance
- Unified build pipeline

### Maintainability:
- Single codebase for all dashboards
- Shared component library
- Consistent patterns

### Developer Experience:
- Single dev server
- Unified tooling
- Better TypeScript support

## Migration Timeline

- **Day 1**: Component library setup
- **Day 2-3**: Core dashboard component migration
- **Day 4**: State management consolidation  
- **Day 5**: Testing and cleanup

## Risk Mitigation

- Keep both apps running during migration
- Progressive migration by component
- Comprehensive testing at each step
- Rollback plan with backup branch