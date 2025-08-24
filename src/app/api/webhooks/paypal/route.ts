import { NextRequest, NextResponse } from 'next/server';
import { PayPalService } from '@/services/paypal';
import { prisma } from '@/lib/prisma';

// Webhook para procesar eventos de PayPal
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const headers: Record<string, string> = {};
    
    // Obtener headers de PayPal
    request.headers.forEach((value, key) => {
      headers[key.toLowerCase()] = value;
    });

    // Verificar firma del webhook
    const webhookId = process.env.PAYPAL_WEBHOOK_ID || '';
    const isValid = PayPalService.verifyWebhookSignature(webhookId, body, headers);

    if (!isValid && process.env.NODE_ENV === 'production') {
      console.error('Firma de webhook inválida');
      return NextResponse.json(
        { success: false, error: 'Firma inválida' },
        { status: 401 }
      );
    }

    // Log del evento
    await prisma.auditLog.create({
      data: {
        action: `paypal_webhook_${body.event_type}`,
        entity: 'webhook',
        entityId: body.id,
        metadata: {
          eventType: body.event_type,
          resourceId: body.resource?.id,
          createTime: body.create_time
        }
      }
    });

    // Procesar el evento
    await PayPalService.processWebhookEvent(body.event_type, body.resource);

    // Responder a PayPal que el webhook fue recibido
    return NextResponse.json({ 
      success: true,
      message: 'Webhook procesado exitosamente' 
    });
  } catch (error) {
    console.error('Error procesando webhook de PayPal:', error);
    
    // PayPal reintentará si devolvemos un error
    // Solo devolver error si queremos que reintente
    return NextResponse.json(
      { success: false, error: 'Error procesando webhook' },
      { status: 500 }
    );
  }
}

// GET para verificar el webhook endpoint
export async function GET(request: NextRequest) {
  return NextResponse.json({
    success: true,
    message: 'PayPal webhook endpoint activo',
    environment: process.env.PAYPAL_ENVIRONMENT,
    timestamp: new Date().toISOString()
  });
}