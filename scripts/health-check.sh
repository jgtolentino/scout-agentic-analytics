#!/bin/bash

# Scout Analytics - Comprehensive Health Check Script
# Validates system health across all components

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Health check results
HEALTH_REPORT="health-check-$(date +%Y%m%d_%H%M%S).log"
TOTAL_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Initialize health report
init_health_report() {
    echo "🏥 Scout Analytics - System Health Check Report" > "$HEALTH_REPORT"
    echo "Generated: $(date)" >> "$HEALTH_REPORT"
    echo "System: $(uname -a)" >> "$HEALTH_REPORT"
    echo "" >> "$HEALTH_REPORT"
}

# Record check result
record_check() {
    local check_name="$1"
    local status="$2"
    local message="$3"
    local details="${4:-}"
    
    ((TOTAL_CHECKS++))
    
    case "$status" in
        "PASS")
            echo -e "${GREEN}✅ $check_name${NC}: $message"
            echo "✅ $check_name: $message" >> "$HEALTH_REPORT"
            ;;
        "FAIL")
            echo -e "${RED}❌ $check_name${NC}: $message"
            echo "❌ $check_name: $message" >> "$HEALTH_REPORT"
            ((FAILED_CHECKS++))
            ;;
        "WARN")
            echo -e "${YELLOW}⚠️  $check_name${NC}: $message"
            echo "⚠️  $check_name: $message" >> "$HEALTH_REPORT"
            ((WARNING_CHECKS++))
            ;;
    esac
    
    if [ -n "$details" ]; then
        echo "   Details: $details" >> "$HEALTH_REPORT"
    fi
    echo "" >> "$HEALTH_REPORT"
}

# System prerequisites check
check_system_prerequisites() {
    echo -e "${BLUE}🔍 Checking System Prerequisites...${NC}"
    
    # Node.js version
    if command -v node &> /dev/null; then
        local node_version=$(node -v | sed 's/v//')
        local major_version=$(echo "$node_version" | cut -d. -f1)
        if [ "$major_version" -ge 18 ]; then
            record_check "Node.js Version" "PASS" "v$node_version (compatible)"
        else
            record_check "Node.js Version" "FAIL" "v$node_version (requires v18+)"
        fi
    else
        record_check "Node.js" "FAIL" "Not installed"
    fi
    
    # npm
    if command -v npm &> /dev/null; then
        local npm_version=$(npm -v)
        record_check "npm" "PASS" "v$npm_version"
    else
        record_check "npm" "FAIL" "Not installed"
    fi
    
    # Git
    if command -v git &> /dev/null; then
        local git_version=$(git --version | cut -d' ' -f3)
        record_check "Git" "PASS" "v$git_version"
    else
        record_check "Git" "FAIL" "Not installed"
    fi
    
    # Python 3
    if command -v python3 &> /dev/null; then
        local python_version=$(python3 --version | cut -d' ' -f2)
        record_check "Python 3" "PASS" "v$python_version"
    else
        record_check "Python 3" "FAIL" "Not installed"
    fi
    
    # Docker
    if command -v docker &> /dev/null; then
        if docker info >/dev/null 2>&1; then
            local docker_version=$(docker --version | cut -d' ' -f3 | tr -d ',')
            record_check "Docker" "PASS" "v$docker_version (daemon running)"
        else
            record_check "Docker" "FAIL" "Installed but daemon not running"
        fi
    else
        record_check "Docker" "FAIL" "Not installed"
    fi
    
    # Docker Compose
    if command -v docker-compose &> /dev/null; then
        local compose_version=$(docker-compose --version | cut -d' ' -f3 | tr -d ',')
        record_check "Docker Compose" "PASS" "v$compose_version"
    else
        record_check "Docker Compose" "FAIL" "Not installed"
    fi
    
    # yq (YAML processor)
    if command -v yq &> /dev/null; then
        local yq_version=$(yq --version | cut -d' ' -f4)
        record_check "yq" "PASS" "v$yq_version"
    else
        record_check "yq" "FAIL" "Not installed (brew install yq)"
    fi
    
    # jq (JSON processor)
    if command -v jq &> /dev/null; then
        local jq_version=$(jq --version | tr -d 'jq-')
        record_check "jq" "PASS" "v$jq_version"
    else
        record_check "jq" "FAIL" "Not installed"
    fi
}

