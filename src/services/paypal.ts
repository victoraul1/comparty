import { 
  Client, 
  Environment, 
  OrdersController,
  PaymentsController,
  SubscriptionsController,
  ProductsController,
  PlansController,
  WebhooksController,
  OrderRequest,
  PlanRequest,
  ProductRequest,
  SubscriptionRequest
} from '@paypal/paypal-server-sdk';
import { prisma } from '@/lib/prisma';
import { Plan, Event } from '@prisma/client';
import crypto from 'crypto';

// Configuración del cliente PayPal
const paypalClient = new Client({
  clientCredentials: {
    clientId: process.env.PAYPAL_CLIENT_ID || '',
    clientSecret: process.env.PAYPAL_CLIENT_SECRET || ''
  },
  environment: process.env.PAYPAL_ENVIRONMENT === 'production' 
    ? Environment.Production 
    : Environment.Sandbox,
  logging: {
    logLevel: process.env.NODE_ENV === 'development' ? 'DEBUG' : 'INFO',
    logRequest: process.env.NODE_ENV === 'development',
    logResponse: process.env.NODE_ENV === 'development'
  }
});

const ordersController = new OrdersController(paypalClient);
const subscriptionsController = new SubscriptionsController(paypalClient);
const productsController = new ProductsController(paypalClient);
const plansController = new PlansController(paypalClient);

export class PayPalService {
  // Crear orden de pago único para planes
  static async createOrder(event: Event, plan: Plan) {
    try {
      const orderRequest: OrderRequest = {
        intent: 'CAPTURE',
        purchaseUnits: [
          {
            referenceId: event.id,
            description: `Plan ${plan.name} - Evento: ${event.name}`,
            customId: event.id,
            amount: {
              currencyCode: 'USD',
              value: plan.priceOnce.toFixed(2),
              breakdown: {
                itemTotal: {
                  currencyCode: 'USD',
                  value: plan.priceOnce.toFixed(2)
                }
              }
            },
            items: [
              {
                name: plan.name,
                description: `${plan.maxInvites} invitados, ${plan.albumMonths} meses de álbum`,
                quantity: '1',
                unitAmount: {
                  currencyCode: 'USD',
                  value: plan.priceOnce.toFixed(2)
                },
                category: 'DIGITAL_GOODS'
              }
            ]
          }
        ],
        applicationContext: {
          brandName: 'Comparty',
          landingPage: 'NO_PREFERENCE',
          userAction: 'PAY_NOW',
          returnUrl: `${process.env.APP_URL}/api/payments/capture`,
          cancelUrl: `${process.env.APP_URL}/events/${event.id}/payment-cancelled`,
          shippingPreference: 'NO_SHIPPING'
        }
      };

      const { body } = await ordersController.ordersCreate({
        body: orderRequest,
        prefer: 'return=representation'
      });

      if (!body || !body.id) {
        throw new Error('No se pudo crear la orden de PayPal');
      }

      // Guardar la orden en la base de datos
      await prisma.payment.create({
        data: {
          eventId: event.id,
          planCode: plan.code,
          provider: 'paypal',
          type: 'ONE_TIME',
          providerRef: body.id,
          status: 'PENDING',
          amount: plan.priceOnce,
          metadata: {
            paypalOrderId: body.id,
            createdAt: new Date().toISOString()
          }
        }
      });

      // Encontrar el link de aprobación
      const approvalLink = body.links?.find(link => link.rel === 'approve');
      
      return {
        orderId: body.id,
        approvalUrl: approvalLink?.href,
        status: body.status
      };
    } catch (error) {
      console.error('Error creando orden PayPal:', error);
      throw error;
    }
  }

  // Capturar pago después de la aprobación
  static async captureOrder(orderId: string) {
    try {
      const { body } = await ordersController.ordersCapture({
        id: orderId,
        prefer: 'return=representation'
      });

      if (!body || !body.status) {
        throw new Error('No se pudo capturar el pago');
      }

      // Actualizar el pago en la base de datos
      const payment = await prisma.payment.findUnique({
        where: { providerRef: orderId },
        include: { event: true }
      });

      if (payment) {
        await prisma.payment.update({
          where: { id: payment.id },
          data: {
            status: body.status === 'COMPLETED' ? 'COMPLETED' : 'FAILED',
            metadata: {
              ...payment.metadata as object,
              capturedAt: new Date().toISOString(),
              paypalStatus: body.status,
              payerId: body.payer?.payerId
            }
          }
        });

        // Si el pago fue exitoso, activar el evento
        if (body.status === 'COMPLETED') {
          await prisma.event.update({
            where: { id: payment.eventId },
            data: { status: 'ACTIVE' }
          });
        }
      }

      return {
        success: body.status === 'COMPLETED',
        orderId: body.id,
        status: body.status,
        payerId: body.payer?.payerId
      };
    } catch (error) {
      console.error('Error capturando pago PayPal:', error);
      throw error;
    }
  }

