#!/bin/bash
# TransXplorer Server Setup Script
# Run this on your fresh Ubuntu server: ssh ubuntu@<your-server-ip>

set -e  # Exit on any error

echo "==================================================="
echo "TransXplorer Server Setup - Phase 1"
echo "==================================================="

# Update system
echo "[1/8] Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install essential tools
echo "[2/8] Installing essential tools..."
sudo apt install -y \
    build-essential \
    curl \
    wget \
    git \
    nano \
    vim \
    htop \
    unzip \
    ufw \
    nginx \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Install Docker
echo "[3/8] Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
rm get-docker.sh

# Add ubuntu user to docker group
sudo usermod -aG docker ubuntu

# Install Docker Compose
echo "[4/8] Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Set up firewall
echo "[5/8] Configuring firewall..."
sudo ufw --force enable
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw status

# Create directory structure
echo "[6/8] Creating directory structure..."
sudo mkdir -p /srv/transxplorer/{app,data,logs,uploads,results}
sudo mkdir -p /srv/transxplorer/data/{tcga,genomes,annotations,hisat2_indexes}
sudo mkdir -p /srv/transxplorer/data/hisat2_indexes/{hg38,mm10,rn6}

# Set permissions
echo "[7/8] Setting permissions..."
sudo chown -R ubuntu:docker /srv/transxplorer
sudo chmod -R 775 /srv/transxplorer

# Create swap file (important for large genomic data processing)
echo "[8/8] Creating swap file (16GB)..."
if [ ! -f /swapfile ]; then
    sudo fallocate -l 16G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

echo ""
echo "==================================================="
echo "✓ Phase 1 Complete!"
echo "==================================================="
echo "IMPORTANT: Log out and log back in for Docker group changes to take effect"
echo "Run: exit"
echo "Then: ssh ubuntu@<your-server-ip>"
echo ""
echo "After logging back in, verify Docker works:"
echo "docker run hello-world"
echo "==================================================="
