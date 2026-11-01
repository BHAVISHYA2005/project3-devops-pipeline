#!/bin/bash
set -euo pipefail

CONTAINER_NAME="devops-pipeline-app"

echo "[stop] Removing ${CONTAINER_NAME} (no-op on first deploy)"
docker rm -f "${CONTAINER_NAME}" || true

echo "[stop] Done."
