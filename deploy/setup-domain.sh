#!/bin/bash

# Comparty Domain and SSL Setup Script
# This configures comparty.app domain with SSL certificate

set -e

DOMAIN="comparty.app"
DROPLET_IP="137.184.183.136"
EMAIL="admin@comparty.app"

echo "================================================"
echo "  Setting up domain: $DOMAIN"
echo "  Droplet IP: $DROPLET_IP"
echo "================================================"

# Update Nginx configuration for the domain
echo "🌐 Configuring Nginx for $DOMAIN..."
cat > /etc/nginx/sites-available/comparty <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;

    # Redirect all HTTP traffic to HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;

    # SSL configuration will be added by Certbot
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Proxy settings
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$server_name;
        proxy_buffering off;
        proxy_request_buffering off;
    }

    # Upload size limit
    client_max_body_size 20M;
    
    # Timeouts
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
}
NGINX

# Enable the site
ln -sf /etc/nginx/sites-available/comparty /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
echo "✅ Testing Nginx configuration..."
nginx -t

# Reload Nginx
echo "🔄 Reloading Nginx..."
systemctl reload nginx

# Install Certbot if not already installed
echo "📦 Installing Certbot..."
apt-get update
apt-get install -y certbot python3-certbot-nginx

# Obtain SSL certificate
echo "🔐 Obtaining SSL certificate..."
certbot --nginx -d $DOMAIN -d www.$DOMAIN \
    --non-interactive \
    --agree-tos \
    --email $EMAIL \
    --redirect \
    --expand

# Setup auto-renewal
echo "⏰ Setting up SSL auto-renewal..."
systemctl enable certbot.timer
systemctl start certbot.timer

# Test SSL renewal
echo "🧪 Testing SSL renewal..."
certbot renew --dry-run

echo "================================================"
echo "  ✅ Domain and SSL Setup Complete!"
echo "================================================"
echo ""
echo "Your site should now be accessible at:"
echo "  https://$DOMAIN"
echo "  https://www.$DOMAIN"
echo ""
echo "SSL certificate will auto-renew before expiration."
echo ""
echo "To manually renew: certbot renew"
echo "To check certificate: certbot certificates"
echo ""
echo "================================================"