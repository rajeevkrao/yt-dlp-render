#!/bin/bash

# YouTube Video Downloader - Docker Setup Script
# This script creates all necessary Docker files and configurations

set -e

echo "🚀 Setting up YouTube Video Downloader with Docker..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}
╔══════════════════════════════════════════════════════════════════╗
║                 YouTube Video Downloader Setup                   ║
║                     Docker Configuration                         ║
╚══════════════════════════════════════════════════════════════════╝
${NC}"
}

print_header

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

print_status "Creating project structure..."

# Create directories
mkdir -p nginx/conf.d
mkdir -p nginx/ssl
mkdir -p data/postgres
mkdir -p data/redis
mkdir -p data/elasticsearch
mkdir -p data/minio
mkdir -p logs/nginx
mkdir -p logs/app

print_status "Creating Dockerfile..."

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    python3-dev \
    libpq-dev \
    curl \
    wget \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser && \
    chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Run application
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "--timeout", "120", "--keep-alive", "5", "app:app"]
EOF

print_status "Creating docker-compose.yml..."

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  # Web Application
  app:
    build: .
    container_name: ytdl_app
    restart: unless-stopped
    depends_on:
      - postgres
      - redis
      - elasticsearch
      - minio
    environment:
      - SECRET_KEY=${SECRET_KEY}
      - DEBUG=False
      - POSTGRES_HOST=postgres
      - POSTGRES_PORT=5432
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - REDIS_URL=redis://redis:6379/0
      - ELASTICSEARCH_HOST=elasticsearch
      - ELASTICSEARCH_PORT=9200
      - MINIO_ENDPOINT=minio:9000
      - MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY}
      - MINIO_SECRET_KEY=${MINIO_SECRET_KEY}
      - MINIO_BUCKET=${MINIO_BUCKET}
      - MINIO_SECURE=false
      - GA_TRACKING_ID=${GA_TRACKING_ID}
      - VIDEO_EXPIRY_DAYS=${VIDEO_EXPIRY_DAYS}
      - MAX_VIDEO_SIZE=${MAX_VIDEO_SIZE}
    volumes:
      - ./logs/app:/app/logs
    networks:
      - ytdl_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # Nginx Reverse Proxy
  nginx:
    image: nginx:alpine
    container_name: ytdl_nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./nginx/ssl:/etc/nginx/ssl
      - ./logs/nginx:/var/log/nginx
    depends_on:
      - app
    networks:
      - ytdl_network
    healthcheck:
      test: ["CMD", "nginx", "-t"]
      interval: 30s
      timeout: 10s
      retries: 3

  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    container_name: ytdl_postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-scripts:/docker-entrypoint-initdb.d
    networks:
      - ytdl_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 30s
      timeout: 10s
      retries: 5

  # Redis Cache
  redis:
    image: redis:7-alpine
    container_name: ytdl_redis
    restart: unless-stopped
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    networks:
      - ytdl_network
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Elasticsearch
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.12.0
    container_name: ytdl_elasticsearch
    restart: unless-stopped
    environment:
      - node.name=elasticsearch
      - cluster.name=ytdl-cluster
      - discovery.type=single-node
      - bootstrap.memory_lock=true
      - xpack.security.enabled=false
      - xpack.security.enrollment.enabled=false
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    networks:
      - ytdl_network
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9200/_cluster/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

  # MinIO Object Storage
  minio:
    image: minio/minio:latest
    container_name: ytdl_minio
    restart: unless-stopped
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ACCESS_KEY}
      MINIO_ROOT_PASSWORD: ${MINIO_SECRET_KEY}
    volumes:
      - minio_data:/data
    networks:
      - ytdl_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 10s
      retries: 3

  # MinIO Client (for bucket creation)
  minio-client:
    image: minio/mc:latest
    container_name: ytdl_minio_client
    depends_on:
      - minio
    networks:
      - ytdl_network
    entrypoint: >
      /bin/sh -c "
      sleep 10;
      /usr/bin/mc alias set myminio http://minio:9000 ${MINIO_ACCESS_KEY} ${MINIO_SECRET_KEY};
      /usr/bin/mc mb myminio/${MINIO_BUCKET} --ignore-existing;
      /usr/bin/mc policy set public myminio/${MINIO_BUCKET};
      exit 0;
      "

