#!/bin/bash

# GCP VM Startup Script
# This script installs Docker and Docker Compose on a fresh Ubuntu VM

set -e
set -x

echo "Starting VM initialization..."

# Update system packages
apt-get update
apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh ./get-docker.sh
rm get-docker.sh

# Add current user to docker group
usermod -aG docker ubuntu

# Verify installations
docker --version
docker compose version

echo "VM initialization completed successfully!"
