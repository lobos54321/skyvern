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
RUN pip install --upgrade pip setuptools wheel
RUN pip install --no-cache-dir --upgrade -r requirements.txt
RUN playwright install-deps
RUN playwright install
RUN apt-get update
RUN apt-get install -y xauth x11-apps netpbm gpg ca-certificates curl nginx
RUN apt-get clean

RUN curl -fsSL https://deb.nodesource.com/setup_20.x -o setup_nodejs.sh
RUN bash setup_nodejs.sh
RUN apt-get install -y nodejs
RUN rm setup_nodejs.sh
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/*
RUN node -v
RUN npm -v

RUN npm install -g @bitwarden/cli@2025.9.0
RUN bw --version

COPY . /app
COPY nginx.conf /app/nginx.conf

ENV PYTHONPATH="/app"
ENV VIDEO_PATH=/data/videos
ENV HAR_PATH=/data/har
ENV LOG_PATH=/data/log
ENV ARTIFACT_STORAGE_PATH=/data/artifacts

RUN chmod +x /app/entrypoint-skyvern.sh

CMD [ "/bin/bash", "/app/entrypoint-skyvern.sh" ]
