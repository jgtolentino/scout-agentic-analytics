# Socket MCP - Enhanced Build Guardrail & Dependency Validation Agent

Error-tolerant local+remote dependency validation system that transforms Socket.dev from a dependency score server into a comprehensive build reliability system.

## 🚀 Key Features

### Error Handling & Recovery
- **Exponential Backoff Retry** - Automatic retry with circuit breaker
- **Network Failure Recovery** - Fallback to local artifacts on registry errors
- **Smart Error Diagnosis** - Pattern-based error categorization
- **Fix Suggestions** - Context-aware remediation commands

### Local Artifact Validation
- **JAR/WAR/EAR** - Java artifact validation with manifest extraction
- **Python Wheels** - .whl and .egg validation with metadata parsing
- **node_modules** - NPM package validation and dependency analysis
- **Checksum Verification** - SHA256/MD5 integrity checking

### Build Failure Diagnostics
- **Pattern Recognition** - Identifies common build errors
- **Root Cause Analysis** - Determines primary failure reasons
- **Action Plans** - Prioritized fix suggestions
- **Prevention Advice** - Long-term stability recommendations

### Security Scanning
- **OSV Database** - Open Source Vulnerability checking
- **Snyk Integration** - Commercial vulnerability database (optional)
- **Pattern Scanning** - Detects hardcoded secrets and weak crypto
- **Risk Scoring** - 0-10 scale security assessment

## Installation

```bash
# Clone repository
git clone https://github.com/tbwa/socket-mcp.git
cd socket-mcp

# Install dependencies
pip install -r requirements.txt

# Set up API keys (optional)
export SOCKET_API_KEY="your-socket-api-key"
export SNYK_API_KEY="your-snyk-api-key"  # Optional
```

## Quick Start

### Validate Packages

```bash
# Validate npm packages with local fallback
python main.py validate --packages express@4.18.0 lodash@4.17.21

# Validate with local artifacts
python main.py validate \
  --packages express@4.18.0 \
  --artifact-paths ./build/libs/myapp.jar ./dist/mylib.whl

# Offline mode (local only)
python main.py validate --packages express lodash --offline
```

### Scan Local Artifacts

```bash
# Deep scan directory
python main.py scan --path ./node_modules --recursive

# Scan specific artifact
python main.py scan --path ./build/libs/application.jar
```

### Diagnose Build Failures

```bash
# Analyze build log
python main.py diagnose --error-log build.log --project-path .

# Example output:
{
  "diagnostics": [
    {
      "category": "missing_dependency",
      "message": "Module not found: 'express'",
      "suggested_fix": "npm install express"
    }
  ],
  "root_cause": "missing_dependency",
  "action_plan": [
    {
      "priority": "HIGH",
      "action": "npm install express",
      "reason": "Module not found error"
    }
  ]
}
```

### Compare Local vs Registry

```bash
# Compare local package with registry version
python main.py compare \
  --local-path ./node_modules/express \
  --package-spec express@latest
```

## Error Handling Examples

### Network Timeout Recovery

```python
# Automatic retry with exponential backoff
# Initial delay: 1s, backoff factor: 2
# Retries: 1s -> 2s -> 4s -> fail or succeed

# If network fails, automatically falls back to local artifact scanning
```

### Missing Package Handling

```python
# Pattern: "404 Not Found: package-name"
# Suggested fixes:
# 1. npm search package-name (check spelling)
# 2. npm config get registry (verify registry)
# 3. Scan local artifacts for alternative
```

### Build Error Patterns

The system recognizes and provides fixes for:
- `ETIMEDOUT` - Network timeouts
- `Module not found` - Missing dependencies
- `Cannot resolve dependency` - Version conflicts
- `Checksum mismatch` - Integrity failures
- `ClassNotFoundException` - Missing Java classes
- `No module named` - Missing Python modules

## API Usage

```python
from socket_mcp import SocketMCP, LocalArtifactScanner

async def validate_dependencies():
    async with SocketMCP() as mcp:
        # Validate packages
        result = await mcp.validate_packages(
            packages=['express@4.18.0'],
            artifact_paths=['./dist/myapp.jar'],
            scan_local=True
        )
        
        print(f"Errors: {result['error_report']['total_errors']}")
        print(f"Suggested fixes: {result['suggested_fixes']}")
        
        # Scan directory
        scan_result = await mcp.scan_directory('./node_modules')
        print(f"Valid artifacts: {scan_result['summary']['valid_artifacts']}")
```

## Configuration

The agent is configured via `socket-mcp.yaml`:

```yaml
agent:
  config:
    error_handling:
      max_retries: 3
      timeout_per_request: 30
      
    local_scanning:
      paths:
        node_modules: ["node_modules", "packages/*/node_modules"]
        python: ["dist", "build", "site-packages"]
        java: ["~/.m2/repository", "build/libs", "*.jar"]
```

## Security Scanning

### Vulnerability Detection

```bash
# Security audit of entire project
python main.py audit --project-path .

# Output includes:
# - Risk score (0-10)
# - CVE listings
# - Fixed versions available
# - Remediation recommendations
```

### Supported Databases
- **OSV** - Google's Open Source Vulnerabilities (default, no API key)
- **Snyk** - Commercial database (requires API key)
- **Pattern Scanner** - Built-in detection for common issues

## Error Categories

| Category | Description | Example Fix |
|----------|-------------|-------------|
| `network_error` | Connection failures | Check proxy, increase timeout |
| `package_not_found` | 404 errors | Verify package name/registry |
| `version_mismatch` | Conflicts | Update constraints, use --force |
| `checksum_mismatch` | Integrity fail | Clear cache, reinstall |
| `missing_dependency` | Module not found | Install missing package |
| `build_failure` | Compilation error | Check logs, fix syntax |

## Advanced Features

### Circuit Breaker
Prevents cascade failures by opening after 5 consecutive errors:
```python
# After 5 failures: circuit opens for 60 seconds
# During open state: fast fail without network calls
# After cooldown: circuit closes, retries resume
```

### Local Artifact Priority
When network fails, automatically checks:
1. `node_modules/` for npm packages
2. `~/.m2/repository` for Maven artifacts  
3. `dist/` and `build/` for Python wheels
4. Custom paths from configuration

### Fix Confidence Scoring
- **HIGH (0.9)** - Direct fix for exact error
- **MEDIUM (0.7)** - Generic fix likely to help
- **LOW (0.5)** - Experimental suggestion
- **EXPERIMENTAL (0.3)** - Last resort options

## Troubleshooting

### Set Debug Logging
```bash
export LOG_LEVEL=DEBUG
python main.py validate --packages express
```

### Check Circuit Breaker Status
```python
# In code:
print(f"Circuit open: {socket_mcp.retry_handler.circuit_open}")
```

### Force Local Only Mode
```bash
python main.py validate --packages express --offline
```

## Performance

- Local artifact scan: ~10ms per file
- Network validation: ~500ms per package (with cache)
- Security scan: ~100ms per artifact
- Error diagnosis: <50ms

## Contributing

1. Fork the repository
2. Create feature branch
3. Add tests for new patterns
4. Submit pull request

## License

MIT License - see LICENSE file

## Support

- Issues: GitHub Issues
- Email: socket-mcp@tbwa.com
- Docs: https://docs.tbwa.com/socket-mcp