  // Crear producto y plan de suscripción para extensiones
  static async setupSubscriptionProduct() {
    try {
      // Crear producto para extensión de álbum
      const productRequest: ProductRequest = {
        id: 'ALBUM_EXTENSION',
        name: 'Extensión de Álbum Comparty',
        description: 'Extensión mensual para mantener tu álbum activo',
        type: 'SERVICE',
        category: 'SOFTWARE',
        imageUrl: `${process.env.APP_URL}/images/extension-icon.png`,
        homeUrl: process.env.APP_URL
      };

      const { body: product } = await productsController.productsCreate({
        body: productRequest,
        prefer: 'return=representation'
      });

      console.log('Producto creado:', product?.id);

      // Crear plan de suscripción mensual
      const planRequest: PlanRequest = {
        productId: 'ALBUM_EXTENSION',
        name: 'Extensión Mensual de Álbum',
        description: 'Mantén tu álbum activo por un mes adicional',
        status: 'ACTIVE',
        billingCycles: [
          {
            frequency: {
              intervalUnit: 'MONTH',
              intervalCount: 1
            },
            tenureType: 'REGULAR',
            sequence: 1,
            totalCycles: 0, // Sin límite de ciclos
            pricingScheme: {
              fixedPrice: {
                value: '10',
                currencyCode: 'USD'
              }
            }
          }
        ],
        paymentPreferences: {
          autoBillOutstanding: true,
          setupFee: {
            value: '0',
            currencyCode: 'USD'
          },
          setupFeeFailureAction: 'CONTINUE',
          paymentFailureThreshold: 3
        },
        taxes: {
          percentage: '0',
          inclusive: false
        }
      };

      const { body: plan } = await plansController.plansCreate({
        body: planRequest,
        prefer: 'return=representation'
      });

      console.log('Plan de suscripción creado:', plan?.id);
      
      return {
        productId: product?.id,
        planId: plan?.id
      };
    } catch (error: any) {
      // Si el producto ya existe, no es un error
      if (error?.statusCode === 409) {
        console.log('Producto/Plan ya existe');
        return {
          productId: 'ALBUM_EXTENSION',
          planId: 'ALBUM_EXTENSION_MONTHLY'
        };
      }
      console.error('Error configurando producto de suscripción:', error);
      throw error;
    }
  }

  // Crear suscripción para extensión
  static async createSubscription(eventId: string) {
    try {
      const event = await prisma.event.findUnique({
        where: { id: eventId },
        include: { user: true }
      });

      if (!event) {
        throw new Error('Evento no encontrado');
      }

      const subscriptionRequest: SubscriptionRequest = {
        planId: 'ALBUM_EXTENSION_MONTHLY',
        quantity: '1',
        subscriber: {
          name: {
            givenName: event.user.name || 'Usuario',
            surname: 'Comparty'
          },
          emailAddress: event.user.email
        },
        applicationContext: {
          brandName: 'Comparty',
          locale: 'es-ES',
          shippingPreference: 'NO_SHIPPING',
          userAction: 'SUBSCRIBE_NOW',
          paymentMethod: {
            payerSelected: 'PAYPAL',
            payeePreferred: 'IMMEDIATE_PAYMENT_REQUIRED'
          },
          returnUrl: `${process.env.APP_URL}/api/subscriptions/confirm`,
          cancelUrl: `${process.env.APP_URL}/events/${eventId}/subscription-cancelled`
        },
        customId: eventId
      };

      const { body } = await subscriptionsController.subscriptionsCreate({
        body: subscriptionRequest,
        prefer: 'return=representation'
      });

      if (!body || !body.id) {
        throw new Error('No se pudo crear la suscripción');
      }

      // Guardar la extensión en la base de datos
      await prisma.extension.create({
        data: {
          eventId,
          months: 1,
          amount: 10,
          providerRef: body.id,
          status: 'PENDING',
          startsAt: new Date(),
          endsAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 días
        }
      });

      // Encontrar el link de aprobación
      const approvalLink = body.links?.find(link => link.rel === 'approve');

      return {
        subscriptionId: body.id,
        approvalUrl: approvalLink?.href,
        status: body.status
      };
    } catch (error) {
      console.error('Error creando suscripción:', error);
      throw error;
    }
  }

