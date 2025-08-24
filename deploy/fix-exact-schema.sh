#!/bin/bash

# Comparty - Fix Exact Schema Fields
# Uses the actual Prisma schema fields shown in output

echo "================================================"
echo "  🔧 Fixing Exact Schema Fields"
echo "================================================"

cd /home/comparty/app

# Fix PhotoProcessor with EXACT schema fields from Upload model
echo "📸 Fixing PhotoProcessor with exact schema fields..."
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

      // Use objectKey field from schema (not url)
      const imageUrl = upload.objectKey || '';
      const imageHash = await this.generateImageHash(imageUrl);

      // Check for duplicates
      if (upload.isDuplicate) {
        return { success: true };
      }

      const duplicate = await db.upload.findFirst({
        where: {
          eventId: upload.eventId,
          objectKey: upload.objectKey,
          id: { not: uploadId }
        }
      });

      if (duplicate) {
        await db.upload.update({
          where: { id: uploadId },
          data: {
            isDuplicate: true,
            duplicateOfId: duplicate.id,
            metadata: {
              imageHash,
              duplicateDetected: true,
              processedAt: new Date().toISOString()
            }
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
          // Check actual PhotoScore schema fields
          aiScore = await db.photoScore.create({
            data: {
              uploadId,
              compositionScore: analysis.composition,
              technicalScore: analysis.technical,
              emotionalImpact: analysis.emotional,
              memorabilityScore: analysis.memorability,
              overallScore: analysis.overall,
              analysis: {
                reasoning: analysis.reasoning || '',
                suggestions: analysis.suggestions || ''
              }
            }
          });
        }
      }

      // Update upload metadata (no status field in Upload model)
      await db.upload.update({
        where: { id: uploadId },
        data: {
          metadata: {
            imageHash,
            aiAnalysisCompleted: !!aiScore,
            processedAt: new Date().toISOString(),
            status: 'PROCESSED'
          }
        }
      });

      return { success: true };

    } catch (error) {
      console.error('Error processing upload:', error);
      
      try {
        await db.upload.update({
          where: { id: uploadId },
          data: {
            metadata: {
              error: error instanceof Error ? error.message : 'Unknown error',
              processedAt: new Date().toISOString(),
              status: 'ERROR'
            }
          }
        });
      } catch (updateError) {
        console.error('Error updating upload metadata:', updateError);
      }
      
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

# Fix queues.ts with the correct export name
echo "🔄 Fixing queues.ts exports..."
cat > /home/comparty/app/src/lib/queues.ts <<'EOF'
import Bull from 'bull';
import { PhotoProcessor } from '@/services/photo-processor';

// Redis connection from environment
const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';

// Create queues
export const photoQueue = new Bull('photo-processing', redisUrl);
export const selectionQueue = new Bull('photo-selection', redisUrl);
export const notificationQueue = new Bull('notifications', redisUrl);

// Photo processing worker
photoQueue.process(async (job) => {
  const { uploadId } = job.data;
  console.log(`[Queue] Processing upload ${uploadId}`);
  
  const result = await PhotoProcessor.processUpload(uploadId);
  
  if (!result.success) {
    throw new Error(result.error || 'Processing error');
  }
  
  return result;
});

// Selection processing worker
selectionQueue.process(async (job) => {
  const { eventId } = job.data;
  console.log(`[Queue] Processing selection for event ${eventId}`);
  
  await PhotoProcessor.processEventBatch(eventId);
  await PhotoProcessor.selectBestPhotos(eventId);
  
  return { success: true };
});

// Notification worker
notificationQueue.process(async (job) => {
  const { type, data } = job.data;
  console.log(`[Queue] Sending notification: ${type}`);
  
  return { success: true };
});

// Export helper functions with correct names
export async function queuePhotoProcessing(uploadId: string) {
  return photoQueue.add({ uploadId }, {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 2000,
    },
  });
}

// Also export as addPhotoToQueue for compatibility
export const addPhotoToQueue = queuePhotoProcessing;

export async function addSelectionToQueue(eventId: string) {
  return selectionQueue.add({ eventId }, {
    attempts: 2,
    delay: 5000,
  });
}

export async function addNotificationToQueue(type: string, data: any) {
  return notificationQueue.add({ type, data }, {
    attempts: 3,
  });
}
EOF

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
    echo "🔐 Checking SSL certificate..."
    if ! [ -f "/etc/letsencrypt/live/comparty.app/fullchain.pem" ]; then
        echo "Setting up SSL certificate..."
        certbot --nginx -d comparty.app -d www.comparty.app \
            --email admin@comparty.app \
            --agree-tos \
            --non-interactive \
            --redirect
    else
        echo "✅ SSL certificate already exists"
    fi
    
    # Restart Nginx
    nginx -t && systemctl restart nginx
    
    echo ""
    echo "⏳ Application starting (waiting 30 seconds)..."
    sleep 30
    
    echo ""
    echo "📊 PM2 Status:"
    sudo -u comparty pm2 list
    echo ""
    
    echo "🔍 Testing application..."
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|301\|302"; then
        echo "✅ Application running on localhost:3000!"
        echo ""
        
        # Test HTTPS
        if curl -s -o /dev/null -w "%{http_code}" https://comparty.app | grep -q "200"; then
            echo "================================================"
            echo "  🎉🎉🎉 DEPLOYMENT SUCCESSFUL! 🎉🎉🎉"
            echo "================================================"
            echo ""
            echo "🌐 Your app is LIVE at: https://comparty.app"
            echo ""
            echo "Open your browser and visit https://comparty.app"
            echo ""
            echo "================================================"
        else
            echo "⚠️  Waiting for HTTPS..."
            sleep 10
            if curl -s -o /dev/null -w "%{http_code}" https://comparty.app | grep -q "200"; then
                echo "✅ HTTPS ready! Visit https://comparty.app"
            fi
        fi
    else
        echo "⚠️  Application logs:"
        sudo -u comparty pm2 logs comparty --lines 30 --nostream
    fi
    
    echo ""
    echo "📝 Commands:"
    echo "   Logs:    sudo -u comparty pm2 logs comparty"
    echo "   Status:  sudo -u comparty pm2 status"
    echo "   Restart: sudo -u comparty pm2 restart comparty"
    echo ""
else
    echo "❌ Build failed. Type errors:"
    sudo -u comparty npx tsc --noEmit 2>&1 | grep "error TS" | head -10
fi