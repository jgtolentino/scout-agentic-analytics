# Pulser Computer Use MCP Server

This MCP server provides computer use capabilities for Pulser agents, enabling them to interact with desktop environments through screenshots, mouse control, and keyboard input.

## Architecture Overview

```
┌─────────────────────┐
│   Pulser CLI       │
│  (:computer-use)   │
└─────────┬───────────┘
          │
┌─────────▼───────────┐
│  MCP Computer Use   │
│      Server         │
└─────────┬───────────┘
          │
┌─────────▼───────────┐     ┌─────────────────┐
│   Agent Loop        │◄────┤  Claude API     │
│   Controller        │     │  (with beta)    │
└─────────┬───────────┘     └─────────────────┘
          │
┌─────────▼───────────┐
│  Docker Container   │
│  - Virtual Display  │
│  - Desktop Env      │
│  - Tool Handlers    │
└─────────────────────┘
```

## Features

- **Screenshot Capture**: Capture current display state
- **Mouse Control**: Click, drag, and move cursor
- **Keyboard Input**: Type text and use shortcuts
- **Desktop Automation**: Interact with any application
- **Security Sandbox**: Isolated Docker environment
- **Multi-Model Support**: Claude 4, Sonnet 3.7, and Sonnet 3.5

## Quick Start

```bash
# Install dependencies
npm install

# Build the MCP server
npm run build

# Start the computer use environment
docker-compose up -d

# Run the MCP server
npm start
```

## Usage with Pulser

### Basic Command
```bash
:computer-use "Save a screenshot of the current desktop"
```

### With Specific Actions
```bash
:computer-use "Open a web browser and search for 'InsightPulse dashboard'"
```

### Complex Automation
```bash
:computer-use "Create a new presentation about retail insights using the data from scout_dashboard.csv"
```

## Security Considerations

1. **Isolated Environment**: Runs in Docker container with limited privileges
2. **No Sensitive Data**: Never provide login credentials or access to sensitive accounts
3. **Human Oversight**: Always review actions before executing in production
4. **Network Restrictions**: Implement allowlist for internet access

## Configuration

### Environment Variables
```bash
# Model configuration
CLAUDE_MODEL=claude-sonnet-4-20250514
CLAUDE_BETA_FLAG=computer-use-2025-01-24

# Display settings
DISPLAY_WIDTH=1024
DISPLAY_HEIGHT=768
DISPLAY_NUMBER=1

# Security settings
ENABLE_INTERNET=false
ALLOWED_DOMAINS=localhost,127.0.0.1
MAX_ITERATIONS=10
```

### Docker Configuration
See `docker-compose.yml` for container setup with:
- Virtual X11 display (Xvfb)
- Lightweight desktop environment
- Pre-installed applications
- Security restrictions

## API Reference

### Available Actions

#### Basic Actions (all versions)
- `screenshot` - Capture the current display
- `left_click` - Click at coordinates
- `type` - Type text string
- `key` - Press key or key combination
- `mouse_move` - Move cursor to coordinates

#### Enhanced Actions (Claude 4/3.7)
- `scroll` - Scroll in any direction
- `left_click_drag` - Click and drag
- `right_click`, `middle_click` - Additional mouse buttons
- `double_click`, `triple_click` - Multiple clicks
- `wait` - Pause between actions

## Integration with Pulser Agents

Computer use can be combined with other Pulser capabilities:

```yaml
# Example agent configuration
agent:
  name: desktop-automation
  capabilities:
    - computer-use
    - file-system
    - web-search
  tools:
    - type: computer_20250124
      name: computer
    - type: bash_20250124
      name: bash
    - type: text_editor_20250124
      name: str_replace_editor
```

## Troubleshooting

### Common Issues

1. **Display not found**: Ensure Docker container is running
2. **Screenshot errors**: Check X11 display configuration
3. **Click accuracy**: Use lower resolution (1024x768)
4. **Slow performance**: Reduce iteration count or timeout

### Debug Mode
```bash
DEBUG=computer-use:* npm start
```

## Examples

See `/examples` directory for:
- Web automation scripts
- Desktop application control
- Data extraction workflows
- UI testing scenarios