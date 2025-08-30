#!/bin/bash

# Comparty - Create Missing Files and Complete Deployment
# Creates the missing database connection and other required files

echo "================================================"
echo "  🔧 Creating Missing Files and Deploying"
echo "================================================"

cd /home/comparty/app

# Create the lib directory if it doesn't exist
echo "📁 Creating lib directory..."
mkdir -p /home/comparty/app/src/lib

# Create the database connection file
echo "🗄️ Creating database connection file..."
cat > /home/comparty/app/src/lib/db.ts <<'EOF'
import { PrismaClient } from '@prisma/client'

declare global {
  var prisma: PrismaClient | undefined
}

export const db = global.prisma || new PrismaClient()

if (process.env.NODE_ENV !== 'production') {
  global.prisma = db
}
EOF

# Create auth utilities
echo "🔐 Creating auth utilities..."
cat > /home/comparty/app/src/lib/auth.ts <<'EOF'
import jwt from 'jsonwebtoken';
import { NextRequest } from 'next/server';

export interface JWTPayload {
  userId: string;
  email: string;
}

export function generateToken(payload: JWTPayload): string {
  return jwt.sign(payload, process.env.JWT_SECRET || 'default-secret', {
    expiresIn: '7d',
  });
}

export function verifyToken(token: string): JWTPayload | null {
  try {
    return jwt.verify(token, process.env.JWT_SECRET || 'default-secret') as JWTPayload;
  } catch {
    return null;
  }
}

export function getTokenFromRequest(request: NextRequest): string | null {
  const authHeader = request.headers.get('authorization');
  if (!authHeader) return null;
  
  const [bearer, token] = authHeader.split(' ');
  if (bearer !== 'Bearer' || !token) return null;
  
  return token;
}
EOF

# Create upload utilities
echo "📤 Creating upload utilities..."
cat > /home/comparty/app/src/lib/upload.ts <<'EOF'
export const MAX_FILE_SIZE = 20 * 1024 * 1024; // 20MB
export const ALLOWED_FILE_TYPES = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];

export function validateFile(file: File): { valid: boolean; error?: string } {
  if (file.size > MAX_FILE_SIZE) {
    return { valid: false, error: 'File size exceeds 20MB limit' };
  }
  
  if (!ALLOWED_FILE_TYPES.includes(file.type)) {
    return { valid: false, error: 'Invalid file type. Only JPEG, PNG, GIF, and WebP are allowed' };
  }
  
  return { valid: true };
}

export function generateFileName(originalName: string): string {
  const ext = originalName.split('.').pop();
  const timestamp = Date.now();
  const random = Math.random().toString(36).substring(7);
  return `${timestamp}-${random}.${ext}`;
}
EOF

# Create constants file
echo "📝 Creating constants..."
cat > /home/comparty/app/src/lib/constants.ts <<'EOF'
export const PLAN_TIERS = {
  FREE: {
    name: 'Gratis',
    price: 0,
    maxGuests: 5,
    maxPhotosPerGuest: 10,
    features: ['5 invitados', '10 fotos por persona', 'Álbum por 30 días']
  },
  BASIC: {
    name: 'Básico',
    price: 50,
    maxGuests: 10,
    maxPhotosPerGuest: 20,
    features: ['10 invitados', '20 fotos por persona', 'Álbum por 90 días', 'Sin marca de agua']
  },
  PREMIUM: {
    name: 'Premium',
    price: 100,
    maxGuests: 15,
    maxPhotosPerGuest: 30,
    features: ['15 invitados', '30 fotos por persona', 'Álbum por 180 días', 'Sin marca de agua', 'Descarga en alta resolución']
  },
  ULTIMATE: {
    name: 'Ultimate',
    price: 200,
    maxGuests: 20,
    maxPhotosPerGuest: -1, // Unlimited
    features: ['20 invitados', 'Fotos ilimitadas', 'Álbum permanente', 'Sin marca de agua', 'Descarga en alta resolución', 'Soporte prioritario']
  }
};

export const EVENT_TYPES = [
  'wedding',
  'birthday',
  'corporate',
  'graduation',
  'baby_shower',
  'anniversary',
  'other'
];
EOF

# Create utils file
echo "🛠️ Creating utilities..."
cat > /home/comparty/app/src/lib/utils.ts <<'EOF'
import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function formatDate(date: Date | string): string {
  return new Date(date).toLocaleDateString('es-ES', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });
}

export function generateSlug(): string {
  return Math.random().toString(36).substring(2, 15);
}
EOF

# Install missing dependencies
echo "📦 Installing missing dependencies..."
sudo -u comparty npm install clsx tailwind-merge --save --legacy-peer-deps

# Set correct ownership
chown -R comparty:comparty /home/comparty/app

# Now build the application
echo "🔨 Building application..."
sudo -u comparty npm run build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Setup database
    echo "🗄️ Setting up database..."
    sudo -u comparty npx prisma generate
    sudo -u comparty npx prisma db push
    
    # Create PM2 ecosystem file if missing
    if [ ! -f "/home/comparty/app/ecosystem.config.js" ]; then
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
    fi
    
    # Start with PM2
    echo "🚀 Starting application with PM2..."
    sudo -u comparty pm2 delete all 2>/dev/null || true
    sudo -u comparty pm2 start ecosystem.config.js
    sudo -u comparty pm2 save
    
    # Setup PM2 startup
    echo "⚙️ Setting up PM2 startup..."
    pm2 startup systemd -u comparty --hp /home/comparty
    systemctl enable pm2-comparty 2>/dev/null || true
    
    # Setup SSL certificate
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
    nginx -t && systemctl restart nginx
    
    echo ""
    echo "================================================"
    echo "  ✅ Deployment Complete!"
    echo "================================================"
    echo ""
    
    # Show PM2 status
    echo "📊 Application Status:"
    sudo -u comparty pm2 list
    
    # Wait for app to start
    echo ""
    echo "⏳ Waiting for application to start..."
    sleep 15
    
    # Test the application
    echo "🔍 Testing application..."
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|301\|302"; then
        echo "✅ Application is running on port 3000!"
        
        # Test domain with HTTPS
        if curl -s -o /dev/null -w "%{http_code}" https://comparty.app | grep -q "200"; then
            echo "✅ Site is LIVE at https://comparty.app!"
        else
            echo "⚠️  HTTPS may still be configuring..."
        fi
    else
        echo "⚠️  Application is starting. Recent logs:"
        sudo -u comparty pm2 logs comparty --lines 10 --nostream
    fi
    
    echo ""
    echo "================================================"
    echo "  🎉 Comparty is Deployed!"
    echo "================================================"
    echo ""
    echo "🌐 Your application is available at:"
    echo "   https://comparty.app"
    echo ""
    echo "📝 Useful commands:"
    echo "   View logs:     sudo -u comparty pm2 logs comparty"
    echo "   Monitor:       sudo -u comparty pm2 monit"
    echo "   Restart:       sudo -u comparty pm2 restart comparty"
    echo "   Check status:  sudo -u comparty pm2 status"
    echo ""
    echo "================================================"
else
    echo "❌ Build failed. Checking what's still missing..."
    echo ""
    echo "Files in src/lib:"
    ls -la /home/comparty/app/src/lib/
    echo ""
    echo "Please check the error messages above."
fi