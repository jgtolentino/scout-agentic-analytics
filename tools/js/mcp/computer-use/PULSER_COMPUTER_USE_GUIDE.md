# Pulser Computer Use Integration Guide

## Overview

This guide explains how to use Claude's computer use capabilities within the Pulser ecosystem. Computer use allows Claude to interact with desktop environments through screenshots, mouse control, and keyboard input.

## Quick Start Commands

### Basic Usage
```bash
# Simple task
:computer-use "Take a screenshot of the desktop"

# Web automation
:computer-use "Open Firefox and search for 'InsightPulse retail analytics'"

# Complex automation
:computer-use "Create a presentation about our Scout Dashboard metrics"
```

### Advanced Usage with Constraints
```bash
# With step limit
:computer-use "Extract data from the website" --max-steps 10

# With timeout
:computer-use "Fill out the form on the page" --timeout 120

# Combined with other tools
:chain computer-use "Find the data file" | grep "scout_metrics"
```

## Architecture Integration

### 1. MCP Server Components

```
/tools/js/mcp/computer-use/
├── src/
│   ├── index.ts              # MCP server entry point
│   ├── computer-use-tool.ts  # Tool implementation
│   ├── agent-loop.ts         # Claude interaction loop
│   └── security-sandbox.ts   # Security controls
├── docker-compose.yml        # Container orchestration
├── Dockerfile               # Virtual environment setup
└── package.json            # Dependencies
```

### 2. Docker Environment

The computer use environment runs in an isolated Docker container with:
- Virtual X11 display (Xvfb)
- VNC server for remote viewing
- Pre-installed applications (Firefox, LibreOffice, etc.)
- Security restrictions

### 3. Pulser CLI Integration

```yaml
# .pulserrc configuration
computer_use:
  enabled: true
  docker_compose: ./tools/js/mcp/computer-use/docker-compose.yml
  security:
    enable_internet: false
    allowed_domains:
      - localhost
      - insightpulse.ai
  display:
    width: 1024
    height: 768
```

## Security Best Practices

### 1. Isolation
- Always run in Docker container
- Use minimal privileges
- No access to host filesystem

### 2. Network Restrictions
```yaml
# Restrict internet access
security:
  enable_internet: false
  allowed_domains:
    - api.insightpulse.ai
    - dashboard.localhost
```

### 3. Sensitive Data Protection
- Never provide login credentials
- Avoid accessing banking/financial sites
- Use read-only access when possible

### 4. Rate Limiting
Built-in rate limits prevent abuse:
- Screenshots: 60/minute
- Clicks: 100/minute
- Typing: 50/minute

## Common Use Cases

### 1. Web Scraping
```bash
:computer-use "Navigate to https://example.com and extract the product prices into a CSV file"
```

### 2. Form Automation
```bash
:computer-use "Fill out the contact form with test data and submit"
```

### 3. Application Testing
```bash
:computer-use "Open the Scout Dashboard and verify all charts load correctly"
```

### 4. Report Generation
```bash
:computer-use "Create a PDF report from the dashboard data using LibreOffice"
```

## Combining with Other Pulser Tools

### 1. With File Operations
```bash
# Extract data and save
:computer-use "Extract table data from the website" && \
:file-write extracted_data.csv
```

### 2. With Data Analysis
```bash
# Capture dashboard and analyze
:computer-use "Take screenshots of all dashboard pages" && \
:analyze-images --extract-metrics
```

### 3. With Agent Chains
```yaml
# Multi-agent workflow
agents:
  - name: web-scraper
    tool: computer-use
    task: "Extract competitor pricing"
  - name: data-analyzer
    tool: python
    task: "Analyze pricing trends"
  - name: report-generator
    tool: computer-use
    task: "Create presentation"
```

## Troubleshooting

### Display Issues
```bash
# Check display
docker exec pulser-computer-use echo $DISPLAY

# Restart X11
docker exec pulser-computer-use pkill Xvfb
docker-compose restart computer-use
```

### VNC Access
```bash
# Connect via VNC viewer
vncviewer localhost:5900
# Password: pulser123

# Or use web interface
open http://localhost:6080
```

### Performance Optimization
1. Use lower resolution (1024x768)
2. Disable animations in applications
3. Limit concurrent operations
4. Clear browser cache regularly

## Best Practices for Prompts

### DO:
- Be specific about UI elements: "Click the blue 'Submit' button in the top right"
- Provide step-by-step instructions
- Include error handling: "If the page doesn't load, refresh and try again"
- Verify actions: "Take a screenshot after each step"

### DON'T:
- Use vague descriptions: "Click somewhere on the page"
- Assume UI state: Always check current state first
- Skip verification: Always confirm actions completed
- Provide credentials: Never include passwords

## Model-Specific Features

### Claude 4 / Sonnet 3.7
- Enhanced scroll control
- Multi-click support (double, triple)
- Fine-grained mouse control
- Thinking mode for debugging

### Claude Sonnet 3.5
- Basic actions only
- Limited scroll capability
- Standard click/type operations

## Example: Complete Workflow

```bash
# 1. Start the environment
cd /tools/js/mcp/computer-use
docker-compose up -d

# 2. Run a complex task
:computer-use "
1. Open Firefox browser
2. Navigate to our Scout Dashboard at http://localhost:3000
3. Take screenshots of each dashboard tab
4. Export the data from the metrics page
5. Create a summary report in LibreOffice Writer
6. Save the report as PDF to the workspace folder
"

# 3. Retrieve results
docker cp pulser-computer-use:/home/user/workspace/report.pdf ./

# 4. Clean up
docker-compose down
```

## Integration with CI/CD

```yaml
# GitHub Actions example
- name: UI Testing with Computer Use
  run: |
    docker-compose up -d
    pulser :computer-use "Run UI test suite on staging environment"
    docker-compose down
```

## Monitoring and Logs

```bash
# View real-time logs
docker logs -f pulser-computer-use

# Check action statistics
:computer-use-stats

# Export action history
docker exec pulser-computer-use cat /var/log/computer-use.log
```

## Future Enhancements

1. **Multi-display support**: Control multiple monitors
2. **Mobile emulation**: Test responsive designs
3. **Recording playback**: Save and replay action sequences
4. **Visual regression**: Automated screenshot comparison
5. **Accessibility testing**: WCAG compliance checks

## Support and Feedback

- Report issues: Create GitHub issue with `computer-use` label
- Request features: Use `enhancement` label
- Security concerns: Email security@insightpulse.ai

Remember: Computer use is a powerful tool. Always prioritize security and verify actions before executing in production environments.