#!/bin/bash

# Logs script for YouTube Video Downloader

echo "📋 YouTube Video Downloader Logs"
echo "================================"

if [ "$1" = "" ]; then
    echo "Usage: ./logs.sh [service]"
    echo ""
    echo "Available services:"
    echo "  app           - Application logs"
    echo "  nginx         - Nginx logs"
    echo "  postgres      - PostgreSQL logs"
    echo "  redis         - Redis logs"
    echo "  elasticsearch - Elasticsearch logs"
    echo "  minio         - MinIO logs"
    echo "  all           - All services logs"
    echo ""
    echo "Examples:"
    echo "  ./logs.sh app"
    echo "  ./logs.sh nginx"
    echo "  ./logs.sh all"
    exit 1
fi

case $1 in
    "app")
        docker-compose logs -f app
        ;;
    "nginx")
        docker-compose logs -f nginx
        ;;
    "postgres")
        docker-compose logs -f postgres
        ;;
    "redis")
        docker-compose logs -f redis
        ;;
    "elasticsearch")
        docker-compose logs -f elasticsearch
        ;;
    "minio")
        docker-compose logs -f minio
        ;;
    "all")
        docker-compose logs -f
        ;;
    *)
        echo "❌ Unknown service: $1"
        exit 1
        ;;
esac
