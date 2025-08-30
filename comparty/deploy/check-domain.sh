#!/bin/bash

# Domain and SSL Verification Script for comparty.app

DOMAIN="comparty.app"
DROPLET_IP="137.184.183.136"

echo "================================================"
echo "  Domain & SSL Check for $DOMAIN"
echo "================================================"
echo ""

# Check DNS Resolution
echo "📡 Checking DNS Resolution..."
echo "--------------------------------"

# Check A record
DNS_IP=$(dig +short $DOMAIN @8.8.8.8)
if [ "$DNS_IP" = "$DROPLET_IP" ]; then
    echo "✅ DNS A record: $DOMAIN → $DNS_IP"
else
    echo "❌ DNS A record mismatch!"
    echo "   Expected: $DROPLET_IP"
    echo "   Got: $DNS_IP"
    echo "   Please update DNS records in Namecheap"
fi

# Check www subdomain
WWW_IP=$(dig +short www.$DOMAIN @8.8.8.8)
if [ "$WWW_IP" = "$DROPLET_IP" ]; then
    echo "✅ DNS A record: www.$DOMAIN → $WWW_IP"
else
    echo "❌ DNS A record mismatch for www!"
    echo "   Expected: $DROPLET_IP"
    echo "   Got: $WWW_IP"
fi

echo ""
echo "🌐 Checking HTTP/HTTPS..."
echo "--------------------------------"

# Check HTTP redirect
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -L http://$DOMAIN)
if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ HTTP accessible (should redirect to HTTPS)"
else
    echo "⚠️  HTTP status: $HTTP_STATUS"
fi

# Check HTTPS
HTTPS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN)
if [ "$HTTPS_STATUS" = "200" ]; then
    echo "✅ HTTPS accessible"
else
    echo "❌ HTTPS not accessible (status: $HTTPS_STATUS)"
    echo "   Run setup-domain.sh on the droplet to install SSL"
fi

echo ""
echo "🔐 Checking SSL Certificate..."
echo "--------------------------------"

# Check SSL certificate
SSL_INFO=$(echo | openssl s_client -connect $DOMAIN:443 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "✅ SSL certificate is valid"
    echo "$SSL_INFO"
else
    echo "❌ No valid SSL certificate found"
    echo "   Run: certbot --nginx -d $DOMAIN -d www.$DOMAIN"
fi

echo ""
echo "🖥️  Server Status..."
echo "--------------------------------"

# Check if server is responding
PING_RESULT=$(ping -c 1 -W 2 $DROPLET_IP 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "✅ Server is reachable at $DROPLET_IP"
else
    echo "❌ Server is not responding to ping"
fi

# Check specific ports
nc -zv -w2 $DROPLET_IP 22 2>/dev/null && echo "✅ SSH port 22 is open" || echo "❌ SSH port 22 is closed"
nc -zv -w2 $DROPLET_IP 80 2>/dev/null && echo "✅ HTTP port 80 is open" || echo "❌ HTTP port 80 is closed"
nc -zv -w2 $DROPLET_IP 443 2>/dev/null && echo "✅ HTTPS port 443 is open" || echo "❌ HTTPS port 443 is closed"

echo ""
echo "================================================"
echo "  Summary"
echo "================================================"

if [ "$DNS_IP" = "$DROPLET_IP" ] && [ "$HTTPS_STATUS" = "200" ]; then
    echo "✅ Domain is properly configured!"
    echo "   Your site is accessible at: https://$DOMAIN"
else
    echo "⚠️  Setup incomplete. Please check:"
    echo "   1. DNS records in Namecheap"
    echo "   2. Run setup scripts on the droplet"
    echo "   3. Install SSL certificate with Certbot"
fi

echo ""
echo "📚 Next Steps:"
echo "   1. SSH to droplet: ssh root@$DROPLET_IP"
echo "   2. Run setup: ./setup-droplet.sh"
echo "   3. Configure SSL: ./setup-domain.sh"
echo "   4. Deploy app: ./install-comparty.sh"
echo ""
echo "================================================"