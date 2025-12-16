# Container Deployment Changes

## Overview
This document describes the changes made to improve container startup reliability and support for relative URL paths in the frontend.

## Problem Statement
1. **Container Startup Issues**: The original Docker setup backgrounded the entrypoint script and then started nginx. If the backend failed to start (e.g., due to DB connection issues), nginx would still serve the UI, resulting in 502 errors for API requests.

2. **Frontend URL Parsing**: The frontend crashed with `Failed to construct 'URL': Invalid URL` when Vite environment variables were set to relative paths (e.g., `/api/v1`).

## Solution

### 1. New Boot Script (`boot.sh`)
Created a comprehensive boot script that:
- Uses `set -euo pipefail` for proper error handling
- Logs key environment variables (with secret redaction)
- Starts all services in order:
  1. Backend API server (`python -m skyvern.forge`) on port 8000
  2. Local server (`localServer.js`) on port 8081 (internal)
  3. Artifact server (`artifactServer.js`) on port 9090
  4. Nginx reverse proxy on port 8080 (external)
- Waits up to 60 seconds for backend to be ready before starting nginx
- Tracks all child process PIDs and ensures proper cleanup on exit
- Exits non-zero if any critical process fails

### 2. Nginx Reverse Proxy (`nginx.conf`)
Added nginx configuration that:
- Listens on port 8080 (external)
- Proxies `/api/` requests to backend at `127.0.0.1:8000`
- Proxies `/artifacts/` requests to artifact server at `127.0.0.1:9090`
- Serves frontend static files from localServer at `127.0.0.1:8081`
- Supports WebSocket upgrades for API connections

### 3. Updated Dockerfile
Enhanced the Dockerfile to:
- Add a frontend build stage that:
  - Builds the frontend with relative path environment variables
  - Uses `VITE_API_BASE_URL=/api/v1`, `VITE_WSS_BASE_URL=/api/v1`, `VITE_ARTIFACT_API_BASE_URL=/artifacts`
- Install nginx in the final stage
- Install frontend production dependencies for servers
- Copy the built frontend assets
- Use `boot.sh` as the container's CMD

### 4. Frontend URL Handling
The frontend already had proper URL handling utilities:
- `parseUrl()` in `src/util/url.ts` handles both absolute and relative URLs
- `toWebSocketUrl()` converts URLs to WebSocket protocol while handling relative paths
- All environment variable parsing in `env.ts` and `AxiosClient.ts` uses these helpers
- Comprehensive test coverage validates both absolute and relative URL scenarios

### 5. LocalServer Configuration
Updated `localServer.js` to:
- Support configurable port via `LOCAL_SERVER_PORT` environment variable
- Disable automatic browser opening in production mode
- Default to port 8080 for development, port 8081 in container

## Architecture

```
External Request (port 8080)
        ↓
    [Nginx]
        ├─→ /api/* → Backend API (127.0.0.1:8000)
        ├─→ /artifacts/* → Artifact Server (127.0.0.1:9090)
        └─→ /* → Local Server/Frontend (127.0.0.1:8081)
```

## Port Mapping
- **8000**: Backend API (internal only)
- **8080**: Nginx reverse proxy (external)
- **8081**: Local server serving frontend (internal only)
- **9090**: Artifact server (internal only)

## Logs
All service logs are written to `/data/log/`:
- `backend.log`: Backend API server logs
- `localserver.log`: Local server logs
- `artifactserver.log`: Artifact server logs
- Nginx logs: `/var/log/nginx/access.log` and `/var/log/nginx/error.log`

## Environment Variables
The following environment variables are used for configuration:

### Frontend Build Args (set during Docker build)
- `VITE_API_BASE_URL`: API base URL (default: `/api/v1`)
- `VITE_WSS_BASE_URL`: WebSocket base URL (default: `/api/v1`)
- `VITE_ARTIFACT_API_BASE_URL`: Artifact API base URL (default: `/artifacts`)
- `VITE_ENVIRONMENT`: Environment (default: `production`)

### Runtime Environment Variables
- `DATABASE_STRING`: PostgreSQL connection string
- `BROWSER_TYPE`: Browser type for Playwright
- `LLM_KEY`: LLM provider key
- `PORT`: Backend server port (default: 8000)
- `LOCAL_SERVER_PORT`: Local server port (used internally, default: 8081)
- `NODE_ENV`: Node environment (set to `production` in container)

## Startup Sequence
1. Create required directories (`/data/log`, `/data/videos`, `/data/har`, `/data/artifacts`)
2. Start backend API server in background
3. Start local server in background
4. Start artifact server in background
5. Wait for backend to respond to health check
6. Start nginx in foreground (blocks container)

## Health Check
The boot script checks backend health by polling:
```
curl -s -f http://127.0.0.1:8000/api/v1/internal/auth/status
```

If the backend doesn't respond within 60 seconds, a warning is logged with the last 20 lines of the backend log, but the container continues (nginx still starts).

## Testing
### Frontend Tests
```bash
cd skyvern-frontend
npm test
```

### Syntax Validation
```bash
# Validate boot.sh
bash -n boot.sh

# Validate nginx.conf
nginx -t -c /path/to/nginx.conf
```

### Docker Build
```bash
docker build -t skyvern:latest .
```

## Troubleshooting

### Container exits immediately
Check logs in `/data/log/backend.log` for backend startup errors.

### 502 Bad Gateway errors
- Verify backend is running: `curl http://127.0.0.1:8000/api/v1/internal/auth/status`
- Check nginx logs: `/var/log/nginx/error.log`
- Verify nginx is proxying correctly: check `nginx.conf`

### Frontend shows connection errors
- Ensure Vite environment variables are set to relative paths
- Check that nginx is proxying requests correctly
- Verify WebSocket upgrades are enabled in nginx config

### Database connection issues
- Check `DATABASE_STRING` environment variable
- Ensure database is accessible from container
- Review backend logs for connection errors

## Backward Compatibility
The original `entrypoint-skyvern.sh` is still present in the Docker image for reference, but `boot.sh` is now the default CMD. The legacy entrypoint can still be used if needed by overriding the CMD.

## Related Files
- `/boot.sh`: Main container boot script
- `/nginx.conf`: Nginx reverse proxy configuration
- `/Dockerfile`: Multi-stage build with frontend and backend
- `/skyvern-frontend/localServer.js`: Frontend static file server
- `/skyvern-frontend/artifactServer.js`: Artifact file server
- `/skyvern-frontend/src/util/url.ts`: URL parsing utilities
- `/skyvern-frontend/src/util/env.ts`: Environment variable parsing
- `/skyvern-frontend/src/api/AxiosClient.ts`: API client setup
