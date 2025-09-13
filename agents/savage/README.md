# Agent Savage - Brand-Aligned Pattern & Visualization Generator

Agent Savage transforms raw data, themes, or brand guidelines into luxury-grade SVG/GIF pattern assets and infographic visualizations. Built for clients like UNDP, OCHA, and corporate partners.

## Features

- 🎨 **Brand-Aligned Patterns**: Generate patterns that perfectly match brand guidelines
- ⚡ **Real-time Preview**: Live SVG rendering with instant parameter updates
- 🎬 **Animated Exports**: Export patterns as animated GIFs with customizable loops
- 📊 **Data-Driven**: Map data values to visual attributes (size, opacity, color)
- 💬 **Collaboration**: Built-in commenting and approval workflow
- 🔧 **Parametric Control**: Fine-tune spacing, rotation, scale, and more

## Quick Start

### Prerequisites

- Python 3.11+
- Docker & Docker Compose
- Supabase project
- Node.js 18+ (for Edge Function)

### Installation

1. **Clone and setup**
   ```bash
   cd agents/savage
   cp .env.example .env
   # Edit .env with your Supabase credentials
   ```

2. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Run database migrations**
   ```bash
   psql $DATABASE_URL < schema.sql
   ```

4. **Start the service**
   ```bash
   docker-compose up -d
   ```

### Deploy Edge Function

```bash
cd supabase/functions/savage-render
supabase functions deploy savage-render
```

## API Usage

### Create a Project

```bash
curl -X POST http://localhost:8000/projects \
  -H "Content-Type: application/json" \
  -d '{
    "project_name": "UNDP Annual Report",
    "org_type": "undp",
    "brand_json": {
      "primary_color": "#0468B1",
      "secondary_color": "#FFFFFF",
      "accent_color": "#FFC72C"
    }
  }'
```

### Generate a Pattern

```bash
curl -X POST http://localhost:8000/patterns/generate \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": "your-project-id",
    "template_id": "grid-stripes",
    "pattern_name": "Cover Pattern",
    "params": {
      "spacing": 20,
      "rotation": 45,
      "scale": 1,
      "strokeWidth": 3,
      "opacity": 0.8
    }
  }'
```

### Export Pattern

```bash
# Export as SVG
curl -X POST http://localhost:8000/patterns/{pattern_id}/export?format=svg

# Export as GIF
curl -X POST http://localhost:8000/patterns/{pattern_id}/export?format=gif
```

## Available Templates

### Geometric Patterns
- **grid-stripes**: Modern grid with diagonal stripes
- **dot-matrix**: Circular dots with variable density

### Organic Patterns
- **wave-flow**: Flowing wave patterns

### Data-Driven
- **data-bars**: Bar chart patterns for data visualization

## Configuration

### Pattern Parameters

| Parameter | Type | Range | Description |
|-----------|------|-------|-------------|
| spacing | number | 5-50 | Distance between pattern elements |
| rotation | number | 0-360 | Rotation angle in degrees |
| scale | number | 0.5-3 | Scale multiplier |
| strokeWidth | number | 1-10 | Line thickness |
| opacity | number | 0.1-1 | Transparency level |

### Brand Configuration

```json
{
  "primary_color": "#0468B1",
  "secondary_color": "#FFFFFF",
  "accent_color": "#FFC72C",
  "font_family": "Roboto"
}
```

## Frontend Integration

### React Component

```tsx
import { PatternPreview, PatternConfigurator } from '@savage/components'

function App() {
  const [params, setParams] = useState(defaultParams)
  const [brand, setBrand] = useState(defaultBrand)
  
  return (
    <div className="flex gap-4">
      <PatternConfigurator
        params={params}
        brandConfig={brand}
        onParamsChange={setParams}
        onBrandChange={setBrand}
      />
      <PatternPreview
        templateId="grid-stripes"
        params={params}
        brandConfig={brand}
      />
    </div>
  )
}
```

## Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────┐
│ React Frontend  │────▶│ FastAPI      │────▶│  Supabase   │
│ (Live Preview)  │     │ (Generation) │     │ (Storage)   │
└─────────────────┘     └──────────────┘     └─────────────┘
         │                      │
         └──────────┬───────────┘
                    ▼
            ┌──────────────┐
            │ Edge Function│
            │ (Rendering)  │
            └──────────────┘
```

## Development

### Running Tests
```bash
pytest tests/
```

### Code Style
```bash
black src/
flake8 src/
```

### Adding New Templates

1. Add template definition to `schema.sql`
2. Implement generation logic in `src/main.py`
3. Add Edge Function variant in `savage-render/index.ts`
4. Update `savage-config.yaml`

## Monitoring

- Health endpoint: `GET /health`
- Statistics: `GET /stats`
- Pattern analytics tracked automatically

## Security

- Row Level Security enabled on all tables
- Service role key only for server-side operations
- CORS configured for allowed origins
- Input validation on all parameters

## Roadmap

- [ ] AI-powered pattern suggestions
- [ ] Figma plugin integration
- [ ] Advanced data mapping UI
- [ ] Pattern animation timeline editor
- [ ] Template marketplace

## Support

For issues or feature requests, contact the Visual Talent Oracle team.