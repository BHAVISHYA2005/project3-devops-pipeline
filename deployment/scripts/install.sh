#!/bin/bash
# ===========================================================================
#  CodeDeploy Hook: BeforeInstall
# ===========================================================================
#  Purpose:  Ensure Docker is installed and running on the EC2 instance.
#            Also prunes dangling images to reclaim disk space.
#
#  This hook runs AFTER ApplicationStop and BEFORE ApplicationStart.
#  It is idempotent — safe to run multiple times.
# ===========================================================================

set -euo pipefail

echo "[install] Checking for Docker installation..."

if ! command -v docker &> /dev/null; then
  echo "[install] Docker not found — installing..."
  sudo apt-get update -y
  sudo apt-get install -y docker.io
  sudo systemctl enable docker
  sudo systemctl start docker

  # Add the ubuntu user to the docker group so we can run docker
  # commands without sudo.  Takes effect on next login, but the
  # current CodeDeploy session runs subsequent hooks as `ubuntu`,
  # so we also use `newgrp` or rely on sudo for this deployment.
  sudo usermod -aG docker ubuntu
  echo "[install] Docker installed successfully."
else
  echo "[install] Docker already installed."
fi

echo "[install] Docker version: $(docker --version)"

# Clean up old/dangling images to prevent disk from filling up over
# many deployments.  `--filter "until=24h"` keeps images from the
# last 24 hours in case you need to roll back quickly.
echo "[install] Pruning old Docker images..."
docker image prune -f --filter "until=24h" || true

echo "[install] Done."
