#!/bin/bash

# Scout Analytics - Environment Setup Script
# Sets up development environment and configurations

set -euo pipefail

PROJECT_DIR="${1:-.}"
ENV_TYPE="${2:-development}"

echo "🔧 Setting up Scout Analytics environment..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to generate secure random strings
generate_secret() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# Create environment files
create_env_files() {
    echo -e "${BLUE}Creating environment files...${NC}"
    
    # Main .env file
    cat > "$PROJECT_DIR/.env" << EOF
# Scout Analytics Dashboard Environment Configuration
# Generated on: $(date)
# Environment: ${ENV_TYPE}

# ===================================
# Application Settings
# ===================================
NODE_ENV=${ENV_TYPE}
APP_NAME=scout-analytics-dashboard
APP_VERSION=1.0.0
LOG_LEVEL=info

# ===================================
# Server Configuration
# ===================================
PORT=3000
API_PORT=3001
CORS_ORIGIN=http://localhost:3000
API_BASE_URL=http://localhost:3001/api

# ===================================
# Database Configuration
# ===================================
DATABASE_URL=postgresql://scout_user:scout_password@localhost:5432/scout_analytics
DATABASE_POOL_SIZE=20
DATABASE_TIMEOUT=5000

# Redis Configuration
REDIS_URL=redis://localhost:6379
REDIS_TTL=300
REDIS_PREFIX=scout:

# ===================================
# Azure Services
# ===================================
# Azure OpenAI
AZURE_OPENAI_ENDPOINT=https://your-instance.openai.azure.com/
AZURE_OPENAI_API_KEY=your_openai_api_key_here
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4
AZURE_OPENAI_API_VERSION=2024-02-01

# Azure Storage
AZURE_STORAGE_ACCOUNT=projectscoutdata
AZURE_STORAGE_KEY=your_storage_key_here
AZURE_STORAGE_CONTAINER=analytics
AZURE_STORAGE_SAS_TOKEN=

# Azure Application Insights
APPLICATION_INSIGHTS_CONNECTION_STRING=InstrumentationKey=your_key_here
APPLICATION_INSIGHTS_SAMPLING_PERCENTAGE=100

# ===================================
# Authentication & Security
# ===================================
JWT_SECRET=$(generate_secret)
JWT_EXPIRES_IN=7d
REFRESH_TOKEN_SECRET=$(generate_secret)
REFRESH_TOKEN_EXPIRES_IN=30d
SESSION_SECRET=$(generate_secret)
BCRYPT_ROUNDS=10

# ===================================
# Feature Flags
# ===================================
ENABLE_AI_INSIGHTS=true
ENABLE_REAL_TIME_UPDATES=true
ENABLE_EXPORT_FEATURES=true
ENABLE_ADVANCED_FILTERS=true

# ===================================
# External Services
# ===================================
SENTRY_DSN=
MIXPANEL_TOKEN=
GOOGLE_ANALYTICS_ID=
HOTJAR_ID=

# ===================================
# Development Settings
# ===================================
DEBUG=false
MOCK_DATA=false
SEED_DATABASE=true
EOF

    # Frontend specific .env
    cat > "$PROJECT_DIR/frontend/.env" << EOF
# Frontend Environment Variables
VITE_API_URL=http://localhost:3001/api
VITE_WS_URL=ws://localhost:3001
VITE_APP_NAME=Scout Analytics
VITE_ENABLE_ANALYTICS=false
VITE_SENTRY_DSN=
EOF

    # Backend specific .env
    cat > "$PROJECT_DIR/backend/.env" << EOF
# Backend Environment Variables
NODE_ENV=${ENV_TYPE}
PORT=3001
DATABASE_URL=postgresql://scout_user:scout_password@localhost:5432/scout_analytics
REDIS_URL=redis://localhost:6379
EOF

    echo -e "${GREEN}✅ Environment files created${NC}"
}

# Create Docker Compose file for local development
create_docker_compose() {
    echo -e "${BLUE}Creating Docker Compose configuration...${NC}"
    
    cat > "$PROJECT_DIR/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    container_name: scout-postgres
    environment:
      POSTGRES_USER: scout_user
      POSTGRES_PASSWORD: scout_password
      POSTGRES_DB: scout_analytics
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/database:/docker-entrypoint-initdb.d
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U scout_user -d scout_analytics"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Redis Cache
  redis:
    image: redis:7-alpine
    container_name: scout-redis
    command: redis-server --appendonly yes
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # pgAdmin (optional, for database management)
  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: scout-pgadmin
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@scout.local
      PGADMIN_DEFAULT_PASSWORD: admin
    ports:
      - "5050:80"
    depends_on:
      - postgres
    profiles:
      - tools

  # Redis Commander (optional, for Redis management)
  redis-commander:
    image: rediscommander/redis-commander:latest
    container_name: scout-redis-commander
    environment:
      - REDIS_HOSTS=local:redis:6379
    ports:
      - "8081:8081"
    depends_on:
      - redis
    profiles:
      - tools

volumes:
  postgres_data:
  redis_data:
EOF

    echo -e "${GREEN}✅ Docker Compose file created${NC}"
}