# Named volumes
volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
  elasticsearch_data:
    driver: local
  minio_data:
    driver: local

# Networks
networks:
  ytdl_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOF

print_status "Creating production docker-compose file..."

# Create docker-compose.prod.yml
cat > docker-compose.prod.yml << 'EOF'
version: '3.8'

services:
  app:
    build: .
    container_name: ytdl_app_prod
    restart: unless-stopped
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
    depends_on:
      - postgres
      - redis
      - elasticsearch
      - minio
    environment:
      - SECRET_KEY=${SECRET_KEY}
      - DEBUG=False
      - POSTGRES_HOST=postgres
      - POSTGRES_PORT=5432
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - REDIS_URL=redis://redis:6379/0
      - ELASTICSEARCH_HOST=elasticsearch
      - ELASTICSEARCH_PORT=9200
      - MINIO_ENDPOINT=minio:9000
      - MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY}
      - MINIO_SECRET_KEY=${MINIO_SECRET_KEY}
      - MINIO_BUCKET=${MINIO_BUCKET}
      - MINIO_SECURE=false
      - GA_TRACKING_ID=${GA_TRACKING_ID}
      - VIDEO_EXPIRY_DAYS=${VIDEO_EXPIRY_DAYS}
      - MAX_VIDEO_SIZE=${MAX_VIDEO_SIZE}
    volumes:
      - ./logs/app:/app/logs
    networks:
      - ytdl_network

  nginx:
    image: nginx:alpine
    container_name: ytdl_nginx_prod
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./nginx/ssl:/etc/nginx/ssl
      - ./logs/nginx:/var/log/nginx
    depends_on:
      - app
    networks:
      - ytdl_network

  postgres:
    image: postgres:15-alpine
    container_name: ytdl_postgres_prod
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
    networks:
      - ytdl_network

  redis:
    image: redis:7-alpine
    container_name: ytdl_redis_prod
    restart: unless-stopped
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    deploy:
      resources:
        limits:
          cpus: '0.25'
          memory: 256M
        reservations:
          cpus: '0.1'
          memory: 128M
    volumes:
      - redis_data:/data
    networks:
      - ytdl_network

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.12.0
    container_name: ytdl_elasticsearch_prod
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 1G
    environment:
      - node.name=elasticsearch
      - cluster.name=ytdl-cluster
      - discovery.type=single-node
      - bootstrap.memory_lock=true
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    networks:
      - ytdl_network

  minio:
    image: minio/minio:latest
    container_name: ytdl_minio_prod
    restart: unless-stopped
    command: server /data --console-address ":9001"
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
    environment:
      MINIO_ROOT_USER: ${MINIO_ACCESS_KEY}
      MINIO_ROOT_PASSWORD: ${MINIO_SECRET_KEY}
    volumes:
      - minio_data:/data
    networks:
      - ytdl_network

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
  elasticsearch_data:
    driver: local
  minio_data:
    driver: local

networks:
  ytdl_network:
    driver: bridge
EOF

print_status "Creating Nginx configuration..."

# Create nginx configuration
cat > nginx/conf.d/default.conf << 'EOF'
# Rate limiting
limit_req_zone $binary_remote_addr zone=download:10m rate=10r/m;
limit_req_zone $binary_remote_addr zone=api:10m rate=30r/m;
limit_req_zone $binary_remote_addr zone=general:10m rate=60r/m;

# Upstream servers
upstream app_backend {
    least_conn;
    server app:5000 max_fails=3 fail_timeout=30s;
    keepalive 32;
}