# System resources check
check_system_resources() {
    echo -e "${BLUE}💻 Checking System Resources...${NC}"
    
    # Disk space
    local available_space=$(df . | tail -1 | awk '{print $4}')
    local available_gb=$((available_space / 1024 / 1024))
    
    if [ $available_gb -ge 5 ]; then
        record_check "Disk Space" "PASS" "${available_gb}GB available"
    elif [ $available_gb -ge 2 ]; then
        record_check "Disk Space" "WARN" "${available_gb}GB available (minimum for basic setup)"
    else
        record_check "Disk Space" "FAIL" "${available_gb}GB available (insufficient)"
    fi
    
    # Memory (if available)
    if command -v free &> /dev/null; then
        local total_mem=$(free -g | awk '/^Mem:/{print $2}')
        local available_mem=$(free -g | awk '/^Mem:/{print $7}')
        
        if [ $available_mem -ge 4 ]; then
            record_check "Memory" "PASS" "${available_mem}GB available of ${total_mem}GB total"
        elif [ $available_mem -ge 2 ]; then
            record_check "Memory" "WARN" "${available_mem}GB available of ${total_mem}GB total"
        else
            record_check "Memory" "FAIL" "${available_mem}GB available (insufficient)"
        fi
    elif [ "$(uname)" = "Darwin" ]; then
        # macOS memory check
        local total_mem_bytes=$(sysctl -n hw.memsize)
        local total_mem_gb=$((total_mem_bytes / 1024 / 1024 / 1024))
        
        if [ $total_mem_gb -ge 8 ]; then
            record_check "Memory" "PASS" "${total_mem_gb}GB total"
        elif [ $total_mem_gb -ge 4 ]; then
            record_check "Memory" "WARN" "${total_mem_gb}GB total"
        else
            record_check "Memory" "FAIL" "${total_mem_gb}GB total (insufficient)"
        fi
    fi
}

# Network connectivity check
check_network_connectivity() {
    echo -e "${BLUE}🌐 Checking Network Connectivity...${NC}"
    
    # Basic internet connectivity
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        record_check "Internet Connectivity" "PASS" "Can reach 8.8.8.8"
    else
        record_check "Internet Connectivity" "FAIL" "Cannot reach external servers"
    fi
    
    # GitHub connectivity
    if curl -sSf --connect-timeout 10 https://api.github.com >/dev/null 2>&1; then
        record_check "GitHub API" "PASS" "api.github.com accessible"
    else
        record_check "GitHub API" "FAIL" "Cannot reach GitHub API"
    fi
    
    # NPM registry
    if curl -sSf --connect-timeout 10 https://registry.npmjs.org >/dev/null 2>&1; then
        record_check "NPM Registry" "PASS" "registry.npmjs.org accessible"
    else
        record_check "NPM Registry" "FAIL" "Cannot reach NPM registry"
    fi
    
    # Azure connectivity (for AI services)
    if curl -sSf --connect-timeout 10 https://azure.microsoft.com >/dev/null 2>&1; then
        record_check "Azure Services" "PASS" "azure.microsoft.com accessible"
    else
        record_check "Azure Services" "WARN" "Cannot reach Azure (may affect AI features)"
    fi
}

