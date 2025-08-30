#!/bin/bash

# Comparty Clean Deploy Script
# Cleans up previous attempts and completes deployment

set -e  # Exit on error

# Check if API key was provided
if [ -z "$1" ]; then
    echo "❌ Error: OpenAI API key not provided"
    echo "Usage: ./clean-deploy.sh \"your-openai-api-key\""
    exit 1
fi

OPENAI_KEY="$1"

echo "================================================"
echo "  🧹 Cleaning and Redeploying Comparty"
echo "================================================"

# Clean up existing app directory
echo "🧹 Cleaning up existing files..."
cd /home/comparty/app

# Check if we're in a git repo and pull latest
if [ -d ".git" ]; then
    echo "📥 Pulling latest code from GitHub..."
    sudo -u comparty git reset --hard
    sudo -u comparty git clean -fd
    sudo -u comparty git pull origin main
else
    echo "📥 Repository not found, cloning fresh..."
    cd /home/comparty
    rm -rf app
    mkdir app
    chown comparty:comparty app
    cd app
    sudo -u comparty git clone https://github.com/victoraul1/comparty.git .
fi

# Update environment file with API key
echo "🔐 Configuring environment..."
cat > /home/comparty/app/.env.local <<EOF
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

chown comparty:comparty /home/comparty/app/.env.local

# Ensure PM2 ecosystem file exists
if [ ! -f "/home/comparty/app/ecosystem.config.js" ]; then
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
fi

# Clean install dependencies
echo "📦 Installing dependencies (this may take 3-5 minutes)..."
cd /home/comparty/app
sudo -u comparty rm -rf node_modules package-lock.json
sudo -u comparty npm install --legacy-peer-deps

# Build application
echo "🔨 Building application (this may take 2-3 minutes)..."
sudo -u comparty npm run build

# Setup database
echo "🗄️ Setting up database..."
sudo -u comparty npx prisma generate
sudo -u comparty npx prisma db push

# Stop any existing PM2 processes
echo "🛑 Stopping any existing processes..."
sudo -u comparty pm2 delete all 2>/dev/null || true

# Start application with PM2
echo "🚀 Starting application..."
sudo -u comparty pm2 start ecosystem.config.js
sudo -u comparty pm2 save

# Setup PM2 startup
echo "⚙️ Configuring PM2 to start on boot..."
pm2 startup systemd -u comparty --hp /home/comparty > /tmp/pm2_startup.sh
bash /tmp/pm2_startup.sh
systemctl enable pm2-comparty 2>/dev/null || true

# Setup SSL certificate if not already done
echo "🔐 Checking SSL certificate..."
if ! [ -f "/etc/letsencrypt/live/comparty.app/fullchain.pem" ]; then
    echo "Setting up SSL certificate..."
    certbot --nginx -d comparty.app -d www.comparty.app \
        --email admin@comparty.app \
        --agree-tos \
        --non-interactive \
        --redirect
else
    echo "✅ SSL certificate already configured"
fi

# Restart Nginx to ensure all configurations are loaded
systemctl restart nginx

echo ""
echo "================================================"
echo "  ✅ Deployment Complete!"
echo "================================================"
echo ""

# Show application status
echo "📊 Application Status:"
sudo -u comparty pm2 list

echo ""
echo "🔍 Checking if application is running..."
sleep 10  # Give the app more time to start

# Test the application
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|301\|302"; then
    echo "✅ Application is running on port 3000!"
    
    # Test the domain
    if curl -s -o /dev/null -w "%{http_code}" https://comparty.app | grep -q "200"; then
        echo "✅ Site is LIVE at https://comparty.app!"
    else
        echo "⚠️  HTTPS is configured but may take a moment to propagate"
    fi
else
    echo "⚠️  Application is still starting. Check logs below:"
    sudo -u comparty pm2 logs comparty --lines 20
fi

echo ""
echo "================================================"
echo "  🎉 Comparty is Deployed!"
echo "================================================"
echo ""
echo "🌐 Access your application at:"
echo "   https://comparty.app"
echo ""
echo "📝 Useful commands:"
echo "   View logs:        sudo -u comparty pm2 logs comparty"
echo "   Monitor app:      sudo -u comparty pm2 monit"
echo "   Restart app:      sudo -u comparty pm2 restart comparty"
echo "   Check status:     sudo -u comparty pm2 status"
echo ""
echo "🔄 To deploy updates in the future:"
echo "   cd /home/comparty/app"
echo "   sudo -u comparty git pull"
echo "   sudo -u comparty npm install --legacy-peer-deps"
echo "   sudo -u comparty npm run build"
echo "   sudo -u comparty pm2 restart comparty"
echo ""
echo "================================================"