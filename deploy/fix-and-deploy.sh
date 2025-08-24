#!/bin/bash

# Comparty Fix and Deploy Script
# Fixes the PostgreSQL repository issue and completes deployment

set -e  # Exit on error

# Check if API key was provided
if [ -z "$1" ]; then
    echo "❌ Error: OpenAI API key not provided"
    echo "Usage: ./fix-and-deploy.sh \"your-openai-api-key\""
    exit 1
fi

OPENAI_KEY="$1"

echo "================================================"
echo "  🔧 Fixing PostgreSQL Repository Issue"
echo "================================================"

# Clean up problematic PostgreSQL repo
echo "🧹 Cleaning up existing PostgreSQL configurations..."
rm -f /etc/apt/sources.list.d/pgdg.list
rm -f /usr/share/keyrings/postgresql-keyring.gpg

# Add PostgreSQL repository with proper key
echo "🔑 Adding PostgreSQL repository with correct key..."
sh -c 'echo "deb [signed-by=/usr/share/keyrings/postgresql-keyring.gpg] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-keyring.gpg
chmod 644 /usr/share/keyrings/postgresql-keyring.gpg

# Update package list
echo "📦 Updating package list..."
apt-get update

# Install PostgreSQL if not already installed
if ! command -v psql &> /dev/null; then
    echo "🐘 Installing PostgreSQL 14..."
    apt-get -y install postgresql-14 postgresql-client-14
    systemctl start postgresql
    systemctl enable postgresql
    
    # Configure PostgreSQL
    echo "🔐 Configuring PostgreSQL..."
    sudo -u postgres psql <<EOF
DROP DATABASE IF EXISTS comparty_prod;
DROP USER IF EXISTS comparty;
CREATE USER comparty WITH PASSWORD 'CompartyDB2025!';
CREATE DATABASE comparty_prod OWNER comparty;
GRANT ALL PRIVILEGES ON DATABASE comparty_prod TO comparty;
\q
EOF
else
    echo "✅ PostgreSQL already installed"
fi

# Ensure Redis is installed
if ! command -v redis-server &> /dev/null; then
    echo "🔴 Installing Redis..."
    apt-get install -y redis-server
    systemctl enable redis-server
    systemctl start redis-server
else
    echo "✅ Redis already installed"
fi

# Ensure PM2 is installed
if ! command -v pm2 &> /dev/null; then
    echo "🔄 Installing PM2..."
    npm install -g pm2
else
    echo "✅ PM2 already installed"
fi

echo ""
echo "================================================"
echo "  📦 Deploying Comparty Application"
echo "================================================"

# Configure environment with actual API key
echo "🔐 Configuring API keys..."
if [ -f "/home/comparty/app/.env.production" ]; then
    sed -i "s|OPENAI_API_KEY=.*|OPENAI_API_KEY=$OPENAI_KEY|g" /home/comparty/app/.env.production
fi

# Clone the repository
echo "📥 Setting up application..."
cd /home/comparty/app
if [ ! -d ".git" ]; then
    sudo -u comparty git clone https://github.com/victoraul1/comparty.git .
else
    echo "Repository exists, pulling latest..."
    sudo -u comparty git pull origin main
fi

# Setup environment file
echo "📋 Setting up environment..."
if [ ! -f ".env.local" ]; then
    sudo -u comparty cp .env.production .env.local
fi
sed -i "s|OPENAI_API_KEY=.*|OPENAI_API_KEY=$OPENAI_KEY|g" /home/comparty/app/.env.local

# Install dependencies
echo "📦 Installing dependencies..."
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
pm2 startup systemd -u comparty --hp /home/comparty > /dev/null 2>&1 || true
systemctl enable pm2-comparty 2>/dev/null || true

# Setup SSL certificate
echo "🔐 Setting up SSL certificate..."
certbot --nginx -d comparty.app -d www.comparty.app \
    --email admin@comparty.app \
    --agree-tos \
    --non-interactive \
    --redirect || echo "SSL setup will be completed later"

# Restart Nginx
nginx -t && systemctl restart nginx

echo ""
echo "================================================"
echo "  ✅ Deployment Complete!"
echo "================================================"
echo ""
echo "🔍 Application Status:"
sudo -u comparty pm2 status

echo ""
echo "🌐 Testing connections..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|301\|302"; then
    echo "✅ Application is running on port 3000"
else
    echo "⚠️  Application may still be starting..."
fi

echo ""
echo "================================================"
echo "  Your app is now deployed!"
echo "  Access it at: https://comparty.app"
echo "================================================"
echo ""
echo "Useful commands:"
echo "  View logs:    sudo -u comparty pm2 logs comparty"
echo "  Monitor app:  sudo -u comparty pm2 monit"
echo "  Restart app:  sudo -u comparty pm2 restart comparty"
echo ""