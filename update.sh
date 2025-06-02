#!/bin/bash

# Update script for YouTube Video Downloader

echo "🔄 Updating YouTube Video Downloader..."

# Create backup before update
echo "📦 Creating backup before update..."
./backup.sh

# Pull latest changes (if using git)
if [ -d ".git" ]; then
    echo "📥 Pulling latest changes..."
    git pull
fi

# Update Docker images
echo "📥 Pulling latest Docker images..."
docker-compose pull

# Rebuild application
echo "🔨 Rebuilding application..."
docker-compose build --no-cache app

# Restart services
echo "🔄 Restarting services..."
docker-compose down
docker-compose up -d

# Wait for services
echo "⏳ Waiting for services to start..."
sleep 30

# Run health check
echo "🏥 Running health check..."
./health-check.sh

echo "✅ Update completed successfully!"
