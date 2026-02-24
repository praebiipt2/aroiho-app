import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding...');

  // 1) Category (ใช้ slug เป็น unique)
  const seafood =
    (await prisma.category.findUnique({ where: { slug: 'seafood' } })) ??
    (await prisma.category.create({
      data: {
        slug: 'seafood',
        name: 'ซีฟู้ดพรีเมียม',
        parentId: null,
        iconUrl: null,
        bannerUrl: null,
        sortOrder: 1,
        isActive: true,
      },
    }));

  const organic =
    (await prisma.category.findUnique({ where: { slug: 'organic' } })) ??
    (await prisma.category.create({
      data: {
        slug: 'organic',
        name: 'ผักออร์แกนิก',
        parentId: null,
        iconUrl: null,
        bannerUrl: null,
        sortOrder: 2,
        isActive: true,
      },
    }));

  // 2) Seller (ไม่มี code/slug unique → ใช้ findFirst by name)
  const seller =
    (await prisma.seller.findFirst({ where: { name: 'ARO Farm Chiang Mai' } })) ??
    (await prisma.seller.create({
      data: {
        name: 'ARO Farm Chiang Mai',
        type: 'FARM',
        taxId: null,
        phone: null,
        addressText: null,
        lat: 18.788015,
        lng: 98.985324,
        status: 'ACTIVE',
      },
    }));

  // 3) Certification (อันนี้มี code จริง)
  const aroCert =
    (await prisma.certification.findUnique({ where: { code: 'ARO_CERT' } })) ??
    (await prisma.certification.create({
      data: {
        code: 'ARO_CERT',
        name: 'Aroiho Certified',
        issuer: 'อร่อยเหาะ',
        description: null,
      },
    }));

  const organicCert =
    (await prisma.certification.findUnique({ where: { code: 'ORGANIC_CERT' } })) ??
    (await prisma.certification.create({
      data: {
        code: 'ORGANIC_CERT',
        name: 'Organic Verified',
        issuer: 'อร่อยเหาะ',
        description: null,
      },
    }));

  // 4) SellerCertification (สมมติ unique เป็น sellerId+certificationId)
  // ถ้า schema ของแพรตั้ง @@unique([sellerId, certificationId]) จะใช้ where แบบนี้ได้
  await prisma.sellerCertification.upsert({
    where: {
      sellerId_certificationId: {
        sellerId: seller.id,
        certificationId: aroCert.id,
      },
    },
    update: {},
    create: {
      sellerId: seller.id,
      certificationId: aroCert.id,
      validFrom: new Date('2025-01-01'),
      validTo: null,
      evidenceUrl: 'https://example.com/cert/aro.pdf',
    },
  });

  await prisma.sellerCertification.upsert({
    where: {
      sellerId_certificationId: {
        sellerId: seller.id,
        certificationId: organicCert.id,
      },
    },
    update: {},
    create: {
      sellerId: seller.id,
      certificationId: organicCert.id,
      validFrom: new Date('2025-01-01'),
      validTo: null,
      evidenceUrl: 'https://example.com/cert/organic.pdf',
    },
  });

  // 5) Product (ใช้ slug เป็น unique)
  const product =
    (await prisma.product.findUnique({ where: { slug: 'premium-lobster' } })) ??
    (await prisma.product.create({
      data: {
        slug: 'premium-lobster',
        name: 'กุ้งมังกรพรีเมียม',
        description: 'สดใหม่ เกรดส่งออก',
        isActive: true,
        unit: 'kg',
        basePrice: 1200,
        thumbnailUrl: 'https://example.com/thumbs/lobster.png',
        sellerId: seller.id,
        categoryId: seafood.id,
      },
    }));

  const organicProduct =
    (await prisma.product.findUnique({ where: { slug: 'organic-salad-set' } })) ??
    (await prisma.product.create({
      data: {
        slug: 'organic-salad-set',
        name: 'ชุดผักสลัดออร์แกนิก',
        description: 'ผักสดปลอดสาร คัดจากฟาร์มทุกเช้า',
        isActive: true,
        unit: 'ชุด',
        basePrice: 165,
        thumbnailUrl: 'https://example.com/thumbs/organic-salad.png',
        sellerId: seller.id,
        categoryId: organic.id,
      },
    }));

  // 6) ProductImage (ถ้ามี unique กันซ้ำ ให้ใช้ createMany + skipDuplicates)
  await prisma.productImage.createMany({
    data: [
      { productId: product.id, imageUrl: 'https://example.com/1.png', sortOrder: 0 },
      { productId: product.id, imageUrl: 'https://example.com/2.png', sortOrder: 1 },
      { productId: organicProduct.id, imageUrl: 'https://example.com/organic-1.png', sortOrder: 0 },
      { productId: organicProduct.id, imageUrl: 'https://example.com/organic-2.png', sortOrder: 1 },
    ],
    skipDuplicates: true,
  });

  // 7) InventoryLot (relation ชื่อ inventoryLots)
  const now = new Date();
  const expires1 = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
  const expires2 = new Date(now.getTime() + 5 * 24 * 60 * 60 * 1000);

  await prisma.inventoryLot.createMany({
    data: [
      {
        productId: product.id,
        sellerId: seller.id,
        lotCode: 'LOT-LOB-001',
        harvestedAt: now,
        packedAt: now,
        expiresAt: expires1,
        quantityAvailable: 20,
        status: 'ACTIVE',
      },
      {
        productId: product.id,
        sellerId: seller.id,
        lotCode: 'LOT-LOB-002',
        harvestedAt: now,
        packedAt: now,
        expiresAt: expires2,
        quantityAvailable: 10,
        status: 'ACTIVE',
      },
      {
        productId: organicProduct.id,
        sellerId: seller.id,
        lotCode: 'LOT-ORG-001',
        harvestedAt: now,
        packedAt: now,
        expiresAt: expires1,
        quantityAvailable: 40,
        status: 'ACTIVE',
      },
      {
        productId: organicProduct.id,
        sellerId: seller.id,
        lotCode: 'LOT-ORG-002',
        harvestedAt: now,
        packedAt: now,
        expiresAt: expires2,
        quantityAvailable: 25,
        status: 'ACTIVE',
      },
    ],
    skipDuplicates: true,
  });

  console.log('✅ Seed completed:', {
    category: [seafood.slug, organic.slug],
    seller: seller.name,
    product: [product.slug, organicProduct.slug],
  });
}

main()
  .then(async () => prisma.$disconnect())
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