# Project structure check
check_project_structure() {
    echo -e "${BLUE}📁 Checking Project Structure...${NC}"
    
    # Check if we're in a project directory
    local project_indicators=("package.json" "bootstrap-config.yaml" "frontend" "backend")
    local found_indicators=0
    
    for indicator in "${project_indicators[@]}"; do
        if [ -f "$indicator" ] || [ -d "$indicator" ]; then
            ((found_indicators++))
        fi
    done
    
    if [ $found_indicators -ge 2 ]; then
        record_check "Project Structure" "PASS" "Found $found_indicators/4 project indicators"
    elif [ $found_indicators -eq 1 ]; then
        record_check "Project Structure" "WARN" "Partial project structure detected"
    else
        record_check "Project Structure" "FAIL" "No project structure found"
    fi
    
    # Check specific directories and files
    if [ -f "package.json" ]; then
        record_check "Root package.json" "PASS" "Found"
    else
        record_check "Root package.json" "WARN" "Not found"
    fi
    
    if [ -d "frontend" ]; then
        if [ -f "frontend/package.json" ]; then
            record_check "Frontend Structure" "PASS" "Directory and package.json found"
        else
            record_check "Frontend Structure" "WARN" "Directory found but no package.json"
        fi
    else
        record_check "Frontend Structure" "WARN" "Directory not found"
    fi
    
    if [ -d "backend" ]; then
        if [ -f "backend/package.json" ]; then
            record_check "Backend Structure" "PASS" "Directory and package.json found"
        else
            record_check "Backend Structure" "WARN" "Directory found but no package.json"
        fi
    else
        record_check "Backend Structure" "WARN" "Directory not found"
    fi
    
    # Environment files
    if [ -f ".env" ]; then
        record_check "Environment File" "PASS" ".env found"
    elif [ -f ".env.example" ]; then
        record_check "Environment File" "WARN" ".env.example found but no .env"
    else
        record_check "Environment File" "WARN" "No environment files found"
    fi
    
    # Docker configuration
    if [ -f "docker-compose.yml" ]; then
        if docker-compose config >/dev/null 2>&1; then
            record_check "Docker Compose Config" "PASS" "Valid configuration"
        else
            record_check "Docker Compose Config" "FAIL" "Invalid configuration"
        fi
    else
        record_check "Docker Compose Config" "WARN" "No docker-compose.yml found"
    fi
}

# Service health check
check_services() {
    echo -e "${BLUE}🔧 Checking Services...${NC}"
    
    # PostgreSQL (if running in Docker)
    if docker-compose ps postgres >/dev/null 2>&1; then
        if docker-compose exec -T postgres pg_isready >/dev/null 2>&1; then
            record_check "PostgreSQL" "PASS" "Running and accepting connections"
        else
            record_check "PostgreSQL" "FAIL" "Running but not accepting connections"
        fi
    else
        record_check "PostgreSQL" "WARN" "Not running (use docker-compose up -d)"
    fi
    
    # Redis (if running in Docker)
    if docker-compose ps redis >/dev/null 2>&1; then
        if docker-compose exec -T redis redis-cli ping >/dev/null 2>&1; then
            record_check "Redis" "PASS" "Running and responding to ping"
        else
            record_check "Redis" "FAIL" "Running but not responding"
        fi
    else
        record_check "Redis" "WARN" "Not running (use docker-compose up -d)"
    fi
    
    # Frontend development server
    if curl -sSf --connect-timeout 5 http://localhost:3000 >/dev/null 2>&1; then
        record_check "Frontend Server" "PASS" "Running on port 3000"
    else
        record_check "Frontend Server" "WARN" "Not running (use npm run dev:frontend)"
    fi
    
    # Backend API server
    if curl -sSf --connect-timeout 5 http://localhost:3001/health >/dev/null 2>&1; then
        record_check "Backend API" "PASS" "Running on port 3001"
    elif curl -sSf --connect-timeout 5 http://localhost:3001 >/dev/null 2>&1; then
        record_check "Backend API" "WARN" "Running but health endpoint not available"
    else
        record_check "Backend API" "WARN" "Not running (use npm run dev:backend)"
    fi
}

# Port availability check
check_ports() {
    echo -e "${BLUE}🔌 Checking Port Availability...${NC}"
    
    local ports=("3000:Frontend" "3001:Backend API" "5432:PostgreSQL" "6379:Redis")
    
    for port_info in "${ports[@]}"; do
        local port=$(echo "$port_info" | cut -d: -f1)
        local service=$(echo "$port_info" | cut -d: -f2)
        
        if lsof -Pi ":$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
            local pid=$(lsof -Pi ":$port" -sTCP:LISTEN -t)
            local process=$(ps -p $pid -o comm= 2>/dev/null || echo "unknown")
            record_check "Port $port ($service)" "PASS" "In use by $process (PID: $pid)"
        else
            record_check "Port $port ($service)" "WARN" "Available (service not running)"
        fi
    done
}

