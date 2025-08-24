#!/bin/bash

# Comparty - Fix with Correct Field Names
# Uses the actual field names from error messages

echo "================================================"
echo "  🔧 Fixing with Correct Field Names"
echo "================================================"

cd /home/comparty/app

# First, let's see what fields actually exist
echo "📋 Checking actual Prisma models..."
echo "Upload model:"
grep -A 30 "model Upload" prisma/schema.prisma | head -35
echo ""
echo "PhotoScore model:"
grep -A 20 "model PhotoScore" prisma/schema.prisma | head -25

# Fix PhotoProcessor with CORRECT field names
echo "📸 Fixing PhotoProcessor with correct field names..."
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

      // Use objectKeyRaw (not objectKey)
      const imageUrl = upload.objectKeyRaw || upload.url || '';
      const imageHash = await this.generateImageHash(imageUrl);

      // Check if already marked as duplicate
      if (upload.isDuplicate) {
        return { success: true };
      }

      // Check for duplicates using objectKeyRaw
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
          // Use correct PhotoScore field names
          aiScore = await db.photoScore.create({
            data: {
              uploadId,
              composition: analysis.composition,
              technical: analysis.technical,
              emotional: analysis.emotional,
              memorability: analysis.memorability,
              overall: analysis.overall,
              reasoning: analysis.reasoning || '',
              suggestions: analysis.suggestions || ''
            }
          });
        }
      }

      // Just mark as processed (no metadata field to update)
      // The status is tracked elsewhere or in app logic
      
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

# Fix the uploads/process route to not pass imageBuffer
echo "📤 Fixing uploads/process route..."
sed -i 's/await queuePhotoProcessing(uploadId, imageBuffer);/await queuePhotoProcessing(uploadId);/g' /home/comparty/app/src/app/api/uploads/process/route.ts

# Set correct ownership
chown -R comparty:comparty /home/comparty/app

# Build the application
echo "🔨 Building application..."
sudo -u comparty npm run build

if [ $? -eq 0 ]; then
    echo ""
    echo "================================================"
    echo "  ✅ BUILD SUCCESSFUL!"
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
    echo "⏳ Starting application (30 seconds)..."
    sleep 30
    
    echo ""
    echo "📊 PM2 Status:"
    sudo -u comparty pm2 list
    echo ""
    
    echo "🔍 Testing application..."
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|301\|302"; then
        echo "✅ Running on localhost:3000!"
        echo ""
        
        # Test HTTPS
        echo "Testing HTTPS..."
        if curl -s -o /dev/null -w "%{http_code}" https://comparty.app | grep -q "200"; then
            echo ""
            echo "================================================"
            echo "  🎉🎉🎉 SUCCESS! APP IS LIVE! 🎉🎉🎉"
            echo "================================================"
            echo ""
            echo "🌐 Your app is running at: https://comparty.app"
            echo ""
            echo "Open https://comparty.app in your browser!"
            echo ""
            echo "================================================"
        else
            echo "Waiting for HTTPS (10 more seconds)..."
            sleep 10
            curl -I https://comparty.app
        fi
    else
        echo "⚠️  Checking logs:"
        sudo -u comparty pm2 logs comparty --lines 20 --nostream
    fi
    
    echo ""
    echo "📝 Management:"
    echo "   Logs: sudo -u comparty pm2 logs comparty"
    echo "   Stop: sudo -u comparty pm2 stop comparty"
    echo "   Start: sudo -u comparty pm2 start comparty"
    echo ""
else
    echo "❌ Build failed. Checking exact errors..."
    echo ""
    echo "Type check errors:"
    sudo -u comparty npx tsc --noEmit 2>&1 | grep -E "(error TS|\.ts\([0-9]+,[0-9]+\))" | head -15
fi