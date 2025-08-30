#!/bin/bash

# Comparty Quick Deploy Script
# Run this on your droplet as root to fully deploy the application
# Usage: ./quick-deploy.sh "your-openai-api-key"

set -e  # Exit on error

# Check if API key was provided
if [ -z "$1" ]; then
    echo "❌ Error: OpenAI API key not provided"
    echo "Usage: ./quick-deploy.sh \"your-openai-api-key\""
    echo "Example: ./quick-deploy.sh \"sk-proj-...\""
    exit 1
fi

OPENAI_KEY="$1"

echo "================================================"
echo "  🚀 Comparty Quick Deploy - Starting"
echo "================================================"
echo ""

# Step 1: Download and run setup script
echo "📥 Downloading setup script..."
cd ~
wget -q https://raw.githubusercontent.com/victoraul1/comparty/main/deploy/setup-droplet-v2.sh
chmod +x setup-droplet-v2.sh

echo "🔧 Running system setup (this may take 5-10 minutes)..."
./setup-droplet-v2.sh

# Step 2: Configure environment with actual API key
echo "🔐 Configuring API keys..."
sed -i "s|OPENAI_API_KEY=your_openai_api_key_here|OPENAI_API_KEY=$OPENAI_KEY|g" /home/comparty/app/.env.production

# Step 3: Clone the repository
echo "📦 Cloning repository..."
cd /home/comparty/app
if [ ! -d ".git" ]; then
    sudo -u comparty git clone https://github.com/victoraul1/comparty.git .
else
    echo "Repository already exists, pulling latest..."
    sudo -u comparty git pull origin main
fi

# Step 4: Setup environment file
echo "📋 Setting up environment..."
sudo -u comparty cp .env.production .env.local
# Update the .env.local with the API key as well
sed -i "s|OPENAI_API_KEY=your_openai_api_key_here|OPENAI_API_KEY=$OPENAI_KEY|g" /home/comparty/app/.env.local

# Step 5: Install dependencies
echo "📦 Installing dependencies (this may take a few minutes)..."
sudo -u comparty npm install --legacy-peer-deps

# Step 6: Build application
echo "🔨 Building application..."
sudo -u comparty npm run build

# Step 7: Setup database
echo "🗄️ Setting up database..."
sudo -u comparty npx prisma generate
sudo -u comparty npx prisma db push

# Step 8: Start application with PM2
echo "🚀 Starting application..."
sudo -u comparty pm2 delete comparty 2>/dev/null || true
sudo -u comparty pm2 start ecosystem.config.js
sudo -u comparty pm2 save

# Step 9: Setup PM2 startup
echo "⚙️ Configuring PM2 startup..."
pm2 startup systemd -u comparty --hp /home/comparty
systemctl enable pm2-comparty

# Step 10: Setup SSL certificate
echo "🔐 Setting up SSL certificate..."
certbot --nginx -d comparty.app -d www.comparty.app \
    --email admin@comparty.app \
    --agree-tos \
    --non-interactive \
    --redirect

# Step 11: Restart Nginx to apply all changes
echo "🔄 Restarting Nginx..."
nginx -t && systemctl restart nginx

# Step 12: Verify everything
echo ""
echo "================================================"
echo "  ✅ Deployment Complete!"
echo "================================================"
echo ""
echo "🔍 Checking application status..."
sudo -u comparty pm2 status

echo ""
echo "🌐 Testing local connection..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|301\|302"; then
    echo "✅ Application is responding on port 3000"
else
    echo "⚠️  Application may still be starting up..."
fi

echo ""
echo "🔐 Testing HTTPS..."
if curl -s -o /dev/null -w "%{http_code}" https://comparty.app | grep -q "200"; then
    echo "✅ Site is live at https://comparty.app"
else
    echo "⚠️  HTTPS may take a few minutes to propagate"
fi

echo ""
echo "================================================"
echo "  📝 Important Information"
echo "================================================"
echo ""
echo "Your application is now deployed!"
echo ""
echo "🌐 Access your site at: https://comparty.app"
echo ""
echo "📊 Useful commands:"
echo "  View logs:        sudo -u comparty pm2 logs comparty"
echo "  Monitor app:      sudo -u comparty pm2 monit"
echo "  Restart app:      sudo -u comparty pm2 restart comparty"
echo "  Check status:     sudo -u comparty pm2 status"
echo ""
echo "🔄 To deploy updates:"
echo "  cd /home/comparty/app"
echo "  sudo -u comparty git pull"
echo "  sudo -u comparty npm install --legacy-peer-deps"
echo "  sudo -u comparty npm run build"
echo "  sudo -u comparty pm2 restart comparty"
echo ""
echo "================================================"