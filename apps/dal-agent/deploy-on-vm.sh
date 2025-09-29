#!/bin/bash
set -euo pipefail

echo "📦 Setting up Scout Analytics API..."

# Ensure directory exists
sudo mkdir -p /opt/scout-analytics
sudo chown azureuser:azureuser /opt/scout-analytics
cd /opt/scout-analytics

echo "📋 Installing dependencies..."
# Clear npm cache and install fresh
npm cache clean --force
npm install --only=production --no-package-lock

echo "🔑 Setting up database configuration..."
# For now, we'll use env vars - Key Vault integration can be added later
export AZURE_SQL_SERVER="sqltbwaprojectscoutserver.database.windows.net"
export AZURE_SQL_DATABASE="SQL-TBWA-ProjectScout-Reporting-Prod"
echo "Database configuration set"

echo "🔄 Setting up PM2 process manager..."
# Stop existing process if running
pm2 delete scout-analytics 2>/dev/null || true

# Start the application
pm2 start src/server.js \
    --name scout-analytics \
    --log /var/log/scout-analytics/app.log \
    --error /var/log/scout-analytics/error.log \
    --env production

# Save PM2 configuration
pm2 save
pm2 startup

echo "🌐 Configuring Nginx reverse proxy..."
sudo tee /etc/nginx/sites-available/scout-analytics > /dev/null << 'NGINX_EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
    }

    location /health {
        proxy_pass http://localhost:8080/health;
        access_log off;
    }
}
NGINX_EOF

# Enable nginx site
sudo ln -sf /etc/nginx/sites-available/scout-analytics /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test and reload nginx
sudo nginx -t && sudo systemctl reload nginx

echo "✅ Scout Analytics API deployed successfully!"
echo "🏥 Health check: http://$(curl -s ifconfig.me)/health"
echo "📊 API endpoint: http://$(curl -s ifconfig.me)/api/v1"

# Show status
pm2 status
