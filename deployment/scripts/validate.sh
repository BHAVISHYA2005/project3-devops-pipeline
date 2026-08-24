#!/bin/bash
# ===========================================================================
#  CodeDeploy Hook: ValidateService
# ===========================================================================
#  Purpose:  Verify the newly deployed container is healthy and responding.
#            If validation fails, CodeDeploy rolls back the deployment.
#
#  This is the LAST hook — it acts as the final gate before CodeDeploy
#  marks the deployment as "Succeeded".
# ===========================================================================

set -euo pipefail

HEALTH_URL="http://localhost:3000/health"
MAX_RETRIES=10
RETRY_INTERVAL=5     # seconds between retries

echo "[validate] Checking service health at ${HEALTH_URL}"
echo "[validate] Will retry up to ${MAX_RETRIES} times (every ${RETRY_INTERVAL}s)"

for attempt in $(seq 1 "${MAX_RETRIES}"); do
  # -s = silent, -f = fail on HTTP errors, -o /dev/null = discard body
  if curl -sf -o /dev/null "${HEALTH_URL}"; then
    echo "[validate] ✓ Health check PASSED on attempt ${attempt}"
    exit 0
  fi
  echo "[validate] Attempt ${attempt}/${MAX_RETRIES} — service not ready, waiting ${RETRY_INTERVAL}s..."
  sleep "${RETRY_INTERVAL}"
done

echo "[validate] ✗ Health check FAILED after ${MAX_RETRIES} attempts"
echo "[validate] Dumping container logs for debugging:"
docker logs devops-pipeline-app --tail 50 2>&1 || true

exit 1
