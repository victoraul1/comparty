#!/bin/bash

# Comparty - DigitalOcean Droplet Setup Script v2
# Updated for Ubuntu 22.04+ without deprecated commands

set -e  # Exit on error

echo "================================================"
echo "  Comparty Droplet Setup v2 - Starting"
echo "================================================"

# Update system
echo "📦 Updating system packages..."
apt-get update
apt-get upgrade -y

# Install essential packages
echo "🔧 Installing essential packages..."
apt-get install -y curl wget git build-essential nginx certbot python3-certbot-nginx ufw software-properties-common gnupg lsb-release

# Node.js is already installed, verify version
echo "📗 Verifying Node.js installation..."
node --version
npm --version

# Install PM2 if not already installed
if ! command -v pm2 &> /dev/null; then
    echo "🔄 Installing PM2 process manager..."
    npm install -g pm2
else
    echo "✅ PM2 already installed"
fi

# Install PostgreSQL 14 (updated method)
echo "🐘 Installing PostgreSQL 14..."
# Create the file repository configuration
sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

# Import the repository signing key
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-keyring.gpg

# Update the package list
apt-get update

# Install PostgreSQL
apt-get -y install postgresql-14 postgresql-client-14

# Start and enable PostgreSQL
systemctl start postgresql
systemctl enable postgresql

# Install Redis
echo "🔴 Installing Redis..."
apt-get install -y redis-server
systemctl enable redis-server
systemctl start redis-server

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

echo "✅ PostgreSQL configured"

# Create app user if doesn't exist
echo "👤 Creating app user..."
if ! id -u comparty > /dev/null 2>&1; then
    useradd -m -s /bin/bash comparty
    usermod -aG sudo comparty
    echo "✅ User 'comparty' created"
else
    echo "✅ User 'comparty' already exists"
fi

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

# Test and restart Nginx
nginx -t && systemctl restart nginx

# Configure firewall
echo "🔥 Configuring firewall..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
echo "y" | ufw enable

# Create environment file template
echo "📝 Creating environment template..."
cat > /home/comparty/app/.env.production <<'ENV'
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
JWT_SECRET=comparty_jwt_secret_2025_CHANGE_THIS
PORT=3000

# Email
SENDGRID_API_KEY=your_sendgrid_api_key_here
FROM_EMAIL=noreply@comparty.app

# OpenAI
OPENAI_API_KEY=your_openai_api_key_here

# Features
AI_SCORING_ENABLED=true
VIDEO_SUPPORT_ENABLED=false

# Security
CSRF_SECRET=generate_random_string_here
ENCRYPTION_KEY=generate_another_random_string_here
ENV

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

# Create log directory
mkdir -p /home/comparty/logs
chown -R comparty:comparty /home/comparty/logs

# Clone the repository
echo "📥 Cloning repository..."
cd /home/comparty/app
if [ ! -d ".git" ]; then
    sudo -u comparty git clone https://github.com/victoraul1/comparty.git .
    echo "✅ Repository cloned"
else
    echo "✅ Repository already exists"
fi

# Copy environment file
if [ ! -f ".env.local" ]; then
    cp .env.production .env.local
    echo "✅ Environment file created. Please update with your actual credentials!"
fi

echo "================================================"
echo "  ✅ Droplet Setup Complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Install app dependencies:"
echo "   cd /home/comparty/app"
echo "   sudo -u comparty npm install --legacy-peer-deps"
echo ""
echo "2. Build the application:"
echo "   sudo -u comparty npm run build"
echo ""
echo "3. Setup database:"
echo "   sudo -u comparty npx prisma generate"
echo "   sudo -u comparty npx prisma db push"
echo ""
echo "4. Start the application:"
echo "   sudo -u comparty pm2 start ecosystem.config.js"
echo "   sudo -u comparty pm2 save"
echo "   pm2 startup systemd -u comparty --hp /home/comparty"
echo ""
echo "5. Setup SSL certificate:"
echo "   certbot --nginx -d comparty.app -d www.comparty.app"
echo ""
echo "================================================"