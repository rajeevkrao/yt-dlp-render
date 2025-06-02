#!/bin/bash

# Cleanup script for YouTube Video Downloader

echo "🧹 Cleaning up YouTube Video Downloader..."

# Stop containers
docker-compose down

# Remove containers, networks, and volumes
read -p "⚠️  Remove all data volumes? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker-compose down -v
    docker volume prune -f
    echo "🗑️  Data volumes removed"
fi

# Remove images
read -p "🗑️  Remove Docker images? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker rmi $(docker images -q --filter reference="*ytdl*")
    docker image prune -f
    echo "🗑️  Images removed"
fi

echo "✅ Cleanup completed"
