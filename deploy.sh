#!/bin/bash

# Deployment script for YouTube Video Downloader

echo "🚀 Deploying YouTube Video Downloader..."

# Pull latest images
docker-compose pull

# Build application
docker-compose build --no-cache

# Stop services
docker-compose down

# Start services
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 30

# Run health check
./health-check.sh

echo "✅ Deployment completed"
