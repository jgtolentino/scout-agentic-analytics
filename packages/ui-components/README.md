# @scout/ui-components

Unified component library for Scout Dashboard applications, now including Amazon dashboard design patterns.

## Components

### Scout Components
- **MetricCard**: Display metrics with trends and variants
- **LoadingSpinner**: Configurable loading indicators  
- **ErrorBoundary**: Production error handling

### Amazon Dashboard Components
- **AmazonLayout**: Complete fixed-sidebar layout system
- **Sidebar**: Navigation with logo, links, and footer
- **AmazonMetricCard**: Icon-based metric cards (migrated from Dash)
- **AmazonChartCard**: Plotly.js chart containers with loading states
- **AmazonDropdown**: Styled select components

## Design System

### Amazon Design Tokens
```typescript
import { amazonTokens } from '@scout/ui-components';

// Colors
amazonTokens.colors.primary        // #f79500 (Amazon orange)
amazonTokens.colors.textPrimary     // #3a4552 (Dark gray)
amazonTokens.colors.background      // #f5f5f5 (Light gray)

// Layout
amazonTokens.layout.sidebar.width   // 16rem
amazonTokens.spacing.cardPadding    // 25px
amazonTokens.shadows.card           // 0 6px 8px rgba(89, 87, 87, 0.1)
```

## Chart Patterns

### Amazon Chart Hooks
```typescript
import { useAmazonCharts } from '@scout/ui-components';

const { createBarChart, createTreemap, createPieChart } = useAmazonCharts();

// Create Amazon-styled bar chart
const salesChart = createBarChart(
  { x: months, y: sales, text: salesText },
  'Monthly Sales',
  { showText: true, textPosition: 'outside' }
);
```

## Migration Guide: Dash → Next.js

### Layout Migration
```tsx
// Before (Dash)
app.layout = html.Div([sidebar, dash.page_container])

// After (Next.js)
<AmazonLayout sidebar={{
  navigation: [
    { label: 'Purchase Overview', href: '/purchase-overview' },
    { label: 'Customer Demographics', href: '/demographics' },
  ],
  footer: {
    createdBy: { name: 'Your Name', href: 'https://github.com/yourname' }
  }
}}>
  {children}
</AmazonLayout>
```

### Card Migration
```tsx
// Before (Dash)
create_card("Purchases", "purchases-card", "fa-list")

// After (Next.js)
<AmazonMetricCard
  title="Purchases"
  value={purchaseCount}
  icon="fa-list"
  id="purchases-card"
/>
```

### Chart Migration
```tsx
// Before (Dash)
dcc.Graph(id="sales-chart", figure=px.bar(...))

// After (Next.js)
<AmazonChartCard
  id="sales-chart"
  figure={createBarChart(data, "Sales Chart")}
  loading={isLoading}
/>
```

## Installation

```bash
npm install @scout/ui-components
```

## Usage

```tsx
import { 
  AmazonLayout, 
  AmazonMetricCard, 
  AmazonChartCard,
  useAmazonCharts,
  amazonTokens 
} from '@scout/ui-components';

export default function Dashboard() {
  const { createBarChart } = useAmazonCharts();
  
  return (
    <AmazonLayout sidebar={{...}}>
      <div className="title">Dashboard</div>
      
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '1rem' }}>
        <AmazonMetricCard title="Sales" value="$1,234" icon="fa-coins" />
        <AmazonMetricCard title="Orders" value="56" icon="fa-list" />
        <AmazonMetricCard title="Customers" value="789" icon="fa-users" />
      </div>
      
      <AmazonChartCard 
        figure={createBarChart(chartData, "Monthly Trends")}
        height="400px"
      />
    </AmazonLayout>
  );
}
```

## Design Compatibility

✅ **Full Amazon Dashboard Compatibility**
- Exact color scheme and typography
- Fixed sidebar layout (16rem width)
- Card shadows and spacing
- FontAwesome icon system
- Plotly.js chart integration
- Responsive breakpoints

✅ **Next.js Optimizations**
- SSR-safe Plotly.js imports
- TypeScript definitions
- Performance optimizations
- Modern React patterns