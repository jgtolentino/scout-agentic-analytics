#!/bin/bash

# =================================================================
# Azure VM Deployment for Scout Analytics API
# Deploy Scout v7 Analytics API to Azure Virtual Machine
# =================================================================

set -euo pipefail

# Configuration
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-RG-TBWA-ProjectScout-Compute}"
VM_NAME="${AZURE_VM_NAME:-scout-analytics-vm}"
LOCATION="${AZURE_LOCATION:-East US}"
VM_SIZE="${AZURE_VM_SIZE:-Standard_B2s}"  # 2 vCPUs, 4GB RAM
VM_IMAGE="Ubuntu2204"
ADMIN_USERNAME="${AZURE_ADMIN_USERNAME:-azureuser}"
NSG_NAME="${VM_NAME}-nsg"
VNET_NAME="${VM_NAME}-vnet"
SUBNET_NAME="${VM_NAME}-subnet"
PUBLIC_IP_NAME="${VM_NAME}-ip"
NIC_NAME="${VM_NAME}-nic"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    print_status "Checking prerequisites..."

    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi

    # Check if logged in to Azure
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi

    # Check if SSH key exists
    if [ ! -f ~/.ssh/id_rsa.pub ]; then
        print_status "Generating SSH key pair..."
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "scout-analytics-vm"
    fi

    print_success "Prerequisites check passed"
}

create_resource_group() {
    print_status "Creating/verifying resource group: $RESOURCE_GROUP"

    if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        print_success "Resource group $RESOURCE_GROUP already exists"
    else
        print_status "Creating resource group $RESOURCE_GROUP in $LOCATION"
        az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
        print_success "Resource group created"
    fi
}

create_network_infrastructure() {
    print_status "Creating network infrastructure..."

    # Create Virtual Network
    if ! az network vnet show --resource-group "$RESOURCE_GROUP" --name "$VNET_NAME" &> /dev/null; then
        print_status "Creating virtual network: $VNET_NAME"
        az network vnet create \
            --resource-group "$RESOURCE_GROUP" \
            --name "$VNET_NAME" \
            --address-prefix 10.0.0.0/16 \
            --subnet-name "$SUBNET_NAME" \
            --subnet-prefix 10.0.1.0/24 \
            --location "$LOCATION"
        print_success "Virtual network created"
    else
        print_success "Virtual network $VNET_NAME already exists"
    fi

    # Create Network Security Group
    if ! az network nsg show --resource-group "$RESOURCE_GROUP" --name "$NSG_NAME" &> /dev/null; then
        print_status "Creating network security group: $NSG_NAME"
        az network nsg create \
            --resource-group "$RESOURCE_GROUP" \
            --name "$NSG_NAME" \
            --location "$LOCATION"

        # Allow SSH
        az network nsg rule create \
            --resource-group "$RESOURCE_GROUP" \
            --nsg-name "$NSG_NAME" \
            --name "AllowSSH" \
            --protocol tcp \
            --priority 1001 \
            --destination-port-range 22 \
            --access allow

        # Allow HTTP (port 8080 for our API)
        az network nsg rule create \
            --resource-group "$RESOURCE_GROUP" \
            --nsg-name "$NSG_NAME" \
            --name "AllowAPI" \
            --protocol tcp \
            --priority 1002 \
            --destination-port-range 8080 \
            --access allow

        # Allow HTTPS (port 443)
        az network nsg rule create \
            --resource-group "$RESOURCE_GROUP" \
            --nsg-name "$NSG_NAME" \
            --name "AllowHTTPS" \
            --protocol tcp \
            --priority 1003 \
            --destination-port-range 443 \
            --access allow

        print_success "Network security group created with rules"
    else
        print_success "Network security group $NSG_NAME already exists"
    fi

    # Create Public IP
    if ! az network public-ip show --resource-group "$RESOURCE_GROUP" --name "$PUBLIC_IP_NAME" &> /dev/null; then
        print_status "Creating public IP: $PUBLIC_IP_NAME"
        az network public-ip create \
            --resource-group "$RESOURCE_GROUP" \
            --name "$PUBLIC_IP_NAME" \
            --allocation-method Static \
            --sku Standard \
            --location "$LOCATION"
        print_success "Public IP created"
    else
        print_success "Public IP $PUBLIC_IP_NAME already exists"
    fi

    # Create Network Interface
    if ! az network nic show --resource-group "$RESOURCE_GROUP" --name "$NIC_NAME" &> /dev/null; then
        print_status "Creating network interface: $NIC_NAME"
        az network nic create \
            --resource-group "$RESOURCE_GROUP" \
            --name "$NIC_NAME" \
            --vnet-name "$VNET_NAME" \
            --subnet "$SUBNET_NAME" \
            --public-ip-address "$PUBLIC_IP_NAME" \
            --network-security-group "$NSG_NAME" \
            --location "$LOCATION"
        print_success "Network interface created"
    else
        print_success "Network interface $NIC_NAME already exists"
    fi
}

