#!/bin/bash

# Secure MCP Network Configuration Script
# Locks down MCP servers to private network/VPN access only

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔒 MCP Network Security Configuration${NC}"
echo "====================================="

# Configuration
MCP_PORTS=(8888 8890 8891 8892 8893)  # MCP server ports
VPN_SUBNET="10.8.0.0/24"              # Example VPN subnet
OFFICE_SUBNET="192.168.1.0/24"        # Example office subnet
LOCALHOST="127.0.0.1"

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root${NC}"
        exit 1
    fi
}

# Function to backup current iptables rules
backup_iptables() {
    echo -e "${YELLOW}Backing up current iptables rules...${NC}"
    iptables-save > /etc/iptables/rules.backup.$(date +%Y%m%d-%H%M%S)
    echo -e "${GREEN}✓ Backup created${NC}"
}

# Function to configure UFW (Uncomplicated Firewall) - Ubuntu/Debian
configure_ufw() {
    echo -e "${YELLOW}Configuring UFW firewall rules...${NC}"
    
    # Enable UFW
    ufw --force enable
    
    # Default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH (important!)
    ufw allow 22/tcp comment "SSH access"
    
    # Allow MCP ports only from specific networks
    for port in "${MCP_PORTS[@]}"; do
        # Allow from localhost
        ufw allow from $LOCALHOST to any port $port comment "MCP server port $port - localhost"
        
        # Allow from VPN subnet
        ufw allow from $VPN_SUBNET to any port $port comment "MCP server port $port - VPN"
        
        # Allow from office subnet
        ufw allow from $OFFICE_SUBNET to any port $port comment "MCP server port $port - Office"
        
        echo -e "${GREEN}✓ Configured port $port${NC}"
    done
    
    # Reload UFW
    ufw reload
    
    echo -e "${GREEN}✓ UFW configuration complete${NC}"
}

# Function to configure iptables directly
configure_iptables() {
    echo -e "${YELLOW}Configuring iptables rules...${NC}"
    
    # Create MCP chain
    iptables -N MCP_SERVERS 2>/dev/null || true
    
    # Flush MCP chain
    iptables -F MCP_SERVERS
    
    # Add rules for each MCP port
    for port in "${MCP_PORTS[@]}"; do
        # Allow localhost
        iptables -A MCP_SERVERS -p tcp --dport $port -s $LOCALHOST -j ACCEPT
        
        # Allow VPN subnet
        iptables -A MCP_SERVERS -p tcp --dport $port -s $VPN_SUBNET -j ACCEPT
        
        # Allow office subnet
        iptables -A MCP_SERVERS -p tcp --dport $port -s $OFFICE_SUBNET -j ACCEPT
        
        # Log and drop everything else
        iptables -A MCP_SERVERS -p tcp --dport $port -j LOG --log-prefix "MCP_BLOCKED: "
        iptables -A MCP_SERVERS -p tcp --dport $port -j DROP
        
        echo -e "${GREEN}✓ Configured port $port${NC}"
    done
    
    # Link MCP chain to INPUT
    iptables -D INPUT -j MCP_SERVERS 2>/dev/null || true
    iptables -I INPUT -j MCP_SERVERS
    
    # Save rules
    if command -v iptables-save &> /dev/null; then
        iptables-save > /etc/iptables/rules.v4
    fi
    
    echo -e "${GREEN}✓ iptables configuration complete${NC}"
}

# Function to configure firewalld (CentOS/RHEL)
configure_firewalld() {
    echo -e "${YELLOW}Configuring firewalld rules...${NC}"
    
    # Create MCP zone
    firewall-cmd --permanent --new-zone=mcp 2>/dev/null || true
    
    # Add sources to MCP zone
    firewall-cmd --permanent --zone=mcp --add-source=$LOCALHOST
    firewall-cmd --permanent --zone=mcp --add-source=$VPN_SUBNET
    firewall-cmd --permanent --zone=mcp --add-source=$OFFICE_SUBNET
    
    # Add ports to MCP zone
    for port in "${MCP_PORTS[@]}"; do
        firewall-cmd --permanent --zone=mcp --add-port=$port/tcp
        echo -e "${GREEN}✓ Configured port $port${NC}"
    done
    
    # Reload firewalld
    firewall-cmd --reload
    
    echo -e "${GREEN}✓ firewalld configuration complete${NC}"
}

