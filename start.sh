#!/bin/bash

# Startup script for YouTube Video Downloader

echo "🚀 Starting YouTube Video Downloader..."

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ .env file not found. Please create it first."
    exit 1
fi

# Create necessary directories
mkdir -p logs/nginx logs/app data/postgres data/redis data/elasticsearch data/minio

# Start services
docker-compose up -d

echo "⏳ Waiting for services to start..."
sleep 30

# Show running containers
docker-compose ps

echo ""
echo "✅ YouTube Video Downloader is starting!"
echo "🌐 Access the application at: http://localhost"
echo "📊 MinIO Console: http://localhost:9001"
echo ""
echo "📋 To view logs:"
echo "   docker-compose logs -f app"
echo "   docker-compose logs -f nginx"
echo ""
echo "🛑 To stop:"
echo "   docker-compose down"