create_virtual_machine() {
    print_status "Creating virtual machine: $VM_NAME"

    if az vm show --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" &> /dev/null; then
        print_success "Virtual machine $VM_NAME already exists"
        return 0
    fi

    print_status "Creating VM with size $VM_SIZE..."
    az vm create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --location "$LOCATION" \
        --nics "$NIC_NAME" \
        --image "$VM_IMAGE" \
        --size "$VM_SIZE" \
        --admin-username "$ADMIN_USERNAME" \
        --ssh-key-values ~/.ssh/id_rsa.pub \
        --custom-data @- << 'EOF'
#!/bin/bash

# Update system
apt-get update -y
apt-get upgrade -y

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt-get install -y nodejs

# Install PM2 for process management
npm install -g pm2

# Install nginx for reverse proxy
apt-get install -y nginx

# Install git
apt-get install -y git

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Create application directory
mkdir -p /opt/scout-analytics
chown azureuser:azureuser /opt/scout-analytics

# Create systemd service file
cat > /etc/systemd/system/scout-analytics.service << 'SERVICE_EOF'
[Unit]
Description=Scout Analytics API
After=network.target

[Service]
Type=forking
User=azureuser
WorkingDirectory=/opt/scout-analytics
ExecStart=/usr/bin/pm2 start src/server.js --name scout-analytics
ExecReload=/usr/bin/pm2 reload scout-analytics
ExecStop=/usr/bin/pm2 delete scout-analytics
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Configure nginx reverse proxy
cat > /etc/nginx/sites-available/scout-analytics << 'NGINX_EOF'
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

    # Health check endpoint
    location /health {
        proxy_pass http://localhost:8080/health;
        access_log off;
    }
}
NGINX_EOF

# Enable nginx site
ln -sf /etc/nginx/sites-available/scout-analytics /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
nginx -t

# Start and enable services
systemctl enable nginx
systemctl start nginx
systemctl enable scout-analytics

# Create log directory
mkdir -p /var/log/scout-analytics
chown azureuser:azureuser /var/log/scout-analytics

echo "VM setup completed!" > /tmp/setup-complete.log
EOF

    print_success "Virtual machine created and configured"
}

