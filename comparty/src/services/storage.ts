import { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import crypto from 'crypto';

const s3Client = new S3Client({
  endpoint: process.env.DO_SPACES_ENDPOINT,
  region: process.env.DO_SPACES_REGION || 'nyc3',
  credentials: {
    accessKeyId: process.env.DO_SPACES_KEY || '',
    secretAccessKey: process.env.DO_SPACES_SECRET || ''
  }
});

const BUCKET_NAME = process.env.DO_SPACES_BUCKET || 'comparty-dev';

export class StorageService {
  static generateKey(eventId: string, uploaderId: string, filename: string, type: 'raw' | 'thumb' | 'public'): string {
    const ext = filename.split('.').pop()?.toLowerCase() || 'jpg';
    const hash = crypto.randomBytes(8).toString('hex');
    return `events/${eventId}/${uploaderId}/${type}/${hash}.${ext}`;
  }

  static async getPresignedUploadUrl(key: string, contentType: string, maxSize: number = 20 * 1024 * 1024) {
    const command = new PutObjectCommand({
      Bucket: BUCKET_NAME,
      Key: key,
      ContentType: contentType,
      ContentLength: maxSize,
      Metadata: {
        uploadedAt: new Date().toISOString()
      }
    });

    const uploadUrl = await getSignedUrl(s3Client, command, { 
      expiresIn: 3600 // 1 hora
    });

    return {
      uploadUrl,
      key,
      bucket: BUCKET_NAME
    };
  }

  static async getPresignedDownloadUrl(key: string, expiresIn: number = 3600) {
    const command = new GetObjectCommand({
      Bucket: BUCKET_NAME,
      Key: key
    });

    return getSignedUrl(s3Client, command, { expiresIn });
  }

  static async uploadFile(key: string, body: Buffer | Uint8Array | string, contentType: string) {
    const command = new PutObjectCommand({
      Bucket: BUCKET_NAME,
      Key: key,
      Body: body,
      ContentType: contentType,
      ACL: 'private'
    });

    await s3Client.send(command);
    return key;
  }

  static async deleteFile(key: string) {
    const command = new DeleteObjectCommand({
      Bucket: BUCKET_NAME,
      Key: key
    });

    await s3Client.send(command);
  }

  static getPublicUrl(key: string): string {
    return `${process.env.DO_SPACES_ENDPOINT}/${BUCKET_NAME}/${key}`;
  }

  static getCDNUrl(key: string): string {
    // Si tienes un CDN configurado
    const cdnDomain = process.env.DO_CDN_DOMAIN;
    if (cdnDomain) {
      return `https://${cdnDomain}/${key}`;
    }
    return this.getPublicUrl(key);
  }
}