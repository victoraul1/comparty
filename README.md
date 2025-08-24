# Comparty 📸

> Las mejores fotos de tu evento, seleccionadas con IA

Comparty es una aplicación web colaborativa para fotos de eventos donde el host invita a sus invitados a subir fotos. El sistema selecciona automáticamente las mejores 5 fotos de cada invitado usando inteligencia artificial GPT-4.

## 🚀 Características

- **Selección Inteligente con IA**: Análisis avanzado con OpenAI GPT-4 Vision
- **Colaboración Simple**: Links únicos para invitados, sin necesidad de registro
- **Procesamiento Automático**: Detección de duplicados, análisis de calidad, y más
- **Pagos Integrados**: PayPal para planes premium y extensiones
- **Privacidad Garantizada**: Marca de agua automática y eliminación de EXIF
- **Almacenamiento en la Nube**: DigitalOcean Spaces para escalabilidad

## 🛠️ Stack Tecnológico

- **Frontend**: Next.js 14, React 19, Tailwind CSS
- **Backend**: Node.js, Prisma ORM
- **Base de Datos**: PostgreSQL
- **Cache/Colas**: Redis, Bull
- **IA**: OpenAI GPT-4 Vision API
- **Pagos**: PayPal SDK
- **Almacenamiento**: DigitalOcean Spaces (S3-compatible)
- **Email**: SendGrid

## 📋 Requisitos Previos

- Node.js 20 LTS (importante: Node.js 24 tiene problemas de compatibilidad)
- PostgreSQL 14+
- Redis 6+
- Cuenta de DigitalOcean
- Cuenta de PayPal Developer
- API Key de OpenAI
- Cuenta de SendGrid (opcional)

## 🔧 Instalación

1. Clona el repositorio:
```bash
git clone https://github.com/victoraul1/comparty.git
cd comparty
```

2. Instala las dependencias:
```bash
npm install --legacy-peer-deps
```

3. Copia el archivo de variables de entorno:
```bash
cp .env.example .env.local
```

4. Configura las variables de entorno en `.env.local`

5. Configura la base de datos:
```bash
npx prisma generate
npx prisma db push
npm run db:seed
```

6. Inicia el servidor de desarrollo:
```bash
npm run dev
```

La aplicación estará disponible en `http://localhost:3000`

## 💳 Planes y Precios

| Plan | Precio | Invitados | Duración | IA |
|------|--------|-----------|----------|-----|
| Gratis | $0 | 2 | 1 mes | ❌ |
| Básico | $50 | 5 | 2 meses | ❌ |
| Estándar | $100 | 10 | 3 meses | ✅ |
| Premium | $200 | 20 | 6 meses | ✅ |

Extensiones: $10/mes para todos los planes de pago

## 🚀 Despliegue en DigitalOcean

### App Platform

1. Conecta tu repositorio de GitHub
2. Configura las variables de entorno
3. Configura el build command: `npm run build`
4. Configura el run command: `npm start`

### Recursos Necesarios

- **App Platform**: Para la aplicación Next.js
- **Managed Database**: PostgreSQL
- **Managed Redis**: Para colas y cache
- **Spaces**: Para almacenamiento de imágenes
- **CDN**: Para servir imágenes rápidamente

## 📝 Scripts Disponibles

- `npm run dev` - Servidor de desarrollo
- `npm run build` - Build de producción
- `npm start` - Iniciar servidor de producción
- `npm run lint` - Verificar código
- `npm run db:migrate` - Ejecutar migraciones
- `npm run db:seed` - Sembrar base de datos
- `npm run db:studio` - Abrir Prisma Studio

## 📄 Licencia

Todos los derechos reservados © 2025 Comparty

---

Desarrollado con ❤️ por [Victor Galindo](https://github.com/victoraul1)
