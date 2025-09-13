#!/bin/bash

# Production Agent Deployment Script
# Deploys agents from the unified registry to production infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AGENT_REGISTRY_DIR="/Users/tbwa/agents/production"
DEPLOYMENT_ENV="${DEPLOYMENT_ENV:-production}"
NAMESPACE="${NAMESPACE:-agent-platform}"
ROLLBACK_ENABLED="${ROLLBACK_ENABLED:-true}"

# Help function
show_help() {
    cat << EOF
Production Agent Deployment Script

Usage: ./deploy_agent.sh [OPTIONS] AGENT_NAME

OPTIONS:
    -h, --help              Show this help message
    -e, --env ENV          Deployment environment (default: production)
    -n, --namespace NS     Kubernetes namespace (default: agent-platform)
    -v, --version VERSION  Agent version to deploy (default: latest)
    -d, --dry-run          Perform dry run without actual deployment
    --no-rollback          Disable automatic rollback on failure

EXAMPLES:
    # Deploy Lyra-Primary to production
    ./deploy_agent.sh Lyra-Primary

    # Deploy Master-Toggle with specific version
    ./deploy_agent.sh -v 1.0.0 Master-Toggle

    # Dry run deployment
    ./deploy_agent.sh -d Iska

SUPPORTED AGENTS:
    Lyra-Primary, Lyra-Secondary, Master-Toggle, Iska, ToggleBot,
    Savage, Fully, Doer, and more...

EOF
}

# Parse arguments
AGENT_NAME=""
DRY_RUN=false
VERSION="latest"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -e|--env)
            DEPLOYMENT_ENV="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-rollback)
            ROLLBACK_ENABLED=false
            shift
            ;;
        *)
            AGENT_NAME="$1"
            shift
            ;;
    esac
done

# Validate agent name
if [ -z "$AGENT_NAME" ]; then
    echo -e "${RED}Error: Agent name is required${NC}"
    show_help
    exit 1
fi

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}Checking prerequisites...${NC}"
    
    # Check for required tools
    for tool in kubectl docker helm jq; do
        if ! command -v $tool &> /dev/null; then
            echo -e "${RED}Error: $tool is not installed${NC}"
            exit 1
        fi
    done
    
    # Check kubectl connection
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
        exit 1
    fi
    
    # Check agent YAML exists
    AGENT_YAML="$AGENT_REGISTRY_DIR/agents/${AGENT_NAME,,}.yaml"
    if [ ! -f "$AGENT_YAML" ]; then
        echo -e "${RED}Error: Agent configuration not found: $AGENT_YAML${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Prerequisites satisfied${NC}"
}

# Function to validate agent configuration
validate_agent_config() {
    echo -e "${BLUE}Validating agent configuration...${NC}"
    
    # Parse YAML and validate required fields
    local validation_errors=0
    
    # Check required fields
    for field in "name" "version" "type" "deployment"; do
        if ! grep -q "^$field:" "$AGENT_YAML"; then
            echo -e "${RED}✗ Missing required field: $field${NC}"
            ((validation_errors++))
        fi
    done
    
    # Validate deployment type
    local deployment_type=$(grep "^deployment:" -A 1 "$AGENT_YAML" | grep "type:" | awk '{print $2}')
    if [[ ! "$deployment_type" =~ ^(kubernetes|docker|edge_function|lambda)$ ]]; then
        echo -e "${RED}✗ Invalid deployment type: $deployment_type${NC}"
        ((validation_errors++))
    fi
    
    if [ $validation_errors -gt 0 ]; then
        echo -e "${RED}Validation failed with $validation_errors errors${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Configuration validated${NC}"
}

