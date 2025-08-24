import { Event, Invitation, Upload, PhotoScore, Selection, User, Plan, Payment } from '@prisma/client';

export type EventWithRelations = Event & {
  user?: User;
  invitations?: Invitation[];
  uploads?: Upload[];
  selections?: Selection[];
  payments?: Payment[];
};

export type UploadWithScore = Upload & {
  photoScore?: PhotoScore;
};

export type SelectionWithUpload = Selection & {
  upload: UploadWithScore;
};

export interface PresignedUrlResponse {
  uploadUrl: string;
  fields: Record<string, string>;
  key: string;
}

export interface PhotoAnalysisResult {
  blurScore: number;
  exposureScore: number;
  facesDetected: number;
  eyesOpenScore: number;
  noiseScore: number;
  qualityScore: number;
}

export interface PayPalConfig {
  clientId: string;
  environment: 'sandbox' | 'production';
}

export interface EmailTemplate {
  to: string;
  subject: string;
  html: string;
  text?: string;
}

export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}