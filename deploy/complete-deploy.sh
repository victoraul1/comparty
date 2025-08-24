#!/bin/bash

# Comparty Complete Deployment Script
# Completes the deployment after initial setup

set -e  # Exit on error

# Check if API key was provided
if [ -z "$1" ]; then
    echo "❌ Error: OpenAI API key not provided"
    echo "Usage: ./complete-deploy.sh \"your-openai-api-key\""
    exit 1
fi

OPENAI_KEY="$1"

echo "================================================"
echo "  🚀 Completing Comparty Deployment"
echo "================================================"

# Create comparty user if doesn't exist
if ! id -u comparty > /dev/null 2>&1; then
    echo "👤 Creating app user..."
    useradd -m -s /bin/bash comparty
    usermod -aG sudo comparty
fi

# Create app directory
echo "📁 Creating app directory..."
mkdir -p /home/comparty/app
mkdir -p /home/comparty/logs
chown -R comparty:comparty /home/comparty

# Create environment file
echo "📝 Creating environment configuration..."
cat > /home/comparty/app/.env.production <<EOF
# DigitalOcean Spaces
DO_SPACES_KEY=your_spaces_key_here
DO_SPACES_SECRET=your_spaces_secret_here
DO_SPACES_BUCKET=comparty-prod
DO_SPACES_REGION=nyc3
DO_SPACES_ENDPOINT=https://nyc3.digitaloceanspaces.com

# PayPal
PAYPAL_CLIENT_ID=AeBgNl5JulR1-p7ZG3cmPnQZIG0t8opuCodP-pUoTUYb6yISxuR4KFXq40cGdIitNtojOAAd7_GReKyf
PAYPAL_CLIENT_SECRET=EAQeFSck2D4ttvwRmSfcTq7myOe3DKCymvq-aH1PBsl0xX9SN6y_BZmpWRwNETcbLwVCp4XbeBdX31Z9
PAYPAL_WEBHOOK_ID=pending_webhook_setup
PAYPAL_ENVIRONMENT=sandbox

# Database
DATABASE_URL=postgresql://comparty:CompartyDB2025!@localhost:5432/comparty_prod

# Redis
REDIS_URL=redis://localhost:6379

# App
APP_URL=https://comparty.app
NODE_ENV=production
JWT_SECRET=comparty_jwt_secret_2025_$(openssl rand -hex 16)
PORT=3000

# Email
SENDGRID_API_KEY=your_sendgrid_api_key_here
FROM_EMAIL=noreply@comparty.app

# OpenAI
OPENAI_API_KEY=$OPENAI_KEY

# Features
AI_SCORING_ENABLED=true
VIDEO_SUPPORT_ENABLED=false

# Security
CSRF_SECRET=$(openssl rand -hex 32)
ENCRYPTION_KEY=$(openssl rand -hex 32)
EOF

chown comparty:comparty /home/comparty/app/.env.production

# Create PM2 ecosystem file
echo "⚙️ Creating PM2 configuration..."
cat > /home/comparty/app/ecosystem.config.js <<'PM2'
module.exports = {
  apps: [{
    name: 'comparty',
    script: 'npm',
    args: 'start',
    cwd: '/home/comparty/app',
    instances: 1,
    exec_mode: 'fork',
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: '/home/comparty/logs/error.log',
    out_file: '/home/comparty/logs/out.log',
    log_file: '/home/comparty/logs/combined.log',
    time: true
  }]
};
PM2

chown comparty:comparty /home/comparty/app/ecosystem.config.js

# Configure Nginx if not already done
echo "🌐 Configuring Nginx..."
cat > /etc/nginx/sites-available/comparty <<'NGINX'
server {
    listen 80;
    server_name comparty.app www.comparty.app;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    client_max_body_size 20M;
}
NGINX

ln -sf /etc/nginx/sites-available/comparty /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

# Clone the repository
echo "📥 Cloning repository..."
cd /home/comparty/app
if [ ! -d ".git" ]; then
    sudo -u comparty git clone https://github.com/victoraul1/comparty.git .
else
    echo "Repository exists, pulling latest..."
    sudo -u comparty git pull origin main
fi

# Setup environment file
echo "📋 Copying environment configuration..."
sudo -u comparty cp .env.production .env.local

# Install dependencies
echo "📦 Installing dependencies (this may take a few minutes)..."
sudo -u comparty npm install --legacy-peer-deps

# Build application
echo "🔨 Building application..."
sudo -u comparty npm run build

# Setup database
echo "🗄️ Setting up database..."
sudo -u comparty npx prisma generate
sudo -u comparty npx prisma db push

# Start application with PM2
echo "🚀 Starting application..."
sudo -u comparty pm2 delete comparty 2>/dev/null || true
sudo -u comparty pm2 start ecosystem.config.js
sudo -u comparty pm2 save

# Setup PM2 startup
echo "⚙️ Setting up PM2 startup..."
pm2 startup systemd -u comparty --hp /home/comparty
systemctl enable pm2-comparty 2>/dev/null || true

# Setup SSL certificate
echo "🔐 Setting up SSL certificate..."
certbot --nginx -d comparty.app -d www.comparty.app \
    --email admin@comparty.app \
    --agree-tos \
    --non-interactive \
    --redirect || echo "Note: SSL setup may need to be run manually later"

echo ""
echo "================================================"
echo "  ✅ Deployment Complete!"
echo "================================================"
echo ""
echo "🔍 Application Status:"
sudo -u comparty pm2 list

echo ""
echo "🌐 Testing application..."
sleep 5  # Give the app time to start
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|301\|302"; then
    echo "✅ Application is running successfully!"
else
    echo "⚠️  Application is starting up. Check logs with: sudo -u comparty pm2 logs comparty"
fi

echo ""
echo "================================================"
echo "  🎉 Your app is deployed!"
echo "================================================"
echo ""
echo "Access your application at:"
echo "  🌐 https://comparty.app"
echo ""
echo "Useful commands:"
echo "  View logs:        sudo -u comparty pm2 logs comparty"
echo "  Monitor app:      sudo -u comparty pm2 monit"
echo "  Restart app:      sudo -u comparty pm2 restart comparty"
echo "  Check status:     sudo -u comparty pm2 status"
echo ""
echo "================================================"