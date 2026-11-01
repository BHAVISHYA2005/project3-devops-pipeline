#!/bin/bash
set -euo pipefail

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Installing Docker, AWS CLI and the CodeDeploy agent ==="
apt-get update -y
apt-get install -y docker.io awscli ruby-full wget
systemctl enable --now docker

# Lets the CodeDeploy hooks (which run as ubuntu) use docker without sudo.
usermod -aG docker ubuntu

cd /tmp
wget "https://aws-codedeploy-${region}.s3.${region}.amazonaws.com/latest/install"
chmod +x ./install
./install auto
systemctl enable --now codedeploy-agent

echo "=== Verifying ==="
docker --version
systemctl is-active codedeploy-agent
