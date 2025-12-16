FROM python:3.11 AS requirements-stage

WORKDIR /tmp
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
RUN ln -s /root/.local/bin/uv /usr/local/bin/uv
COPY ./pyproject.toml /tmp/pyproject.toml
COPY ./uv.lock /tmp/uv.lock
RUN uv pip compile pyproject.toml -o requirements.txt

FROM python:3.11-slim-bookworm
WORKDIR /app
COPY --from=requirements-stage /tmp/requirements.txt /app/requirements.txt

RUN pip install --upgrade pip
RUN pip install --upgrade setuptools wheel
RUN pip install --no-cache-dir --upgrade -r requirements.txt
RUN playwright install-deps
RUN playwright install

RUN apt-get update
RUN apt-get install -y xauth
RUN apt-get install -y x11-apps
RUN apt-get install -y netpbm
RUN apt-get install -y gpg
RUN apt-get install -y ca-certificates
RUN apt-get install -y curl
RUN apt-get install -y nginx
RUN apt-get clean

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | sh -
RUN apt-get install -y nodejs
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/*

RUN node -v
RUN npm -v
RUN npm install -g @bitwarden/cli@2025.9.0
RUN bw --version

COPY . /app

RUN cd /app/skyvern-frontend && npm install
RUN cd /app/skyvern-frontend && npm run build

ENV PYTHONPATH="/app"
ENV VIDEO_PATH=/data/videos
ENV HAR_PATH=/data/har
ENV LOG_PATH=/data/log
ENV ARTIFACT_STORAGE_PATH=/data/artifacts

RUN chmod +x /app/entrypoint-skyvern.sh

CMD ["/bin/bash", "/app/entrypoint-skyvern.sh"]
