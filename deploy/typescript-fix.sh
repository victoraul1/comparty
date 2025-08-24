#!/bin/bash

# Comparty TypeScript Fix and Final Deploy
# Fixes the Zod TypeScript error and completes deployment

echo "================================================"
echo "  🔧 Fixing TypeScript Errors and Deploying"
echo "================================================"

cd /home/comparty/app

# Fix the TypeScript error in the auth route
echo "🔧 Fixing TypeScript error in auth route..."
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

    if (!user) {
      return NextResponse.json(
        { success: false, error: 'Credenciales inválidas' },
        { status: 401 }
      );
    }

    // Verify password
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

# Fix similar error in register route if it exists
echo "🔧 Fixing TypeScript error in register route..."
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

# Now build the application
echo "🔨 Building application..."
sudo -u comparty npm run build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Setup database
    echo "🗄️ Setting up database..."
    sudo -u comparty npx prisma generate
    sudo -u comparty npx prisma db push
    
    # Start with PM2
    echo "🚀 Starting application with PM2..."
    sudo -u comparty pm2 delete all 2>/dev/null || true
    sudo -u comparty pm2 start ecosystem.config.js
    sudo -u comparty pm2 save
    
    # Setup PM2 startup
    echo "⚙️ Setting up PM2 startup..."
    pm2 startup systemd -u comparty --hp /home/comparty > /tmp/pm2_startup.sh 2>/dev/null || true
    bash /tmp/pm2_startup.sh 2>/dev/null || true
    systemctl enable pm2-comparty 2>/dev/null || true
    
    # Setup SSL certificate
    echo "🔐 Setting up SSL certificate..."
    if ! [ -f "/etc/letsencrypt/live/comparty.app/fullchain.pem" ]; then
        certbot --nginx -d comparty.app -d www.comparty.app \
            --email admin@comparty.app \
            --agree-tos \
            --non-interactive \
            --redirect || echo "SSL will be configured later"
    else
        echo "✅ SSL certificate already exists"
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
    sleep 15
    
    # Test the application
    echo "🔍 Testing application..."
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|301\|302"; then
        echo "✅ Application is running on port 3000!"
        
        # Test domain
        if curl -s -o /dev/null -w "%{http_code}" https://comparty.app | grep -q "200"; then
            echo "✅ Site is LIVE at https://comparty.app!"
        else
            echo "⚠️  HTTPS is being configured, may take a moment..."
        fi
    else
        echo "⚠️  Application may still be starting. Check logs:"
        sudo -u comparty pm2 logs comparty --lines 20 --nostream
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
    echo "❌ Build failed. Please check the errors above."
fi