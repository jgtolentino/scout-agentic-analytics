#!/bin/bash

# =================================================================
# Deploy Scout Analytics API to existing Azure VM
# =================================================================

set -euo pipefail

VM_IP="172.190.34.236"
ADMIN_USERNAME="azureuser"

echo "🚀 Deploying Scout Analytics API to VM: $VM_IP"

# Create environment file
cat > .env.production << 'ENV_EOF'
NODE_ENV=production
PORT=8080
AZURE_SQL_SERVER=sqltbwaprojectscoutserver.database.windows.net
AZURE_SQL_DATABASE=SQL-TBWA-ProjectScout-Reporting-Prod
ANALYTICS_API_VERSION=v1
ENABLE_REAL_TIME_MONITORING=true
ENABLE_CULTURAL_ANALYTICS=true
ENABLE_CONVERSATION_INTELLIGENCE=true
CONNECTION_POOL_MAX=20
CONNECTION_POOL_MIN=5
CACHE_TTL_SECONDS=300
ENV_EOF

# Create deployment script for VM
cat > deploy-on-vm.sh << 'DEPLOY_EOF'
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
DEPLOY_EOF

chmod +x deploy-on-vm.sh

echo "📦 Creating deployment package..."
cp package-simple.json package.json
# Use simplified database config without Azure Key Vault
cp src/config/database-simple.js src/config/database.js
tar -czf deployment.tar.gz src/ package.json .env.production deploy-on-vm.sh

echo "📤 Copying files to VM..."
scp -o StrictHostKeyChecking=no -o ConnectTimeout=30 deployment.tar.gz "$ADMIN_USERNAME@$VM_IP:/tmp/"

echo "🔧 Installing application on VM..."
ssh -o StrictHostKeyChecking=no "$ADMIN_USERNAME@$VM_IP" << 'SSH_EOF'
cd /tmp
tar -xzf deployment.tar.gz
sudo mkdir -p /opt/scout-analytics /var/log/scout-analytics
sudo chown azureuser:azureuser /opt/scout-analytics /var/log/scout-analytics
cp -r src/ package*.json .env.production /opt/scout-analytics/
cp deploy-on-vm.sh /opt/scout-analytics/
cd /opt/scout-analytics
./deploy-on-vm.sh
SSH_EOF

echo "🎉 Deployment completed!"
echo ""
echo "🌐 Your Scout Analytics API is now running at:"
echo "   📍 Public IP: http://$VM_IP"
echo "   🏥 Health Check: http://$VM_IP/health"
echo "   📊 API Documentation: http://$VM_IP/api/v1"
echo ""
echo "🔧 Management commands:"
echo "   📋 Check status: ssh $ADMIN_USERNAME@$VM_IP 'pm2 status'"
echo "   📝 View logs: ssh $ADMIN_USERNAME@$VM_IP 'pm2 logs scout-analytics'"
echo "   🔄 Restart: ssh $ADMIN_USERNAME@$VM_IP 'pm2 restart scout-analytics'"

# Cleanup
rm -f deployment.tar.gz .env.production deploy-on-vm.sh