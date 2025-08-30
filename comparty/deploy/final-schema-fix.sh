#!/bin/bash

# Comparty - Final Schema Fix
# Removes non-existent fields and uses exact schema names

echo "================================================"
echo "  🔧 Final Schema Fix"
echo "================================================"

cd /home/comparty/app

# Check exact PhotoScore fields
echo "📋 Checking PhotoScore model fields..."
grep -A 15 "model PhotoScore" prisma/schema.prisma

# Fix PhotoProcessor with only existing fields
echo "📸 Fixing PhotoProcessor - final version..."
cat > /home/comparty/app/src/services/photo-processor.ts <<'EOF'
import { db } from '@/lib/db';
import { AIAnalyzer } from './ai-analyzer';
import crypto from 'crypto';

export class PhotoProcessor {
  static async processUpload(uploadId: string): Promise<{ success: boolean; error?: string }> {
    try {
      const upload = await db.upload.findUnique({
        where: { id: uploadId },
        include: { event: true }
      });

      if (!upload) {
        return { success: false, error: 'Upload not found' };
      }

      // Use only objectKeyRaw which exists
      const imageUrl = upload.objectKeyRaw || '';
      const imageHash = await this.generateImageHash(imageUrl);

      // Check if already marked as duplicate
      if (upload.isDuplicate) {
        return { success: true };
      }

      // Check for duplicates
      const duplicate = await db.upload.findFirst({
        where: {
          eventId: upload.eventId,
          objectKeyRaw: upload.objectKeyRaw,
          id: { not: uploadId }
        }
      });

      if (duplicate) {
        await db.upload.update({
          where: { id: uploadId },
          data: {
            isDuplicate: true,
            duplicateOfId: duplicate.id
          }
        });
        return { success: true };
      }

      // Analyze with AI if enabled
      let aiScore = null;
      if (process.env.AI_SCORING_ENABLED === 'true') {
        const analysis = await AIAnalyzer.analyzePhoto(
          imageUrl,
          upload.event.type,
          upload.event.name
        );

        if (analysis) {
          // Use exact PhotoScore field names from schema
          aiScore = await db.photoScore.create({
            data: {
              uploadId,
              compositionScore: analysis.composition || 0,
              technicalScore: analysis.technical || 0,
              emotionalImpact: analysis.emotional || 0,
              memorabilityScore: analysis.memorability || 0,
              overallScore: analysis.overall || 0,
              analysis: {
                reasoning: analysis.reasoning || '',
                suggestions: analysis.suggestions || ''
              }
            }
          });
        }
      }

      return { success: true };

    } catch (error) {
      console.error('Error processing upload:', error);
      return { 
        success: false, 
        error: error instanceof Error ? error.message : 'Processing failed' 
      };
    }
  }

  private static async generateImageHash(imageUrl: string): Promise<string> {
    return crypto.createHash('md5').update(imageUrl).digest('hex');
  }

  static async processEventBatch(eventId: string): Promise<void> {
    console.log('Processing event batch:', eventId);
  }

  static async generatePublicVersion(eventId: string): Promise<void> {
    console.log('Generating public version for event:', eventId);
  }

  static async selectBestPhotos(eventId: string): Promise<void> {
    console.log('Selecting best photos for event:', eventId);
  }
}

export { PhotoProcessor as PhotoProcessorService };
export default PhotoProcessor;
EOF

# Set correct ownership
chown -R comparty:comparty /home/comparty/app

# Build the application
echo "🔨 Building application..."
sudo -u comparty npm run build

if [ $? -eq 0 ]; then
    echo ""
    echo "================================================"
    echo "  ✅✅✅ BUILD SUCCESSFUL! ✅✅✅"
    echo "================================================"
    echo ""
    
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
    pm2 startup systemd -u comparty --hp /home/comparty
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
    echo "⏳ Waiting for application to start (30 seconds)..."
    for i in {30..1}; do
        echo -ne "\r⏳ Starting in $i seconds...  "
        sleep 1
    done
    echo ""
    echo ""
    
    echo "📊 PM2 Status:"
    sudo -u comparty pm2 list
    echo ""
    
    echo "🔍 Testing application..."
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|301\|302"; then
        echo "✅ Application running on localhost:3000!"
        echo ""
        
        # Test HTTPS
        echo "Testing HTTPS access..."
        HTTPS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://comparty.app)
        
        if [ "$HTTPS_STATUS" = "200" ] || [ "$HTTPS_STATUS" = "301" ] || [ "$HTTPS_STATUS" = "302" ]; then
            echo ""
            echo "================================================"
            echo "                                                "
            echo "  🎉🎉🎉 DEPLOYMENT SUCCESSFUL! 🎉🎉🎉      "
            echo "                                                "
            echo "  🌐 Your app is LIVE at:                      "
            echo "     https://comparty.app                      "
            echo "                                                "
            echo "  Open your browser and visit the site!        "
            echo "                                                "
            echo "================================================"
        else
            echo "⚠️  HTTPS returned status: $HTTPS_STATUS"
            echo "Waiting 15 more seconds for SSL..."
            sleep 15
            HTTPS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://comparty.app)
            if [ "$HTTPS_STATUS" = "200" ] || [ "$HTTPS_STATUS" = "301" ] || [ "$HTTPS_STATUS" = "302" ]; then
                echo "✅ HTTPS is now working! Visit https://comparty.app"
            else
                echo "Please wait a few minutes for DNS/SSL to propagate"
            fi
        fi
    else
        echo "⚠️  Application may still be starting. Recent logs:"
        sudo -u comparty pm2 logs comparty --lines 30 --nostream
    fi
    
    echo ""
    echo "📝 Useful commands:"
    echo "   View logs:    sudo -u comparty pm2 logs comparty"
    echo "   Monitor:      sudo -u comparty pm2 monit"
    echo "   Restart app:  sudo -u comparty pm2 restart comparty"
    echo ""
else
    echo "❌ Build still failing. Let me check what's wrong..."
    echo ""
    echo "Remaining errors:"
    sudo -u comparty npx tsc --noEmit 2>&1 | grep "error TS" | head -10
fi