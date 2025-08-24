import { NextRequest, NextResponse } from 'next/server';
import { PayPalService } from '@/services/paypal';
import { prisma } from '@/lib/prisma';

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const token = searchParams.get('token'); // PayPal order ID
    const payerId = searchParams.get('PayerID');

    if (!token) {
      return NextResponse.json(
        { success: false, error: 'Token de pago no proporcionado' },
        { status: 400 }
      );
    }

    // Capturar el pago
    const result = await PayPalService.captureOrder(token);

    if (!result.success) {
      // Redirigir a página de error
      return NextResponse.redirect(
        new URL(`/payment-failed?reason=capture_failed`, process.env.APP_URL!)
      );
    }

    // Obtener el evento asociado al pago
    const payment = await prisma.payment.findUnique({
      where: { providerRef: token },
      include: { event: true }
    });

    if (!payment) {
      return NextResponse.redirect(
        new URL(`/payment-failed?reason=payment_not_found`, process.env.APP_URL!)
      );
    }

    // Redirigir a página de éxito
    return NextResponse.redirect(
      new URL(`/events/${payment.eventId}/payment-success`, process.env.APP_URL!)
    );
  } catch (error) {
    console.error('Error capturando pago:', error);
    return NextResponse.redirect(
      new URL(`/payment-failed?reason=unexpected_error`, process.env.APP_URL!)
    );
  }
}

// POST para captura manual (útil para SPA)
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { orderId } = body;

    if (!orderId) {
      return NextResponse.json(
        { success: false, error: 'Order ID no proporcionado' },
        { status: 400 }
      );
    }

    const result = await PayPalService.captureOrder(orderId);

    if (!result.success) {
      return NextResponse.json(
        { success: false, error: 'No se pudo capturar el pago' },
        { status: 400 }
      );
    }

    // Obtener información del evento
    const payment = await prisma.payment.findUnique({
      where: { providerRef: orderId },
      include: { 
        event: {
          include: {
            user: true
          }
        }
      }
    });

    return NextResponse.json({
      success: true,
      data: {
        orderId: result.orderId,
        status: result.status,
        payerId: result.payerId,
        eventId: payment?.eventId,
        eventName: payment?.event.name,
        message: 'Pago procesado exitosamente'
      }
    });
  } catch (error) {
    console.error('Error capturando pago:', error);
    return NextResponse.json(
      { success: false, error: 'Error al procesar el pago' },
      { status: 500 }
    );
  }
}