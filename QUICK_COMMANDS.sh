#!/bin/bash
# Scout v7 Auto-Sync Quick Deployment Commands
# Usage: ./QUICK_COMMANDS.sh [docker|k8s|test]

set -e

# Configuration
AZSQL_HOST="sqltbwaprojectscoutserver.database.windows.net"
AZSQL_DB="SQL-TBWA-ProjectScout-Reporting-Prod"
AZSQL_USER_WRITER="TBWA"
AZSQL_PASS_WRITER="R@nd0mPA$$2025!"
IMAGE="ghcr.io/jgtolentino/scout-agentic-analytics/auto-sync:latest"

echo "🚀 Scout v7 Auto-Sync Quick Deploy"
echo "=================================="

case ${1:-docker} in
  "test")
    echo "🧪 Testing SQL connection..."
    sqlcmd -S "$AZSQL_HOST" -d "$AZSQL_DB" -U "$AZSQL_USER_WRITER" -P "$AZSQL_PASS_WRITER" -Q "SELECT 'Connection OK' AS status, SYSUTCDATETIME() AS current_time"

    echo "🧪 Running one-shot export test..."
    docker run --rm \
      -e AZSQL_HOST="$AZSQL_HOST" \
      -e AZSQL_DB="$AZSQL_DB" \
      -e AZSQL_USER_WRITER="$AZSQL_USER_WRITER" \
      -e AZSQL_PASS_WRITER="$AZSQL_PASS_WRITER" \
      -e TASK_OVERRIDE="EXPORT_ONCE" \
      -e LOG_LEVEL="INFO" \
      "$IMAGE"

    echo "✅ Test completed successfully!"
    ;;

  "docker")
    echo "🐳 Deploying Docker container..."

    # Stop existing container if running
    docker stop scout-autosync 2>/dev/null || true
    docker rm scout-autosync 2>/dev/null || true

    # Create exports directory
    mkdir -p ./exports

    # Start container
    docker run -d --name scout-autosync \
      --restart=unless-stopped \
      -p 8080:8080 \
      -v "$(pwd)/exports:/app/exports" \
      -e AZSQL_HOST="$AZSQL_HOST" \
      -e AZSQL_DB="$AZSQL_DB" \
      -e AZSQL_USER_WRITER="$AZSQL_USER_WRITER" \
      -e AZSQL_PASS_WRITER="$AZSQL_PASS_WRITER" \
      -e SYNC_INTERVAL="60" \
      -e LOG_LEVEL="INFO" \
      "$IMAGE"

    echo "⏳ Waiting for container to start..."
    sleep 10

    # Health check
    if curl -fsS http://localhost:8080/healthz >/dev/null 2>&1; then
      echo "✅ Container healthy at http://localhost:8080/healthz"
      echo "📊 View logs: docker logs -f scout-autosync"
      echo "🛑 Stop: docker stop scout-autosync"
    else
      echo "❌ Health check failed"
      echo "📊 Check logs: docker logs scout-autosync"
      exit 1
    fi
    ;;

  "k8s")
    echo "☸️  Deploying to Kubernetes..."

    # Create secret
    kubectl create secret generic scout-autosync-secrets \
      --from-literal=AZSQL_HOST="$AZSQL_HOST" \
      --from-literal=AZSQL_DB="$AZSQL_DB" \
      --from-literal=AZSQL_USER_WRITER="$AZSQL_USER_WRITER" \
      --from-literal=AZSQL_PASS_WRITER="$AZSQL_PASS_WRITER" \
      --dry-run=client -o yaml | kubectl apply -f -

    # Deploy application
    kubectl apply -f k8s/deploy-autosync.yaml

    echo "⏳ Waiting for deployment to be ready..."
    kubectl rollout status deployment/scout-autosync --timeout=300s

    # Port forward for health check
    kubectl port-forward deployment/scout-autosync 8080:8080 &
    PF_PID=$!
    sleep 5

    if curl -fsS http://localhost:8080/healthz >/dev/null 2>&1; then
      echo "✅ Deployment healthy"
      echo "📊 View logs: kubectl logs -f deployment/scout-autosync"
      echo "🌐 Access: kubectl port-forward deployment/scout-autosync 8080:8080"
    else
      echo "❌ Health check failed"
      echo "📊 Check logs: kubectl logs deployment/scout-autosync"
    fi

    # Stop port forward
    kill $PF_PID 2>/dev/null || true
    ;;

  "parity")
    echo "⚖️  Running parity check..."
    docker run --rm \
      -e AZSQL_HOST="$AZSQL_HOST" \
      -e AZSQL_DB="$AZSQL_DB" \
      -e AZSQL_USER_WRITER="$AZSQL_USER_WRITER" \
      -e AZSQL_PASS_WRITER="$AZSQL_PASS_WRITER" \
      -e TASK_OVERRIDE="PARITY_CHECK" \
      -e PARITY_DAYS_BACK="30" \
      -e LOG_LEVEL="INFO" \
      "$IMAGE"
    echo "✅ Parity check completed"
    ;;

  "sync-once")
    echo "🔄 Running single sync cycle..."
    docker run --rm \
      -e AZSQL_HOST="$AZSQL_HOST" \
      -e AZSQL_DB="$AZSQL_DB" \
      -e AZSQL_USER_WRITER="$AZSQL_USER_WRITER" \
      -e AZSQL_PASS_WRITER="$AZSQL_PASS_WRITER" \
      -e TASK_OVERRIDE="SYNC_ONCE" \
      -e LOG_LEVEL="INFO" \
      "$IMAGE"
    echo "✅ Sync cycle completed"
    ;;

  *)
    echo "Usage: $0 [test|docker|k8s|parity|sync-once]"
    echo ""
    echo "Commands:"
    echo "  test      - Test SQL connection and one-shot export"
    echo "  docker    - Deploy continuous auto-sync with Docker"
    echo "  k8s       - Deploy to Kubernetes cluster"
    echo "  parity    - Run parity check (30 days)"
    echo "  sync-once - Run single sync cycle test"
    echo ""
    echo "Examples:"
    echo "  $0 test                    # Quick validation"
    echo "  $0 docker                  # Production Docker deployment"
    echo "  $0 k8s                     # Production K8s deployment"
    exit 1
    ;;
esac

echo ""
echo "🎉 Scout v7 Auto-Sync deployment complete!"
echo "📚 Full docs: ./DEPLOY_NOW.md"
echo "📊 Dashboard: ./grafana/scout_v7_autosync_dashboard.json"