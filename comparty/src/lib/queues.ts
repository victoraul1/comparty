import Bull from 'bull';
import { PhotoProcessorService } from '@/services/photo-processor';

const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';

// Cola para procesamiento de fotos
export const photoProcessingQueue = new Bull('photo-processing', REDIS_URL, {
  defaultJobOptions: {
    removeOnComplete: 100,
    removeOnFail: 50,
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 2000
    }
  }
});

// Cola para envío de emails
export const emailQueue = new Bull('email-sending', REDIS_URL, {
  defaultJobOptions: {
    removeOnComplete: 50,
    removeOnFail: 10,
    attempts: 5,
    backoff: {
      type: 'exponential',
      delay: 5000
    }
  }
});

// Procesador de fotos
photoProcessingQueue.process('process-upload', async (job) => {
  const { uploadId, imageBuffer } = job.data;
  console.log(`[Queue] Procesando upload ${uploadId}`);
  
  const result = await PhotoProcessorService.processUpload(uploadId, Buffer.from(imageBuffer));
  
  if (!result.success) {
    throw new Error(result.error || 'Error en procesamiento');
  }
  
  return result;
});

// Procesador de lotes de eventos
photoProcessingQueue.process('process-event-batch', async (job) => {
  const { eventId } = job.data;
  console.log(`[Queue] Procesando lote del evento ${eventId}`);
  
  await PhotoProcessorService.processEventBatch(eventId);
  
  return { success: true, eventId };
});

// Procesador de versiones públicas
photoProcessingQueue.process('generate-public-version', async (job) => {
  const { uploadId, uploaderName } = job.data;
  console.log(`[Queue] Generando versión pública para ${uploadId}`);
  
  const publicKey = await PhotoProcessorService.generatePublicVersion(uploadId, uploaderName);
  
  return { success: true, publicKey };
});

// Eventos de la cola
photoProcessingQueue.on('completed', (job, result) => {
  console.log(`[Queue] Job ${job.id} completado:`, result);
});

photoProcessingQueue.on('failed', (job, err) => {
  console.error(`[Queue] Job ${job.id} falló:`, err);
});

photoProcessingQueue.on('stalled', (job) => {
  console.warn(`[Queue] Job ${job.id} estancado`);
});

// Funciones helper para agregar trabajos
export async function queuePhotoProcessing(uploadId: string, imageBuffer: Buffer) {
  return photoProcessingQueue.add('process-upload', {
    uploadId,
    imageBuffer: imageBuffer.toString('base64')
  }, {
    priority: 1,
    delay: 100
  });
}

export async function queueEventBatchProcessing(eventId: string) {
  return photoProcessingQueue.add('process-event-batch', {
    eventId
  }, {
    priority: 2,
    delay: 5000
  });
}

export async function queuePublicVersionGeneration(uploadId: string, uploaderName: string) {
  return photoProcessingQueue.add('generate-public-version', {
    uploadId,
    uploaderName
  }, {
    priority: 3
  });
}

export async function queueEmail(template: string, data: any) {
  return emailQueue.add(template, data, {
    priority: template === 'invitation' ? 1 : 2
  });
}

// Estadísticas de las colas
export async function getQueueStats() {
  const [photoStats, emailStats] = await Promise.all([
    photoProcessingQueue.getJobCounts(),
    emailQueue.getJobCounts()
  ]);

  return {
    photoProcessing: photoStats,
    email: emailStats
  };
}