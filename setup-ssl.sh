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
