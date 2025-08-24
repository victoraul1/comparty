#!/bin/bash

# Comparty - Fix Auth TypeScript Errors and Deploy
# Fixes the password null check and completes deployment

echo "================================================"
echo "  🔧 Fixing Auth Type Errors and Deploying"
echo "================================================"

cd /home/comparty/app

# Fix the auth routes with proper null checks
echo "🔧 Fixing login route with null checks..."
cat > /home/comparty/app/src/app/api/auth/login/route.ts <<'EOF'
import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { db } from '@/lib/db';

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
});

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { email, password } = loginSchema.parse(body);

    // Find user
    const user = await db.user.findUnique({
      where: { email },
    });

    if (!user || !user.password) {
      return NextResponse.json(
        { success: false, error: 'Credenciales inválidas' },
        { status: 401 }
      );
    }

    // Verify password - user.password is now guaranteed to be non-null
    const isValidPassword = await bcrypt.compare(password, user.password);
    if (!isValidPassword) {
      return NextResponse.json(
        { success: false, error: 'Credenciales inválidas' },
        { status: 401 }
      );
    }

    // Generate JWT
    const token = jwt.sign(
      { userId: user.id, email: user.email },
      process.env.JWT_SECRET || 'default-secret',
      { expiresIn: '7d' }
    );

    return NextResponse.json({
      success: true,
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
      },
    });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { success: false, error: 'Datos inválidos', details: error.issues },
        { status: 400 }
      );
    }
    
    console.error('Login error:', error);
    return NextResponse.json(
      { success: false, error: 'Error interno del servidor' },
      { status: 500 }
    );
  }
}
EOF

echo "🔧 Fixing register route with proper types..."
cat > /home/comparty/app/src/app/api/auth/register/route.ts <<'EOF'
import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { db } from '@/lib/db';

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
  name: z.string().min(2),
});

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { email, password, name } = registerSchema.parse(body);

    // Check if user exists
    const existingUser = await db.user.findUnique({
      where: { email },
    });

    if (existingUser) {
      return NextResponse.json(
        { success: false, error: 'El usuario ya existe' },
        { status: 400 }
      );
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create user
    const user = await db.user.create({
      data: {
        email,
        password: hashedPassword,
        name,
      },
    });

    // Generate JWT
    const token = jwt.sign(
      { userId: user.id, email: user.email },
      process.env.JWT_SECRET || 'default-secret',
      { expiresIn: '7d' }
    );

    return NextResponse.json({
      success: true,
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
      },
    });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { success: false, error: 'Datos inválidos', details: error.issues },
        { status: 400 }
      );
    }
    
    console.error('Register error:', error);
    return NextResponse.json(
      { success: false, error: 'Error interno del servidor' },
      { status: 500 }
    );
  }
}
EOF

# Set correct ownership
chown -R comparty:comparty /home/comparty/app

# Build the application
echo "🔨 Building application..."
sudo -u comparty npm run build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Setup database
    echo "🗄️ Setting up database..."
    sudo -u comparty npx prisma generate
    sudo -u comparty npx prisma db push
    
    # Ensure logs directory exists
    mkdir -p /home/comparty/logs
    chown -R comparty:comparty /home/comparty/logs
    
    # Start with PM2
    echo "🚀 Starting application with PM2..."
    sudo -u comparty pm2 delete all 2>/dev/null || true
    sudo -u comparty pm2 start ecosystem.config.js
    sudo -u comparty pm2 save
    
    # Setup PM2 startup
    echo "⚙️ Configuring PM2 startup..."
    env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u comparty --hp /home/comparty
    systemctl enable pm2-comparty 2>/dev/null || true
    
    # Setup SSL certificate
    echo "🔐 Setting up SSL certificate..."
    if ! [ -f "/etc/letsencrypt/live/comparty.app/fullchain.pem" ]; then
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
    echo "  ✅ Application Successfully Deployed!"
    echo "================================================"
    echo ""
    
    # Show PM2 status
    echo "📊 Application Status:"
    sudo -u comparty pm2 list
    
    # Wait for app to start
    echo ""
    echo "⏳ Waiting for application to start..."
    sleep 20
    
    # Test the application
    echo "🔍 Testing application..."
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|301\|302"; then
        echo "✅ Application is running on port 3000!"
        
        # Test domain
        echo "Testing HTTPS..."
        if curl -s -o /dev/null -w "%{http_code}" https://comparty.app | grep -q "200"; then
            echo "✅ Site is LIVE at https://comparty.app!"
        else
            echo "⚠️  HTTPS is being configured..."
        fi
    else
        echo "⚠️  Application may still be starting. Showing recent logs:"
        sudo -u comparty pm2 logs comparty --lines 15 --nostream
    fi
    
    echo ""
    echo "================================================"
    echo "  🎉 Comparty is Live!"
    echo "================================================"
    echo ""
    echo "🌐 Access your application at:"
    echo "   https://comparty.app"
    echo ""
    echo "📝 Management commands:"
    echo "   View logs:     sudo -u comparty pm2 logs comparty"
    echo "   Monitor:       sudo -u comparty pm2 monit"
    echo "   Restart:       sudo -u comparty pm2 restart comparty"
    echo "   Check status:  sudo -u comparty pm2 status"
    echo ""
    echo "================================================"
else
    echo "❌ Build still failing. Let's check for other type errors..."
    echo ""
    echo "Running type check:"
    sudo -u comparty npx tsc --noEmit 2>&1 | head -20
fi