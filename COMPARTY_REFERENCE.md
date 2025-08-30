# Comparty - Documento de Referencia del Proyecto

## Última Actualización: 2025-08-23 - v3.0 con IA y PayPal integrados

## Descripción General
**Comparty** es una aplicación web colaborativa para fotos de eventos donde el host invita a 2-20 invitados a subir sus mejores fotos. El sistema selecciona automáticamente las mejores 5 fotos por invitado mediante un proceso de culling inteligente y ofrece moderación, marca de agua y compartir en redes sociales.

**URL de Producción:** https://comparty.app

## Estado Actual del Proyecto
- **Fase:** Desarrollo avanzado con IA y pagos integrados
- **Stack Tecnológico:** Next.js 14 (App Router) + Node.js + PostgreSQL + Redis + OpenAI + PayPal
- **Infraestructura:** DigitalOcean (App Platform + Spaces + Managed DB)
- **API de OpenAI:** ✅ INTEGRADA - Análisis inteligente de fotos con GPT-4 Vision
- **PayPal:** ✅ INTEGRADO - Pagos únicos y suscripciones mensuales

## Problema que Resuelve
Las fotos de los invitados a eventos quedan dispersas en múltiples plataformas (WhatsApp, Google Drive, etc.). El host no logra centralizarlas ni curarlas fácilmente, resultando en álbumes desorganizados y de calidad variable.

## Solución
Un álbum único y curado del evento donde:
1. El host crea el evento y elige un plan de pago
2. Invita a un grupo reducido de invitados (2-20 según plan)
3. Cada invitado sube fotos desde un link único sin necesidad de registro
4. Comparty selecciona automáticamente las mejores 5 fotos por invitado
5. Se aplica marca de agua con el nombre del uploader
6. El host puede moderar (aprobar, descartar, reemplazar)
7. Compartir el álbum final con un clic

## Modelo de Negocio

### Planes (Pago Único vía PayPal)
- **Free:** 2 invitados, subidas 1 semana, álbum activo 1 mes
- **$50:** 5 invitados, 2 meses de álbum, extensiones $10/mes
- **$100:** 10 invitados, 3 meses de álbum, extensiones $10/mes
- **$200:** 20 invitados, 6 meses de álbum, extensiones $10/mes

### Extensiones
- $10/mes para mantener el álbum activo después del periodo inicial
- Gestionado mediante suscripciones de PayPal

## Arquitectura Técnica

### Frontend
- **Framework:** Next.js 14 con App Router
- **UI:** Tailwind CSS + shadcn/ui
- **Estado:** Zustand o Context API
- **Subida de archivos:** Uppy o react-dropzone
- **Galería:** react-photo-album o photoswipe

### Backend
- **API:** Next.js API Routes o Express.js separado
- **Base de datos:** PostgreSQL (Managed DB en DigitalOcean)
- **Cache/Colas:** Redis (Managed Redis en DigitalOcean)
- **Almacenamiento:** DigitalOcean Spaces (S3-compatible)
- **Procesamiento de imágenes:** Sharp + OpenCV.js/wasm
- **Emails:** SendGrid o Resend
- **Pagos:** PayPal Checkout SDK

### Infraestructura
- **Hosting:** DigitalOcean App Platform
- **CDN:** DigitalOcean CDN para Spaces
- **SSL:** Let's Encrypt (automático en App Platform)
- **Dominio:** comparty.app

## Funcionalidades Principales

### 1. Gestión de Eventos
- Crear evento con nombre, fecha, tipo (boda/quinceañera/bautizo/otro)
- Portada opcional del evento
- Selección y pago de plan vía PayPal
- Dashboard del host con métricas y estado

### 2. Sistema de Invitaciones
- Registro de emails de invitados (2-20 según plan)
- Envío de email con link único (token firmado con expiración)
- Subida sin registro dentro de la ventana temporal
- Tracking de aceptación y subidas

