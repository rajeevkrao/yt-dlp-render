#!/bin/bash

# Stop script for YouTube Video Downloader

echo "🛑 Stopping YouTube Video Downloader..."

# Stop and remove containers
docker-compose down

# Remove orphaned containers
docker-compose down --remove-orphans

echo "✅ YouTube Video Downloader stopped"