# Function to build agent image
build_agent_image() {
    echo -e "${BLUE}Building agent image...${NC}"
    
    local agent_dir="$AGENT_REGISTRY_DIR/agents/${AGENT_NAME,,}"
    local image_name="tbwa-agents/${AGENT_NAME,,}:$VERSION"
    
    if [ $DRY_RUN = true ]; then
        echo -e "${YELLOW}[DRY RUN] Would build image: $image_name${NC}"
        return 0
    fi
    
    # Check if Dockerfile exists
    if [ -f "$agent_dir/Dockerfile" ]; then
        echo "Building from Dockerfile..."
        docker build -t "$image_name" "$agent_dir"
    else
        # Use generic agent Dockerfile
        echo "Using generic agent Dockerfile..."
        docker build -t "$image_name" \
            --build-arg AGENT_NAME="$AGENT_NAME" \
            --build-arg AGENT_VERSION="$VERSION" \
            -f "$AGENT_REGISTRY_DIR/Dockerfile.agent" \
            "$AGENT_REGISTRY_DIR"
    fi
    
    # Tag for registry
    docker tag "$image_name" "registry.tbwa.com/$image_name"
    
    # Push to registry
    echo "Pushing to registry..."
    docker push "registry.tbwa.com/$image_name"
    
    echo -e "${GREEN}✓ Image built and pushed${NC}"
}

# Function to deploy to Kubernetes
deploy_to_kubernetes() {
    echo -e "${BLUE}Deploying to Kubernetes...${NC}"
    
    local deployment_file="/tmp/${AGENT_NAME,,}-deployment.yaml"
    
    # Generate deployment manifest
    cat > "$deployment_file" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${AGENT_NAME,,}
  namespace: $NAMESPACE
  labels:
    app: ${AGENT_NAME,,}
    version: $VERSION
    environment: $DEPLOYMENT_ENV
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${AGENT_NAME,,}
  template:
    metadata:
      labels:
        app: ${AGENT_NAME,,}
        version: $VERSION
    spec:
      containers:
      - name: ${AGENT_NAME,,}
        image: registry.tbwa.com/tbwa-agents/${AGENT_NAME,,}:$VERSION
        ports:
        - containerPort: 8080
        env:
        - name: AGENT_NAME
          value: "$AGENT_NAME"
        - name: DEPLOYMENT_ENV
          value: "$DEPLOYMENT_ENV"
        - name: SUPABASE_URL
          valueFrom:
            secretKeyRef:
              name: supabase-credentials
              key: url
        - name: SUPABASE_SERVICE_ROLE_KEY
          valueFrom:
            secretKeyRef:
              name: supabase-credentials
              key: service-role-key
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: ${AGENT_NAME,,}
  namespace: $NAMESPACE
spec:
  selector:
    app: ${AGENT_NAME,,}
  ports:
  - port: 80
    targetPort: 8080
EOF

    if [ $DRY_RUN = true ]; then
        echo -e "${YELLOW}[DRY RUN] Would apply deployment:${NC}"
        cat "$deployment_file"
        return 0
    fi
    
    # Store current deployment for rollback
    kubectl get deployment "${AGENT_NAME,,}" -n "$NAMESPACE" -o yaml > "/tmp/${AGENT_NAME,,}-backup.yaml" 2>/dev/null || true
    
    # Apply deployment
    kubectl apply -f "$deployment_file"
    
    # Wait for rollout
    echo "Waiting for deployment to complete..."
    if kubectl rollout status deployment/"${AGENT_NAME,,}" -n "$NAMESPACE" --timeout=300s; then
        echo -e "${GREEN}✓ Deployment successful${NC}"
    else
        echo -e "${RED}✗ Deployment failed${NC}"
        
        if [ "$ROLLBACK_ENABLED" = true ] && [ -f "/tmp/${AGENT_NAME,,}-backup.yaml" ]; then
            echo -e "${YELLOW}Initiating rollback...${NC}"
            kubectl apply -f "/tmp/${AGENT_NAME,,}-backup.yaml"
            kubectl rollout status deployment/"${AGENT_NAME,,}" -n "$NAMESPACE" --timeout=300s
            echo -e "${GREEN}✓ Rollback completed${NC}"
        fi
        
        exit 1
    fi
}

