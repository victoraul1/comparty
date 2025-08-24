#!/bin/bash

# Comparty Build Fix and Deploy Script
# Fixes the Tailwind CSS dependency issue and completes deployment

set -e  # Exit on error

# Check if API key was provided
if [ -z "$1" ]; then
    echo "❌ Error: OpenAI API key not provided"
    echo "Usage: ./fix-build.sh \"your-openai-api-key\""
    exit 1
fi

OPENAI_KEY="$1"

echo "================================================"
echo "  🔧 Fixing Build Issues and Deploying"
echo "================================================"

cd /home/comparty/app

# Fix the Tailwind CSS dependency issue
echo "📦 Installing missing Tailwind dependencies..."
sudo -u comparty npm install --save-dev @tailwindcss/postcss autoprefixer postcss --legacy-peer-deps

# Ensure all dependencies are properly installed
echo "📦 Reinstalling all dependencies..."
sudo -u comparty npm install --legacy-peer-deps

# Update the postcss.config.js to use the correct format
echo "🔧 Updating PostCSS configuration..."
cat > /home/comparty/app/postcss.config.js <<'EOF'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF
chown comparty:comparty /home/comparty/app/postcss.config.js

# Ensure environment is configured
echo "🔐 Verifying environment configuration..."
if ! grep -q "OPENAI_API_KEY=$OPENAI_KEY" /home/comparty/app/.env.local; then
    sed -i "s|OPENAI_API_KEY=.*|OPENAI_API_KEY=$OPENAI_KEY|g" /home/comparty/app/.env.local
fi

# Try building again
echo "🔨 Building application..."
sudo -u comparty npm run build

# If build succeeds, continue with deployment
if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
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
    pm2 startup systemd -u comparty --hp /home/comparty > /tmp/pm2_startup.sh 2>/dev/null || true
    bash /tmp/pm2_startup.sh 2>/dev/null || true
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
    
    # Restart Nginx
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
    echo "🔍 Testing application..."
    sleep 10  # Give the app time to start
    
    # Test the application
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|301\|302"; then
        echo "✅ Application is running on port 3000!"
        
        # Test the domain
        if curl -s -o /dev/null -w "%{http_code}" https://comparty.app | grep -q "200"; then
            echo "✅ Site is LIVE at https://comparty.app!"
        else
            echo "⚠️  HTTPS is being configured..."
        fi
    else
        echo "⚠️  Application is starting. Showing recent logs:"
        sudo -u comparty pm2 logs comparty --lines 20 --nostream
    fi
    
    echo ""
    echo "================================================"
    echo "  🎉 Comparty is Deployed!"
    echo "================================================"
    echo ""
    echo "🌐 Your application is available at:"
    echo "   https://comparty.app"
    echo ""
    echo "📝 Commands to manage your app:"
    echo "   View logs:    sudo -u comparty pm2 logs comparty"
    echo "   Monitor:      sudo -u comparty pm2 monit"
    echo "   Restart:      sudo -u comparty pm2 restart comparty"
    echo "   Status:       sudo -u comparty pm2 status"
    echo ""
else
    echo "❌ Build failed. Checking the issue..."
    echo "Please check the error messages above."
fi

echo "================================================"