# Function to configure nginx reverse proxy with IP restrictions
configure_nginx() {
    echo -e "${YELLOW}Creating nginx configuration for MCP servers...${NC}"
    
    cat > /etc/nginx/sites-available/mcp-servers << 'EOF'
# MCP Server Proxy Configuration
# IP-restricted access to MCP servers

# Define allowed IPs
geo $allowed_ip {
    default 0;
    127.0.0.1 1;
    10.8.0.0/24 1;      # VPN subnet
    192.168.1.0/24 1;   # Office subnet
}

# HR Intelligence MCP Server
server {
    listen 443 ssl http2;
    server_name mcp-hr.internal.company.com;
    
    ssl_certificate /etc/nginx/ssl/mcp.crt;
    ssl_certificate_key /etc/nginx/ssl/mcp.key;
    
    # IP restriction
    if ($allowed_ip = 0) {
        return 403;
    }
    
    location / {
        proxy_pass http://localhost:8890;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Security headers
        add_header X-Frame-Options "DENY" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
    }
    
    # Logging
    access_log /var/log/nginx/mcp-hr-access.log;
    error_log /var/log/nginx/mcp-hr-error.log;
}

# Finance Operations MCP Server
server {
    listen 443 ssl http2;
    server_name mcp-finance.internal.company.com;
    
    ssl_certificate /etc/nginx/ssl/mcp.crt;
    ssl_certificate_key /etc/nginx/ssl/mcp.key;
    
    if ($allowed_ip = 0) {
        return 403;
    }
    
    location / {
        proxy_pass http://localhost:8891;
        # ... same proxy configuration as above
    }
}

# Add similar blocks for other MCP servers...
EOF
    
    # Enable the configuration
    ln -sf /etc/nginx/sites-available/mcp-servers /etc/nginx/sites-enabled/
    
    # Test nginx configuration
    nginx -t
    
    # Reload nginx
    systemctl reload nginx
    
    echo -e "${GREEN}✓ nginx configuration complete${NC}"
}

# Function to configure SSH tunnel access
configure_ssh_tunnel() {
    echo -e "${YELLOW}Configuring SSH tunnel access...${NC}"
    
    # Create dedicated user for MCP tunnel access
    useradd -r -s /bin/false -d /var/empty/mcp-tunnel mcp-tunnel 2>/dev/null || true
    
    # Create SSH config for tunnel-only access
    cat > /etc/ssh/sshd_config.d/mcp-tunnel.conf << 'EOF'
# MCP Tunnel User Configuration
Match User mcp-tunnel
    # Allow only port forwarding
    AllowTcpForwarding yes
    X11Forwarding no
    PermitTunnel no
    GatewayPorts no
    AllowAgentForwarding no
    
    # Force command to prevent shell access
    ForceCommand /bin/false
    
    # Restrict to specific ports
    PermitOpen localhost:8888 localhost:8890 localhost:8891 localhost:8892 localhost:8893
EOF
    
    # Restart SSH service
    systemctl restart sshd
    
    echo -e "${GREEN}✓ SSH tunnel configuration complete${NC}"
    echo -e "${YELLOW}To use: ssh -L 8888:localhost:8888 mcp-tunnel@server${NC}"
}

# Function to configure fail2ban for MCP servers
configure_fail2ban() {
    echo -e "${YELLOW}Configuring fail2ban for MCP servers...${NC}"
    
    # Create fail2ban filter
    cat > /etc/fail2ban/filter.d/mcp-auth.conf << 'EOF'
[Definition]
failregex = ^.*MCP authentication failed.*from <HOST>.*$
            ^.*MCP rate limit exceeded.*from <HOST>.*$
            ^.*MCP_BLOCKED:.*SRC=<HOST>.*$
ignoreregex =
EOF
    
    # Create fail2ban jail
    cat > /etc/fail2ban/jail.d/mcp.conf << 'EOF'
[mcp-auth]
enabled = true
port = 8888,8890,8891,8892,8893
protocol = tcp
filter = mcp-auth
logpath = /var/log/mcp-audit.log
          /var/log/syslog
maxretry = 5
findtime = 600
bantime = 3600
EOF
    
    # Restart fail2ban
    systemctl restart fail2ban
    
    echo -e "${GREEN}✓ fail2ban configuration complete${NC}"
}

