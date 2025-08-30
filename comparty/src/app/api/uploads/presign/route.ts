import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { withInvitationToken } from '@/middleware/auth';
import { StorageService } from '@/services/storage';
import { prisma } from '@/lib/prisma';

const presignSchema = z.object({
  filename: z.string(),
  contentType: z.string().regex(/^image\/(jpeg|jpg|png|webp|heic|heif)$/i),
  fileSize: z.number().max(20 * 1024 * 1024) // 20MB máximo
});

export async function POST(request: NextRequest) {
  return withInvitationToken(request, async (req, invitation) => {
    try {
      const body = await request.json();
      const { filename, contentType, fileSize } = presignSchema.parse(body);

      // Verificar que el evento esté activo y en ventana de subida
      const event = invitation.event;
      if (event.status !== 'ACTIVE') {
        return NextResponse.json(
          { success: false, error: 'Event is not active' },
          { status: 400 }
        );
      }

      if (new Date() > event.uploadWindowEnd) {
        return NextResponse.json(
          { success: false, error: 'Upload window has expired' },
          { status: 400 }
        );
      }

      // Verificar límite de fotos por invitado (opcional)
      const uploadCount = await prisma.upload.count({
        where: {
          eventId: event.id,
          uploaderId: invitation.uploaderId
        }
      });

      const MAX_PHOTOS_PER_GUEST = 100; // Configurable
      if (uploadCount >= MAX_PHOTOS_PER_GUEST) {
        return NextResponse.json(
          { success: false, error: `Limit of ${MAX_PHOTOS_PER_GUEST} photos reached` },
          { status: 400 }
        );
      }

      // Generar key única para el archivo
      const key = StorageService.generateKey(
        event.id,
        invitation.uploaderId,
        filename,
        'raw'
      );

      // Obtener URL pre-firmada para subida
      const { uploadUrl, bucket } = await StorageService.getPresignedUploadUrl(
        key,
        contentType,
        fileSize
      );

      // Crear registro de upload en la base de datos
      const upload = await prisma.upload.create({
        data: {
          eventId: event.id,
          uploaderId: invitation.uploaderId,
          invitationId: invitation.id,
          objectKeyRaw: key,
          fileSize,
          mimeType: contentType,
          originalName: filename
        }
      });

      // Marcar invitación como aceptada si es la primera vez
      if (!invitation.acceptedAt) {
        await prisma.invitation.update({
          where: { id: invitation.id },
          data: { acceptedAt: new Date() }
        });
      }

      return NextResponse.json({
        success: true,
        data: {
          uploadId: upload.id,
          uploadUrl,
          key,
          bucket,
          maxSize: fileSize
        }
      });
    } catch (error) {
      if (error instanceof z.ZodError) {
        return NextResponse.json(
          { success: false, error: 'Invalid data', details: error.errors },
          { status: 400 }
        );
      }

      console.error('Error generando URL pre-firmada:', error);
      return NextResponse.json(
        { success: false, error: 'Error preparing upload' },
        { status: 500 }
      );
    }
  });
}