### 3. Procesamiento de Imágenes con IA (OpenAI GPT-4 Vision)
- Subida directa a DigitalOcean Spaces con pre-signed URLs
- Generación de thumbnails (≤1024px)
- Eliminación de datos EXIF en versiones públicas
- Pipeline de análisis híbrido (Heurísticas + IA):
  - **Análisis técnico básico:**
    - Detección de desenfoque (varianza del Laplaciano)
    - Evaluación de exposición (histograma)
    - Estimación de ruido/ISO
    - Deduplicación (pHash/dHash/SSIM)
  - **Análisis avanzado con OpenAI GPT-4 Vision:**
    - Score estético (0-10)
    - Relevancia contextual con el evento
    - Análisis de composición (regla de tercios, balance, líneas guía)
    - Detección de emociones
    - Memorabilidad de la foto
    - Identificación de fotos grupales vs individuales
    - Detección de momentos espontáneos vs posados
    - Sugerencias de mejora
- Score compuesto inteligente 0-1 combinando todos los factores
- Generación automática de resúmenes emotivos del evento

### 4. Selección Automática (Top-5)
- Algoritmo que selecciona las mejores 5 fotos por invitado
- Basado en score compuesto de calidad
- Posibilidad de override manual por el host
- Categorización: "Top", "Posibles", "Duplicados"

### 5. Moderación y Edición
- Interfaz de moderación para el host
- Filtros por invitado
- Acciones: aprobar, descartar, reemplazar
- Pin manual de fotos favoritas

### 6. Marca de Agua
- Texto con nombre del invitado/uploader
- Posición: esquina inferior derecha
- Configuración de tamaño y opacidad
- Aplicación automática en versiones públicas

### 7. Compartir y Exportar
- Generación de URL pública del álbum
- Descarga de pack con fotos seleccionadas
- Versiones con marca de agua para redes sociales
- Sin datos EXIF en versiones públicas

### 8. Sistema de Pagos con PayPal (INTEGRADO)
- Integración con PayPal Checkout para planes
- Suscripciones PayPal para extensiones mensuales
- Webhooks para actualización de estados
- Recibos automáticos por email

### 9. Gestión de Caducidad
- Ventana de subida limitada según plan
- Expiración del álbum con avisos previos
- Opción de extensión mensual
- Retención de datos según políticas

### 10. Emails Automatizados
- Invitación a subir fotos
- Confirmación de pago
- Recordatorios de cierre (48h antes)
- Avisos de expiración (7d y 24h antes)
- Confirmación de extensión

## Base de Datos (PostgreSQL)

### Tablas Principales
- `users`: Hosts y staff del sistema
- `events`: Información del evento y configuración
- `invitations`: Tokens y estado de invitados
- `uploads`: Archivos subidos y sus versiones
- `photo_scores`: Métricas de calidad por foto
- `selections`: Top-5 y overrides manuales
- `plans`: Configuración de planes disponibles
- `payments`: Transacciones con PayPal
- `extensions`: Renovaciones mensuales
- `audit_logs`: Registro de acciones importantes

## API Endpoints

### Autenticación y Eventos
- `POST /api/auth/magic-link` - Login del host
- `POST /api/events` - Crear evento
- `GET /api/events/:id` - Detalles del evento
- `PUT /api/events/:id` - Actualizar evento

### Pagos
- `POST /api/payments/checkout` - Iniciar pago PayPal
- `POST /api/webhooks/paypal` - Webhook de PayPal
- `POST /api/extensions/checkout` - Suscripción mensual

### Invitaciones
- `POST /api/events/:id/invitations` - Crear/reenviar
- `GET /api/invitations/:token` - Validar token

### Subida y Procesamiento
- `POST /api/uploads/presign` - Obtener URL firmada
- `POST /api/uploads/process` - Encolar procesamiento
- `GET /api/uploads/:id/status` - Estado del procesamiento

### Moderación
- `GET /api/events/:id/photos` - Listar fotos con filtros
- `POST /api/selections` - Pin/override manual
- `DELETE /api/photos/:id` - Soft delete