  // Verificar firma de webhook
  static verifyWebhookSignature(
    webhookId: string,
    eventBody: any,
    headers: Record<string, string>
  ): boolean {
    try {
      const transmissionId = headers['paypal-transmission-id'];
      const transmissionTime = headers['paypal-transmission-time'];
      const certUrl = headers['paypal-cert-url'];
      const authAlgo = headers['paypal-auth-algo'];
      const actualSignature = headers['paypal-transmission-sig'];

      // Construir el mensaje para verificar
      const message = `${transmissionId}|${transmissionTime}|${webhookId}|${JSON.stringify(eventBody)}`;
      
      // Por ahora, retornamos true en desarrollo
      // En producción, deberías verificar la firma correctamente
      if (process.env.NODE_ENV === 'development') {
        return true;
      }

      // TODO: Implementar verificación real de firma
      console.log('Verificación de webhook:', { transmissionId, certUrl });
      
      return true;
    } catch (error) {
      console.error('Error verificando firma de webhook:', error);
      return false;
    }
  }

  // Procesar evento de webhook
  static async processWebhookEvent(eventType: string, resource: any) {
    console.log(`Procesando webhook: ${eventType}`);

    switch (eventType) {
      case 'CHECKOUT.ORDER.APPROVED':
        // Orden aprobada, proceder a capturar
        await this.captureOrder(resource.id);
        break;

      case 'PAYMENT.CAPTURE.COMPLETED':
        // Pago completado exitosamente
        const payment = await prisma.payment.findUnique({
          where: { providerRef: resource.supplementary_data?.related_ids?.order_id }
        });
        
        if (payment) {
          await prisma.payment.update({
            where: { id: payment.id },
            data: { 
              status: 'COMPLETED',
              metadata: {
                ...payment.metadata as object,
                captureId: resource.id,
                completedAt: new Date().toISOString()
              }
            }
          });

          // Activar el evento
          await prisma.event.update({
            where: { id: payment.eventId },
            data: { status: 'ACTIVE' }
          });
        }
        break;

      case 'BILLING.SUBSCRIPTION.ACTIVATED':
        // Suscripción activada
        const extension = await prisma.extension.findUnique({
          where: { providerRef: resource.id }
        });
        
        if (extension) {
          await prisma.extension.update({
            where: { id: extension.id },
            data: { 
              status: 'COMPLETED',
              startsAt: new Date(resource.start_time),
              endsAt: new Date(resource.billing_info?.next_billing_time)
            }
          });

          // Extender la fecha de expiración del álbum
          await prisma.event.update({
            where: { id: extension.eventId },
            data: {
              albumExpiresAt: new Date(resource.billing_info?.next_billing_time)
            }
          });
        }
        break;

      case 'BILLING.SUBSCRIPTION.CANCELLED':
        // Suscripción cancelada
        const cancelledExt = await prisma.extension.findUnique({
          where: { providerRef: resource.id }
        });
        
        if (cancelledExt) {
          await prisma.extension.update({
            where: { id: cancelledExt.id },
            data: { status: 'CANCELLED' }
          });
        }
        break;

      case 'PAYMENT.CAPTURE.DENIED':
      case 'PAYMENT.CAPTURE.REFUNDED':
        // Pago denegado o reembolsado
        const failedPayment = await prisma.payment.findUnique({
          where: { providerRef: resource.supplementary_data?.related_ids?.order_id }
        });
        
        if (failedPayment) {
          await prisma.payment.update({
            where: { id: failedPayment.id },
            data: { 
              status: eventType === 'PAYMENT.CAPTURE.REFUNDED' ? 'REFUNDED' : 'FAILED'
            }
          });
        }
        break;

      default:
        console.log(`Evento de webhook no manejado: ${eventType}`);
    }
  }

  // Obtener configuración para el cliente
  static getClientConfig() {
    return {
      clientId: process.env.PAYPAL_CLIENT_ID,
      environment: process.env.PAYPAL_ENVIRONMENT === 'production' ? 'production' : 'sandbox',
      currency: 'USD'
    };
  }
}