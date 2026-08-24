#!/bin/bash
# ===========================================================================
#  CodeDeploy Hook: ApplicationStart
# ===========================================================================
#  Purpose:  Pull the new Docker image from ECR and start the container.
#
#  Environment variables ECR_REGISTRY and IMAGE_TAG are expected to be set
#  on the EC2 instance (e.g., via the CodeDeploy bundle or instance env).
#  Defaults are provided for local testing.
# ===========================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
ECR_REGISTRY="${ECR_REGISTRY:-public.ecr.aws}"
ECR_REPOSITORY="devops-pipeline-app"
IMAGE_TAG="${IMAGE_TAG:-latest}"
CONTAINER_NAME="devops-pipeline-app"
HOST_PORT=3000
CONTAINER_PORT=3000
FULL_IMAGE="${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"

# ---------------------------------------------------------------------------
# Pull the new image
# ---------------------------------------------------------------------------
echo "[start] Pulling image: ${FULL_IMAGE}"
docker pull "${FULL_IMAGE}"

# ---------------------------------------------------------------------------
# Start the container
# ---------------------------------------------------------------------------
echo "[start] Starting container '${CONTAINER_NAME}' on port ${HOST_PORT}"
docker run -d \
  --name "${CONTAINER_NAME}" \
  -p "${HOST_PORT}:${CONTAINER_PORT}" \
  --restart unless-stopped \
  --memory 256m \
  --cpus 0.5 \
  -e NODE_ENV=production \
  -e PORT="${CONTAINER_PORT}" \
  "${FULL_IMAGE}"

#  Flags explained:
#    -d                    → run in background (detached)
#    --restart unless-stopped → auto-restart on crash, but not after `docker stop`
#    --memory / --cpus     → resource limits prevent runaway processes
#    -e                    → inject environment variables

echo "[start] Container started.  Waiting 5s for boot..."
sleep 5

echo "[start] Done."
