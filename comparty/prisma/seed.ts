import { PrismaClient, PlanTier } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting database seed...');

  const plans = [
    {
      code: PlanTier.FREE,
      name: 'Plan Gratis',
      priceOnce: 0,
      maxInvites: 2,
      albumMonths: 1,
      uploadWindowDays: 7,
      extensionPrice: 10,
      features: {
        watermark: true,
        autoSelection: true,
        moderation: true,
        publicAlbum: true,
        downloadPack: false,
        aiScoring: false,
        support: 'community'
      }
    },
    {
      code: PlanTier.P50,
      name: 'Plan Básico',
      priceOnce: 50,
      maxInvites: 5,
      albumMonths: 2,
      uploadWindowDays: 14,
      extensionPrice: 10,
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
      code: PlanTier.P100,
      name: 'Plan Estándar',
      priceOnce: 100,
      maxInvites: 10,
      albumMonths: 3,
      uploadWindowDays: 21,
      extensionPrice: 10,
      features: {
        watermark: true,
        autoSelection: true,
        moderation: true,
        publicAlbum: true,
        downloadPack: true,
        aiScoring: true,
        support: 'priority'
      }
    },
    {
      code: PlanTier.P200,
      name: 'Plan Premium',
      priceOnce: 200,
      maxInvites: 20,
      albumMonths: 6,
      uploadWindowDays: 30,
      extensionPrice: 10,
      features: {
        watermark: true,
        autoSelection: true,
        moderation: true,
        publicAlbum: true,
        downloadPack: true,
        aiScoring: true,
        support: 'priority',
        customWatermark: true,
        videoSupport: true
      }
    }
  ];

  for (const plan of plans) {
    await prisma.plan.upsert({
      where: { code: plan.code },
      update: plan,
      create: plan
    });
    console.log(`✅ Upserted plan: ${plan.name}`);
  }

  if (process.env.NODE_ENV === 'development') {
    const testUser = await prisma.user.upsert({
      where: { email: 'test@comparty.app' },
      update: {},
      create: {
        email: 'test@comparty.app',
        password: '$2a$10$K.0kCJhbD6H5D0r8w2F7Z.N6C7j5N7J4K6K7j5N7J4K6K7j5N7J4K', // password: Test123!
        role: 'HOST',
        name: 'Usuario de Prueba'
      }
    });
    console.log(`✅ Created test user: ${testUser.email}`);
  }

  console.log('✨ Database seeded successfully!');
}

main()
  .catch((e) => {
    console.error('❌ Error seeding database:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });