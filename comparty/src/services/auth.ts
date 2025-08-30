import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { prisma } from '@/lib/prisma';
import { User } from '@prisma/client';

const JWT_SECRET = process.env.JWT_SECRET || 'change-this-in-production';

export interface JWTPayload {
  userId: string;
  email: string;
  role: string;
}

export class AuthService {
  static async hashPassword(password: string): Promise<string> {
    return bcrypt.hash(password, 10);
  }

  static async verifyPassword(password: string, hashedPassword: string): Promise<boolean> {
    return bcrypt.compare(password, hashedPassword);
  }

  static generateToken(payload: JWTPayload): string {
    return jwt.sign(payload, JWT_SECRET, { expiresIn: '7d' });
  }

  static verifyToken(token: string): JWTPayload {
    return jwt.verify(token, JWT_SECRET) as JWTPayload;
  }

  static generateInvitationToken(): string {
    return Array.from({ length: 32 }, () => 
      Math.random().toString(36).charAt(2)
    ).join('');
  }

  static async hashToken(token: string): Promise<string> {
    return bcrypt.hash(token, 5);
  }

  static async verifyInvitationToken(token: string, hashedToken: string): Promise<boolean> {
    return bcrypt.compare(token, hashedToken);
  }

  static async createMagicLink(email: string): Promise<{ token: string; expiresAt: Date }> {
    const token = this.generateInvitationToken();
    const expiresAt = new Date(Date.now() + 30 * 60 * 1000); // 30 minutos
    
    // Here you would normally save the token to the database
    // Por ahora solo retornamos el token
    
    return { token, expiresAt };
  }

  static async validateMagicLink(token: string): Promise<User | null> {
    // Here you would validate the token against the database
    // Por ahora es un placeholder
    
    return null;
  }

  static async createUser(email: string, password?: string, name?: string): Promise<User> {
    const hashedPassword = password ? await this.hashPassword(password) : null;
    
    return prisma.user.create({
      data: {
        email,
        password: hashedPassword,
        name,
        role: 'HOST'
      }
    });
  }

  static async findUserByEmail(email: string): Promise<User | null> {
    return prisma.user.findUnique({
      where: { email }
    });
  }

  static async findUserById(id: string): Promise<User | null> {
    return prisma.user.findUnique({
      where: { id }
    });
  }
}