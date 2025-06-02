#!/bin/bash

# Backup script for YouTube Video Downloader

BACKUP_DIR="./backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "📦 Creating backup in $BACKUP_DIR..."

# Backup database
docker exec ytdl_postgres pg_dump -U ytdl_user ytdl_app > "$BACKUP_DIR/database.sql"

# Backup MinIO data
docker exec ytdl_minio mc mirror /data "$BACKUP_DIR/minio" > /dev/null 2>&1

# Backup configuration
cp .env "$BACKUP_DIR/"
cp -r nginx/conf.d "$BACKUP_DIR/"

echo "✅ Backup completed: $BACKUP_DIR"
