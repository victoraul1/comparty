import { prisma } from '@/lib/prisma';
import { ImageProcessorService } from './image-processor';
import { AIAnalyzerService } from './ai-analyzer';
import { StorageService } from './storage';
import { Upload, Event, PhotoScore } from '@prisma/client';
import sharp from 'sharp';

export interface ProcessingResult {
  success: boolean;
  uploadId: string;
  scores?: PhotoScore;
  error?: string;
}

export class PhotoProcessorService {
  static async processUpload(
    uploadId: string,
    imageBuffer: Buffer
  ): Promise<ProcessingResult> {
    try {
      // Obtener información del upload y evento
      const upload = await prisma.upload.findUnique({
        where: { id: uploadId },
        include: {
          event: true,
          invitation: true
        }
      });

      if (!upload) {
        throw new Error('Upload no encontrado');
      }

      // 1. Generar thumbnail
      console.log(`[${uploadId}] Generando thumbnail...`);
      const thumbnail = await ImageProcessorService.generateThumbnail(imageBuffer, 1024);
      const thumbnailKey = StorageService.generateKey(
        upload.eventId,
        upload.uploaderId,
        upload.originalName,
        'thumb'
      );
      await StorageService.uploadFile(thumbnailKey, thumbnail, 'image/jpeg');

      // 2. Análisis básico de calidad
      console.log(`[${uploadId}] Analizando calidad básica...`);
      const basicAnalysis = await ImageProcessorService.analyzeImage(imageBuffer);

      // 3. Calcular hash para detección de duplicados
      const imageHash = await ImageProcessorService.calculateHash(imageBuffer);
      
      // Buscar duplicados
      const existingPhotos = await prisma.upload.findMany({
        where: {
          eventId: upload.eventId,
          id: { not: uploadId }
        },
        include: {
          photoScore: true
        }
      });

      let isDuplicate = false;
      let duplicateOfId: string | null = null;

      for (const existing of existingPhotos) {
        if (existing.photoScore?.metadata) {
          const existingMeta = existing.photoScore.metadata as any;
          if (existingMeta.imageHash) {
            const similarity = ImageProcessorService.calculateSimilarity(
              imageHash,
              existingMeta.imageHash
            );
            if (similarity > 0.95) { // 95% similar = duplicado
              isDuplicate = true;
              duplicateOfId = existing.id;
              break;
            }
          }
        }
      }

      // 4. Análisis con IA (si está habilitado y el plan lo permite)
      let aiAnalysis = null;
      const shouldUseAI = process.env.AI_SCORING_ENABLED === 'true' && 
                         !isDuplicate &&
                         ['P100', 'P200'].includes(upload.event.planTier);

      if (shouldUseAI) {
        console.log(`[${uploadId}] Analizando con IA...`);
        const thumbnailBase64 = thumbnail.toString('base64');
        aiAnalysis = await AIAnalyzerService.analyzePhoto(
          thumbnailBase64,
          upload.event.type,
          upload.event.name
        );
      }

      // 5. Calcular score final
      const finalQualityScore = aiAnalysis
        ? AIAnalyzerService.calculateEnhancedQualityScore(basicAnalysis, aiAnalysis)
        : basicAnalysis.qualityScore;

      // 6. Guardar resultados en la base de datos
      const photoScore = await prisma.photoScore.upsert({
        where: { uploadId },
        create: {
          uploadId,
          blurScore: basicAnalysis.blurScore,
          exposureScore: basicAnalysis.exposureScore,
          facesDetected: basicAnalysis.facesDetected,
          eyesOpenScore: basicAnalysis.eyesOpenScore,
          noiseScore: basicAnalysis.noiseScore,
          aiAestheticScore: aiAnalysis?.aestheticScore ? aiAnalysis.aestheticScore / 10 : null,
          aiContextScore: aiAnalysis?.contextScore ? aiAnalysis.contextScore / 10 : null,
          qualityScore: finalQualityScore,
          metadata: {
            imageHash,
            aiAnalysis: aiAnalysis || undefined,
            processedAt: new Date().toISOString()
          }
        },
        update: {
          blurScore: basicAnalysis.blurScore,
          exposureScore: basicAnalysis.exposureScore,
          facesDetected: basicAnalysis.facesDetected,
          eyesOpenScore: basicAnalysis.eyesOpenScore,
          noiseScore: basicAnalysis.noiseScore,
          aiAestheticScore: aiAnalysis?.aestheticScore ? aiAnalysis.aestheticScore / 10 : null,
          aiContextScore: aiAnalysis?.contextScore ? aiAnalysis.contextScore / 10 : null,
          qualityScore: finalQualityScore,
          metadata: {
            imageHash,
            aiAnalysis: aiAnalysis || undefined,
            processedAt: new Date().toISOString()
          }
        }
      });

      // 7. Actualizar el upload con la información del thumbnail y duplicados
      await prisma.upload.update({
        where: { id: uploadId },
        data: {
          objectKeyThumb: thumbnailKey,
          isDuplicate,
          duplicateOfId
        }
      });

      // 8. Actualizar selección automática (Top 5)
      await this.updateAutoSelection(upload.eventId, upload.uploaderId);

      console.log(`[${uploadId}] Procesamiento completado. Score: ${finalQualityScore.toFixed(3)}`);

      return {
        success: true,
        uploadId,
        scores: photoScore
      };
    } catch (error) {
      console.error(`Error procesando upload ${uploadId}:`, error);
      return {
        success: false,
        uploadId,
        error: error instanceof Error ? error.message : 'Error desconocido'
      };
    }
  }

