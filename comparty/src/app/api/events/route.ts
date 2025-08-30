import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { withAuth } from '@/middleware/auth';
import { prisma } from '@/lib/prisma';
import { generateSlug } from '@/lib/utils';
import { EventType, PlanTier, EventStatus } from '@prisma/client';
import { addDays, addMonths } from 'date-fns';

const createEventSchema = z.object({
  name: z.string().min(3).max(100),
  type: z.nativeEnum(EventType),
  date: z.string().datetime(),
  planTier: z.nativeEnum(PlanTier),
  coverImageUrl: z.string().url().optional()
});

// GET /api/events - Listar eventos del usuario
export async function GET(request: NextRequest) {
  return withAuth(request, async (req, user) => {
    try {
      const events = await prisma.event.findMany({
        where: { userId: user.id },
        include: {
          invitations: {
            select: {
              id: true,
              email: true,
              acceptedAt: true
            }
          },
          uploads: {
            select: {
              id: true
            }
          },
          payments: {
            where: {
              status: 'COMPLETED'
            },
            select: {
              id: true,
              amount: true,
              createdAt: true
            }
          }
        },
        orderBy: { createdAt: 'desc' }
      });

      return NextResponse.json({
        success: true,
        data: events.map(event => ({
          ...event,
          invitationsCount: event.invitations.length,
          acceptedInvitations: event.invitations.filter(i => i.acceptedAt).length,
          uploadsCount: event.uploads.length
        }))
      });
    } catch (error) {
      console.error('Error al obtener eventos:', error);
      return NextResponse.json(
        { success: false, error: 'Error fetching events' },
        { status: 500 }
      );
    }
  });
}

// POST /api/events - Crear nuevo evento
export async function POST(request: NextRequest) {
  return withAuth(request, async (req, user) => {
    try {
      const body = await request.json();
      const data = createEventSchema.parse(body);

      // Obtener configuración del plan
      const plan = await prisma.plan.findUnique({
        where: { code: data.planTier }
      });

      if (!plan) {
        return NextResponse.json(
          { success: false, error: 'Invalid plan' },
          { status: 400 }
        );
      }

      // Generar slug único
      let publicSlug = generateSlug(data.name);
      let slugExists = true;
      let counter = 0;
      
      while (slugExists) {
        const existingEvent = await prisma.event.findUnique({
          where: { publicSlug: counter === 0 ? publicSlug : `${publicSlug}-${counter}` }
        });
        if (!existingEvent) {
          slugExists = false;
          if (counter > 0) {
            publicSlug = `${publicSlug}-${counter}`;
          }
        }
        counter++;
      }

      // Calcular fechas según el plan
      const now = new Date();
      const uploadWindowEnd = addDays(now, plan.uploadWindowDays);
      const albumExpiresAt = addMonths(now, plan.albumMonths);

      // Crear evento
      const event = await prisma.event.create({
        data: {
          userId: user.id,
          name: data.name,
          type: data.type,
          date: new Date(data.date),
          planTier: data.planTier,
          coverImageUrl: data.coverImageUrl,
          publicSlug,
          status: data.planTier === 'FREE' ? 'ACTIVE' : 'PENDING_PAYMENT',
          maxInvites: plan.maxInvites,
          albumMonths: plan.albumMonths,
          uploadWindowDays: plan.uploadWindowDays,
          uploadWindowEnd,
          albumExpiresAt
        }
      });

      // Si es plan gratuito, activar inmediatamente
      if (data.planTier === 'FREE') {
        await prisma.payment.create({
          data: {
            eventId: event.id,
            planCode: 'FREE',
            provider: 'system',
            type: 'ONE_TIME',
            providerRef: `free-${event.id}`,
            status: 'COMPLETED',
            amount: 0
          }
        });
      }

      return NextResponse.json({
        success: true,
        data: event,
        message: data.planTier === 'FREE' 
          ? 'Evento creado exitosamente' 
          : 'Evento creado. Procede con el pago para activarlo.'
      });
    } catch (error) {
      if (error instanceof z.ZodError) {
        return NextResponse.json(
          { success: false, error: 'Invalid data', details: error.errors },
          { status: 400 }
        );
      }

      console.error('Error al crear evento:', error);
      return NextResponse.json(
        { success: false, error: 'Error creating event' },
        { status: 500 }
      );
    }
  });
}