# Function to update agent registry
update_agent_registry() {
    echo -e "${BLUE}Updating agent registry...${NC}"
    
    if [ $DRY_RUN = true ]; then
        echo -e "${YELLOW}[DRY RUN] Would update agent status in registry${NC}"
        return 0
    fi
    
    # Update agent status in database
    cat << EOF | python3
import os
from supabase import create_client

# Initialize Supabase client
url = os.getenv('SUPABASE_URL')
key = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
supabase = create_client(url, key)

# Update agent status
result = supabase.table('agents').update({
    'status': 'active',
    'version': '$VERSION',
    'last_heartbeat': 'NOW()',
    'deployment_type': 'kubernetes',
    'endpoint_url': 'http://${AGENT_NAME,,}.$NAMESPACE.svc.cluster.local',
    'health_check_url': 'http://${AGENT_NAME,,}.$NAMESPACE.svc.cluster.local/health'
}).eq('agent_name', '$AGENT_NAME').execute()

print(f"Updated agent registry: {result}")

# Create audit log
audit = supabase.table('audit_log').insert({
    'agent_id': result.data[0]['id'] if result.data else None,
    'event_type': 'deployment',
    'event_data': {
        'version': '$VERSION',
        'environment': '$DEPLOYMENT_ENV',
        'namespace': '$NAMESPACE'
    },
    'initiated_by': 'deployment_script',
    'success': True
}).execute()

print(f"Created audit log: {audit}")
EOF
    
    echo -e "${GREEN}✓ Registry updated${NC}"
}

# Function to run health checks
run_health_checks() {
    echo -e "${BLUE}Running health checks...${NC}"
    
    local health_url="http://${AGENT_NAME,,}.$NAMESPACE.svc.cluster.local/health"
    local max_attempts=10
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if kubectl exec -n "$NAMESPACE" deployment/"${AGENT_NAME,,}" -- curl -s "$health_url" | grep -q "healthy"; then
            echo -e "${GREEN}✓ Health check passed${NC}"
            return 0
        fi
        
        echo "Waiting for agent to become healthy... (attempt $((attempt+1))/$max_attempts)"
        sleep 5
        ((attempt++))
    done
    
    echo -e "${RED}✗ Health check failed${NC}"
    return 1
}

# Function to send notifications
send_notifications() {
    local status="$1"
    local message="$2"
    
    echo -e "${BLUE}Sending deployment notifications...${NC}"
    
    # Slack notification
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        curl -X POST "$SLACK_WEBHOOK_URL" \
            -H 'Content-Type: application/json' \
            -d "{
                \"text\": \"Agent Deployment: $AGENT_NAME\",
                \"attachments\": [{
                    \"color\": \"$([ "$status" = "success" ] && echo "good" || echo "danger")\",
                    \"fields\": [
                        {\"title\": \"Agent\", \"value\": \"$AGENT_NAME\", \"short\": true},
                        {\"title\": \"Version\", \"value\": \"$VERSION\", \"short\": true},
                        {\"title\": \"Environment\", \"value\": \"$DEPLOYMENT_ENV\", \"short\": true},
                        {\"title\": \"Status\", \"value\": \"$status\", \"short\": true},
                        {\"title\": \"Message\", \"value\": \"$message\"}
                    ]
                }]
            }"
    fi
}

# Main deployment flow
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Production Agent Deployment${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo "Agent: $AGENT_NAME"
    echo "Version: $VERSION"
    echo "Environment: $DEPLOYMENT_ENV"
    echo "Namespace: $NAMESPACE"
    echo ""
    
    # Pre-deployment checks
    check_prerequisites
    validate_agent_config
    
    # Build and deploy
    build_agent_image
    deploy_to_kubernetes
    
    # Post-deployment
    if run_health_checks; then
        update_agent_registry
        send_notifications "success" "Agent deployed successfully"
        
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}✓ Deployment completed successfully!${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""
        echo "Agent URL: http://${AGENT_NAME,,}.$NAMESPACE.svc.cluster.local"
        echo "Health Check: http://${AGENT_NAME,,}.$NAMESPACE.svc.cluster.local/health"
        echo ""
    else
        send_notifications "failed" "Health checks failed after deployment"
        exit 1
    fi
}

# Run main function
main