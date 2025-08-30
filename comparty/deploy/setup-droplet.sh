#!/bin/bash

# Comparty - DigitalOcean Droplet Setup Script
# This script configures a fresh Ubuntu droplet for Comparty deployment

set -e  # Exit on error

echo "================================================"
echo "  Comparty Droplet Setup - Starting"
echo "================================================"

# Update system
echo "📦 Updating system packages..."
apt-get update
apt-get upgrade -y

# Install essential packages
echo "🔧 Installing essential packages..."
apt-get install -y curl wget git build-essential nginx certbot python3-certbot-nginx ufw

# Install Node.js 20 LTS
echo "📗 Installing Node.js 20 LTS..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Verify Node installation
node --version
npm --version

# Install PM2 globally
echo "🔄 Installing PM2 process manager..."
npm install -g pm2

# Install PostgreSQL 14
echo "🐘 Installing PostgreSQL 14..."
sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
apt-get update
apt-get -y install postgresql-14 postgresql-client-14

# Install Redis
echo "🔴 Installing Redis..."
apt-get install -y redis-server
systemctl enable redis-server
systemctl start redis-server

# Configure PostgreSQL
echo "🔐 Configuring PostgreSQL..."
sudo -u postgres psql <<EOF
CREATE USER comparty WITH PASSWORD 'CompartyDB2025!';
CREATE DATABASE comparty_prod OWNER comparty;
GRANT ALL PRIVILEGES ON DATABASE comparty_prod TO comparty;
EOF

# Create app user
echo "👤 Creating app user..."
useradd -m -s /bin/bash comparty || echo "User already exists"
usermod -aG sudo comparty

# Create app directory
echo "📁 Creating app directory..."
mkdir -p /home/comparty/app
chown -R comparty:comparty /home/comparty/app

# Configure Nginx
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
nginx -t
systemctl restart nginx

# Configure firewall
echo "🔥 Configuring firewall..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# Create environment file template
echo "📝 Creating environment template..."
cat > /home/comparty/app/.env.production <<'ENV'
# DigitalOcean Spaces
DO_SPACES_KEY=
DO_SPACES_SECRET=
DO_SPACES_BUCKET=comparty-prod
DO_SPACES_REGION=nyc3
DO_SPACES_ENDPOINT=https://nyc3.digitaloceanspaces.com

# PayPal
PAYPAL_CLIENT_ID=
PAYPAL_CLIENT_SECRET=
PAYPAL_WEBHOOK_ID=
PAYPAL_ENVIRONMENT=production

# Database
DATABASE_URL=postgresql://comparty:CompartyDB2025!@localhost:5432/comparty_prod

# Redis
REDIS_URL=redis://localhost:6379

# App
APP_URL=https://comparty.app
NODE_ENV=production
JWT_SECRET=
PORT=3000

# Email
SENDGRID_API_KEY=
FROM_EMAIL=noreply@comparty.app

# OpenAI
OPENAI_API_KEY=

# Features
AI_SCORING_ENABLED=true
VIDEO_SUPPORT_ENABLED=false

# Security
CSRF_SECRET=
ENCRYPTION_KEY=
ENV

chown comparty:comparty /home/comparty/app/.env.production

# Create deployment script
echo "🚀 Creating deployment script..."
cat > /home/comparty/deploy.sh <<'DEPLOY'
#!/bin/bash
cd /home/comparty/app

echo "🔄 Pulling latest changes from GitHub..."
git pull origin main

echo "📦 Installing dependencies..."
npm ci --legacy-peer-deps

echo "🔨 Building application..."
npm run build

echo "🗄️ Running database migrations..."
npx prisma generate
npx prisma migrate deploy

echo "🔄 Restarting application..."
pm2 restart comparty || pm2 start npm --name "comparty" -- start

echo "✅ Deployment complete!"
DEPLOY

chmod +x /home/comparty/deploy.sh
chown comparty:comparty /home/comparty/deploy.sh

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

# Create log directory
mkdir -p /home/comparty/logs
chown -R comparty:comparty /home/comparty/logs

# Create systemd service for PM2
echo "🔧 Setting up PM2 as system service..."
sudo -u comparty pm2 startup systemd -u comparty --hp /home/comparty
systemctl enable pm2-comparty

echo "================================================"
echo "  ✅ Droplet Setup Complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. Clone your repository:"
echo "   sudo -u comparty git clone https://github.com/victoraul1/comparty.git /home/comparty/app"
echo ""
echo "2. Update environment variables:"
echo "   nano /home/comparty/app/.env.production"
echo ""
echo "3. Install app dependencies:"
echo "   cd /home/comparty/app && sudo -u comparty npm install --legacy-peer-deps"
echo ""
echo "4. Build and start the app:"
echo "   cd /home/comparty/app && sudo -u comparty npm run build"
echo "   sudo -u comparty pm2 start ecosystem.config.js"
echo ""
echo "5. Setup SSL certificate:"
echo "   certbot --nginx -d comparty.app -d www.comparty.app"
echo ""
echo "================================================"