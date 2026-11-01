#!/bin/bash
set -euo pipefail

HEALTH_URL="http://localhost:3000/health"
MAX_RETRIES=10
RETRY_INTERVAL=5

echo "[validate] Checking ${HEALTH_URL}"

for attempt in $(seq 1 "${MAX_RETRIES}"); do
  if curl -sf --max-time 3 -o /dev/null "${HEALTH_URL}"; then
    echo "[validate] Health check passed on attempt ${attempt}"
    exit 0
  fi
  echo "[validate] Attempt ${attempt}/${MAX_RETRIES} failed, retrying in ${RETRY_INTERVAL}s"
  sleep "${RETRY_INTERVAL}"
done

echo "[validate] Health check failed after ${MAX_RETRIES} attempts"
docker logs devops-pipeline-app --tail 50 2>&1 || true

exit 1