configure_vm_identity() {
    print_status "Configuring managed identity for Key Vault access..."

    # Enable system-assigned managed identity
    IDENTITY_RESULT=$(az vm identity assign \
        --name "$VM_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --output json)

    PRINCIPAL_ID=$(echo "$IDENTITY_RESULT" | jq -r '.systemAssignedIdentity.principalId')

    if [ "$PRINCIPAL_ID" != "null" ]; then
        print_success "Managed identity configured with Principal ID: $PRINCIPAL_ID"

        # Grant Key Vault access
        print_status "Granting Key Vault access to managed identity..."
        az keyvault set-policy \
            --name "kv-scout-tbwa-1750202017" \
            --object-id "$PRINCIPAL_ID" \
            --secret-permissions get list \
            > /dev/null

        print_success "Key Vault access granted"
    else
        print_warning "Failed to configure managed identity"
    fi
}

deploy_application() {
    print_status "Deploying Scout Analytics API to VM..."

    # Get VM IP address
    VM_IP=$(az network public-ip show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$PUBLIC_IP_NAME" \
        --query ipAddress \
        --output tsv)

    if [ -z "$VM_IP" ]; then
        print_error "Failed to get VM IP address"
        return 1
    fi

    print_status "VM IP Address: $VM_IP"

    # Wait for VM to be ready
    print_status "Waiting for VM to be ready..."
    sleep 60

    # Create deployment package
    print_status "Creating deployment package..."

    # Create temporary directory for deployment
    TEMP_DIR=$(mktemp -d)

    # Copy application files
    cp -r src/ "$TEMP_DIR/"
    cp package*.json "$TEMP_DIR/"

    # Create environment file
    cat > "$TEMP_DIR/.env" << ENV_EOF
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

    # Create deployment script
    cat > "$TEMP_DIR/deploy-vm-app.sh" << 'DEPLOY_EOF'
#!/bin/bash
set -euo pipefail

cd /opt/scout-analytics

# Install dependencies
npm ci --only=production

# Get database connection string from Key Vault using managed identity
echo "Retrieving database connection string..."
export AZURE_SQL_CONNECTION_STRING=$(az keyvault secret show \
    --vault-name kv-scout-tbwa-1750202017 \
    --name azure-sql-conn-str \
    --query value \
    --output tsv)

# Start the application with PM2
pm2 delete scout-analytics 2>/dev/null || true
pm2 start src/server.js \
    --name scout-analytics \
    --log /var/log/scout-analytics/app.log \
    --error /var/log/scout-analytics/error.log \
    --env production

# Save PM2 configuration
pm2 save

# Start systemd service
sudo systemctl start scout-analytics
sudo systemctl enable scout-analytics

echo "Application deployed successfully!"
DEPLOY_EOF

    chmod +x "$TEMP_DIR/deploy-vm-app.sh"

    # Copy files to VM
    print_status "Copying application files to VM..."

    # Try to copy files (with retries)
    for i in {1..5}; do
        if scp -o StrictHostKeyChecking=no -o ConnectTimeout=30 -r "$TEMP_DIR"/* "$ADMIN_USERNAME@$VM_IP:/opt/scout-analytics/"; then
            print_success "Files copied successfully"
            break
        else
            print_warning "Copy attempt $i failed, retrying in 10 seconds..."
            sleep 10
        fi

        if [ $i -eq 5 ]; then
            print_error "Failed to copy files after 5 attempts"
            rm -rf "$TEMP_DIR"
            return 1
        fi
    done

    # Execute deployment script on VM
    print_status "Executing deployment script on VM..."
    ssh -o StrictHostKeyChecking=no "$ADMIN_USERNAME@$VM_IP" "cd /opt/scout-analytics && ./deploy-vm-app.sh"

    # Clean up temporary directory
    rm -rf "$TEMP_DIR"

    print_success "Application deployment completed"
}

verify_deployment() {
    print_status "Verifying deployment..."

    # Get VM IP address
    VM_IP=$(az network public-ip show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$PUBLIC_IP_NAME" \
        --query ipAddress \
        --output tsv)

    print_status "Waiting for application to start..."
    sleep 30

    # Test health endpoint
    if curl -f "http://$VM_IP/health" > /dev/null 2>&1; then
        print_success "Health check passed"
    else
        print_warning "Health check failed - checking application status..."

        # Check application status on VM
        ssh -o StrictHostKeyChecking=no "$ADMIN_USERNAME@$VM_IP" "pm2 status"
    fi

    print_success "Deployment verification completed"
    echo ""
    echo "🎉 Scout Analytics API deployed successfully on Azure VM!"
    echo ""
    echo "📍 VM IP Address: $VM_IP"
    echo "🏥 Health Check: http://$VM_IP/health"
    echo "📊 API Documentation: http://$VM_IP/api/v1"
    echo "🖥️  SSH Access: ssh $ADMIN_USERNAME@$VM_IP"
    echo ""
    echo "Available endpoints:"
    echo "  • Analytics: http://$VM_IP/api/v1/analytics"
    echo "  • Monitoring: http://$VM_IP/api/v1/monitoring"
    echo "  • Cultural: http://$VM_IP/api/v1/cultural"
    echo ""
    echo "VM Management:"
    echo "  • Check logs: ssh $ADMIN_USERNAME@$VM_IP 'pm2 logs'"
    echo "  • Restart app: ssh $ADMIN_USERNAME@$VM_IP 'pm2 restart scout-analytics'"
    echo "  • VM status: az vm show --resource-group $RESOURCE_GROUP --name $VM_NAME --show-details"
}

# Main deployment process
main() {
    print_status "Starting Azure VM deployment for Scout Analytics API"
    echo "================================================="
    echo "Resource Group: $RESOURCE_GROUP"
    echo "VM Name: $VM_NAME"
    echo "Location: $LOCATION"
    echo "VM Size: $VM_SIZE"
    echo "Admin Username: $ADMIN_USERNAME"
    echo "================================================="
    echo ""

    check_prerequisites
    create_resource_group
    create_network_infrastructure
    create_virtual_machine
    configure_vm_identity
    deploy_application
    verify_deployment
}

# Check if running as source or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi