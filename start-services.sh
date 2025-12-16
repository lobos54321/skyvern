#!/bin/bash

set -euo pipefail

echo "=================================="
echo "Skyvern Services Startup"
echo "=================================="

# Run database migrations
echo "Running database migrations..."
alembic upgrade head || echo "Migration failed, continuing..."

# Create organization if needed
if [ ! -f ".streamlit/secrets.toml" ]; then
    echo "Creating organization and API token..."
    org_output=$(python scripts/create_organization.py Skyvern-Open-Source)
    api_token=$(echo "$org_output" | awk '/token=/{gsub(/.*token='\''|'\''.*/, ""); print}')
    mkdir -p .streamlit
    echo -e "[skyvern]\nconfigs = [\n    {\"env\" = \"local\", \"host\" = \"http://skyvern:8000/api/v1\", \"orgs\" = [{name=\"Skyvern\", cred=\"$api_token\"}]}\n]" > .streamlit/secrets.toml
    echo "Organization created"
fi

# Setup Xvfb
echo "Starting Xvfb..."
rm -f /tmp/.X99-lock
export DISPLAY=:99
Xvfb :99 -screen 0 1920x1080x16 &
xvfb_pid=$!
sleep 2

# Ensure data directories exist
mkdir -p /data/log /data/videos /data/har /data/artifacts

# Start backend
echo "Starting backend on port 8000..."
python -m skyvern.forge > /data/log/backend.log 2>&1 &
backend_pid=$!
echo "Backend started (PID: $backend_pid)"

# Start frontend
echo "Starting frontend on port 8081..."
cd /app/skyvern-frontend
LOCAL_SERVER_PORT=8081 NODE_ENV=production node localServer.js > /data/log/frontend.log 2>&1 &
frontend_pid=$!
echo "Frontend started (PID: $frontend_pid)"

# Start artifact server
echo "Starting artifact server on port 9090..."
node artifactServer.js > /data/log/artifacts.log 2>&1 &
artifacts_pid=$!
echo "Artifacts started (PID: $artifacts_pid)"

cd /app

# Wait for backend to be ready
echo "Waiting for backend..."
for i in {1..60}; do
    if curl -s http://127.0.0.1:8000/api/v1/internal/auth/status > /dev/null 2>&1; then
        echo "Backend is ready!"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "Backend did not start in time"
        tail -n 50 /data/log/backend.log
    fi
    sleep 1
done

# Get nginx port from environment or default
NGINX_PORT="${PORT:-8080}"
echo "Starting nginx on port $NGINX_PORT..."

# Update nginx config with correct port
sed "s/listen 8080;/listen $NGINX_PORT;/" /app/nginx.conf > /etc/nginx/nginx.conf

echo "=================================="
echo "All services started!"
echo "Backend: http://127.0.0.1:8000"
echo "Frontend: http://127.0.0.1:8081"
echo "Artifacts: http://127.0.0.1:9090"
echo "Nginx: http://0.0.0.0:$NGINX_PORT"
echo "=================================="

# Cleanup function
cleanup() {
    echo "Shutting down..."
    kill $backend_pid $frontend_pid $artifacts_pid $xvfb_pid 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT

# Start nginx in foreground
exec nginx -g 'daemon off;'
