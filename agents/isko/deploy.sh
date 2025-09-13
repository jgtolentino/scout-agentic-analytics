#!/bin/bash
# Deployment script for Isko Agent

set -e

echo "🚀 Starting Isko Agent deployment..."

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found. Copy .env.example and configure it."
    exit 1
fi

# Load environment variables
export $(cat .env | grep -v '^#' | xargs)

# Build Docker image
echo "📦 Building Docker image..."
docker build -t isko-agent:latest .

# Run database migrations (if any)
# echo "🔄 Running database migrations..."
# python migrate.py

# Stop existing container
echo "🛑 Stopping existing container..."
docker-compose down || true

# Start new container
echo "▶️ Starting new container..."
docker-compose up -d

# Wait for health check
echo "⏳ Waiting for health check..."
sleep 10

# Check if service is healthy
if curl -f http://localhost:${ISKO_AGENT_PORT:-8000}/health; then
    echo "✅ Isko Agent deployed successfully!"
    echo "📊 Access the API at: http://localhost:${ISKO_AGENT_PORT:-8000}"
else
    echo "❌ Health check failed. Check logs with: docker-compose logs"
    exit 1
fi

# Register with Pulser MCP (if available)
if command -v pulser &> /dev/null; then
    echo "📡 Registering with Pulser MCP..."
    pulser mcp add isko_scraper \
        --type http \
        --url http://localhost:${ISKO_AGENT_PORT:-8000} \
        --health /health \
        --tools scrape=/scrape \
        --description "Isko: JSON scraper for FMCG & Tobacco SKUs"
    pulser mcp start isko_scraper
fi

echo "🎉 Deployment complete!"