#!/bin/bash

set -euo pipefail

echo "==================================="
echo "Skyvern Container Boot Script"
echo "==================================="
echo "Starting all services..."
echo ""

# Log key environment variables (redacting sensitive values)
echo "Environment Configuration:"
# Redact password from DATABASE_STRING (handles most PostgreSQL URL formats)
# Note: For complex passwords with special chars, consider using external config tools
echo "  DATABASE_STRING: ${DATABASE_STRING:-<not set>}" | sed 's/:[^:@]*@/:***@/g; s/password=[^& ]*/password=***/g'
echo "  BROWSER_TYPE: ${BROWSER_TYPE:-<not set>}"
echo "  LLM_KEY: ${LLM_KEY:-<not set>}"
echo "  ENABLE_OPENAI: ${ENABLE_OPENAI:-<not set>}"
echo "  BACKEND_PORT: ${PORT:-8000}"
# Zeabur and other platforms often provide PORT env var for the main service port
export NGINX_PORT="${PORT:-8080}"
echo "  NGINX_PORT: ${NGINX_PORT}"
echo ""

# Track PIDs of background processes
declare -a PIDS=()

# Cleanup function to kill all child processes
cleanup() {
    echo ""
    echo "Shutting down services..."
    for pid in "${PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            echo "Stopping process $pid"
            kill -TERM "$pid" 2>/dev/null || true
        fi
    done
    wait
    echo "All services stopped"
    exit 1
}

trap cleanup SIGTERM SIGINT

# Ensure required directories exist
mkdir -p /data/log /data/videos /data/har /data/artifacts

# Start the backend API server
echo "Starting backend API server (port 8000)..."
python -m skyvern.forge > /data/log/backend.log 2>&1 &
BACKEND_PID=$!
PIDS+=($BACKEND_PID)
echo "  Backend started with PID: $BACKEND_PID"

# Start the local server (serves frontend)
echo "Starting local server (port 8081)..."
cd /app/skyvern-frontend
LOCAL_SERVER_PORT=8081 NODE_ENV=production node localServer.js > /data/log/localserver.log 2>&1 &
LOCAL_SERVER_PID=$!
PIDS+=($LOCAL_SERVER_PID)
echo "  Local server started with PID: $LOCAL_SERVER_PID"

# Start the artifact server
echo "Starting artifact server (port 9090)..."
node artifactServer.js > /data/log/artifactserver.log 2>&1 &
ARTIFACT_SERVER_PID=$!
PIDS+=($ARTIFACT_SERVER_PID)
echo "  Artifact server started with PID: $ARTIFACT_SERVER_PID"

cd /app

# Wait for backend to be ready
echo ""
echo "Waiting for backend API to be ready..."
MAX_WAIT=60
WAIT_COUNT=0
BACKEND_READY=false
BACKEND_HEALTH_URL="${BACKEND_HEALTH_CHECK_URL:-http://127.0.0.1:8000/api/v1/internal/auth/status}"

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if curl -s -f "$BACKEND_HEALTH_URL" > /dev/null 2>&1; then
        echo "  Backend is ready!"
        BACKEND_READY=true
        break
    fi
    
    # Check if backend process is still running
    if ! kill -0 $BACKEND_PID 2>/dev/null; then
        echo "  ERROR: Backend process died during startup!"
        echo "  Last 20 lines of backend log:"
        tail -n 20 /data/log/backend.log
        cleanup
        exit 1
    fi
    
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
    if [ $((WAIT_COUNT % 10)) -eq 0 ]; then
        echo "  Still waiting... ($WAIT_COUNT/$MAX_WAIT seconds)"
    fi
done

if [ "$BACKEND_READY" = false ]; then
    echo "  WARNING: Backend did not become ready within $MAX_WAIT seconds"
    echo "  Last 20 lines of backend log:"
    tail -n 20 /data/log/backend.log
    echo "  Continuing anyway..."
fi

# Generate nginx config from template with environment variable substitution
echo ""
echo "Generating nginx configuration (port ${NGINX_PORT})..."
if [ -f "/app/nginx.conf.template" ]; then
    # Try using envsubst if available, otherwise use sed
    if command -v envsubst >/dev/null 2>&1; then
        envsubst '${NGINX_PORT}' < /app/nginx.conf.template > /etc/nginx/nginx.conf
        echo "  Nginx config generated from template using envsubst"
    else
        # Fallback to sed if envsubst is not available
        sed "s/\${NGINX_PORT}/${NGINX_PORT}/g" /app/nginx.conf.template > /etc/nginx/nginx.conf
        echo "  Nginx config generated from template using sed (envsubst not available)"
    fi
else
    echo "  WARNING: nginx.conf.template not found, using existing nginx.conf"
fi

# Start nginx in foreground
echo ""
echo "Starting nginx reverse proxy (port ${NGINX_PORT} external)..."
echo "==================================="
echo "All services started successfully!"
echo "  Backend API: http://127.0.0.1:8000"
echo "  Frontend (internal): http://127.0.0.1:8081"
echo "  Artifacts (internal): http://127.0.0.1:9090"
echo "  Nginx (external): http://0.0.0.0:${NGINX_PORT}"
echo "==================================="
echo ""

# Start nginx in foreground - this blocks and keeps the container running
exec nginx -g 'daemon off;'
