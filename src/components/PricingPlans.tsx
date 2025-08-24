'use client';

import { Check, X, Sparkles } from 'lucide-react';
import { cn } from '@/lib/utils';

interface Plan {
  code: string;
  name: string;
  price: number;
  maxInvites: number;
  albumMonths: number;
  uploadWindowDays: number;
  features: {
    watermark: boolean;
    autoSelection: boolean;
    moderation: boolean;
    publicAlbum: boolean;
    downloadPack: boolean;
    aiScoring: boolean;
    support: string;
    customWatermark?: boolean;
    videoSupport?: boolean;
  };
  recommended?: boolean;
}

const plans: Plan[] = [
  {
    code: 'FREE',
    name: 'Gratis',
    price: 0,
    maxInvites: 2,
    albumMonths: 1,
    uploadWindowDays: 7,
    features: {
      watermark: true,
      autoSelection: true,
      moderation: true,
      publicAlbum: true,
      downloadPack: false,
      aiScoring: false,
      support: 'comunidad'
    }
  },
  {
    code: 'P50',
    name: 'Básico',
    price: 50,
    maxInvites: 5,
    albumMonths: 2,
    uploadWindowDays: 14,
    features: {
      watermark: true,
      autoSelection: true,
      moderation: true,
      publicAlbum: true,
      downloadPack: true,
      aiScoring: false,
      support: 'email'
    }
  },
  {
    code: 'P100',
    name: 'Estándar',
    price: 100,
    maxInvites: 10,
    albumMonths: 3,
    uploadWindowDays: 21,
    features: {
      watermark: true,
      autoSelection: true,
      moderation: true,
      publicAlbum: true,
      downloadPack: true,
      aiScoring: true,
      support: 'prioritario'
    },
    recommended: true
  },
  {
    code: 'P200',
    name: 'Premium',
    price: 200,
    maxInvites: 20,
    albumMonths: 6,
    uploadWindowDays: 30,
    features: {
      watermark: true,
      autoSelection: true,
      moderation: true,
      publicAlbum: true,
      downloadPack: true,
      aiScoring: true,
      support: 'prioritario',
      customWatermark: true,
      videoSupport: true
    }
  }
];

interface PricingPlansProps {
  onSelectPlan?: (planCode: string) => void;
  selectedPlan?: string;
}

