import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { withInvitationToken } from '@/middleware/auth';
import { prisma } from '@/lib/prisma';
import { StorageService } from '@/services/storage';
import { queuePhotoProcessing } from '@/lib/queues';

const processSchema = z.object({
  uploadId: z.string(),
  key: z.string()
});

export async function POST(request: NextRequest) {
  return withInvitationToken(request, async (req, invitation) => {
    try {
      const body = await request.json();
      const { uploadId, key } = processSchema.parse(body);

      // Verificar que el upload pertenece al invitado
      const upload = await prisma.upload.findFirst({
        where: {
          id: uploadId,
          uploaderId: invitation.uploaderId,
          eventId: invitation.eventId
        }
      });

      if (!upload) {
        return NextResponse.json(
          { success: false, error: 'Upload not found' },
          { status: 404 }
        );
      }

      // Descargar la imagen desde S3 para procesamiento
      const downloadUrl = await StorageService.getPresignedDownloadUrl(key);
      const response = await fetch(downloadUrl);
      
      if (!response.ok) {
        throw new Error('No se pudo descargar la imagen');
      }

      const imageBuffer = Buffer.from(await response.arrayBuffer());

      // Obtener metadatos básicos de la imagen
      const sharp = (await import('sharp')).default;
      const metadata = await sharp(imageBuffer).metadata();

      // Actualizar dimensiones en la base de datos
      await prisma.upload.update({
        where: { id: uploadId },
        data: {
          width: metadata.width,
          height: metadata.height
        }
      });

      // Encolar procesamiento asíncrono con IA
      await queuePhotoProcessing(uploadId, imageBuffer);

      return NextResponse.json({
        success: true,
        data: {
          uploadId,
          status: 'processing',
          message: 'Foto subida exitosamente. Procesando con IA...',
          dimensions: {
            width: metadata.width,
            height: metadata.height
          }
        }
      });
    } catch (error) {
      if (error instanceof z.ZodError) {
        return NextResponse.json(
          { success: false, error: 'Invalid data', details: error.errors },
          { status: 400 }
        );
      }

      console.error('Error procesando upload:', error);
      return NextResponse.json(
        { success: false, error: 'Error processing image' },
        { status: 500 }
      );
    }
  });
}