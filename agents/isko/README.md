# Isko Agent - Intelligent SKU Discovery

Isko is a production-grade web scraping agent that automatically discovers and catalogs FMCG (Fast-Moving Consumer Goods) and Tobacco SKUs from configured e-commerce sites.

## Features

- 🔍 Automated SKU discovery from multiple sources
- 📊 Real-time synchronization with Supabase database
- 🚀 Production-ready FastAPI/Edge Function deployment
- 📈 Built-in analytics and monitoring
- 🔄 Configurable scheduling and retry logic
- 🛡️ Rate limiting and error handling

## Quick Start

### 1. Prerequisites

- Python 3.11+ or Node.js 18+ (for Edge Function)
- Docker and Docker Compose
- Supabase account with project created
- Pulser MCP (optional, for orchestration)

### 2. Configuration

1. Copy the environment template:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` with your credentials:
   - Supabase URL and keys
   - Target URLs for scraping
   - Agent configuration

3. Customize `isko-config.yaml` with your scraping targets

### 3. Database Setup

Run the schema creation script in your Supabase SQL editor:

```bash
# Or use Supabase CLI
supabase db push
```

### 4. Deployment

#### Option A: Docker Deployment
```bash
# Build and run with Docker Compose
./deploy.sh
```

#### Option B: Supabase Edge Function
```bash
# Deploy as Edge Function
supabase functions deploy isko_scraper
```

#### Option C: Python Service
```bash
# Install dependencies
pip install -r requirements.txt

# Run the service
uvicorn api:app --host 0.0.0.0 --port 8000
```

## API Endpoints

### GET /scrape
Triggers SKU discovery and returns results.

**Response:**
```json
[
  {
    "sku_id": "SKU123",
    "brand_name": "Brand",
    "sku_name": "Product Name",
    "pack_size": 500,
    "pack_unit": "ml",
    "category": "Beverage",
    "price": 25.50
  }
]
```

### GET /health
Health check endpoint.

### GET /stats
Returns scraping statistics.

## Configuration

### Scraping Targets

Edit `isko-config.yaml` to add new targets:

```yaml
scraping_targets:
  - category: "New Category"
    url: "https://example.com/products"
```

### CSS Selectors

Customize selectors in the config:

```yaml
selectors:
  product_card: ".product-item"
  sku_code: ".item-code"
  sku_name: ".item-title"
```

## Monitoring

- View logs: `docker-compose logs -f isko-agent`
- Check metrics in Supabase dashboard
- Query scraping history:
  ```sql
  SELECT * FROM get_scraping_stats(30);
  ```

## Troubleshooting

### Common Issues

1. **Connection errors**: Check your `.env` credentials
2. **No SKUs found**: Verify CSS selectors match target site
3. **Rate limiting**: Adjust `rate_limit_delay` in config

### Debug Mode

Enable debug logging:
```bash
export ISKO_LOG_LEVEL=debug
```

## Development

### Running Tests
```bash
pytest tests/
```

### Adding New Sites

1. Add target to `isko-config.yaml`
2. Test selectors with browser dev tools
3. Run a test scrape: `curl http://localhost:8000/scrape`

## Security

- Never commit `.env` files
- Use service role keys only in secure environments
- Implement rate limiting for public endpoints
- Validate all scraped data before storage

## License

Part of InsightPulseAI SKR - See main repository for license details.