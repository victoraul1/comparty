import sharp from 'sharp';
import crypto from 'crypto';
import { PhotoAnalysisResult } from '@/types';

export class ImageProcessorService {
  static async generateThumbnail(imageBuffer: Buffer, maxWidth: number = 1024): Promise<Buffer> {
    return sharp(imageBuffer)
      .resize(maxWidth, null, {
        withoutEnlargement: true,
        fit: 'inside'
      })
      .jpeg({ quality: 85, progressive: true })
      .toBuffer();
  }

  static async removeExif(imageBuffer: Buffer): Promise<Buffer> {
    return sharp(imageBuffer)
      .rotate() // Auto-rotate based on EXIF
      .withMetadata({
        orientation: undefined // Remove orientation
      })
      .toBuffer();
  }

  static async addWatermark(
    imageBuffer: Buffer,
    text: string,
    position: 'bottom-right' | 'bottom-left' = 'bottom-right'
  ): Promise<Buffer> {
    const image = sharp(imageBuffer);
    const metadata = await image.metadata();
    
    if (!metadata.width || !metadata.height) {
      throw new Error('No se pudo obtener las dimensiones de la imagen');
    }

    // Crear SVG con el texto de marca de agua
    const watermarkSvg = `
      <svg width="${metadata.width}" height="${metadata.height}">
        <style>
          .watermark {
            fill: white;
            font-size: ${Math.max(16, metadata.width / 50)}px;
            font-family: Arial, sans-serif;
            opacity: 0.7;
          }
        </style>
        <text
          x="${position === 'bottom-right' ? metadata.width - 20 : 20}"
          y="${metadata.height - 20}"
          text-anchor="${position === 'bottom-right' ? 'end' : 'start'}"
          class="watermark"
        >${text}</text>
      </svg>
    `;

    return image
      .composite([{
        input: Buffer.from(watermarkSvg),
        top: 0,
        left: 0
      }])
      .toBuffer();
  }

  static async analyzeImage(imageBuffer: Buffer): Promise<PhotoAnalysisResult> {
    const image = sharp(imageBuffer);
    const { data, info } = await image
      .raw()
      .toBuffer({ resolveWithObject: true });

    // Calcular desenfoque usando varianza del Laplaciano
    const blurScore = this.calculateBlurScore(data, info.width, info.height, info.channels);
    
    // Analyze exposure using histogram
    const exposureScore = await this.calculateExposureScore(imageBuffer);
    
    // Por ahora, valores placeholder para otros scores
    // En producción, estos usarían bibliotecas especializadas o IA
    const facesDetected = 0;
    const eyesOpenScore = 1;
    const noiseScore = this.estimateNoiseScore(data, info.width, info.height, info.channels);
    
    // Calcular score de calidad compuesto
    const qualityScore = this.calculateQualityScore({
      blurScore,
      exposureScore,
      facesDetected,
      eyesOpenScore,
      noiseScore
    });

    return {
      blurScore,
      exposureScore,
      facesDetected,
      eyesOpenScore,
      noiseScore,
      qualityScore
    };
  }

  private static calculateBlurScore(
    data: Buffer,
    width: number,
    height: number,
    channels: number
  ): number {
    // Implementación simplificada del cálculo de desenfoque
    // En producción, usar OpenCV o similar para Laplaciano real
    
    let variance = 0;
    const pixels = width * height;
    const step = Math.max(1, Math.floor(pixels / 10000)); // Muestreo
    
    for (let i = 0; i < data.length; i += channels * step) {
      const gray = 0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2];
      variance += gray;
    }
    
    // Normalizar a 0-1 (1 = nítido, 0 = borroso)
    const normalized = Math.min(1, variance / (pixels / step) / 255);
    return normalized;
  }

  private static async calculateExposureScore(imageBuffer: Buffer): Promise<number> {
    const { dominant } = await sharp(imageBuffer).stats();
    
    // Calcular luminancia promedio
    const luminance = 0.299 * dominant.r + 0.587 * dominant.g + 0.114 * dominant.b;
    
    // Penalizar extremos (muy oscuro o muy claro)
    const idealLuminance = 127.5;
    const deviation = Math.abs(luminance - idealLuminance);
    const score = 1 - (deviation / idealLuminance);
    
    return Math.max(0, Math.min(1, score));
  }

  private static estimateNoiseScore(
    data: Buffer,
    width: number,
    height: number,
    channels: number
  ): number {
    // Estimación simple de ruido
    // En producción, usar análisis más sofisticado
    
    let totalDiff = 0;
    let comparisons = 0;
    const step = Math.max(1, Math.floor((width * height) / 5000));
    
    for (let y = 1; y < height - 1; y += step) {
      for (let x = 1; x < width - 1; x += step) {
        const idx = (y * width + x) * channels;
        const neighbors = [
          (y * width + x - 1) * channels,
          (y * width + x + 1) * channels,
          ((y - 1) * width + x) * channels,
          ((y + 1) * width + x) * channels
        ];
        
        for (const neighborIdx of neighbors) {
          if (neighborIdx >= 0 && neighborIdx < data.length) {
            const diff = Math.abs(data[idx] - data[neighborIdx]);
            totalDiff += diff;
            comparisons++;
          }
        }
      }
    }
    
    const avgDiff = totalDiff / comparisons / 255;
    // Invertir: menos ruido = mejor score
    return Math.max(0, Math.min(1, 1 - avgDiff * 2));
  }

  private static calculateQualityScore(scores: Omit<PhotoAnalysisResult, 'qualityScore'>): number {
    // Ponderación de cada factor
    const weights = {
      blur: 0.3,
      exposure: 0.25,
      faces: 0.15,
      eyes: 0.1,
      noise: 0.2
    };
    
    // Bonus si hay caras detectadas
    const faceBonus = scores.facesDetected > 0 ? 0.1 : 0;
    
    const weightedScore = 
      scores.blurScore * weights.blur +
      scores.exposureScore * weights.exposure +
      (scores.facesDetected > 0 ? 1 : 0) * weights.faces +
      scores.eyesOpenScore * weights.eyes +
      scores.noiseScore * weights.noise +
      faceBonus;
    
    return Math.max(0, Math.min(1, weightedScore));
  }

  static async calculateHash(imageBuffer: Buffer): Promise<string> {
    // Generar hash perceptual simple para detección de duplicados
    const resized = await sharp(imageBuffer)
      .resize(8, 8, { fit: 'fill' })
      .grayscale()
      .raw()
      .toBuffer();
    
    // Calcular valor promedio
    const avg = resized.reduce((sum, val) => sum + val, 0) / resized.length;
    
    // Crear hash binario
    let hash = '';
    for (let i = 0; i < resized.length; i++) {
      hash += resized[i] > avg ? '1' : '0';
    }
    
    // Convertir a hexadecimal
    return Buffer.from(hash, 'binary').toString('hex');
  }

  static calculateSimilarity(hash1: string, hash2: string): number {
    // Calcular distancia de Hamming
    let distance = 0;
    for (let i = 0; i < hash1.length; i++) {
      if (hash1[i] !== hash2[i]) distance++;
    }
    
    // Convertir a similitud (0-1)
    return 1 - (distance / hash1.length);
  }
}