# HTTP to HTTPS redirect
server {
    listen 80;
    server_name localhost;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    # Health check endpoint
    location /nginx-health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    # Redirect to HTTPS (uncomment for production with SSL)
    # return 301 https://$server_name$request_uri;
    
    # For development, serve directly
    location / {
        proxy_pass http://app_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Rate limiting
        limit_req zone=general burst=20 nodelay;
    }
    
    # API endpoints with stricter rate limiting
    location /api/ {
        proxy_pass http://app_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Rate limiting for API
        limit_req zone=api burst=10 nodelay;
        
        # Longer timeout for video processing
        proxy_connect_timeout 30s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
    
    # Download endpoints with very strict rate limiting
    location /download/ {
        proxy_pass http://app_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Rate limiting for downloads
        limit_req zone=download burst=5 nodelay;
        
        # Very long timeout for file downloads
        proxy_connect_timeout 30s;
        proxy_send_timeout 600s;
        proxy_read_timeout 600s;
        
        # Large file support
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    # Static files (if served by nginx)
    location /static/ {
        proxy_pass http://app_backend;
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header X-Static-File "true";
    }
    
    # Favicon
    location = /favicon.ico {
        proxy_pass http://app_backend;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
    
    # Robots.txt
    location = /robots.txt {
        proxy_pass http://app_backend;
        expires 1d;
        add_header Cache-Control "public";
        access_log off;
    }
}

# HTTPS server (for production)
server {
    listen 443 ssl http2;
    server_name localhost;
    
    # SSL configuration (uncomment and configure for production)
    # ssl_certificate /etc/nginx/ssl/cert.pem;
    # ssl_certificate_key /etc/nginx/ssl/key.pem;
    # ssl_session_timeout 1d;
    # ssl_session_cache shared:SSL:50m;
    # ssl_session_tickets off;
    
    # Modern configuration
    # ssl_protocols TLSv1.2 TLSv1.3;
    # ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    # ssl_prefer_server_ciphers off;
    
    # HSTS (uncomment for production)
    # add_header Strict-Transport-Security "max-age=63072000" always;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' https://www.googletagmanager.com https://www.google-analytics.com; style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com; img-src 'self' data: https:; font-src 'self' https://cdnjs.cloudflare.com; connect-src 'self' https://www.google-analytics.com;" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;
    
    # Main application
    location / {
        proxy_pass http://app_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Rate limiting
        limit_req zone=general burst=20 nodelay;
    }
    
    # API endpoints
    location /api/ {
        proxy_pass http://app_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Rate limiting for API
        limit_req zone=api burst=10 nodelay;
        
        # Longer timeout for video processing
        proxy_connect_timeout 30s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
    
    # Download endpoints
    location /download/ {
        proxy_pass http://app_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Rate limiting for downloads
        limit_req zone=download burst=5 nodelay;
        
        # Very long timeout for file downloads
        proxy_connect_timeout 30s;
        proxy_send_timeout 600s;
        proxy_read_timeout 600s;
        
        # Large file support
        proxy_buffering off;
        proxy_request_buffering off;
    }
}
EOF

print_status "Creating environment file..."

# Create .env file with secure defaults
cat > .env << EOF
# Flask Configuration
SECRET_KEY=$(openssl rand -hex 32)
DEBUG=False

# Database Configuration
POSTGRES_DB=ytdl_app
POSTGRES_USER=ytdl_user
POSTGRES_PASSWORD=$(openssl rand -base64 32)

# Redis Configuration
REDIS_PASSWORD=$(openssl rand -base64 32)

# MinIO Configuration
MINIO_ACCESS_KEY=ytdl_admin
MINIO_SECRET_KEY=$(openssl rand -base64 32)
MINIO_BUCKET=video-downloads

# Google Analytics (replace with your tracking ID)
GA_TRACKING_ID=G-XXXXXXXXXX

# Application Settings
VIDEO_EXPIRY_DAYS=30
MAX_VIDEO_SIZE=500
EOF

print_status "Creating additional configuration files..."

# Create .dockerignore
cat > .dockerignore << 'EOF'
**/.git
**/.gitignore
**/README.md
**/Dockerfile*
**/docker-compose*
**/node_modules
**/.env*
**/venv
**/__pycache__
**/.pytest_cache
**/logs
**/data
**/backups
**/*.pyc
**/*.pyo
**/*.pyd
**/.Python
**/pip-log.txt
**/pip-delete-this-directory.txt
**/.coverage
**/.tox
EOF

# Create nginx.conf for development
cat > nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    # Performance
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # Include configurations
    include /etc/nginx/conf.d/*.conf;
}
EOF

# Create health check script
cat > health-check.sh << 'EOF'
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
EOF

chmod +x health-check.sh

# Create backup script
cat > backup.sh << 'EOF'
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
EOF

chmod +x backup.sh

# Create deployment script
cat > deploy.sh << 'EOF'
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
EOF

chmod +x deploy.sh

print_status "Creating startup script..."

# Create startup script
cat > start.sh << 'EOF'
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
EOF

chmod +x start.sh

print_status "Creating stop script..."

# Create stop script
cat > stop.sh << 'EOF'
#!/bin/bash

# Stop script for YouTube Video Downloader

echo "🛑 Stopping YouTube Video Downloader..."

# Stop and remove containers
docker-compose down

# Remove orphaned containers
docker-compose down --remove-orphans

echo "✅ YouTube Video Downloader stopped"
EOF

chmod +x stop.sh

print_status "Creating cleanup script..."

# Create cleanup script
cat > cleanup.sh << 'EOF'
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
EOF

chmod +x cleanup.sh

print_status "Creating monitoring script..."

# Create monitoring script
cat > monitor.sh << 'EOF'
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
EOF

chmod +x monitor.sh

print_status "Creating logs script..."

# Create logs script
cat > logs.sh << 'EOF'
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
EOF

chmod +x logs.sh

print_status "Creating SSL setup script..."

# Create SSL setup script
cat > setup-ssl.sh << 'EOF'
#!/bin/bash

# SSL Setup script for YouTube Video Downloader

echo "🔒 Setting up SSL certificates..."

DOMAIN=${1:-localhost}

if [ "$DOMAIN" = "localhost" ]; then
    echo "⚠️  Setting up self-signed certificates for development"
    echo "   For production, provide your domain: ./setup-ssl.sh yourdomain.com"
fi

# Create SSL directory
mkdir -p nginx/ssl

if [ "$DOMAIN" = "localhost" ]; then
    # Generate self-signed certificate for development
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout nginx/ssl/key.pem \
        -out nginx/ssl/cert.pem \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
    
    echo "✅ Self-signed certificate created for localhost"
    echo "⚠️  Browsers will show security warnings for self-signed certificates"
else
    # Setup for Let's Encrypt (production)
    echo "🔧 Setting up Let's Encrypt for $DOMAIN"
    
    # Install certbot if not available
    if ! command -v certbot &> /dev/null; then
        echo "📦 Installing certbot..."
        apt-get update && apt-get install -y certbot python3-certbot-nginx
    fi
    
    # Generate certificate
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email admin@"$DOMAIN"
    
    # Copy certificates to nginx directory
    cp /etc/letsencrypt/live/"$DOMAIN"/fullchain.pem nginx/ssl/cert.pem
    cp /etc/letsencrypt/live/"$DOMAIN"/privkey.pem nginx/ssl/key.pem
    
    echo "✅ Let's Encrypt certificate installed for $DOMAIN"
fi

# Update nginx configuration to enable SSL
echo "🔧 Updating nginx configuration for SSL..."

# Backup original config
cp nginx/conf.d/default.conf nginx/conf.d/default.conf.backup

# Update the config to enable SSL sections
sed -i 's|# return 301 https://|return 301 https://|g' nginx/conf.d/default.conf
sed -i 's|# ssl_certificate|ssl_certificate|g' nginx/conf.d/default.conf
sed -i 's|# ssl_certificate_key|ssl_certificate_key|g' nginx/conf.d/default.conf
sed -i 's|# ssl_session|ssl_session|g' nginx/conf.d/default.conf
sed -i 's|# ssl_protocols|ssl_protocols|g' nginx/conf.d/default.conf
sed -i 's|# ssl_ciphers|ssl_ciphers|g' nginx/conf.d/default.conf
sed -i 's|# ssl_prefer|ssl_prefer|g' nginx/conf.d/default.conf
sed -i 's|# add_header Strict-Transport-Security|add_header Strict-Transport-Security|g' nginx/conf.d/default.conf

echo "✅ SSL setup completed"
echo "🔄 Restart nginx to apply changes: docker-compose restart nginx"
EOF

chmod +x setup-ssl.sh

print_status "Creating update script..."

# Create update script
cat > update.sh << 'EOF'
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
EOF

chmod +x update.sh

print_status "Creating development environment setup..."

# Create development docker-compose
cat > docker-compose.dev.yml << 'EOF'
version: '3.8'

services:
  app:
    build: .
    container_name: ytdl_app_dev
    restart: unless-stopped
    ports:
      - "5000:5000"
    depends_on:
      - postgres
      - redis
      - elasticsearch
      - minio
    environment:
      - SECRET_KEY=dev-secret-key
      - DEBUG=True
      - POSTGRES_HOST=postgres
      - POSTGRES_PORT=5432
      - POSTGRES_DB=ytdl_app_dev
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
      - REDIS_URL=redis://redis:6379/0
      - ELASTICSEARCH_HOST=elasticsearch
      - ELASTICSEARCH_PORT=9200
      - MINIO_ENDPOINT=minio:9000
      - MINIO_ACCESS_KEY=minioadmin
      - MINIO_SECRET_KEY=minioadmin
      - MINIO_BUCKET=video-downloads-dev
      - MINIO_SECURE=false
      - GA_TRACKING_ID=G-XXXXXXXXXX
      - VIDEO_EXPIRY_DAYS=7
      - MAX_VIDEO_SIZE=100
    volumes:
      - .:/app
      - ./logs/app:/app/logs
    networks:
      - ytdl_network
    command: ["python", "app.py"]

  postgres:
    image: postgres:15-alpine
    container_name: ytdl_postgres_dev
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: ytdl_app_dev
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_dev_data:/var/lib/postgresql/data
    networks:
      - ytdl_network

  redis:
    image: redis:7-alpine
    container_name: ytdl_redis_dev
    restart: unless-stopped
    ports:
      - "6379:6379"
    volumes:
      - redis_dev_data:/data
    networks:
      - ytdl_network

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.12.0
    container_name: ytdl_elasticsearch_dev
    restart: unless-stopped
    ports:
      - "9200:9200"
    environment:
      - node.name=elasticsearch
      - cluster.name=ytdl-dev-cluster
      - discovery.type=single-node
      - bootstrap.memory_lock=true
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms256m -Xmx256m"
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - elasticsearch_dev_data:/usr/share/elasticsearch/data
    networks:
      - ytdl_network

  minio:
    image: minio/minio:latest
    container_name: ytdl_minio_dev
    restart: unless-stopped
    ports:
      - "9000:9000"
      - "9001:9001"
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    volumes:
      - minio_dev_data:/data
    networks:
      - ytdl_network

volumes:
  postgres_dev_data:
  redis_dev_data:
  elasticsearch_dev_data:
  minio_dev_data:

networks:
  ytdl_network:
    driver: bridge
EOF

print_status "Creating README for Docker setup..."

# Create Docker README
cat > DOCKER_README.md << 'EOF'
# YouTube Video Downloader - Docker Setup

This directory contains a complete Docker setup for the YouTube Video Downloader application.

## 🚀 Quick Start

### Development Environment
```bash
# Start development environment
./start-dev.sh

# Access application at http://localhost:5000
# Access MinIO console at http://localhost:9001
```

### Production Environment
```bash
# Start production environment
./start.sh

# Access application at http://localhost
```

## 📁 Files Created

### Docker Configuration
- `Dockerfile` - Application container definition
- `docker-compose.yml` - Production orchestration
- `docker-compose.prod.yml` - Production with resource limits
- `docker-compose.dev.yml` - Development environment
- `.dockerignore` - Files to exclude from Docker build

### Nginx Configuration
- `nginx/conf.d/default.conf` - Main nginx configuration
- `nginx/nginx.conf` - Nginx main configuration
- `nginx/ssl/` - SSL certificates directory

### Scripts
- `start.sh` - Start production environment
- `start-dev.sh` - Start development environment
- `stop.sh` - Stop all services
- `deploy.sh` - Production deployment
- `backup.sh` - Backup database and files
- `cleanup.sh` - Remove all containers and data
- `health-check.sh` - Check service health
- `monitor.sh` - Real-time monitoring dashboard
- `logs.sh` - View service logs
- `setup-ssl.sh` - Setup SSL certificates
- `update.sh` - Update application

### Configuration
- `.env` - Environment variables (generated with secure passwords)

## 🔧 Services

| Service | Port | Purpose |
|---------|------|---------|
| App | 5000 | Flask application |
| Nginx | 80/443 | Reverse proxy |
| PostgreSQL | 5432 | Database |
| Redis | 6379 | Cache |
| Elasticsearch | 9200 | Search engine |
| MinIO | 9000/9001 | Object storage |

## 📋 Commands

### Basic Operations
```bash
# Start services
./start.sh

# Stop services
./stop.sh

# View logs
./logs.sh app
./logs.sh nginx
./logs.sh all

# Monitor services
./monitor.sh

# Health check
./health-check.sh
```

### Development
```bash
# Start development environment
docker-compose -f docker-compose.dev.yml up -d

# View application logs
docker-compose -f docker-compose.dev.yml logs -f app

# Rebuild app container
docker-compose -f docker-compose.dev.yml build app
```

### Production Deployment
```bash
# Deploy to production
./deploy.sh

# Backup before deployment
./backup.sh

# Update application
./update.sh
```

### SSL Setup
```bash
# Development (self-signed)
./setup-ssl.sh

# Production (Let's Encrypt)
./setup-ssl.sh yourdomain.com
```

### Maintenance
```bash
# Create backup
./backup.sh

# Clean up everything
./cleanup.sh

# Remove only containers
docker-compose down

# Remove containers and volumes
docker-compose down -v
```

## 🔒 Security Features

### Nginx Security
- Rate limiting for downloads and API
- Security headers (XSS, CSRF, etc.)
- Gzip compression
- SSL/TLS support
- Content Security Policy

### Application Security
- Secure session management
- Input validation
- SQL injection prevention
- File upload restrictions
- User data isolation

### Infrastructure Security
- Non-root containers
- Secure random passwords
- Network isolation
- Volume encryption support

## 📊 Monitoring

### Health Checks
All services include health checks:
- App: HTTP endpoint `/health`
- Nginx: Configuration validation
- PostgreSQL: Connection test
- Redis: Ping test
- Elasticsearch: Cluster health
- MinIO: Live endpoint

### Monitoring Dashboard
```bash
./monitor.sh
```

Shows real-time:
- Service status
- Resource usage (CPU, Memory, Network)
- Disk usage
- Container statistics

### Logs
```bash
# Application logs
./logs.sh app

# Nginx access/error logs
./logs.sh nginx

# Database logs
./logs.sh postgres

# All services
./logs.sh all
```

## 🔧 Customization

### Environment Variables
Edit `.env` file to customize:
- Database credentials
- Storage settings
- API keys
- Application limits

### Nginx Configuration
Edit `nginx/conf.d/default.conf` for:
- Rate limiting rules
- SSL settings
- Cache headers
- Security policies

### Resource Limits
Use `docker-compose.prod.yml` for production with resource limits:
```bash
docker-compose -f docker-compose.prod.yml up -d
```

## 🚨 Troubleshooting

### Common Issues

1. **Port Already in Use**
   ```bash
   # Find process using port
   sudo lsof -i :80
   
   # Stop conflicting service
   sudo systemctl stop apache2  # or nginx
   ```

2. **Permission Denied**
   ```bash
   # Fix permissions
   sudo chown -R $USER:$USER .
   chmod +x *.sh
   ```

3. **Services Not Starting**
   ```bash
   # Check logs
   ./logs.sh all
   
   # Check health
   ./health-check.sh
   
   # Restart services
   docker-compose restart
   ```

4. **Database Connection Failed**
   ```bash
   # Check PostgreSQL logs
   ./logs.sh postgres
   
   # Restart database
   docker-compose restart postgres
   ```

5. **Out of Disk Space**
   ```bash
   # Clean up Docker
   docker system prune -a
   
   # Remove old logs
   docker-compose exec app sh -c "find /app/logs -name '*.log' -mtime +7 -delete"
   ```

### Performance Tuning

1. **Increase Worker Processes**
   Edit `Dockerfile` CMD:
   ```dockerfile
   CMD ["gunicorn", "--workers", "8", "--bind", "0.0.0.0:5000", "app:app"]
   ```

2. **Optimize Database**
   ```bash
   # Connect to PostgreSQL
   docker-compose exec postgres psql -U ytdl_user -d ytdl_app
   
   # Run maintenance
   VACUUM ANALYZE;
   REINDEX DATABASE ytdl_app;
   ```

3. **Optimize Elasticsearch**
   Increase heap size in docker-compose.yml:
   ```yaml
   environment:
     - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
   ```

## 📚 Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Elasticsearch Documentation](https://www.elastic.co/guide/)
- [MinIO Documentation](https://docs.min.io/)
EOF

print_status "Creating development start script..."

# Create development start script
cat > start-dev.sh << 'EOF'
#!/bin/bash

# Development startup script for YouTube Video Downloader

echo "🚀 Starting YouTube Video Downloader (Development Mode)..."

# Create necessary directories
mkdir -p logs/nginx logs/app data/postgres data/redis data/elasticsearch data/minio

# Start development services
docker-compose -f docker-compose.dev.yml up -d

echo "⏳ Waiting for services to start..."
sleep 30

# Show running containers
docker-compose -f docker-compose.dev.yml ps

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
EOF

chmod +x start-dev.sh

print_status "All Docker files created successfully!"

echo ""
echo -e "${GREEN}✅ Docker setup completed successfully!${NC}"
echo ""
echo -e "${BLUE}📁 Created files and directories:${NC}"
echo "   ├── Dockerfile"
echo "   ├── docker-compose.yml"
echo "   ├── docker-compose.prod.yml"
echo "   ├── docker-compose.dev.yml"
echo "   ├── .dockerignore"
echo "   ├── .env (with secure passwords)"
echo "   ├── nginx/"
echo "   │   ├── conf.d/default.conf"
echo "   │   └── nginx.conf"
echo "   └── Scripts:"
echo "       ├── start.sh (production)"
echo "       ├── start-dev.sh (development)"
echo "       ├── stop.sh"
echo "       ├── deploy.sh"
echo "       ├── backup.sh"
echo "       ├── cleanup.sh"
echo "       ├── health-check.sh"
echo "       ├── monitor.sh"
echo "       ├── logs.sh"
echo "       ├── setup-ssl.sh"
echo "       └── update.sh"
echo ""
echo -e "${YELLOW}🚀 Quick Start:${NC}"
echo "   Development: ${GREEN}./start-dev.sh${NC}"
echo "   Production:  ${GREEN}./start.sh${NC}"
echo ""
echo -e "${YELLOW}🔧 Next steps:${NC}"
echo "   1. Review .env file and update settings"
echo "   2. Update GA_TRACKING_ID in .env file"
echo "   3. For production: ./setup-ssl.sh yourdomain.com"
echo "   4. Start the application: ./start.sh"
echo ""
echo -e "${BLUE}📖 Documentation: DOCKER_README.md${NC}"