### Público
- `GET /api/albums/:slug` - Álbum público
- `GET /api/albums/:slug/download` - Descargar pack

## Variables de Entorno

```env
# DigitalOcean
DO_SPACES_KEY=
DO_SPACES_SECRET=
DO_SPACES_BUCKET=comparty-prod
DO_SPACES_REGION=nyc3
DO_SPACES_ENDPOINT=

# PayPal
PAYPAL_CLIENT_ID=
PAYPAL_CLIENT_SECRET=
PAYPAL_WEBHOOK_ID=
PAYPAL_ENVIRONMENT=production

# Database
DATABASE_URL=postgresql://user:pass@host:5432/comparty
REDIS_URL=redis://default:pass@host:6379

# App
APP_URL=https://comparty.app
NODE_ENV=production
JWT_SECRET=

# Email
SENDGRID_API_KEY=
FROM_EMAIL=hola@comparty.app

# OpenAI (cuando se proporcione)
OPENAI_API_KEY=

# Features
AI_SCORING_ENABLED=false
VIDEO_SUPPORT_ENABLED=false
```

## Seguridad y Privacidad

### Medidas de Seguridad
- Tokens firmados con JWT y expiración
- CORS configurado correctamente
- Protección CSRF en formularios
- Rate limiting en API
- Validación de MIME types
- Límite de tamaño de archivo (20MB)
- Sanitización de nombres de archivo

### Privacidad
- Consentimiento explícito para análisis de calidad
- Eliminación de EXIF en versiones públicas
- Retención de datos según plan
- Borrado automático post-expiración + 30 días
- Cumplimiento con políticas de privacidad

## Próximas Funcionalidades (Roadmap)

### Fase 2: Videos Cortos
- Soporte para MP4/MOV ≤60s
- Transcodificación con FFmpeg
- Thumbnails de videos
- Scoring adaptado para videos

### Fase 3: Mejoras de IA
- Detección de escenas específicas
- Agrupación por momentos
- Sugerencias de composición
- Reconocimiento de emociones

### Fase 4: Social
- Comentarios en fotos
- Likes/favoritos de invitados
- Notificaciones en tiempo real
- Integración directa con redes sociales

## Comandos de Desarrollo

```bash
# Instalación
npm install

# Desarrollo local
npm run dev

# Build de producción
npm run build

# Tests
npm run test
npm run test:e2e

# Linting y formato
npm run lint
npm run format

# Migraciones de DB
npm run db:migrate
npm run db:seed

# Despliegue
npm run deploy:production
```

## Contacto y Soporte
- Email técnico: dev@comparty.app
- Documentación: /docs
- Estado del sistema: /status

## Historial de Actualizaciones

### 2025-08-23 v3.0 - Integración de PayPal
- ✅ Integración completa con PayPal SDK
- ✅ Checkout para planes de pago único
- ✅ Suscripciones para extensiones mensuales
- ✅ Webhooks para procesamiento automático
- ✅ Componentes React para pagos
- ✅ Hook personalizado usePayPal
- ✅ Componente de planes con precios
- ✅ Manejo de errores y reintentos

### 2025-08-23 v2.0 - Integración de IA con OpenAI
- ✅ Integración completa con OpenAI GPT-4 Vision
- ✅ Análisis inteligente de fotos con múltiples métricas
- ✅ Score híbrido combinando heurísticas y IA
- ✅ Detección de emociones y momentos memorables
- ✅ Generación de resúmenes emotivos del evento
- ✅ Sistema de colas con Bull para procesamiento asíncrono
- ✅ Optimización del algoritmo de selección Top-5

### 2025-08-23 v1.0 - Inicio del Proyecto
- Creación del documento de referencia
- Definición de arquitectura y stack tecnológico
- Planificación de funcionalidades MVP
- Estructura inicial del proyecto
- Backend básico con autenticación y eventos
- Sistema de almacenamiento con DigitalOcean Spaces

---

**Nota:** Este documento debe actualizarse con cada cambio significativo en la arquitectura, funcionalidades o configuración del proyecto.