# Function to create monitoring script
create_monitoring_script() {
    echo -e "${YELLOW}Creating MCP monitoring script...${NC}"
    
    cat > /usr/local/bin/monitor-mcp-access.sh << 'EOF'
#!/bin/bash

# Monitor MCP access attempts
LOG_FILE="/var/log/mcp-access-monitor.log"

# Function to log with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Monitor iptables logs for blocked attempts
tail -f /var/log/syslog | while read line; do
    if echo "$line" | grep -q "MCP_BLOCKED"; then
        # Extract source IP
        SOURCE_IP=$(echo "$line" | grep -oP 'SRC=\K[^ ]+')
        PORT=$(echo "$line" | grep -oP 'DPT=\K[^ ]+')
        
        log_message "BLOCKED: Attempt from $SOURCE_IP to port $PORT"
        
        # Send alert if needed (example: to Slack)
        # curl -X POST -H 'Content-type: application/json' \
        #     --data "{\"text\":\"MCP Access Blocked: $SOURCE_IP attempted to access port $PORT\"}" \
        #     YOUR_SLACK_WEBHOOK_URL
    fi
done
EOF
    
    chmod +x /usr/local/bin/monitor-mcp-access.sh
    
    # Create systemd service for monitoring
    cat > /etc/systemd/system/mcp-monitor.service << 'EOF'
[Unit]
Description=MCP Access Monitoring
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/monitor-mcp-access.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable mcp-monitor.service
    systemctl start mcp-monitor.service
    
    echo -e "${GREEN}✓ Monitoring script created${NC}"
}

# Function to display summary
display_summary() {
    echo -e "\n${GREEN}=== MCP Network Security Configuration Summary ===${NC}"
    echo -e "✅ Firewall rules configured for MCP ports: ${MCP_PORTS[*]}"
    echo -e "✅ Access allowed only from:"
    echo -e "   - Localhost (127.0.0.1)"
    echo -e "   - VPN subnet ($VPN_SUBNET)"
    echo -e "   - Office subnet ($OFFICE_SUBNET)"
    echo -e "✅ SSH tunnel access configured for user 'mcp-tunnel'"
    echo -e "✅ fail2ban protection enabled"
    echo -e "✅ Access monitoring enabled"
    echo -e "\n${YELLOW}⚠️  Important:${NC}"
    echo -e "1. Update VPN_SUBNET and OFFICE_SUBNET variables to match your network"
    echo -e "2. Generate SSH keys for mcp-tunnel user"
    echo -e "3. Configure SSL certificates for nginx"
    echo -e "4. Test all connections before going live"
    echo -e "5. Monitor /var/log/mcp-access-monitor.log for blocked attempts"
}

# Main execution
main() {
    check_root
    
    echo -e "${YELLOW}Select firewall system:${NC}"
    echo "1) UFW (Ubuntu/Debian)"
    echo "2) iptables (Generic)"
    echo "3) firewalld (CentOS/RHEL)"
    read -p "Enter choice [1-3]: " choice
    
    backup_iptables
    
    case $choice in
        1)
            configure_ufw
            ;;
        2)
            configure_iptables
            ;;
        3)
            configure_firewalld
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
    
    # Additional security configurations
    configure_ssh_tunnel
    configure_fail2ban
    create_monitoring_script
    
    # Optional nginx configuration
    read -p "Configure nginx reverse proxy? (y/n): " nginx_choice
    if [[ $nginx_choice == "y" ]]; then
        configure_nginx
    fi
    
    display_summary
}

# Run main function
main "$@"