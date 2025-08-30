import OpenAI from 'openai';
import { PhotoAnalysisResult } from '@/types';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

export interface AIPhotoAnalysis {
  aestheticScore: number;
  contextScore: number;
  composition: {
    ruleOfThirds: boolean;
    balance: string;
    leadingLines: boolean;
  };
  technicalQuality: {
    sharpness: string;
    exposure: string;
    colorBalance: string;
  };
  emotions: string[];
  sceneType: string;
  memorability: number;
  suggestions: string[];
  eventRelevance: number;
  groupPhoto: boolean;
  candid: boolean;
}

export class AIAnalyzerService {
  private static readonly AI_ENABLED = process.env.AI_SCORING_ENABLED === 'true';
  
  static async analyzePhoto(
    imageBase64: string,
    eventType: string,
    eventName: string
  ): Promise<AIPhotoAnalysis | null> {
    if (!this.AI_ENABLED) {
      return null;
    }

    try {
      const prompt = this.buildPrompt(eventType, eventName);
      
      const response = await openai.chat.completions.create({
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: "Eres un experto en fotografía de eventos que analiza imágenes para seleccionar las mejores fotos de eventos sociales. Responde siempre en formato JSON válido."
          },
          {
            role: "user",
            content: [
              { type: "text", text: prompt },
              {
                type: "image_url",
                image_url: {
                  url: `data:image/jpeg;base64,${imageBase64}`,
                  detail: "low"
                }
              }
            ]
          }
        ],
        max_tokens: 500,
        temperature: 0.3,
        response_format: { type: "json_object" }
      });

      const result = JSON.parse(response.choices[0].message.content || '{}');
      