# Dependencies check
check_dependencies() {
    echo -e "${BLUE}📦 Checking Dependencies...${NC}"
    
    # Root dependencies
    if [ -f "package.json" ]; then
        if [ -d "node_modules" ]; then
            local package_count=$(find node_modules -maxdepth 1 -type d | wc -l)
            record_check "Root Dependencies" "PASS" "$package_count packages installed"
        else
            record_check "Root Dependencies" "WARN" "node_modules not found (run npm install)"
        fi
    fi
    
    # Frontend dependencies
    if [ -f "frontend/package.json" ]; then
        if [ -d "frontend/node_modules" ]; then
            local package_count=$(find frontend/node_modules -maxdepth 1 -type d | wc -l)
            record_check "Frontend Dependencies" "PASS" "$package_count packages installed"
        else
            record_check "Frontend Dependencies" "WARN" "node_modules not found (run npm install)"
        fi
    fi
    
    # Backend dependencies
    if [ -f "backend/package.json" ]; then
        if [ -d "backend/node_modules" ]; then
            local package_count=$(find backend/node_modules -maxdepth 1 -type d | wc -l)
            record_check "Backend Dependencies" "PASS" "$package_count packages installed"
        else
            record_check "Backend Dependencies" "WARN" "node_modules not found (run npm install)"
        fi
    fi
}

# Configuration check
check_configuration() {
    echo -e "${BLUE}⚙️  Checking Configuration...${NC}"
    
    # Environment variables
    if [ -f ".env" ]; then
        local env_vars=("NODE_ENV" "DATABASE_URL" "REDIS_URL")
        local missing_vars=0
        
        for var in "${env_vars[@]}"; do
            if grep -q "^$var=" .env; then
                local value=$(grep "^$var=" .env | cut -d= -f2)
                if [ -n "$value" ] && [ "$value" != "your_value_here" ]; then
                    record_check "Environment Variable $var" "PASS" "Configured"
                else
                    record_check "Environment Variable $var" "WARN" "Not configured"
                    ((missing_vars++))
                fi
            else
                record_check "Environment Variable $var" "WARN" "Not found"
                ((missing_vars++))
            fi
        done
        
        if [ $missing_vars -eq 0 ]; then
            record_check "Environment Configuration" "PASS" "All required variables configured"
        else
            record_check "Environment Configuration" "WARN" "$missing_vars variables need configuration"
        fi
    else
        record_check "Environment Configuration" "FAIL" "No .env file found"
    fi
    
    # Git configuration
    if git config user.name >/dev/null 2>&1 && git config user.email >/dev/null 2>&1; then
        record_check "Git Configuration" "PASS" "User name and email configured"
    else
        record_check "Git Configuration" "WARN" "Git user not configured"
    fi
}

# Generate health summary
generate_health_summary() {
    echo "" >> "$HEALTH_REPORT"
    echo "=== HEALTH CHECK SUMMARY ===" >> "$HEALTH_REPORT"
    echo "Total Checks: $TOTAL_CHECKS" >> "$HEALTH_REPORT"
    echo "Passed: $((TOTAL_CHECKS - FAILED_CHECKS - WARNING_CHECKS))" >> "$HEALTH_REPORT"
    echo "Warnings: $WARNING_CHECKS" >> "$HEALTH_REPORT"
    echo "Failed: $FAILED_CHECKS" >> "$HEALTH_REPORT"
    echo "" >> "$HEALTH_REPORT"
    
    local pass_rate=$(( (TOTAL_CHECKS - FAILED_CHECKS) * 100 / TOTAL_CHECKS ))
    
    if [ $FAILED_CHECKS -eq 0 ]; then
        echo "Overall Status: HEALTHY" >> "$HEALTH_REPORT"
        if [ $WARNING_CHECKS -eq 0 ]; then
            echo -e "\n${GREEN}🎉 System is fully healthy! All checks passed.${NC}"
        else
            echo -e "\n${YELLOW}⚠️  System is mostly healthy with $WARNING_CHECKS warnings.${NC}"
        fi
    else
        echo "Overall Status: NEEDS ATTENTION" >> "$HEALTH_REPORT"
        echo -e "\n${RED}❌ System needs attention: $FAILED_CHECKS failed checks${NC}"
    fi
    
    echo -e "\n${CYAN}📋 Health Report:${NC} $HEALTH_REPORT"
    echo -e "${CYAN}📊 Pass Rate:${NC} $pass_rate%"
}

# Main execution
main() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}       Scout Analytics - Comprehensive Health Check                     ${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    init_health_report
    
    check_system_prerequisites
    echo
    check_system_resources
    echo
    check_network_connectivity
    echo
    check_project_structure
    echo
    check_services
    echo
    check_ports
    echo
    check_dependencies
    echo
    check_configuration
    echo
    
    generate_health_summary
}

# Run health check
main "$@"