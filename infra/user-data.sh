#!/bin/bash
# ===========================================================================
#  EC2 User-Data — Bootstrap script
# ===========================================================================
#  This script runs ONCE when the EC2 instance first launches.
#  It installs:
#    1. Docker     — to run our containerized application
#    2. CodeDeploy — agent that listens for deployment commands from AWS
#
#  Logs are written to /var/log/user-data.log for debugging.
#  You can also view them via: `sudo cat /var/log/cloud-init-output.log`
#
#  IMPORTANT: The CodeDeploy agent download URL is region-specific.
#  If you change aws_region in variables.tf, update the URL below!
# ===========================================================================

set -euo pipefail

# Redirect all output to a log file AND the console for debugging
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== [1/3] Installing Docker ==="
apt-get update -y
apt-get install -y docker.io
systemctl enable docker
systemctl start docker

# Allow the ubuntu user to run docker commands without sudo
usermod -aG docker ubuntu

echo "=== [2/3] Installing CodeDeploy Agent ==="
apt-get install -y ruby-full wget

cd /tmp
# NOTE: "ap-south-1" is hardcoded here — must match your aws_region variable
wget https://aws-codedeploy-ap-south-1.s3.ap-south-1.amazonaws.com/latest/install
chmod +x ./install
./install auto

systemctl start codedeploy-agent
systemctl enable codedeploy-agent

echo "=== [3/3] Verifying installations ==="
echo "Docker version: $(docker --version)"
echo "CodeDeploy agent status: $(systemctl is-active codedeploy-agent)"

echo "=== Bootstrap complete ==="
