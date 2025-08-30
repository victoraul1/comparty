# Comparty 📸

> The best photos from your event, AI-selected

Comparty is a collaborative web application for event photos where the host invites guests to upload photos. The system automatically selects the best 5 photos from each guest using GPT-4 artificial intelligence.

## 🚀 Features

- **Intelligent AI Selection**: Advanced analysis with OpenAI GPT-4 Vision
- **Simple Collaboration**: Unique links for guests, no registration needed
- **Automatic Processing**: Duplicate detection, quality analysis, and more
- **Integrated Payments**: PayPal for premium plans and extensions
- **Guaranteed Privacy**: Automatic watermarking and EXIF removal
- **Cloud Storage**: DigitalOcean Spaces for scalability

## 🛠️ Tech Stack

- **Frontend**: Next.js 14, React 19, Tailwind CSS
- **Backend**: Node.js, Prisma ORM
- **Database**: PostgreSQL
- **Cache/Queues**: Redis, Bull
- **AI**: OpenAI GPT-4 Vision API
- **Payments**: PayPal SDK
- **Storage**: DigitalOcean Spaces (S3-compatible)
- **Email**: SendGrid

## 📋 Prerequisites

- Node.js 20 LTS (important: Node.js 24 has compatibility issues)
- PostgreSQL 14+
- Redis 6+
- DigitalOcean account
- PayPal Developer account
- OpenAI API Key
- SendGrid account (optional)

## 🔧 Installation

1. Clone the repository:
```bash
git clone https://github.com/victoraul1/comparty.git
cd comparty
```

2. Install dependencies:
```bash
npm install --legacy-peer-deps
```

3. Copy the environment variables file:
```bash
cp .env.example .env.local
```

4. Configure environment variables in `.env.local`

5. Set up the database:
```bash
npx prisma generate
npx prisma db push
npm run db:seed
```

6. Start the development server:
```bash
npm run dev
```

The application will be available at `http://localhost:3000`

## 💳 Plans and Pricing

| Plan | Price | Guests | Duration | AI |
|------|-------|--------|----------|----|
| Free | $0 | 2 | 1 month | ❌ |
| Basic | $50 | 5 | 2 months | ❌ |
| Standard | $100 | 10 | 3 months | ✅ |
| Premium | $200 | 20 | 6 months | ✅ |

Extensions: $10/month for all paid plans

## 🚀 Deployment on DigitalOcean

### App Platform

1. Connect your GitHub repository
2. Configure environment variables
3. Set build command: `npm run build`
4. Set run command: `npm start`

### Required Resources

- **App Platform**: For the Next.js application
- **Managed Database**: PostgreSQL
- **Managed Redis**: For queues and cache
- **Spaces**: For image storage
- **CDN**: For fast image serving

## 📝 Available Scripts

- `npm run dev` - Development server
- `npm run build` - Production build
- `npm start` - Start production server
- `npm run lint` - Lint code
- `npm run db:migrate` - Run migrations
- `npm run db:seed` - Seed database
- `npm run db:studio` - Open Prisma Studio

## 📄 License

All rights reserved © 2025 Comparty

---

Developed with ❤️ by [Victor Galindo](https://github.com/victoraul1)
