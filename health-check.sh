#!/bin/bash

# Health check script for YouTube Video Downloader

echo "🏥 Running health checks..."

# Check if all services are running
services=("ytdl_app" "ytdl_nginx" "ytdl_postgres" "ytdl_redis" "ytdl_elasticsearch" "ytdl_minio")

for service in "${services[@]}"; do
    if docker ps --format "table {{.Names}}" | grep -q "$service"; then
        echo "✅ $service is running"
    else
        echo "❌ $service is not running"
    fi
done

# Check service health
echo ""
echo "🔍 Checking service health..."

# Check app health
if curl -f http://localhost/health > /dev/null 2>&1; then
    echo "✅ App health check passed"
else
    echo "❌ App health check failed"
fi

# Check Nginx
if curl -f http://localhost/nginx-health > /dev/null 2>&1; then
    echo "✅ Nginx health check passed"
else
    echo "❌ Nginx health check failed"
fi

echo ""
echo "🏥 Health check completed"
