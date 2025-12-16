#!/bin/bash

set -euo pipefail

echo "=================================="
echo "Skyvern Container Starting"
echo "=================================="

ALLOWED_SKIP_DB_MIGRATION_VERSION=${ALLOWED_SKIP_DB_MIGRATION_VERSION:-}
run_migration=true

if [ -n "$ALLOWED_SKIP_DB_MIGRATION_VERSION" ]; then
    current_version=$(alembic current 2>&1 | grep -Eo "[0-9a-f]{12,}" | tail -n 1 || echo "")
    echo "Current DB version: $current_version"
    if [ "$current_version" = "$ALLOWED_SKIP_DB_MIGRATION_VERSION" ]; then
        echo "WARNING: Skipping database migrations"
        run_migration=false
    fi
fi

if [ "$run_migration" = true ]; then
    echo "Running database migrations..."
    alembic upgrade head || echo "Migration warning, continuing..."
    alembic check || true
fi

if [ ! -f ".streamlit/secrets.toml" ]; then
    echo "Creating organization..."
    mkdir -p .streamlit
    org_output=$(python scripts/create_organization.py Skyvern-Open-Source || echo "")
    if [ -n "$org_output" ]; then
        api_token=$(echo "$org_output" | awk '/token=/{gsub(/.*token='\''|'\''.*/, ""); print}')
        echo -e "[skyvern]\nconfigs = [\n    {\"env\" = \"local\", \"host\" = \"http://skyvern:8000/api/v1\", \"orgs\" = [{name=\"Skyvern\", cred=\"$api_token\"}]}\n]" > .streamlit/secrets.toml
        echo "Organization created"
        echo "=========================================="
        echo "IMPORTANT: Save this API token!"
        echo "API Token: $api_token"
        echo "=========================================="
    fi
fi

# Ensure data directories exist
mkdir -p /data/log /data/videos /data/har /data/artifacts

# Start Xvfb
echo "Starting Xvfb..."
rm -f /tmp/.X99-lock
export DISPLAY=:99
Xvfb :99 -screen 0 1920x1080x16 > /data/log/xvfb.log 2>&1 &
xvfb_pid=$!
sleep 2

DISPLAY=:99 xterm > /dev/null 2>&1 &
python run_streaming.py > /data/log/streaming.log 2>&1 &

# Start backend on port 8000 (unset PORT to use default)
echo "Starting backend API on port 8000..."
(unset PORT && python -m skyvern.forge > /data/log/backend.log 2>&1) &
backend_pid=$!

# Start frontend
echo "Checking for frontend directory..."
if [ -d "/app/skyvern-frontend" ]; then
    echo "Frontend directory found, starting services..."
    cd /app/skyvern-frontend

    echo "Starting frontend on port 8081..."
    LOCAL_SERVER_PORT=8081 NODE_ENV=production node localServer.js > /data/log/frontend.log 2>&1 &
    frontend_pid=$!
    echo "Frontend PID: $frontend_pid"

    echo "Starting artifact server on port 9090..."
    node artifactServer.js > /data/log/artifacts.log 2>&1 &
    artifacts_pid=$!
    echo "Artifact server PID: $artifacts_pid"

    cd /app
else
    echo "WARNING: /app/skyvern-frontend directory not found!"
    echo "Listing /app contents:"
    ls -la /app/ | head -20
    frontend_pid=""
    artifacts_pid=""
fi

# Wait for backend
echo "Waiting for backend to be ready..."
for i in {1..30}; do
    # Just check if backend is listening on port 8000
    if curl -sf http://127.0.0.1:8000 > /dev/null 2>&1; then
        echo "Backend is ready!"
        break
    fi
    sleep 1
    if [ $i -eq 30 ]; then
        echo "Backend may not be fully ready, continuing anyway..."
        tail -n 20 /data/log/backend.log || true
    fi
done

# Configure nginx with dynamic port
NGINX_PORT="${PORT:-8080}"
echo "Configuring nginx on port $NGINX_PORT..."
mkdir -p /etc/nginx
sed "s/listen 8080;/listen $NGINX_PORT;/" /app/nginx.conf > /etc/nginx/nginx.conf
nginx -t || echo "Nginx config test failed, check configuration"

# Cleanup handler
cleanup() {
    echo "Shutting down services..."
    kill $backend_pid $frontend_pid $artifacts_pid $xvfb_pid 2>/dev/null || true
    nginx -s quit 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT

echo "=================================="
echo "Services started successfully!"
echo "Backend API: http://127.0.0.1:8000"
echo "Frontend: http://127.0.0.1:8081"
echo "Nginx proxy: http://0.0.0.0:$NGINX_PORT"
echo "=================================="

# Start nginx in foreground
exec nginx -g 'daemon off;'