      return this.normalizeAIResponse(result);
    } catch (error) {
      console.error('Error en análisis con IA:', error);
      return null;
    }
  }

  private static buildPrompt(eventType: string, eventName: string): string {
    const eventTypeSpanish = this.translateEventType(eventType);
    
    return `Analiza esta foto del evento "${eventName}" (tipo: ${eventTypeSpanish}) y proporciona una evaluación JSON con los siguientes campos:

    {
      "aestheticScore": número del 0 al 10 para la calidad estética general,
      "contextScore": número del 0 al 10 para relevancia con el tipo de evento,
      "composition": {
        "ruleOfThirds": booleano si sigue la regla de los tercios,
        "balance": "simétrico", "asimétrico" o "desequilibrado",
        "leadingLines": booleano si tiene líneas guía
      },
      "technicalQuality": {
        "sharpness": "excelente", "buena", "aceptable" o "pobre",
        "exposure": "perfecta", "buena", "sobreexpuesta", "subexpuesta",
        "colorBalance": "natural", "cálido", "frío", "desbalanceado"
      },
      "emotions": array de emociones detectadas ["alegría", "emoción", "amor", etc],
      "sceneType": tipo de escena ("retrato", "grupo", "paisaje", "detalle", "acción", "ceremonia"),
      "memorability": número del 0 al 10 para qué tan memorable es la foto,
      "eventRelevance": número del 0 al 10 para relevancia con ${eventTypeSpanish},
      "groupPhoto": booleano si es foto grupal,
      "candid": booleano si es espontánea (no posada),
      "suggestions": array con máximo 2 sugerencias breves de mejora
    }
    
    Evalúa considerando que es un evento de tipo ${eventTypeSpanish} y prioriza:
    - Momentos emotivos y genuinos
    - Buena composición y técnica
    - Relevancia con el tipo de evento
    - Calidad técnica aceptable o superior`;
  }

  private static translateEventType(eventType: string): string {
    const translations: Record<string, string> = {
      'WEDDING': 'boda',
      'QUINCEANERA': 'quinceañera',
      'BAPTISM': 'bautizo',
      'OTHER': 'celebración'
    };
    return translations[eventType] || 'evento';
  }

  private static normalizeAIResponse(response: any): AIPhotoAnalysis {
    return {
      aestheticScore: this.normalizeScore(response.aestheticScore),
      contextScore: this.normalizeScore(response.contextScore),
      composition: {
        ruleOfThirds: Boolean(response.composition?.ruleOfThirds),
        balance: response.composition?.balance || 'asimétrico',
        leadingLines: Boolean(response.composition?.leadingLines)
      },
      technicalQuality: {
        sharpness: response.technicalQuality?.sharpness || 'aceptable',
        exposure: response.technicalQuality?.exposure || 'buena',
        colorBalance: response.technicalQuality?.colorBalance || 'natural'
      },
      emotions: Array.isArray(response.emotions) ? response.emotions : [],
      sceneType: response.sceneType || 'general',
      memorability: this.normalizeScore(response.memorability),
      suggestions: Array.isArray(response.suggestions) ? response.suggestions.slice(0, 2) : [],
      eventRelevance: this.normalizeScore(response.eventRelevance),
      groupPhoto: Boolean(response.groupPhoto),
      candid: Boolean(response.candid)
    };
  }

  private static normalizeScore(score: any): number {
    const num = parseFloat(score);
    if (isNaN(num)) return 5;
    return Math.max(0, Math.min(10, num));
  }

  static calculateEnhancedQualityScore(
    basicAnalysis: PhotoAnalysisResult,
    aiAnalysis: AIPhotoAnalysis | null
  ): number {
    // Si no hay análisis de IA, usar solo el análisis básico
    if (!aiAnalysis) {
      return basicAnalysis.qualityScore;
    }

    // Mapear calidad técnica a scores
    const technicalScores = {
      sharpness: this.mapTechnicalToScore(aiAnalysis.technicalQuality.sharpness),
      exposure: this.mapExposureToScore(aiAnalysis.technicalQuality.exposure)
    };

    // Ponderación de factores
    const weights = {
      technical: 0.25,      // Análisis técnico básico
      aesthetic: 0.20,      // Estética según IA
      context: 0.15,        // Relevancia con el evento
      memorability: 0.15,   // Qué tan memorable es
      composition: 0.10,    // Composición
      emotion: 0.10,        // Contenido emocional
      eventRelevance: 0.05  // Relevancia específica del evento
    };

    // Calcular score de composición
    const compositionScore = (
      (aiAnalysis.composition.ruleOfThirds ? 3 : 0) +
      (aiAnalysis.composition.balance !== 'desequilibrado' ? 3 : 0) +
      (aiAnalysis.composition.leadingLines ? 4 : 0)
    ) / 10;

    // Calcular score emocional
    const emotionScore = Math.min(10, aiAnalysis.emotions.length * 2.5) / 10;

    // Bonus por características especiales
    let bonus = 0;
    if (aiAnalysis.candid) bonus += 0.05; // Fotos espontáneas son valiosas
    if (aiAnalysis.groupPhoto && aiAnalysis.aestheticScore > 7) bonus += 0.05; // Fotos grupales buenas son difíciles

    // Calcular score final ponderado
    const finalScore = (
      basicAnalysis.qualityScore * weights.technical +
      (aiAnalysis.aestheticScore / 10) * weights.aesthetic +
      (aiAnalysis.contextScore / 10) * weights.context +
      (aiAnalysis.memorability / 10) * weights.memorability +
      compositionScore * weights.composition +
      emotionScore * weights.emotion +
      (aiAnalysis.eventRelevance / 10) * weights.eventRelevance
    ) + bonus;

    return Math.max(0, Math.min(1, finalScore));
  }

  private static mapTechnicalToScore(quality: string): number {
    const mapping: Record<string, number> = {
      'excelente': 1.0,
      'buena': 0.75,
      'aceptable': 0.5,
      'pobre': 0.25
    };
    return mapping[quality] || 0.5;
  }

  private static mapExposureToScore(exposure: string): number {
    const mapping: Record<string, number> = {
      'perfecta': 1.0,
      'buena': 0.8,
      'sobreexpuesta': 0.4,
      'subexpuesta': 0.4
    };
    return mapping[exposure] || 0.6;
  }

  static async batchAnalyzePhotos(
    photos: Array<{
      id: string;
      base64: string;
      eventType: string;
      eventName: string;
    }>,
    maxConcurrent: number = 3
  ): Promise<Map<string, AIPhotoAnalysis | null>> {
    const results = new Map<string, AIPhotoAnalysis | null>();
    
    // Procesar en lotes para no sobrecargar la API
    for (let i = 0; i < photos.length; i += maxConcurrent) {
      const batch = photos.slice(i, i + maxConcurrent);
      const batchPromises = batch.map(photo =>
        this.analyzePhoto(photo.base64, photo.eventType, photo.eventName)
          .then(analysis => ({ id: photo.id, analysis }))
      );
      
      const batchResults = await Promise.all(batchPromises);
      batchResults.forEach(({ id, analysis }) => {
        results.set(id, analysis);
      });
      
      // Pequeña pausa entre lotes para respetar rate limits
      if (i + maxConcurrent < photos.length) {
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
    }
    
    return results;
  }

  static async generateEventSummary(
    eventName: string,
    eventType: string,
    photoAnalyses: AIPhotoAnalysis[]
  ): Promise<string> {
    if (!this.AI_ENABLED || photoAnalyses.length === 0) {
      return '';
    }

    try {
      // Recopilar estadísticas
      const emotions = photoAnalyses.flatMap(a => a.emotions);
      const uniqueEmotions = [...new Set(emotions)];
      const avgAesthetic = photoAnalyses.reduce((sum, a) => sum + a.aestheticScore, 0) / photoAnalyses.length;
      const avgMemorability = photoAnalyses.reduce((sum, a) => sum + a.memorability, 0) / photoAnalyses.length;
      
      const response = await openai.chat.completions.create({
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: "Eres un experto en fotografía de eventos que crea resúmenes emotivos y concisos."
          },
          {
            role: "user",
            content: `Crea un resumen breve y emotivo (máximo 3 oraciones) del evento "${eventName}" (${this.translateEventType(eventType)}) basándote en estos datos:
            - Emociones detectadas: ${uniqueEmotions.join(', ')}
            - Calidad estética promedio: ${avgAesthetic.toFixed(1)}/10
            - Memorabilidad promedio: ${avgMemorability.toFixed(1)}/10
            - Total de fotos analizadas: ${photoAnalyses.length}
            
            El resumen debe ser positivo, emotivo y capturar la esencia del evento.`
          }
        ],
        max_tokens: 150,
        temperature: 0.7
      });

      return response.choices[0].message.content || '';
    } catch (error) {
      console.error('Error generando resumen del evento:', error);
      return '';
    }
  }
}