#!/bin/bash
set -euo pipefail

echo "[install] Ensuring Docker is installed"

if ! command -v docker &> /dev/null; then
  sudo apt-get update -y
  sudo apt-get install -y docker.io
  sudo systemctl enable --now docker
  # Takes effect for the next hook: CodeDeploy spawns each hook in a new process.
  sudo usermod -aG docker ubuntu
fi

docker --version

# Tagged :sha images are never "dangling", so -a is required to reclaim space.
docker image prune -a -f --filter "until=168h" || true

echo "[install] Done."
