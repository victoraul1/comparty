# Comparty - DigitalOcean Deployment Guide

## 📋 Prerequisites

- DigitalOcean Droplet (Ubuntu 22.04 LTS)
- Domain name pointing to droplet IP
- SSH access to droplet

## 🚀 Quick Deployment

### Step 1: Connect to your droplet

```bash
ssh root@137.184.183.136
```

### Step 2: Download and run setup script

```bash
# Download the setup script
wget https://raw.githubusercontent.com/victoraul1/comparty/main/deploy/setup-droplet.sh

# Make it executable
chmod +x setup-droplet.sh

# Run the setup
./setup-droplet.sh
```

This script will install:
- Node.js 20 LTS
- PostgreSQL 14
- Redis
- Nginx
- PM2
- SSL certificates

### Step 3: Clone and setup the application

```bash
# Switch to comparty user
su - comparty

# Clone the repository
cd /home/comparty/app
git clone https://github.com/victoraul1/comparty.git .

# Copy production environment file
wget https://raw.githubusercontent.com/victoraul1/comparty/main/deploy/production.env
cp production.env .env.local

# Edit environment variables with your actual values
nano .env.local
```

### Step 4: Install and build

```bash
# Install dependencies
npm install --legacy-peer-deps

# Setup database
npx prisma generate
npx prisma migrate deploy
npm run db:seed

# Build the application
npm run build
```

### Step 5: Start the application

```bash
# Start with PM2
pm2 start ecosystem.config.js
pm2 save
pm2 startup
```

### Step 6: Setup SSL (optional but recommended)

```bash
# Exit to root user
exit

# Get SSL certificate
certbot --nginx -d your-domain.com -d www.your-domain.com
```

## 🔧 Manual Setup Commands

If you prefer to set up manually, here are the individual commands:

### Update system
```bash
apt update && apt upgrade -y
```

### Install Node.js 20
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs
```

### Install PostgreSQL
```bash
apt install -y postgresql postgresql-contrib
sudo -u postgres createuser comparty
sudo -u postgres createdb comparty_prod
sudo -u postgres psql -c "ALTER USER comparty WITH PASSWORD 'your_password';"
```

### Install Redis
```bash
apt install -y redis-server
systemctl enable redis-server
systemctl start redis-server
```

### Install Nginx
```bash
apt install -y nginx
```

### Configure Nginx
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

### Install PM2
```bash
npm install -g pm2
```

## 📝 Environment Variables

Required environment variables in `.env.local`:

```env
# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/comparty_prod

# Redis
REDIS_URL=redis://localhost:6379

# PayPal
PAYPAL_CLIENT_ID=your_client_id
PAYPAL_CLIENT_SECRET=your_secret

# OpenAI
OPENAI_API_KEY=your_api_key

# App
APP_URL=https://your-domain.com
NODE_ENV=production
JWT_SECRET=random_string_here
```

## 🔍 Monitoring

### View application logs
```bash
pm2 logs comparty
```

### Check application status
```bash
pm2 status
```

### Monitor resources
```bash
pm2 monit
```

### Restart application
```bash
pm2 restart comparty
```

## 🆘 Troubleshooting

### Database connection issues
```bash
# Check PostgreSQL status
systemctl status postgresql

# Check database exists
sudo -u postgres psql -l
```

### Application won't start
```bash
# Check logs
pm2 logs comparty --lines 100

# Check Node version
node --version  # Should be v20.x

# Rebuild
npm run build
```

### Nginx issues
```bash
# Test configuration
nginx -t

# Restart Nginx
systemctl restart nginx

# Check logs
tail -f /var/log/nginx/error.log
```

## 🔐 Security Recommendations

1. **Change default passwords**
   - PostgreSQL password
   - JWT secret
   - All other secrets in .env

2. **Setup firewall**
```bash
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

3. **Create non-root user**
```bash
adduser comparty
usermod -aG sudo comparty
```

4. **Disable root SSH login**
```bash
nano /etc/ssh/sshd_config
# Set: PermitRootLogin no
systemctl restart sshd
```

5. **Keep system updated**
```bash
apt update && apt upgrade -y
```

## 📧 Support

For issues or questions:
- GitHub Issues: https://github.com/victoraul1/comparty/issues
- Email: victor@comparty.app

---

Last updated: 2025-08-23