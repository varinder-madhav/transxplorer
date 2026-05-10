#!/bin/bash
# Deploy TransXplorer to Server
# Run this script to build and deploy your application

set -e

echo "==================================================="
echo "TransXplorer Deployment Script"
echo "==================================================="

# Check if we're in the right directory
if [ ! -f "Dockerfile" ]; then
    echo "ERROR: Dockerfile not found. Please run this script from the project directory."
    exit 1
fi

if [ ! -f "PBC_Seurat.R" ]; then
    echo "ERROR: PBC_Seurat.R not found. Please ensure your R script is in this directory."
    exit 1
fi

# Create necessary directories
echo "[1/7] Creating directory structure..."
mkdir -p /srv/transxplorer/{app,data,logs,uploads,results,queue}
mkdir -p /srv/transxplorer/logs/nginx
mkdir -p www

# Set permissions
sudo chown -R ubuntu:docker /srv/transxplorer
sudo chmod -R 775 /srv/transxplorer

# Stop existing containers
echo "[2/7] Stopping existing containers (if any)..."
docker-compose down || true

# Build the Docker image
echo "[3/7] Building Docker image (this will take 20-30 minutes)..."
docker-compose build --no-cache

# Verify the build
echo "[4/7] Verifying Docker image..."
if ! docker images | grep -q transxplorer; then
    echo "ERROR: Docker image build failed"
    exit 1
fi

echo "✓ Docker image built successfully"
docker images | grep transxplorer

# Test the container
echo "[5/7] Testing container startup..."
docker-compose up -d

# Wait for container to be ready
echo "Waiting for app to start..."
sleep 30

# Check if container is running
if ! docker ps | grep -q transxplorer_app; then
    echo "ERROR: Container failed to start"
    docker-compose logs
    exit 1
fi

# Check if app is responding
echo "[6/7] Testing application..."
if curl -f http://localhost:3838/ > /dev/null 2>&1; then
    echo "✓ Application is responding"
else
    echo "WARNING: Application may not be fully ready yet"
    echo "Check logs with: docker-compose logs -f transxplorer"
fi

# Print status
echo "[7/7] Deployment complete!"
echo ""
echo "==================================================="
echo "✓ TransXplorer is now running!"
echo "==================================================="
echo ""
echo "Access your app:"
echo "  - Local: http://localhost:3838/transxplorer/"
echo "  - Server: http://135.125.171.30:3838/transxplorer/"
echo ""
echo "Useful commands:"
echo "  - View logs:        docker-compose logs -f"
echo "  - Restart app:      docker-compose restart"
echo "  - Stop app:         docker-compose down"
echo "  - View containers:  docker ps"
echo ""
echo "Next steps:"
echo "  1. Test the application in your browser"
echo "  2. Set up SSL certificate (see 06_setup_ssl.sh)"
echo "  3. Configure your domain name"
echo ""
echo "==================================================="

# Show running containers
docker ps

# Show resource usage
echo ""
echo "Current resource usage:"
docker stats --no-stream
