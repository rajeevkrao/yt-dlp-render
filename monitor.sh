#!/bin/bash

# Monitoring script for YouTube Video Downloader

echo "📊 YouTube Video Downloader Monitoring Dashboard"
echo "=============================================="

# Function to check service status
check_service() {
    local service=$1
    if docker ps --format "table {{.Names}}" | grep -q "$service"; then
        echo "✅ $service"
    else
        echo "❌ $service"
    fi
}

# Function to get container stats
get_stats() {
    echo ""
    echo "📈 Resource Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" $(docker ps --format "{{.Names}}" | grep ytdl)
}

# Function to check disk usage
check_disk() {
    echo ""
    echo "💾 Disk Usage:"
    echo "Docker volumes:"
    docker system df -v | grep ytdl
    echo ""
    echo "Log files:"
    du -sh logs/ 2>/dev/null || echo "No logs directory"
    echo "Data directories:"
    du -sh data/ 2>/dev/null || echo "No data directory"
}

# Main monitoring loop
while true; do
    clear
    echo "📊 YouTube Video Downloader Monitoring Dashboard"
    echo "=============================================="
    echo "🕒 $(date)"
    echo ""
    
    echo "🔧 Service Status:"
    check_service "ytdl_app"
    check_service "ytdl_nginx"
    check_service "ytdl_postgres"
    check_service "ytdl_redis"
    check_service "ytdl_elasticsearch"
    check_service "ytdl_minio"
    
    get_stats
    check_disk
    
    echo ""
    echo "Press Ctrl+C to exit, or wait 30 seconds for refresh..."
    sleep 30
done
