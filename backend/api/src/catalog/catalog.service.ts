import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class CatalogService {
  constructor(private readonly prisma: PrismaService) {}

  async listCategories() {
    return this.prisma.category.findMany({
      where: { isActive: true, parentId: null },
      orderBy: { sortOrder: 'asc' },
      include: {
        children: {
          where: { isActive: true },
          orderBy: { sortOrder: 'asc' },
        },
      },
    });
  }

  async listProducts(filter: {
    categoryId?: string;
    q?: string;
    page?: number;
    limit?: number;
  }) {
    const page = filter.page ?? 1;
    const limit = filter.limit ?? 20;
    const skip = (page - 1) * limit;

    const where: any = {
      isActive: true,
      ...(filter.categoryId ? { categoryId: filter.categoryId } : {}),
      ...(filter.q
        ? {
            OR: [
              { name: { contains: filter.q, mode: 'insensitive' } },
              { description: { contains: filter.q, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [items, total] = await Promise.all([
      this.prisma.product.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          name: true,
          unit: true,
          basePrice: true,
          thumbnailUrl: true,
          categoryId: true,
          sellerId: true,
        },
      }),
      this.prisma.product.count({ where }),
    ]);

    return {
      page,
      limit,
      total,
      items: items.map((p) => ({
        id: p.id,
        categoryId: p.categoryId,
        sellerId: p.sellerId,
        name: p.name,
        basePrice: Number(p.basePrice),
        unit: p.unit,
        thumbnailUrl: p.thumbnailUrl,
      })),
    };
  }

  async getProductDetail(id: string) {
    const now = new Date();

    const product = await this.prisma.product.findUnique({
      where: { id },
      include: {
        images: { orderBy: { sortOrder: 'asc' } },
        seller: {
          include: {
            certifications: {
              where: {
                validFrom: { lte: now },
                OR: [{ validTo: null }, { validTo: { gte: now } }],
              },
              include: { certification: true },
              orderBy: { validFrom: 'desc' },
            },
          },
        },
        inventoryLots: {
          where: {
            status: 'ACTIVE',
            quantityAvailable: { gt: 0 },
            expiresAt: { gte: now },
          },
          orderBy: [{ expiresAt: 'asc' }],
        },
        tags: {
          include: { tag: true },
        },
      },
    });

    if (!product) throw new NotFoundException('Product not found');

    return {
      id: product.id,
      name: product.name,
      description: product.description,
      unit: product.unit,
      basePrice: Number(product.basePrice),
      images: product.images.map((img) => ({
        url: img.imageUrl,
        sortOrder: img.sortOrder,
      })),
      tags: product.tags.map((t) => t.tag.name),
      lots: product.inventoryLots.map((lot) => ({
        id: lot.id,
        lotCode: lot.lotCode,
        harvestedAt: lot.harvestedAt,
        packedAt: lot.packedAt,
        expiresAt: lot.expiresAt,
        recommendedConsumeBefore: lot.recommendedConsumeBefore,
        storageCondition: lot.storageCondition,
        quantityAvailable: Number(lot.quantityAvailable),
        status: lot.status,
        freshnessIndicator: this.calculateFreshness(
          lot.harvestedAt,
          lot.expiresAt,
        ),
      })),
      seller: {
        id: product.seller.id,
        name: product.seller.name,
        lat: product.seller.lat ? Number(product.seller.lat) : null,
        lng: product.seller.lng ? Number(product.seller.lng) : null,
        certifications: product.seller.certifications.map((sc) => ({
          code: sc.certification.code,
          name: sc.certification.name,
          issuer: sc.certification.issuer,
          validFrom: sc.validFrom,
          validTo: sc.validTo,
          evidenceUrl: sc.evidenceUrl,
        })),
      },
    };
  }

  async getSellerInfo(id: string) {
    const now = new Date();
    const seller = await this.prisma.seller.findUnique({
      where: { id },
      include: {
        certifications: {
          where: {
            validFrom: { lte: now },
            OR: [{ validTo: null }, { validTo: { gte: now } }],
          },
          include: { certification: true },
          orderBy: { validFrom: 'desc' },
        },
      },
    });

    if (!seller) throw new NotFoundException('Seller not found');

    return {
      id: seller.id,
      name: seller.name,
      lat: seller.lat ? Number(seller.lat) : null,
      lng: seller.lng ? Number(seller.lng) : null,
      certifications: seller.certifications.map((sc) => ({
        code: sc.certification.code,
        name: sc.certification.name,
        issuer: sc.certification.issuer,
        validFrom: sc.validFrom,
        validTo: sc.validTo,
        evidenceUrl: sc.evidenceUrl,
      })),
    };
  }

  async listProductsBySeller(
    sellerId: string,
    pagination?: { page?: number; limit?: number },
  ) {
    const seller = await this.prisma.seller.findUnique({
      where: { id: sellerId },
      select: { id: true },
    });
    if (!seller) throw new NotFoundException('Seller not found');

    const page = pagination?.page ?? 1;
    const limit = pagination?.limit ?? 20;
    const skip = (page - 1) * limit;

    const where = { isActive: true, sellerId };

    const [items, total] = await Promise.all([
      this.prisma.product.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          categoryId: true,
          sellerId: true,
          name: true,
          basePrice: true,
          unit: true,
          thumbnailUrl: true,
        },
      }),
      this.prisma.product.count({ where }),
    ]);

    return {
      page,
      limit,
      total,
      items: items.map((p) => ({
        id: p.id,
        categoryId: p.categoryId,
        sellerId: p.sellerId,
        name: p.name,
        basePrice: Number(p.basePrice),
        unit: p.unit,
        thumbnailUrl: p.thumbnailUrl,
      })),
    };
  }

  private calculateFreshness(harvestedAt: Date | null, expiresAt: Date | null) {
    if (!expiresAt) return null;

    const now = new Date();
    const daysRemaining = Math.ceil(
      (expiresAt.getTime() - now.getTime()) / (1000 * 60 * 60 * 24),
    );

    let freshnessLevel: string;
    let message: string;

    if (daysRemaining <= 0) {
      freshnessLevel = 'EXPIRED';
      message = 'หมดอายุแล้ว';
    } else if (daysRemaining <= 2) {
      freshnessLevel = 'EXPIRING_SOON';
      message = `เหลือ ${daysRemaining} วัน`;
    } else if (daysRemaining <= 4) {
      freshnessLevel = 'FRESH';
      message = `สดดี เหลือ ${daysRemaining} วัน`;
    } else {
      freshnessLevel = 'VERY_FRESH';
      message = `สดมาก เหลือ ${daysRemaining} วัน`;
    }

    return {
      daysRemaining,
      freshnessLevel,
      message,
    };
  }
}
