import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { withAuth } from '@/middleware/auth';
import { prisma } from '@/lib/prisma';
import { PayPalService } from '@/services/paypal';

const checkoutSchema = z.object({
  eventId: z.string(),
  planCode: z.enum(['FREE', 'P50', 'P100', 'P200'])
});

export async function POST(request: NextRequest) {
  return withAuth(request, async (req, user) => {
    try {
      const body = await request.json();
      const { eventId, planCode } = checkoutSchema.parse(body);

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

      // Verificar que el evento está pendiente de pago
      if (event.status !== 'PENDING_PAYMENT') {
        return NextResponse.json(
          { success: false, error: 'El evento ya está activo o cancelado' },
          { status: 400 }
        );
      }

      // Obtener el plan
      const plan = await prisma.plan.findUnique({
        where: { code: planCode }
      });

      if (!plan) {
        return NextResponse.json(
          { success: false, error: 'Plan no válido' },
          { status: 400 }
        );
      }

      // Si es plan gratuito, activar directamente
      if (planCode === 'FREE') {
        await prisma.event.update({
          where: { id: eventId },
          data: { status: 'ACTIVE' }
        });

        await prisma.payment.create({
          data: {
            eventId,
            planCode: 'FREE',
            provider: 'system',
            type: 'ONE_TIME',
            providerRef: `free-${eventId}-${Date.now()}`,
            status: 'COMPLETED',
            amount: 0
          }
        });

        return NextResponse.json({
          success: true,
          data: {
            message: 'Plan gratuito activado exitosamente',
            redirectUrl: `/events/${eventId}/invitations`
          }
        });
      }

      // Crear orden de PayPal para planes de pago
      const order = await PayPalService.createOrder(event, plan);

      if (!order.approvalUrl) {
        throw new Error('No se pudo obtener la URL de aprobación de PayPal');
      }

      return NextResponse.json({
        success: true,
        data: {
          orderId: order.orderId,
          approvalUrl: order.approvalUrl,
          message: 'Redirigiendo a PayPal para completar el pago...'
        }
      });
    } catch (error) {
      if (error instanceof z.ZodError) {
        return NextResponse.json(
          { success: false, error: 'Datos inválidos', details: error.errors },
          { status: 400 }
        );
      }

      console.error('Error en checkout:', error);
      return NextResponse.json(
        { success: false, error: 'Error al procesar el pago' },
        { status: 500 }
      );
    }
  });
}

// GET para obtener la configuración de PayPal para el cliente
export async function GET(request: NextRequest) {
  try {
    const config = PayPalService.getClientConfig();
    
    return NextResponse.json({
      success: true,
      data: config
    });
  } catch (error) {
    console.error('Error obteniendo configuración de PayPal:', error);
    return NextResponse.json(
      { success: false, error: 'Error al obtener configuración' },
      { status: 500 }
    );
  }
}