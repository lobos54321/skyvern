FROM python:3.11 AS requirements-stage
# Run `skyvern init llm` before building to generate the .env file

WORKDIR /tmp
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
 && ln -s /root/.local/bin/uv /usr/local/bin/uv
COPY ./pyproject.toml /tmp/pyproject.toml
COPY ./uv.lock /tmp/uv.lock
RUN uv pip compile pyproject.toml -o requirements.txt \
    --no-annotate \
    --no-header

# Frontend build stage
FROM node:20.12-slim AS frontend-build
WORKDIR /app/skyvern-frontend
COPY ./skyvern-frontend/package*.json ./
RUN npm ci
COPY ./skyvern-frontend ./

# Build frontend with relative paths for nginx proxy
ARG VITE_API_BASE_URL=/api/v1
ARG VITE_WSS_BASE_URL=/api/v1
ARG VITE_ARTIFACT_API_BASE_URL=/artifacts
ARG VITE_ENVIRONMENT=production

ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}
ENV VITE_WSS_BASE_URL=${VITE_WSS_BASE_URL}
ENV VITE_ARTIFACT_API_BASE_URL=${VITE_ARTIFACT_API_BASE_URL}
ENV VITE_ENVIRONMENT=${VITE_ENVIRONMENT}

RUN npm run build

FROM python:3.11-slim-bookworm
WORKDIR /app
COPY --from=requirements-stage /tmp/requirements.txt /app/requirements.txt
RUN pip install --upgrade pip setuptools wheel
RUN pip install --no-cache-dir --upgrade -r requirements.txt
RUN playwright install-deps
RUN playwright install
RUN apt-get update && apt-get install -y \
    xauth \
    x11-apps \
    netpbm \
    gpg \
    ca-certificates \
    nginx \
    curl \
    gettext-base \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY .nvmrc /app/.nvmrc
COPY nodesource-repo.gpg.key /tmp/nodesource-repo.gpg.key

# Setup Node.js repository
RUN cat /tmp/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
RUN NODE_MAJOR=$(cut -d. -f1 < /app/.nvmrc) && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" > /etc/apt/sources.list.d/nodesource.list

# Install Node.js
RUN apt-get update && \
    apt-get install -y nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Cleanup and verify installation
RUN rm /tmp/nodesource-repo.gpg.key
RUN node -v && npm -v

# install bitwarden cli
RUN npm install -g @bitwarden/cli@2025.9.0
RUN bw --version

COPY . /app

# Copy built frontend from frontend-build stage
COPY --from=frontend-build /app/skyvern-frontend/dist /app/skyvern-frontend/dist

# Install frontend dependencies for servers
WORKDIR /app/skyvern-frontend
RUN npm ci --omit=dev
WORKDIR /app

ENV PYTHONPATH="/app"
ENV VIDEO_PATH=/data/videos
ENV HAR_PATH=/data/har
ENV LOG_PATH=/data/log
ENV ARTIFACT_STORAGE_PATH=/data/artifacts

# Copy nginx configuration template (will be processed by boot.sh)
COPY ./nginx.conf.template /app/nginx.conf.template
# Keep the static config as fallback
COPY ./nginx.conf /etc/nginx/nginx.conf

# Copy boot script
COPY ./boot.sh /app/boot.sh
RUN chmod +x /app/boot.sh

# Keep legacy entrypoint for compatibility
COPY ./entrypoint-skyvern.sh /app/entrypoint-skyvern.sh
RUN chmod +x /app/entrypoint-skyvern.sh

CMD [ "/bin/bash", "/app/boot.sh" ]
