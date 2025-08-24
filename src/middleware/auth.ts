import { NextRequest, NextResponse } from 'next/server';
import { AuthService } from '@/services/auth';
import { prisma } from '@/lib/prisma';

export async function withAuth(
  request: NextRequest,
  handler: (request: NextRequest, user: any) => Promise<NextResponse>
) {
  try {
    const token = request.headers.get('authorization')?.replace('Bearer ', '');
    
    if (!token) {
      return NextResponse.json(
        { success: false, error: 'Token no proporcionado' },
        { status: 401 }
      );
    }

    const payload = AuthService.verifyToken(token);
    const user = await prisma.user.findUnique({
      where: { id: payload.userId }
    });

    if (!user) {
      return NextResponse.json(
        { success: false, error: 'Usuario no encontrado' },
        { status: 401 }
      );
    }

    return handler(request, user);
  } catch (error) {
    return NextResponse.json(
      { success: false, error: 'Token inválido' },
      { status: 401 }
    );
  }
}

export async function withInvitationToken(
  request: NextRequest,
  handler: (request: NextRequest, invitation: any) => Promise<NextResponse>
) {
  try {
    const token = request.headers.get('x-invitation-token');
    
    if (!token) {
      return NextResponse.json(
        { success: false, error: 'Token de invitación no proporcionado' },
        { status: 401 }
      );
    }

    const hashedToken = await AuthService.hashToken(token);
    const invitation = await prisma.invitation.findUnique({
      where: { tokenHash: hashedToken },
      include: { event: true }
    });

    if (!invitation) {
      return NextResponse.json(
        { success: false, error: 'Invitación no válida' },
        { status: 401 }
      );
    }

    if (invitation.tokenExpiry < new Date()) {
      return NextResponse.json(
        { success: false, error: 'Invitación expirada' },
        { status: 401 }
      );
    }

    return handler(request, invitation);
  } catch (error) {
    return NextResponse.json(
      { success: false, error: 'Error al validar invitación' },
      { status: 500 }
    );
  }
}