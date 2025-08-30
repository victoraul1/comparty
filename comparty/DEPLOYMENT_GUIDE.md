# Comparty Deployment Guide

## Quick Start Commands for DigitalOcean Droplet

SSH into your droplet and run these commands in order:

```bash
# 1. SSH into your droplet
ssh root@137.184.183.136

# 2. Download the updated setup script (fixes apt-key issue)
wget https://raw.githubusercontent.com/victoraul1/comparty/main/deploy/setup-droplet-v2.sh
chmod +x setup-droplet-v2.sh

# 3. Run the setup script
./setup-droplet-v2.sh

# 4. After setup completes, configure environment variables
nano /home/comparty/app/.env.production
# Add your actual API keys:
# - OPENAI_API_KEY (starts with sk-proj-)
# - SENDGRID_API_KEY
# - DO_SPACES_KEY and DO_SPACES_SECRET

# 5. Install the application
cd /home/comparty/app
sudo -u comparty git clone https://github.com/victoraul1/comparty.git .
sudo -u comparty cp .env.production .env.local
sudo -u comparty npm install --legacy-peer-deps
sudo -u comparty npm run build
sudo -u comparty npx prisma generate
sudo -u comparty npx prisma db push

# 6. Start the application
sudo -u comparty pm2 start ecosystem.config.js
sudo -u comparty pm2 save
pm2 startup systemd -u comparty --hp /home/comparty

# 7. Setup SSL certificate for comparty.app
certbot --nginx -d comparty.app -d www.comparty.app --email admin@comparty.app --agree-tos --non-interactive

# 8. Verify everything is working
pm2 status
curl http://localhost:3000
```

## Troubleshooting

### If PostgreSQL installation fails:
```bash
# The setup-droplet-v2.sh script fixes the apt-key deprecation issue
# If you still have issues, manually install PostgreSQL:
sudo sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-keyring.gpg
sudo apt-get update
sudo apt-get -y install postgresql-14
```

### Check application logs:
```bash
pm2 logs comparty
pm2 monit
```

### Restart application:
```bash
pm2 restart comparty
```

### Check Nginx status:
```bash
systemctl status nginx
nginx -t
```

### View domain/SSL status:
```bash
# Run from your local machine
./deploy/check-domain.sh
```

## Important API Keys to Configure

After running the setup script, update `/home/comparty/app/.env.local` with:

1. **OpenAI API Key** (Required for AI photo analysis)
2. **SendGrid API Key** (Required for email notifications)
3. **DigitalOcean Spaces** (For image storage):
   - DO_SPACES_KEY
   - DO_SPACES_SECRET

## Domain Configuration

Ensure comparty.app is pointing to your droplet IP (137.184.183.136) in Namecheap:
- A Record: @ → 137.184.183.136
- A Record: www → 137.184.183.136

## Security Notes

- The setup script creates a non-root user 'comparty' for running the app
- Firewall is configured to only allow SSH (22), HTTP (80), and HTTPS (443)
- SSL certificate auto-renews via Certbot
- Database password is set to 'CompartyDB2025!' - consider changing this

## Deployment Updates

To deploy new code changes:
```bash
cd /home/comparty/app
sudo -u comparty git pull origin main
sudo -u comparty npm install --legacy-peer-deps
sudo -u comparty npm run build
sudo -u comparty npx prisma generate
sudo -u comparty npx prisma migrate deploy
sudo -u comparty pm2 restart comparty
```