  static async updateAutoSelection(eventId: string, uploaderId: string): Promise<void> {
    // Obtener las mejores 5 fotos no duplicadas del uploader
    const topPhotos = await prisma.upload.findMany({
      where: {
        eventId,
        uploaderId,
        isDuplicate: false
      },
      include: {
        photoScore: true
      },
      orderBy: [
        { photoScore: { qualityScore: 'desc' } },
        { createdAt: 'asc' }
      ],
      take: 5
    });

    // Eliminar selecciones anteriores que no estén fijadas por el host
    await prisma.selection.deleteMany({
      where: {
        eventId,
        uploaderId,
        isPinnedByHost: false
      }
    });

    // Crear nuevas selecciones
    const selections = topPhotos.map((photo, index) => ({
      eventId,
      uploaderId,
      invitationId: photo.invitationId,
      uploadId: photo.id,
      rank: index + 1,
      isPinnedByHost: false
    }));

    if (selections.length > 0) {
      await prisma.selection.createMany({
        data: selections,
        skipDuplicates: true
      });
    }

    console.log(`Actualizada selección automática para uploader ${uploaderId}: ${selections.length} fotos`);
  }

  static async generatePublicVersion(
    uploadId: string,
    uploaderName: string
  ): Promise<string> {
    const upload = await prisma.upload.findUnique({
      where: { id: uploadId }
    });

    if (!upload) {
      throw new Error('Upload no encontrado');
    }

    // Descargar imagen original
    const originalUrl = await StorageService.getPresignedDownloadUrl(upload.objectKeyRaw);
    const response = await fetch(originalUrl);
    const imageBuffer = Buffer.from(await response.arrayBuffer());

    // Remover EXIF
    const cleanImage = await ImageProcessorService.removeExif(imageBuffer);

    // Agregar marca de agua
    const watermarkedImage = await ImageProcessorService.addWatermark(
      cleanImage,
      uploaderName,
      'bottom-right'
    );

    // Optimizar para web
    const optimized = await sharp(watermarkedImage)
      .jpeg({ quality: 85, progressive: true })
      .toBuffer();

    // Subir versión pública
    const publicKey = StorageService.generateKey(
      upload.eventId,
      upload.uploaderId,
      upload.originalName,
      'public'
    );

    await StorageService.uploadFile(publicKey, optimized, 'image/jpeg');

    // Actualizar registro
    await prisma.upload.update({
      where: { id: uploadId },
      data: {
        objectKeyPublic: publicKey,
        isPublic: true
      }
    });

    return publicKey;
  }

  static async processEventBatch(eventId: string): Promise<void> {
    // Procesar todas las fotos pendientes de un evento
    const pendingUploads = await prisma.upload.findMany({
      where: {
        eventId,
        photoScore: null
      }
    });

    console.log(`Procesando lote de ${pendingUploads.length} fotos para evento ${eventId}`);

    for (const upload of pendingUploads) {
      try {
        // Descargar imagen
        const url = await StorageService.getPresignedDownloadUrl(upload.objectKeyRaw);
        const response = await fetch(url);
        const buffer = Buffer.from(await response.arrayBuffer());

        await this.processUpload(upload.id, buffer);
      } catch (error) {
        console.error(`Error procesando ${upload.id}:`, error);
      }
    }

    // Generar resumen del evento con IA
    if (process.env.AI_SCORING_ENABLED === 'true') {
      await this.generateEventInsights(eventId);
    }
  }

  static async generateEventInsights(eventId: string): Promise<void> {
    const event = await prisma.event.findUnique({
      where: { id: eventId },
      include: {
        uploads: {
          where: { isDuplicate: false },
          include: {
            photoScore: true
          }
        }
      }
    });

    if (!event) return;

    const aiAnalyses = event.uploads
      .map(u => (u.photoScore?.metadata as any)?.aiAnalysis)
      .filter(Boolean);

    if (aiAnalyses.length > 0) {
      const summary = await AIAnalyzerService.generateEventSummary(
        event.name,
        event.type,
        aiAnalyses
      );

      console.log(`Resumen del evento ${event.name}: ${summary}`);
      
      // Aquí podrías guardar el resumen en la base de datos o enviarlo por email
    }
  }
}