# Create VS Code settings
create_vscode_settings() {
    echo -e "${BLUE}Creating VS Code settings...${NC}"
    
    mkdir -p "$PROJECT_DIR/.vscode"
    
    cat > "$PROJECT_DIR/.vscode/settings.json" << 'EOF'
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": true
  },
  "typescript.tsdk": "node_modules/typescript/lib",
  "typescript.enablePromptUseWorkspaceTsdk": true,
  "files.exclude": {
    "**/.git": true,
    "**/.DS_Store": true,
    "**/node_modules": true,
    "**/dist": true,
    "**/.next": true,
    "**/coverage": true
  },
  "search.exclude": {
    "**/node_modules": true,
    "**/dist": true,
    "**/.next": true,
    "**/coverage": true,
    "**/*.log": true
  },
  "[typescript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[typescriptreact]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[json]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "eslint.validate": [
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact"
  ],
  "tailwindCSS.experimental.classRegex": [
    ["clsx\\(([^)]*)\\)", "(?:'|\"|`)([^']*)(?:'|\"|`)"],
    ["cn\\(([^)]*)\\)", "(?:'|\"|`)([^']*)(?:'|\"|`)"]
  ]
}
EOF

    # Create VS Code extensions recommendations
    cat > "$PROJECT_DIR/.vscode/extensions.json" << 'EOF'
{
  "recommendations": [
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "bradlc.vscode-tailwindcss",
    "prisma.prisma",
    "ms-azuretools.vscode-docker",
    "github.copilot",
    "ms-vscode.vscode-typescript-next",
    "christian-kohler.path-intellisense",
    "formulahendry.auto-rename-tag",
    "steoates.autoimport",
    "usernamehw.errorlens",
    "wix.vscode-import-cost"
  ]
}
EOF

    echo -e "${GREEN}✅ VS Code settings created${NC}"
}

# Create Git hooks
create_git_hooks() {
    echo -e "${BLUE}Setting up Git hooks...${NC}"
    
    mkdir -p "$PROJECT_DIR/.husky"
    
    # Pre-commit hook
    cat > "$PROJECT_DIR/.husky/pre-commit" << 'EOF'
#!/bin/sh
. "$(dirname "$0")/_/husky.sh"

echo "🔍 Running pre-commit checks..."

# Run linting
npm run lint

# Run type checking
npm run type-check

# Run tests
npm test -- --run
EOF
    
    chmod +x "$PROJECT_DIR/.husky/pre-commit"
    
    # Commit message hook
    cat > "$PROJECT_DIR/.husky/commit-msg" << 'EOF'
#!/bin/sh
. "$(dirname "$0")/_/husky.sh"

# Conventional commits pattern
commit_regex='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?: .{1,72}$'

if ! grep -qE "$commit_regex" "$1"; then
    echo "❌ Invalid commit message format!"
    echo "📝 Format: <type>(<scope>): <subject>"
    echo "📋 Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert"
    echo "Example: feat(dashboard): add new analytics chart"
    exit 1
fi
EOF
    
    chmod +x "$PROJECT_DIR/.husky/commit-msg"
    
    echo -e "${GREEN}✅ Git hooks created${NC}"
}

# Create development scripts
create_dev_scripts() {
    echo -e "${BLUE}Creating development scripts...${NC}"
    
    mkdir -p "$PROJECT_DIR/scripts"
    
    # Database setup script
    cat > "$PROJECT_DIR/scripts/setup-database.sh" << 'EOF'
#!/bin/bash

echo "🗄️ Setting up Scout Analytics database..."

# Wait for PostgreSQL to be ready
until PGPASSWORD=scout_password psql -h localhost -U scout_user -d postgres -c '\q' 2>/dev/null; do
  echo "⏳ Waiting for PostgreSQL..."
  sleep 2
done

echo "✅ PostgreSQL is ready!"

# Create database if it doesn't exist
PGPASSWORD=scout_password psql -h localhost -U scout_user -d postgres << SQL
SELECT 'CREATE DATABASE scout_analytics'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'scout_analytics')\gexec
SQL

echo "✅ Database created or already exists"

# Run migrations
cd backend && npm run db:migrate

# Seed database in development
if [ "$NODE_ENV" = "development" ]; then
    npm run db:seed
    echo "✅ Database seeded with sample data"
fi

echo "🎉 Database setup complete!"
EOF
    
    chmod +x "$PROJECT_DIR/scripts/setup-database.sh"
    
    # Health check script
    cat > "$PROJECT_DIR/scripts/health-check.sh" << 'EOF'
#!/bin/bash

echo "🏥 Running health checks..."

# Check PostgreSQL
if pg_isready -h localhost -p 5432 > /dev/null 2>&1; then
    echo "✅ PostgreSQL is healthy"
else
    echo "❌ PostgreSQL is not responding"
fi

# Check Redis
if redis-cli ping > /dev/null 2>&1; then
    echo "✅ Redis is healthy"
else
    echo "❌ Redis is not responding"
fi

# Check API
if curl -f http://localhost:3001/health > /dev/null 2>&1; then
    echo "✅ API is healthy"
else
    echo "❌ API is not responding"
fi

# Check Frontend
if curl -f http://localhost:3000 > /dev/null 2>&1; then
    echo "✅ Frontend is healthy"
else
    echo "❌ Frontend is not responding"
fi
EOF
    
    chmod +x "$PROJECT_DIR/scripts/health-check.sh"
    
    echo -e "${GREEN}✅ Development scripts created${NC}"
}

# Main execution
main() {
    cd "$PROJECT_DIR"
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}       Scout Analytics - Environment Setup                                ${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    create_env_files
    create_docker_compose
    create_vscode_settings
    create_git_hooks
    create_dev_scripts
    
    echo
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ Environment setup completed successfully!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Review and update .env file with your actual credentials"
    echo "2. Start Docker services: docker-compose up -d"
    echo "3. Run database setup: ./scripts/setup-database.sh"
    echo "4. Install dependencies: npm install"
    echo "5. Start development: npm run dev"
    echo
}

main "$@"