#!/bin/bash
# ===========================================================================
#  CodeDeploy Hook: ApplicationStop
# ===========================================================================
#  Purpose:  Gracefully stop the running container before a new version
#            is deployed.  This is the FIRST hook CodeDeploy calls.
#
#  Why `|| true` at the end?
#    On the very first deployment there is no running container to stop.
#    Without `|| true`, the `docker stop` command would fail and CodeDeploy
#    would abort the deployment entirely.  We want this hook to be
#    idempotent — safe to run regardless of current state.
# ===========================================================================

set -euo pipefail   # -e: exit on error, -u: error on undefined vars, -o pipefail

CONTAINER_NAME="devops-pipeline-app"

echo "[stop] Checking for running container: ${CONTAINER_NAME}"

# Check if the container exists (running OR stopped)
if docker ps -aq --filter "name=${CONTAINER_NAME}" | grep -q .; then
  echo "[stop] Stopping container: ${CONTAINER_NAME}"
  docker stop "${CONTAINER_NAME}" || true
  echo "[stop] Removing container: ${CONTAINER_NAME}"
  docker rm -f "${CONTAINER_NAME}" || true
else
  echo "[stop] No existing container found — first deployment?"
fi

echo "[stop] Done."