export default function PricingPlans({ onSelectPlan, selectedPlan }: PricingPlansProps) {
  return (
    <div className="py-12">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="text-center">
          <h2 className="text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl">
            Elige el plan perfecto para tu evento
          </h2>
          <p className="mt-4 text-lg text-gray-600">
            Todos los planes incluyen selección automática con IA y marca de agua
          </p>
        </div>

        <div className="mt-12 grid gap-8 lg:grid-cols-4">
          {plans.map((plan) => (
            <div
              key={plan.code}
              className={cn(
                'relative rounded-2xl border bg-white p-8 shadow-sm',
                plan.recommended ? 'border-blue-600 ring-2 ring-blue-600' : 'border-gray-200',
                selectedPlan === plan.code && 'ring-2 ring-blue-500'
              )}
            >
              {plan.recommended && (
                <div className="absolute -top-5 left-0 right-0 mx-auto w-fit rounded-full bg-gradient-to-r from-blue-600 to-purple-600 px-3 py-1 text-sm font-medium text-white">
                  Más Popular
                </div>
              )}

              <div className="text-center">
                <h3 className="text-lg font-semibold text-gray-900">{plan.name}</h3>
                <div className="mt-4 flex items-baseline justify-center">
                  <span className="text-5xl font-bold tracking-tight text-gray-900">
                    ${plan.price}
                  </span>
                  {plan.price > 0 && (
                    <span className="ml-1 text-xl text-gray-500">/evento</span>
                  )}
                </div>
                {plan.price > 0 && (
                  <p className="mt-2 text-sm text-gray-500">
                    Extensiones: $10/mes
                  </p>
                )}
              </div>

              <ul className="mt-8 space-y-4">
                <li className="flex items-start">
                  <Check className="h-5 w-5 flex-shrink-0 text-green-500" />
                  <span className="ml-3 text-sm text-gray-700">
                    Hasta <strong>{plan.maxInvites} invitados</strong>
                  </span>
                </li>
                <li className="flex items-start">
                  <Check className="h-5 w-5 flex-shrink-0 text-green-500" />
                  <span className="ml-3 text-sm text-gray-700">
                    Álbum activo por <strong>{plan.albumMonths} {plan.albumMonths === 1 ? 'mes' : 'meses'}</strong>
                  </span>
                </li>
                <li className="flex items-start">
                  <Check className="h-5 w-5 flex-shrink-0 text-green-500" />
                  <span className="ml-3 text-sm text-gray-700">
                    <strong>{plan.uploadWindowDays} días</strong> para subir fotos
                  </span>
                </li>
                <li className="flex items-start">
                  <Check className="h-5 w-5 flex-shrink-0 text-green-500" />
                  <span className="ml-3 text-sm text-gray-700">
                    Selección automática Top-5
                  </span>
                </li>
                <li className="flex items-start">
                  <Check className="h-5 w-5 flex-shrink-0 text-green-500" />
                  <span className="ml-3 text-sm text-gray-700">
                    Álbum público compartible
                  </span>
                </li>
                
                {/* Feature: Descarga de pack */}
                <li className="flex items-start">
                  {plan.features.downloadPack ? (
                    <Check className="h-5 w-5 flex-shrink-0 text-green-500" />
                  ) : (
                    <X className="h-5 w-5 flex-shrink-0 text-gray-400" />
                  )}
                  <span className={cn(
                    "ml-3 text-sm",
                    plan.features.downloadPack ? "text-gray-700" : "text-gray-400"
                  )}>
                    Descarga pack de fotos
                  </span>
                </li>

                {/* Feature: IA */}
                <li className="flex items-start">
                  {plan.features.aiScoring ? (
                    <Sparkles className="h-5 w-5 flex-shrink-0 text-purple-500" />
                  ) : (
                    <X className="h-5 w-5 flex-shrink-0 text-gray-400" />
                  )}
                  <span className={cn(
                    "ml-3 text-sm",
                    plan.features.aiScoring ? "text-gray-700 font-semibold" : "text-gray-400"
                  )}>
                    {plan.features.aiScoring ? 'Análisis con IA GPT-4' : 'Sin análisis con IA'}
                  </span>
                </li>

                {/* Features exclusivos Premium */}
                {plan.features.customWatermark && (
                  <li className="flex items-start">
                    <Check className="h-5 w-5 flex-shrink-0 text-green-500" />
                    <span className="ml-3 text-sm text-gray-700">
                      Marca de agua personalizada
                    </span>
                  </li>
                )}
                {plan.features.videoSupport && (
                  <li className="flex items-start">
                    <Check className="h-5 w-5 flex-shrink-0 text-green-500" />
                    <span className="ml-3 text-sm text-gray-700">
                      Soporte para videos (próximamente)
                    </span>
                  </li>
                )}

                {/* Soporte */}
                <li className="flex items-start">
                  <Check className="h-5 w-5 flex-shrink-0 text-green-500" />
                  <span className="ml-3 text-sm text-gray-700">
                    Soporte {plan.features.support}
                  </span>
                </li>
              </ul>

              <button
                onClick={() => onSelectPlan?.(plan.code)}
                className={cn(
                  "mt-8 w-full rounded-lg px-4 py-2 text-sm font-semibold transition-colors",
                  plan.recommended
                    ? "bg-blue-600 text-white hover:bg-blue-700"
                    : "bg-gray-900 text-white hover:bg-gray-800",
                  selectedPlan === plan.code && "ring-2 ring-offset-2 ring-blue-500"
                )}
              >
                {selectedPlan === plan.code ? 'Plan Seleccionado' : 'Seleccionar Plan'}
              </button>
            </div>
          ))}
        </div>

        <div className="mt-12 text-center">
          <p className="text-base text-gray-600">
            ¿Tienes preguntas? {' '}
            <a href="/contact" className="font-medium text-blue-600 hover:text-blue-500">
              Contáctanos
            </a>
          </p>
        </div>
      </div>
    </div>
  );
}