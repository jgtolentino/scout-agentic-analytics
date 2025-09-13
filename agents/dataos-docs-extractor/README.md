# DataOS Documentation Extractor & Diff Engine

Production-grade documentation extraction, archiving, and version comparison for any web-based documentation system.

## Features

- 🔎 **Full-site Extraction** - Crawl & export all docs (HTML, Markdown, PDF)
- ⚡ **Dynamic Content Support** - Headless browser for JS-heavy documentation
- 📆 **Scheduled Snapshots** - Automated extraction with cron scheduling  
- 🧠 **Semantic Diff** - Content-aware diff (not just line-by-line)
- 📝 **Visual Diff** - Screenshot comparison for visual changes
- 🗄️ **Archive Management** - Timestamped snapshots with compression
- 📤 **Notifications** - Webhook, Slack, and email alerts
- 🏷️ **Structure Extraction** - TOC/heading extraction as JSON
- 🔒 **Authentication Support** - Handle private docs with various auth methods
- 📊 **Change Analytics** - Comprehensive reports and insights

## Installation

```bash
# Clone the repository
git clone https://github.com/tbwa/dataos-docs-extractor.git
cd dataos-docs-extractor

# Install dependencies
pip install -r requirements.txt

# Install Playwright browsers
playwright install chromium

# Make CLI executable
chmod +x main.py
```

## Quick Start

### CLI Usage

```bash
# Extract documentation
python main.py extract --source https://dataos.info --format markdown

# Compare two snapshots
python main.py diff --archive1 /dataos-archives/20240807 --archive2 /dataos-archives/20240808

# Schedule daily extraction
python main.py schedule --source https://dataos.info --cron "0 2 * * *"

# Analyze an archive
python main.py analyze --archive /dataos-archives/20240808
```

### API Usage

```bash
# Start API server
python api.py

# Or with uvicorn
uvicorn api:app --reload
```

API endpoints:
- `POST /api/extract` - Start extraction task
- `POST /api/diff` - Compare archives
- `GET /api/archives` - List archives
- `POST /api/analyze` - Analyze archive
- `POST /api/schedule` - Schedule extraction

## Configuration

The agent can be configured via `dataos-docs-extractor.yaml`:

```yaml
agent:
  config:
    extraction:
      default_method: "hybrid"  # static, dynamic, hybrid
      timeout: 300             # 5 minutes per page
      max_depth: 10           # Max crawl depth
      max_pages: 10000        # Safety limit
      
    archive:
      base_path: "/dataos-archives"
      retention_days: 365
      compression: true
      
    notifications:
      enabled: true
      channels:
        - type: webhook
          url: "${WEBHOOK_URL}"
        - type: slack
          channel: "#docs-updates"
```

## Extraction Methods

### Static (wget)
Fast extraction for simple HTML documentation:
```bash
python main.py extract --source https://docs.example.com --method static
```

### Dynamic (Playwright)
For JavaScript-heavy documentation:
```bash
python main.py extract --source https://spa-docs.example.com --method dynamic
```

### Hybrid (Default)
Combines static crawling with dynamic re-extraction for JS content:
```bash
python main.py extract --source https://modern-docs.example.com --method hybrid
```

## Authentication

Handle private documentation with various auth methods:

```bash
# Cookie authentication
python main.py extract --source https://private.docs.com \
  --auth '{"method": "cookie", "credentials": {"cookies": [{"name": "session", "value": "..."}]}}'

# Basic authentication  
python main.py extract --source https://private.docs.com \
  --auth '{"method": "basic", "credentials": {"username": "user", "password": "pass"}}'
```

## Diff Modes

### Semantic Diff
Content-aware comparison that understands document structure:
```bash
python main.py diff --archive1 /path/to/archive1 --archive2 /path/to/archive2 --mode semantic
```

### Visual Diff
Screenshot-based comparison for visual changes:
```bash
python main.py diff --archive1 /path/to/archive1 --archive2 /path/to/archive2 --mode visual
```

### Both (Default)
Combines semantic and visual diff:
```bash
python main.py diff --archive1 /path/to/archive1 --archive2 /path/to/archive2 --mode both
```

## Archive Structure

```
/dataos-archives/
├── 20240808_143022/
│   ├── metadata.json        # Extraction metadata
│   ├── index.html          # Homepage
│   ├── index.md            # Markdown version
│   ├── getting-started/
│   │   ├── index.html
│   │   └── index.md
│   ├── api-reference/
│   │   ├── index.html
│   │   └── index.md
│   └── toc.json           # Table of contents
├── diffs/
│   └── 20240807_vs_20240808_143500/
│       ├── semantic_diff.md
│       └── visual/
│           ├── index.html_v1.png
│           ├── index.html_v2.png
│           └── index.html_diff.png
└── schedules/
    └── schedule_20240808_143022.json
```

## Notifications

Configure webhooks for change notifications:

```python
# In your code
notification_config = {
    "enabled": True,
    "channels": [
        {
            "type": "webhook",
            "url": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
        },
        {
            "type": "email",
            "recipients": ["team@example.com"]
        }
    ]
}
```

## API Examples

### Start Extraction
```bash
curl -X POST http://localhost:8000/api/extract \
  -H "Content-Type: application/json" \
  -d '{
    "source_url": "https://dataos.info",
    "output_format": "markdown",
    "extraction_method": "hybrid"
  }'
```

### Check Task Status
```bash
curl http://localhost:8000/api/tasks/extract_20240808_143022_12345
```

### List Archives
```bash
curl http://localhost:8000/api/archives?source_url=https://dataos.info
```

### Download Archive
```bash
curl http://localhost:8000/api/archives/20240808_143022/download -o archive.tar.gz
```

## Performance

- **Static extraction**: ~100 pages/minute
- **Dynamic extraction**: ~10-20 pages/minute  
- **Hybrid extraction**: ~50 pages/minute
- **Diff computation**: <5 seconds for 1000 pages
- **Visual diff**: ~1 second per page

## Use Cases

1. **Documentation Monitoring** - Track changes in SaaS documentation
2. **Compliance Archiving** - Maintain auditable documentation history
3. **Competitive Analysis** - Compare competitor documentation changes
4. **Knowledge Base Building** - Create structured snapshots for RAG/LLM
5. **Change Management** - Automated change logs and notifications

## Troubleshooting

### Playwright Issues
```bash
# Reinstall browsers
playwright install --with-deps chromium

# Check browser installation
playwright install --list
```

### Memory Issues
For large documentation sites, increase memory limits:
```bash
export NODE_OPTIONS="--max-old-space-size=4096"
python main.py extract --source https://huge-docs.example.com
```

### Authentication Failures
Enable debug logging:
```bash
export LOG_LEVEL=DEBUG
python main.py extract --source https://private-docs.com --auth '...'
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

- Issues: GitHub Issues
- Email: dataos-extractor@tbwa.com
- Docs: https://docs.tbwa.com/dataos-extractor