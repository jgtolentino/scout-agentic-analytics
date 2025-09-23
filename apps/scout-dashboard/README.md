# Scout v7 Dashboard

A comprehensive analytics dashboard for Scout v7 platform, built on Next.js and integrated with Scout's medallion architecture.

## Features

- **Real-time Analytics** - Live transaction and customer data
- **Brand Intelligence** - Market share, CRP analysis, competitive insights
- **Store Performance** - Location-based analytics with geographic visualization
- **Natural Language Queries** - NL2SQL interface for custom analytics
- **Predictive Insights** - AI-powered forecasting and recommendations

## Data Sources

- **Scout Edge Devices** - Real-time transaction data
- **Azure SQL Database** - Historical analytics
- **Supabase** - Medallion architecture (Bronze → Silver → Gold → Platinum)

## Tech Stack

- **Frontend**: Next.js 14, React, TypeScript
- **Styling**: Tailwind CSS, Shadcn/ui
- **Data**: Azure Functions, Supabase Edge Functions
- **Analytics**: NL2SQL, Cross-tabulation views
- **Maps**: Mapbox GL, GeoJSON

## Setup Instructions

### 1. Clone and Install

```bash
# From Vercel source snapshot
cd apps/scout-dashboard
npm ci
```

### 2. Environment Configuration

Create `.env.local`:

```env
# Azure Functions
NEXT_PUBLIC_AZURE_API_BASE=https://fn-scout-readonly.azurewebsites.net/api

# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://cxzllzyxwpyptfretryc.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN4emxsenl4d3B5cHRmcmV0cnljIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUyMDYzMzQsImV4cCI6MjA3MDc4MjMzNH0.H8b3qF7Mz8QKzCZrZr5J8Q9x4Z3kJ2f8X6v4Z3mN1kQ

# Map Services
NEXT_PUBLIC_MAPBOX_TOKEN=<your_mapbox_token>
```

### 3. Development

```bash
npm run dev
```

Visit `http://localhost:3000`

### 4. Deployment

```bash
vercel --prod
```

## Architecture

### Data Flow
```
Scout Edge Devices → Bronze Layer → Silver Layer → Gold Layer → Dashboard
                                                              ↗
Azure SQL Database → MindsDB Federation → Analytics Views → Dashboard
```

### API Endpoints

- `/api/scout/transactions` - Transaction data with filtering
- `/api/scout/analytics` - Pre-computed analytics views
- `/api/scout/kpis` - Key performance indicators
- `/api/scout/brands` - Brand performance metrics
- `/api/scout/nl2sql` - Natural language query interface

### Component Structure

```
/components
  /scout
    /analytics     - Analytics dashboards
    /brands        - Brand performance
    /stores        - Store analytics
    /customers     - Customer insights
    /maps          - Geographic visualization
  /ui              - Shared UI components
```

## Data Models

### Transaction Model
```typescript
interface ScoutTransaction {
  transaction_id: string;
  store_id: string;
  device_id: string;
  facial_id: string;
  brand: string;
  category: string;
  total_price: number;
  transaction_ts: string;
  age: number;
  gender: string;
  emotion: string;
  latitude: number;
  longitude: number;
}
```

### Analytics Model
```typescript
interface BrandAnalytics {
  brand_name: string;
  market_share_percent: number;
  consumer_reach_points: number;
  avg_price_php: number;
  brand_tier: string;
  growth_status: string;
  competitive_status: string;
}
```

## Performance

- **Query Speed**: <200ms for 95% of analytics queries
- **Data Freshness**: <10s for real-time data
- **Cache TTL**: 5 minutes for analytics views
- **Geographic Data**: GeoJSON with WebGL rendering

## Security

- **Row-Level Security**: Store-based access control
- **Authentication**: Azure AD integration
- **API Keys**: Managed through Azure Key Vault
- **Data Masking**: PII protection for customer data

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Create Pull Request

## License

MIT License - see LICENSE file for details

## Support

For issues and questions:
- Create GitHub issue
- Contact: scout-support@tbwa.com
- Documentation: [Scout v7 Docs](../docs/)