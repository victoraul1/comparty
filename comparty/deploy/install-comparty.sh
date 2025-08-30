#!/bin/bash

# Comparty Installation Script for DigitalOcean Droplet
# Run this after setup-droplet.sh

set -e

echo "================================================"
echo "  Installing Comparty Application"
echo "================================================"

# Switch to comparty user
cd /home/comparty/app

# Clone repository
echo "📥 Cloning repository..."
if [ ! -d ".git" ]; then
    git clone https://github.com/victoraul1/comparty.git .
else
    echo "Repository already exists, pulling latest changes..."
    git pull origin main
fi

# Copy environment file
echo "📋 Setting up environment..."
if [ ! -f ".env.local" ]; then
    cp .env.production .env.local
    echo "⚠️  Please update .env.local with your actual credentials!"
fi

# Install dependencies
echo "📦 Installing dependencies..."
npm install --legacy-peer-deps

# Generate Prisma client
echo "🗄️ Setting up database..."
npx prisma generate

# Run migrations
echo "🔄 Running database migrations..."
npx prisma migrate deploy || echo "No migrations to run"

# Seed database
echo "🌱 Seeding database..."
npm run db:seed || echo "Database already seeded"

# Build application
echo "🔨 Building application..."
npm run build

# Start with PM2
echo "🚀 Starting application with PM2..."
pm2 delete comparty 2>/dev/null || true
pm2 start ecosystem.config.js
pm2 save

echo "================================================"
echo "  ✅ Comparty Installation Complete!"
echo "================================================"
echo ""
echo "Application is running at: http://localhost:3000"
echo ""
echo "To view logs: pm2 logs comparty"
echo "To restart: pm2 restart comparty"
echo "To stop: pm2 stop comparty"
echo ""
echo "================================================"