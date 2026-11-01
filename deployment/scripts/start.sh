#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
set -a
. ./.env
set +a

# Fail loudly rather than pulling from some default registry.
: "${ECR_REGISTRY:?ECR_REGISTRY missing from .env}"
: "${IMAGE_REF:?IMAGE_REF missing from .env}"
: "${IMAGE_TAG:?IMAGE_TAG missing from .env}"
: "${AWS_REGION:?AWS_REGION missing from .env}"

CONTAINER_NAME="devops-pipeline-app"
HOST_PORT=3000
CONTAINER_PORT=3000

echo "[start] Logging in to ECR"
aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${ECR_REGISTRY}"

echo "[start] Pulling ${IMAGE_REF}"
docker pull "${IMAGE_REF}"

echo "[start] Starting container"
docker run -d \
  --name "${CONTAINER_NAME}" \
  -p "${HOST_PORT}:${CONTAINER_PORT}" \
  --restart unless-stopped \
  --stop-timeout 20 \
  --memory 256m \
  --cpus 0.5 \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  -e NODE_ENV=production \
  -e PORT="${CONTAINER_PORT}" \
  -e APP_VERSION="${IMAGE_TAG}" \
  "${IMAGE_REF}"

# --stop-timeout 20: server.js needs up to 10s to drain, and the default
# docker stop timeout is also 10s, so the two would race.
# --log-opt: default json-file logging grows unbounded and fills the disk.

echo "[start] Waiting for boot"
sleep 5

echo "[start] Done."
