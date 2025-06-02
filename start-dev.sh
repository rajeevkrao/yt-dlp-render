#!/bin/bash

# Development startup script for YouTube Video Downloader

echo "🚀 Starting YouTube Video Downloader (Development Mode)..."

# Create necessary directories
mkdir -p logs/nginx logs/app data/postgres data/redis data/elasticsearch data/minio

sudo docker-compose -f docker-compose.dev.yml down

# Start development services
sudo docker-compose -f docker-compose.dev.yml build
sudo docker-compose -f docker-compose.dev.yml up -d

# Show running containers
sudo docker-compose -f docker-compose.dev.yml ps

echo ""
echo "✅ YouTube Video Downloader is running in development mode!"
echo "🌐 Application: http://localhost:5000"
echo "🗄️  Database: localhost:5432"
echo "🔍 Elasticsearch: http://localhost:9200"
echo "📦 MinIO Console: http://localhost:9001"
echo "🗃️  Redis: localhost:6379"
echo ""
echo "📋 Development commands:"
echo "   View logs: docker-compose -f docker-compose.dev.yml logs -f"
echo "   Stop: docker-compose -f docker-compose.dev.yml down"
echo "   Rebuild: docker-compose -f docker-compose.dev.yml build"
