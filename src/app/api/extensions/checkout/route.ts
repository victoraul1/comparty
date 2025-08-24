import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { withAuth } from '@/middleware/auth';
import { prisma } from '@/lib/prisma';
import { PayPalService } from '@/services/paypal';
import { addMonths } from 'date-fns';

const extensionSchema = z.object({
  eventId: z.string()
});

export async function POST(request: NextRequest) {
  return withAuth(request, async (req, user) => {
    try {
      const body = await request.json();
      const { eventId } = extensionSchema.parse(body);

      // Verificar que el evento pertenece al usuario
      const event = await prisma.event.findFirst({
        where: {
          id: eventId,
          userId: user.id
        },
        include: {
          payments: {
            where: { status: 'COMPLETED' },
            orderBy: { createdAt: 'desc' },
            take: 1
          }
        }
      });

      if (!event) {
        return NextResponse.json(
          { success: false, error: 'Evento no encontrado' },
          { status: 404 }
        );
      }

      // Verificar que el evento no sea plan gratuito
      if (event.planTier === 'FREE') {
        return NextResponse.json(
          { success: false, error: 'El plan gratuito no permite extensiones' },
          { status: 400 }
        );
      }

      // Verificar si ya hay una suscripción activa
      const activeExtension = await prisma.extension.findFirst({
        where: {
          eventId,
          status: 'COMPLETED',
          endsAt: { gt: new Date() }
        }
      });

      if (activeExtension) {
        return NextResponse.json(
          { success: false, error: 'Ya tienes una extensión activa' },
          { status: 400 }
        );
      }

      // Configurar producto de suscripción si no existe
      await PayPalService.setupSubscriptionProduct();

      // Crear suscripción de PayPal
      const subscription = await PayPalService.createSubscription(eventId);

      if (!subscription.approvalUrl) {
        throw new Error('No se pudo obtener la URL de aprobación de PayPal');
      }

      return NextResponse.json({
        success: true,
        data: {
          subscriptionId: subscription.subscriptionId,
          approvalUrl: subscription.approvalUrl,
          message: 'Redirigiendo a PayPal para configurar la suscripción...'
        }
      });
    } catch (error) {
      if (error instanceof z.ZodError) {
        return NextResponse.json(
          { success: false, error: 'Datos inválidos', details: error.errors },
          { status: 400 }
        );
      }

      console.error('Error creando extensión:', error);
      return NextResponse.json(
        { success: false, error: 'Error al procesar la extensión' },
        { status: 500 }
      );
    }
  });
}

// GET para verificar estado de extensión
export async function GET(request: NextRequest) {
  return withAuth(request, async (req, user) => {
    try {
      const { searchParams } = new URL(request.url);
      const eventId = searchParams.get('eventId');

      if (!eventId) {
        return NextResponse.json(
          { success: false, error: 'Event ID no proporcionado' },
          { status: 400 }
        );
      }

      // Verificar que el evento pertenece al usuario
      const event = await prisma.event.findFirst({
        where: {
          id: eventId,
          userId: user.id
        }
      });

      if (!event) {
        return NextResponse.json(
          { success: false, error: 'Evento no encontrado' },
          { status: 404 }
        );
      }

      // Buscar extensiones activas
      const extensions = await prisma.extension.findMany({
        where: { eventId },
        orderBy: { createdAt: 'desc' }
      });

      const activeExtension = extensions.find(
        ext => ext.status === 'COMPLETED' && ext.endsAt > new Date()
      );

      return NextResponse.json({
        success: true,
        data: {
          hasActiveExtension: !!activeExtension,
          activeExtension,
          extensions,
          albumExpiresAt: event.albumExpiresAt,
          canExtend: event.planTier !== 'FREE'
        }
      });
    } catch (error) {
      console.error('Error verificando extensión:', error);
      return NextResponse.json(
        { success: false, error: 'Error al verificar extensión' },
        { status: 500 }
      );
    }
  });
}