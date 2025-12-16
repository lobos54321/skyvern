FROM python:3.11 AS requirements-stage

WORKDIR /tmp
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    ln -s /root/.local/bin/uv /usr/local/bin/uv
COPY ./pyproject.toml /tmp/pyproject.toml
COPY ./uv.lock /tmp/uv.lock
RUN uv pip compile pyproject.toml -o requirements.txt --no-annotate --no-header

FROM node:20.12-slim AS frontend-build
WORKDIR /app/skyvern-frontend
COPY ./skyvern-frontend/package*.json ./
RUN npm ci
COPY ./skyvern-frontend ./

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

RUN apt-get update && \
    apt-get install -y xauth x11-apps netpbm gpg ca-certificates nginx curl gettext-base && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    node -v && npm -v

RUN npm install -g @bitwarden/cli@2025.9.0
RUN bw --version

COPY . /app
COPY --from=frontend-build /app/skyvern-frontend/dist /app/skyvern-frontend/dist

WORKDIR /app/skyvern-frontend
RUN npm ci --omit=dev
WORKDIR /app

ENV PYTHONPATH="/app"
ENV VIDEO_PATH=/data/videos
ENV HAR_PATH=/data/har
ENV LOG_PATH=/data/log
ENV ARTIFACT_STORAGE_PATH=/data/artifacts

COPY ./nginx.conf.template /app/nginx.conf.template
COPY ./nginx.conf /etc/nginx/nginx.conf
COPY ./boot.sh /app/boot.sh
RUN chmod +x /app/boot.sh
COPY ./entrypoint-skyvern.sh /app/entrypoint-skyvern.sh
RUN chmod +x /app/entrypoint-skyvern.sh

CMD ["/bin/bash", "/app/boot.sh"]
