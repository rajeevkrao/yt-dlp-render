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
