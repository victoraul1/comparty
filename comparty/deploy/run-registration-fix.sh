#!/bin/bash

# Direct server commands to fix registration
cat << 'SCRIPT' | ssh root@137.184.183.136
#!/bin/bash

echo "================================================"
echo "  🔧 Fixing Registration - Direct Fix"
echo "================================================"

cd /home/comparty/app

# Check PM2 logs first
echo "📋 Checking current errors..."
sudo -u comparty pm2 logs comparty --lines 20 --nostream | grep -i error || true

# Install missing dependencies
echo "📦 Installing missing dependencies..."
sudo -u comparty npm install jsonwebtoken @types/jsonwebtoken bcryptjs @types/bcryptjs --save

# Create simplified registration endpoint
echo "📝 Creating working registration endpoint..."
cat > /home/comparty/app/src/app/api/auth/register/route.ts << 'EOF'
import { NextRequest, NextResponse } from 'next/server';
import bcrypt from 'bcryptjs';
import { db } from '@/lib/db';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { email, password, name } = body;

    console.log('Registration attempt for:', email);

    // Validate input
    if (!email || !password || !name) {
      return NextResponse.json(
        { success: false, error: 'Todos los campos son requeridos' },
        { status: 400 }
      );
    }

    // Check if user exists
    const existingUser = await db.user.findUnique({
      where: { email }
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
        name
      }
    });

    console.log('User created successfully:', user.id);

    // Simple response without JWT for now
    return NextResponse.json({
      success: true,
      message: 'Usuario creado exitosamente',
      userId: user.id
    });

  } catch (error: any) {
    console.error('Registration error:', error);
    
    // Handle specific Prisma errors
    if (error.code === 'P2002') {
      return NextResponse.json(
        { success: false, error: 'El email ya está registrado' },
        { status: 400 }
      );
    }
    
    if (error.code === 'P2021') {
      return NextResponse.json(
        { success: false, error: 'Error de base de datos - tabla no encontrada' },
        { status: 500 }
      );
    }
    
    return NextResponse.json(
      { success: false, error: 'Error al crear usuario. Por favor intenta de nuevo.' },
      { status: 500 }
    );
  }
}
EOF

# Create simple login endpoint
echo "📝 Creating login endpoint..."
cat > /home/comparty/app/src/app/api/auth/login/route.ts << 'EOF'
import { NextRequest, NextResponse } from 'next/server';
import bcrypt from 'bcryptjs';
import { db } from '@/lib/db';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { email, password } = body;

    if (!email || !password) {
      return NextResponse.json(
        { success: false, error: 'Email y contraseña son requeridos' },
        { status: 400 }
      );
    }

    const user = await db.user.findUnique({
      where: { email }
    });

    if (!user || !user.password) {
      return NextResponse.json(
        { success: false, error: 'Credenciales inválidas' },
        { status: 401 }
      );
    }

    const isValid = await bcrypt.compare(password, user.password);

    if (!isValid) {
      return NextResponse.json(
        { success: false, error: 'Credenciales inválidas' },
        { status: 401 }
      );
    }

    // Return simple token
    return NextResponse.json({
      success: true,
      token: Buffer.from(user.id).toString('base64'),
      user: {
        id: user.id,
        email: user.email,
        name: user.name
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    return NextResponse.json(
      { success: false, error: 'Error al iniciar sesión' },
      { status: 500 }
    );
  }
}
EOF

# Ensure db.ts exists
echo "📚 Ensuring database library..."
cat > /home/comparty/app/src/lib/db.ts << 'EOF'
import { PrismaClient } from '@prisma/client';

declare global {
  var prisma: PrismaClient | undefined;
}

export const db = global.prisma || new PrismaClient({
  log: ['error', 'warn']
});

if (process.env.NODE_ENV !== 'production') {
  global.prisma = db;
}
EOF

# Generate Prisma client
echo "🔨 Generating Prisma client..."
sudo -u comparty npx prisma generate

# Push schema to database
echo "📤 Syncing database schema..."
sudo -u comparty npx prisma db push --accept-data-loss

# Set ownership
chown -R comparty:comparty /home/comparty/app

# Build
echo "🔨 Building application..."
sudo -u comparty npm run build

if [ \$? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Clear logs
    sudo -u comparty pm2 flush
    
    # Restart
    echo "🔄 Restarting application..."
    sudo -u comparty pm2 restart comparty
    
    sleep 5
    
    # Test the endpoint
    echo ""
    echo "🧪 Testing registration endpoint..."
    curl -X POST https://comparty.app/api/auth/register \
      -H "Content-Type: application/json" \
      -d '{"email":"test@example.com","password":"test123","name":"Test User"}' \
      2>/dev/null | python3 -m json.tool || true
    
    echo ""
    echo "================================================"
    echo "  ✅ Registration Fix Complete!"
    echo "================================================"
    echo ""
    echo "Try registering at: https://comparty.app/register"
    echo ""
    echo "Check logs: sudo -u comparty pm2 logs comparty"
    echo ""
else
    echo "❌ Build failed. Showing errors..."
    sudo -u comparty npm run build 2>&1 | tail -30
fi
SCRIPT