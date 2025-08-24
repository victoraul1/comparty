# DNS Configuration for comparty.app

## 🌐 Namecheap DNS Settings

Configure your domain at Namecheap to point to your DigitalOcean droplet.

### Step 1: Login to Namecheap

1. Go to https://www.namecheap.com
2. Login to your account
3. Go to Dashboard → Domain List
4. Find `comparty.app` and click "Manage"

### Step 2: Configure DNS Records

Click on "Advanced DNS" and add these records:

| Type | Host | Value | TTL |
|------|------|-------|-----|
| A Record | @ | 137.184.183.136 | Automatic |
| A Record | www | 137.184.183.136 | Automatic |
| CNAME | * | comparty.app | Automatic |

### Step 3: Remove Default Records

Delete any existing records that conflict:
- Remove any default parking page records
- Remove any forwarding rules
- Keep only the records listed above

### Step 4: Save Changes

Click "Save All Changes" button.

## ⏱️ DNS Propagation

DNS changes can take up to 48 hours to propagate globally, but usually happens within:
- 5-10 minutes for most locations
- 1-2 hours for complete global propagation

### Check DNS Propagation

You can verify DNS propagation using:

1. **Command line:**
```bash
# Check A record
nslookup comparty.app

# Check with specific DNS
nslookup comparty.app 8.8.8.8

# Check DNS propagation
dig comparty.app
```

2. **Online tools:**
- https://www.whatsmydns.net/#A/comparty.app
- https://dnschecker.org/#A/comparty.app

## 🔧 Alternative: Using DigitalOcean DNS

If you prefer, you can use DigitalOcean's DNS instead:

### Step 1: Add Domain to DigitalOcean

1. Login to DigitalOcean
2. Go to Networking → Domains
3. Add domain: `comparty.app`
4. Select your droplet

### Step 2: Update Namecheap Nameservers

In Namecheap, change to "Custom DNS" and use:
- ns1.digitalocean.com
- ns2.digitalocean.com
- ns3.digitalocean.com

### Step 3: Configure in DigitalOcean

DigitalOcean will automatically create the necessary A records.

## 🔐 After DNS Propagation

Once DNS is working, run the SSL setup on your droplet:

```bash
ssh root@137.184.183.136

# Run the domain setup script
cd /home/comparty/app/deploy
chmod +x setup-domain.sh
./setup-domain.sh
```

## ✅ Verification

After setup, verify everything is working:

1. **HTTP redirect to HTTPS:**
   - Visit http://comparty.app → Should redirect to https://comparty.app

2. **SSL Certificate:**
   - Check for padlock icon in browser
   - Visit https://www.ssllabs.com/ssltest/analyze.html?d=comparty.app

3. **Both www and non-www:**
   - https://comparty.app → Should work
   - https://www.comparty.app → Should work

## 🚨 Troubleshooting

### DNS not resolving

```bash
# Clear DNS cache on Mac
sudo dscacheutil -flushcache

# Clear DNS cache on Windows
ipconfig /flushdns

# Clear DNS cache on Linux
sudo systemd-resolve --flush-caches
```

### SSL certificate issues

```bash
# On the droplet, check certificate status
certbot certificates

# Manually obtain certificate
certbot --nginx -d comparty.app -d www.comparty.app

# Check Nginx logs
tail -f /var/log/nginx/error.log
```

### Application not accessible

```bash
# Check if app is running
pm2 status

# Check if Nginx is running
systemctl status nginx

# Check if port 3000 is listening
netstat -tlnp | grep 3000
```

## 📧 Email Configuration

For email delivery from comparty.app, add these records in Namecheap:

| Type | Host | Value | Priority | TTL |
|------|------|-------|----------|-----|
| MX | @ | mail.comparty.app | 10 | Automatic |
| TXT | @ | v=spf1 include:sendgrid.net ~all | - | Automatic |
| TXT | _dmarc | v=DMARC1; p=none; rua=mailto:admin@comparty.app | - | Automatic |

## 📝 Notes

- Domain: comparty.app
- Droplet IP: 137.184.183.136
- SSL Provider: Let's Encrypt (free)
- Auto-renewal: Enabled via Certbot

---

Last updated: 2025-08-23