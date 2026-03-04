import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '@prisma/client';

@Injectable()
export class CatalogService {
  constructor(private readonly prisma: PrismaService) {}
  private readonly allowedLotStatuses = ['ACTIVE', 'HOLD', 'EXHAUSTED'] as const;
  private readonly defaultInitialLotQuantity = 100;
  private readonly promotionPlans = [
    { planCode: 'BOOST_LITE', name: 'Boost Lite', pricePerDay: 49, minDays: 3 },
    { planCode: 'BOOST_PLUS', name: 'Boost Plus', pricePerDay: 99, minDays: 7 },
    { planCode: 'BOOST_MAX', name: 'Boost Max', pricePerDay: 199, minDays: 7 },
  ] as const;
  private isAllowedLotStatus(status: string) {
    return this.allowedLotStatuses.includes(
      status as (typeof this.allowedLotStatuses)[number],
    );
  }

  private getPromotionPlan(planCode: string) {
    return this.promotionPlans.find(
      (p) => p.planCode === planCode.trim().toUpperCase(),
    );
  }

  private async resolveManagedSeller(userId: string, role?: string) {
    const seller = await this.prisma.seller.findFirst({
      where: { userId },
      select: { id: true, userId: true },
    });
    if (seller) return seller;

    if (role === 'ADMIN') {
      const byId = await this.prisma.seller.findUnique({
        where: { id: userId },
        select: { id: true, userId: true },
      });
      if (byId) return byId;
    }

    throw new ForbiddenException('Seller account required');
  }

  private toPublicProduct(p: {
    id: string;
    categoryId: string;
    sellerId: string;
    name: string;
    basePrice: Prisma.Decimal;
    unit: string;
    thumbnailUrl: string | null;
    isActive?: boolean;
    description?: string | null;
  }) {
    return {
      id: p.id,
      categoryId: p.categoryId,
      sellerId: p.sellerId,
      name: p.name,
      basePrice: Number(p.basePrice),
      unit: p.unit,
      thumbnailUrl: p.thumbnailUrl,
      isActive: p.isActive ?? true,
      description: p.description ?? null,
    };
  }

  private toManagedLot(lot: {
    id: string;
    productId: string;
    sellerId: string;
    lotCode: string;
    harvestedAt: Date | null;
    packedAt: Date | null;
    expiresAt: Date | null;
    recommendedConsumeBefore: Date | null;
    storageCondition: string | null;
    quantityAvailable: Prisma.Decimal;
    status: string;
    createdAt: Date;
  }) {
    return {
      id: lot.id,
      productId: lot.productId,
      sellerId: lot.sellerId,
      lotCode: lot.lotCode,
      harvestedAt: lot.harvestedAt,
      packedAt: lot.packedAt,
      expiresAt: lot.expiresAt,
      recommendedConsumeBefore: lot.recommendedConsumeBefore,
      storageCondition: lot.storageCondition,
      quantityAvailable: Number(lot.quantityAvailable),
      status: lot.status,
      createdAt: lot.createdAt,
    };
  }

  private slugify(input: string) {
    return input
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9ก-๙\s-]/g, '')
      .replace(/\s+/g, '-')
      .replace(/-+/g, '-');
  }

  private buildAutoLotCode(productName: string) {
    const prefix = this.slugify(productName)
      .replace(/-/g, '')
      .slice(0, 10)
      .toUpperCase();
    const stamp = Date.now().toString(36).toUpperCase();
    const rand = Math.floor(Math.random() * 1000)
      .toString()
      .padStart(3, '0');
    return `${prefix || 'LOT'}-AUTO-${stamp}${rand}`;
  }

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

  async getMySeller(userId: string) {
    return this.prisma.seller.findFirst({
      where: { userId },
      select: {
        id: true,
        userId: true,
        name: true,
        type: true,
        phone: true,
        addressText: true,
        taxId: true,
        coverImageUrl: true,
        aboutText: true,
        lat: true,
        lng: true,
        status: true,
        createdAt: true,
      },
    });
  }

  async applySeller(
    userId: string,
    dto: {
      name: string;
      phone?: string;
      addressText?: string;
      type?: string;
      taxId?: string;
      coverImageUrl?: string;
      aboutText?: string;
      lat?: number | null;
      lng?: number | null;
    },
  ) {
    const existing = await this.prisma.seller.findFirst({
      where: { userId },
      select: { id: true },
    });
    if (existing) throw new ConflictException('Seller account already exists');

    if (!dto.name?.trim()) throw new BadRequestException('Seller name is required');

    const seller = await this.prisma.seller.create({
      data: {
        userId,
        type: dto.type?.trim() || 'FARM',
        name: dto.name.trim(),
        phone: dto.phone?.trim() || null,
        addressText: dto.addressText?.trim() || null,
        taxId: dto.taxId?.trim() || null,
        coverImageUrl: dto.coverImageUrl?.trim() || null,
        aboutText: dto.aboutText?.trim() || null,
        lat: dto.lat == null ? null : new Prisma.Decimal(dto.lat),
        lng: dto.lng == null ? null : new Prisma.Decimal(dto.lng),
        status: 'ACTIVE',
      },
      select: {
        id: true,
        userId: true,
        name: true,
        type: true,
        phone: true,
        addressText: true,
        taxId: true,
        coverImageUrl: true,
        aboutText: true,
        lat: true,
        lng: true,
        status: true,
      },
    });

    await this.prisma.user.update({
      where: { id: userId },
      data: { role: 'CUSTOMER_SELLER' },
    });

    return seller;
  }

  async updateMySeller(
    userId: string,
    role: string | undefined,
    dto: Partial<{
      name: string;
      phone?: string;
      addressText?: string;
      type?: string;
      taxId?: string;
      coverImageUrl?: string;
      aboutText?: string;
      lat?: number | null;
      lng?: number | null;
    }>,
  ) {
    const seller = await this.resolveManagedSeller(userId, role);

    if (dto.name !== undefined && !dto.name.trim()) {
      throw new BadRequestException('Seller name is required');
    }
    if (dto.lat !== undefined && Number.isNaN(Number(dto.lat))) {
      throw new BadRequestException('Invalid latitude');
    }
    if (dto.lng !== undefined && Number.isNaN(Number(dto.lng))) {
      throw new BadRequestException('Invalid longitude');
    }

    const updated = await this.prisma.seller.update({
      where: { id: seller.id },
      data: {
        name: dto.name === undefined ? undefined : dto.name.trim(),
        phone: dto.phone === undefined ? undefined : dto.phone.trim() || null,
        addressText:
          dto.addressText === undefined
            ? undefined
            : dto.addressText.trim() || null,
        type: dto.type === undefined ? undefined : dto.type.trim() || 'FARM',
        taxId: dto.taxId === undefined ? undefined : dto.taxId.trim() || null,
        coverImageUrl:
          dto.coverImageUrl === undefined
            ? undefined
            : dto.coverImageUrl.trim() || null,
        aboutText:
          dto.aboutText === undefined ? undefined : dto.aboutText.trim() || null,
        lat:
          dto.lat === undefined
            ? undefined
            : dto.lat === null
              ? null
              : new Prisma.Decimal(dto.lat),
        lng:
          dto.lng === undefined
            ? undefined
            : dto.lng === null
              ? null
              : new Prisma.Decimal(dto.lng),
      },
      select: {
        id: true,
        userId: true,
        name: true,
        type: true,
        phone: true,
        addressText: true,
        taxId: true,
        coverImageUrl: true,
        aboutText: true,
        lat: true,
        lng: true,
        status: true,
      },
    });

    return updated;
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
      items: items.map((p) => this.toPublicProduct(p)),
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
            OR: [{ expiresAt: null }, { expiresAt: { gte: now } }],
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
        phone: product.seller.phone,
        addressText: product.seller.addressText,
        coverImageUrl: product.seller.coverImageUrl,
        aboutText: product.seller.aboutText,
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
      phone: seller.phone,
      addressText: seller.addressText,
      coverImageUrl: seller.coverImageUrl,
      aboutText: seller.aboutText,
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
      items: items.map((p) => this.toPublicProduct(p)),
    };
  }

  async listManagedProducts(
    userId: string,
    role?: string,
    page = 1,
    limit = 30,
  ) {
    const seller = await this.resolveManagedSeller(userId, role);
    const sellerId = seller.id;

    const skip = (Math.max(1, page) - 1) * Math.max(1, limit);
    const take = Math.min(100, Math.max(1, limit));

    const where = { sellerId };
    const [items, total] = await Promise.all([
      this.prisma.product.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          categoryId: true,
          sellerId: true,
          name: true,
          description: true,
          basePrice: true,
          unit: true,
          thumbnailUrl: true,
          isActive: true,
        },
      }),
      this.prisma.product.count({ where }),
    ]);

    return {
      page: Math.max(1, page),
      limit: take,
      total,
      items: items.map((p) => this.toPublicProduct(p)),
    };
  }

  async getSellerDashboard(userId: string, role?: string, days = 7) {
    const seller = await this.resolveManagedSeller(userId, role);
    const sellerId = seller.id;
    const periodDays = [7, 14, 30].includes(days) ? days : 7;

    const now = new Date();
    const startOfToday = new Date(now);
    startOfToday.setHours(0, 0, 0, 0);
    const periodStart = new Date(startOfToday);
    periodStart.setDate(periodStart.getDate() - (periodDays - 1));
    const expiringInDays = 3;
    const expiringCutoff = new Date(now);
    expiringCutoff.setDate(expiringCutoff.getDate() + expiringInDays);

    const paidNotCancelledOrderFilter = {
      paymentStatus: 'PAID',
      orderStatus: { not: 'CANCELLED' as const },
    };

    const [
      salesTodayAgg,
      sales7dAgg,
      orderTodayDistinct,
      order7dDistinct,
      orderItems7d,
      activeProducts,
      pendingOrders,
      expiringLots,
    ] = await Promise.all([
      this.prisma.orderItem.aggregate({
        where: {
          sellerId,
          order: { ...paidNotCancelledOrderFilter, createdAt: { gte: startOfToday } },
        },
        _sum: { lineTotal: true, quantity: true },
      }),
      this.prisma.orderItem.aggregate({
        where: {
          sellerId,
          order: { ...paidNotCancelledOrderFilter, createdAt: { gte: periodStart } },
        },
        _sum: { lineTotal: true, quantity: true },
      }),
      this.prisma.orderItem.findMany({
        where: {
          sellerId,
          order: { orderStatus: { not: 'CANCELLED' }, createdAt: { gte: startOfToday } },
        },
        select: { orderId: true },
        distinct: ['orderId'],
      }),
      this.prisma.orderItem.findMany({
        where: {
          sellerId,
          order: { orderStatus: { not: 'CANCELLED' }, createdAt: { gte: periodStart } },
        },
        select: { orderId: true, order: { select: { createdAt: true } } },
        distinct: ['orderId'],
      }),
      this.prisma.orderItem.findMany({
        where: {
          sellerId,
          order: { ...paidNotCancelledOrderFilter, createdAt: { gte: periodStart } },
        },
        select: {
          productId: true,
          quantity: true,
          lineTotal: true,
          order: { select: { createdAt: true } },
          product: { select: { name: true } },
        },
      }),
      this.prisma.product.findMany({
        where: { sellerId, isActive: true },
        select: {
          id: true,
          name: true,
          inventoryLots: {
            where: { status: 'ACTIVE' },
            select: { quantityAvailable: true },
          },
        },
      }),
      this.prisma.order.findMany({
        where: {
          orderStatus: { in: ['CONFIRMED', 'PREPARING', 'SHIPPED'] },
          items: { some: { sellerId } },
        },
        select: { id: true },
      }),
      this.prisma.inventoryLot.findMany({
        where: {
          sellerId,
          status: 'ACTIVE',
          quantityAvailable: { gt: 0 },
          expiresAt: { not: null, lte: expiringCutoff, gte: now },
        },
        orderBy: { expiresAt: 'asc' },
        take: 10,
        select: {
          id: true,
          lotCode: true,
          expiresAt: true,
          quantityAvailable: true,
          product: { select: { id: true, name: true } },
        },
      }),
    ]);

    const lowStockThreshold = 10;
    const lowStockProducts = activeProducts
      .map((p) => ({
        id: p.id,
        name: p.name,
        totalQty: p.inventoryLots.reduce(
          (sum, lot) => sum + Number(lot.quantityAvailable),
          0,
        ),
      }))
      .filter((p) => p.totalQty <= lowStockThreshold)
      .sort((a, b) => a.totalQty - b.totalQty)
      .slice(0, 10);

    const byProduct = new Map<
      string,
      { productId: string; productName: string; totalAmount: number; totalQty: number }
    >();
    for (const row of orderItems7d) {
      const key = row.productId;
      const current = byProduct.get(key) ?? {
        productId: key,
        productName: row.product?.name ?? '-',
        totalAmount: 0,
        totalQty: 0,
      };
      current.totalAmount += Number(row.lineTotal);
      current.totalQty += Number(row.quantity);
      byProduct.set(key, current);
    }
    const topProductsPeriod = [...byProduct.values()]
      .sort((a, b) => b.totalAmount - a.totalAmount)
      .slice(0, 5);

    const soldByProduct = new Map<
      string,
      { productId: string; productName: string; totalAmount: number; totalQty: number }
    >();
    for (const row of orderItems7d) {
      const key = row.productId;
      const current = soldByProduct.get(key) ?? {
        productId: key,
        productName: row.product?.name ?? '-',
        totalAmount: 0,
        totalQty: 0,
      };
      current.totalAmount += Number(row.lineTotal);
      current.totalQty += Number(row.quantity);
      soldByProduct.set(key, current);
    }

    const allActiveProductStats = activeProducts
      .map((p) => {
        const sold = soldByProduct.get(p.id);
        return {
          productId: p.id,
          productName: p.name,
          totalQty: sold?.totalQty ?? 0,
          totalAmount: sold?.totalAmount ?? 0,
        };
      })
      .sort((a, b) => {
        if (a.totalQty != b.totalQty) return a.totalQty - b.totalQty;
        return a.totalAmount - b.totalAmount;
      });

    const bestSellerPeriod =
      allActiveProductStats
        .filter((p) => p.totalQty > 0)
        .sort((a, b) => {
          if (a.totalAmount != b.totalAmount) return b.totalAmount - a.totalAmount;
          return b.totalQty - a.totalQty;
        })[0] ?? null;

    const slowMovingProductsPeriod = allActiveProductStats.slice(0, 5);

    const byDay = new Map<string, { date: string; sales: number; orders: number }>();
    for (let i = periodDays - 1; i >= 0; i--) {
      const d = new Date(startOfToday);
      d.setDate(startOfToday.getDate() - i);
      const key = d.toISOString().slice(0, 10);
      byDay.set(key, { date: key, sales: 0, orders: 0 });
    }
    for (const row of orderItems7d) {
      const key = new Date(row.order.createdAt).toISOString().slice(0, 10);
      const item = byDay.get(key);
      if (!item) continue;
      item.sales += Number(row.lineTotal);
    }
    for (const row of order7dDistinct) {
      const key = new Date(row.order.createdAt).toISOString().slice(0, 10);
      const item = byDay.get(key);
      if (!item) continue;
      item.orders += 1;
    }
    const dailyTrendPeriod = [...byDay.values()];

    const recommendDays = periodDays >= 30 ? 7 : 3;
    const recommendationItems = slowMovingProductsPeriod
      .filter((p) => p.totalQty <= 0 || p.totalAmount <= 0)
      .slice(0, 3)
      .map((p, index) => {
        const selectedPlan = index === 0 ? this.promotionPlans[1] : this.promotionPlans[0];
        const recommendedDays = Math.max(recommendDays, selectedPlan.minDays);
        const estimatedCost = selectedPlan.pricePerDay * recommendedDays;
        return {
          type: 'PROMOTE_PRODUCT',
          productId: p.productId,
          productName: p.productName,
          reason:
            p.totalQty <= 0
              ? `${periodDays} วันล่าสุดยังไม่มียอดขาย`
              : `${periodDays} วันล่าสุดยอดขายต่ำ`,
          suggestedPlan: {
            ...selectedPlan,
            recommendedDays,
            estimatedCost,
            currency: 'THB',
          },
          billingNote:
            'จะยังไม่คิดเงินจนกว่าร้านค้ากดยืนยันเริ่มโปรโมตแคมเปญ',
        };
      });

    return {
      sellerId,
      generatedAt: now,
      periodDays,
      kpis: {
        salesToday: Number(salesTodayAgg._sum.lineTotal ?? 0),
        salesPeriod: Number(sales7dAgg._sum.lineTotal ?? 0),
        sales7d: Number(sales7dAgg._sum.lineTotal ?? 0),
        ordersToday: orderTodayDistinct.length,
        ordersPeriod: order7dDistinct.length,
        orders7d: order7dDistinct.length,
        unitsSoldPeriod: Number(sales7dAgg._sum.quantity ?? 0),
        unitsSold7d: Number(sales7dAgg._sum.quantity ?? 0),
        pendingShipmentOrders: pendingOrders.length,
      },
      inventory: {
        activeProducts: activeProducts.length,
        lowStockThreshold,
        lowStockProducts,
        expiringInDays,
        expiringLots: expiringLots.map((lot) => ({
          id: lot.id,
          lotCode: lot.lotCode,
          expiresAt: lot.expiresAt,
          quantityAvailable: Number(lot.quantityAvailable),
          product: lot.product,
        })),
      },
      topProductsPeriod,
      topProducts7d: topProductsPeriod,
      dailyTrendPeriod,
      dailyTrend7d: dailyTrendPeriod,
      insights: {
        bestSellerPeriod,
        bestSeller7d: bestSellerPeriod,
        slowMovingProductsPeriod,
        slowMovingProducts7d: slowMovingProductsPeriod,
        recommendations: recommendationItems,
        promotionCatalog: {
          plans: this.promotionPlans,
          billingRule: 'คิดเงินเมื่อกดเริ่มโปรโมตเท่านั้น',
        },
      },
    };
  }

  async listMyPromotionCampaigns(
    userId: string,
    role?: string,
    status?: string,
  ) {
    const seller = await this.resolveManagedSeller(userId, role);
    const where: Prisma.SellerPromotionCampaignWhereInput = {
      sellerId: seller.id,
    };
    if (status?.trim()) where.status = status.trim().toUpperCase();

    const rows = await this.prisma.sellerPromotionCampaign.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: 50,
      select: {
        id: true,
        productId: true,
        planCode: true,
        planName: true,
        pricePerDay: true,
        durationDays: true,
        estimatedCost: true,
        status: true,
        billingStatus: true,
        note: true,
        startsAt: true,
        endsAt: true,
        createdAt: true,
        product: { select: { name: true, thumbnailUrl: true } },
      },
    });

    return {
      total: rows.length,
      items: rows.map((r) => ({
        ...r,
        pricePerDay: Number(r.pricePerDay),
        estimatedCost: Number(r.estimatedCost),
      })),
    };
  }

  async startPromotionCampaign(
    userId: string,
    role: string | undefined,
    dto: {
      productId: string;
      planCode: string;
      days: number;
      note?: string;
    },
  ) {
    const seller = await this.resolveManagedSeller(userId, role);
    const sellerId = seller.id;
    if (!dto.productId?.trim()) throw new BadRequestException('productId is required');
    if (!dto.planCode?.trim()) throw new BadRequestException('planCode is required');

    const product = await this.prisma.product.findUnique({
      where: { id: dto.productId },
      select: { id: true, sellerId: true, isActive: true, name: true },
    });
    if (!product || product.sellerId !== sellerId) {
      throw new NotFoundException('Product not found');
    }
    if (!product.isActive) {
      throw new BadRequestException('Product must be active to promote');
    }

    const plan = this.getPromotionPlan(dto.planCode);
    if (!plan) {
      throw new BadRequestException(
        `Invalid planCode. Allowed: ${this.promotionPlans.map((p) => p.planCode).join(', ')}`,
      );
    }
    if (!Number.isFinite(dto.days) || dto.days < plan.minDays || dto.days > 30) {
      throw new BadRequestException(
        `Invalid days for ${plan.planCode}. Must be ${plan.minDays}-30`,
      );
    }

    const now = new Date();
    const endsAt = new Date(now);
    endsAt.setDate(endsAt.getDate() + dto.days);
    const estimatedCost = plan.pricePerDay * dto.days;

    const created = await this.prisma.sellerPromotionCampaign.create({
      data: {
        sellerId,
        productId: product.id,
        planCode: plan.planCode,
        planName: plan.name,
        pricePerDay: new Prisma.Decimal(plan.pricePerDay),
        durationDays: dto.days,
        estimatedCost: new Prisma.Decimal(estimatedCost),
        status: 'ACTIVE',
        billingStatus: 'PENDING',
        note: dto.note?.trim() || null,
        startsAt: now,
        endsAt,
      },
      select: {
        id: true,
        productId: true,
        planCode: true,
        planName: true,
        pricePerDay: true,
        durationDays: true,
        estimatedCost: true,
        status: true,
        billingStatus: true,
        note: true,
        startsAt: true,
        endsAt: true,
        createdAt: true,
      },
    });

    return {
      ...created,
      pricePerDay: Number(created.pricePerDay),
      estimatedCost: Number(created.estimatedCost),
      billingMessage:
        'แคมเปญถูกสร้างแล้ว ระบบจะคิดค่าใช้จ่ายตามแพ็กเกจที่เลือกตามรอบเรียกเก็บของแพลตฟอร์ม',
    };
  }

  async createManagedProduct(
    userId: string,
    role: string | undefined,
    dto: {
      categoryId: string;
      name: string;
      unit: string;
      basePrice: number;
      description?: string;
      thumbnailUrl?: string;
      isActive?: boolean;
    },
  ) {
    const seller = await this.resolveManagedSeller(userId, role);
    const sellerId = seller.id;

    const category = await this.prisma.category.findUnique({
      where: { id: dto.categoryId },
      select: { id: true },
    });
    if (!category) throw new NotFoundException('Category not found');

    const slugBase = this.slugify(dto.name);
    const slug = `${slugBase}-${Date.now().toString(36)}`;
    const created = await this.prisma.$transaction(async (tx) => {
      const product = await tx.product.create({
        data: {
          sellerId,
          categoryId: dto.categoryId,
          name: dto.name.trim(),
          slug,
          description: dto.description?.trim() || null,
          unit: dto.unit.trim(),
          basePrice: new Prisma.Decimal(dto.basePrice || 0),
          thumbnailUrl: dto.thumbnailUrl?.trim() || null,
          isActive: dto.isActive ?? true,
        },
        select: {
          id: true,
          categoryId: true,
          sellerId: true,
          name: true,
          description: true,
          basePrice: true,
          unit: true,
          thumbnailUrl: true,
          isActive: true,
        },
      });

      await tx.inventoryLot.create({
        data: {
          productId: product.id,
          sellerId,
          lotCode: this.buildAutoLotCode(product.name),
          quantityAvailable: new Prisma.Decimal(this.defaultInitialLotQuantity),
          status: 'ACTIVE',
          storageCondition: 'AUTO_DEFAULT',
        },
      });

      return product;
    });

    return this.toPublicProduct(created);
  }

  async updateManagedProduct(
    userId: string,
    role: string | undefined,
    id: string,
    dto: Partial<{
      categoryId: string;
      name: string;
      unit: string;
      basePrice: number;
      description?: string;
      thumbnailUrl?: string;
      isActive?: boolean;
    }>,
  ) {
    const seller = await this.resolveManagedSeller(userId, role);
    const sellerId = seller.id;
    const existing = await this.prisma.product.findUnique({
      where: { id },
      select: { id: true, sellerId: true },
    });
    if (!existing || existing.sellerId !== sellerId) {
      throw new NotFoundException('Product not found');
    }

    if (dto.categoryId) {
      const category = await this.prisma.category.findUnique({
        where: { id: dto.categoryId },
        select: { id: true },
      });
      if (!category) throw new NotFoundException('Category not found');
    }

    const data: Prisma.ProductUpdateInput = {
      category: dto.categoryId
        ? {
            connect: { id: dto.categoryId },
          }
        : undefined,
      name: dto.name?.trim() || undefined,
      unit: dto.unit?.trim() || undefined,
      description:
        dto.description === undefined ? undefined : dto.description.trim() || null,
      thumbnailUrl:
        dto.thumbnailUrl === undefined ? undefined : dto.thumbnailUrl.trim() || null,
      isActive: dto.isActive ?? undefined,
      basePrice:
        dto.basePrice === undefined
          ? undefined
          : new Prisma.Decimal(dto.basePrice),
    };

    const updated = await this.prisma.product.update({
      where: { id },
      data,
      select: {
        id: true,
        categoryId: true,
        sellerId: true,
        name: true,
        description: true,
        basePrice: true,
        unit: true,
        thumbnailUrl: true,
        isActive: true,
      },
    });

    return this.toPublicProduct(updated);
  }

  async toggleManagedProduct(
    userId: string,
    role: string | undefined,
    id: string,
    isActive: boolean,
  ) {
    const seller = await this.resolveManagedSeller(userId, role);
    const sellerId = seller.id;
    const existing = await this.prisma.product.findUnique({
      where: { id },
      select: { id: true, sellerId: true },
    });
    if (!existing || existing.sellerId !== sellerId) {
      throw new NotFoundException('Product not found');
    }

    const updated = await this.prisma.product.update({
      where: { id },
      data: { isActive },
      select: {
        id: true,
        categoryId: true,
        sellerId: true,
        name: true,
        description: true,
        basePrice: true,
        unit: true,
        thumbnailUrl: true,
        isActive: true,
      },
    });

    return this.toPublicProduct(updated);
  }

  async claimManagedProduct(
    userId: string,
    role: string | undefined,
    productId: string,
  ) {
    const seller = await this.resolveManagedSeller(userId, role);
    const mySellerId = seller.id;

    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      select: {
        id: true,
        sellerId: true,
        seller: { select: { id: true, userId: true } },
      },
    });
    if (!product) throw new NotFoundException('Product not found');

    if (product.sellerId === mySellerId) {
      const same = await this.prisma.product.findUnique({
        where: { id: productId },
        select: {
          id: true,
          categoryId: true,
          sellerId: true,
          name: true,
          description: true,
          basePrice: true,
          unit: true,
          thumbnailUrl: true,
          isActive: true,
        },
      });
      if (!same) throw new NotFoundException('Product not found');
      return { claimed: false, product: this.toPublicProduct(same) };
    }

    if (product.seller.userId && product.seller.userId !== userId) {
      throw new ForbiddenException('Product already belongs to another seller');
    }

    const claimed = await this.prisma.$transaction(async (tx) => {
      const updated = await tx.product.update({
        where: { id: productId },
        data: { sellerId: mySellerId },
        select: {
          id: true,
          categoryId: true,
          sellerId: true,
          name: true,
          description: true,
          basePrice: true,
          unit: true,
          thumbnailUrl: true,
          isActive: true,
        },
      });

      await tx.inventoryLot.updateMany({
        where: { productId, sellerId: product.sellerId },
        data: { sellerId: mySellerId },
      });

      return updated;
    });

    return { claimed: true, product: this.toPublicProduct(claimed) };
  }

  async listManagedLots(
    userId: string,
    role: string | undefined,
    productId: string,
  ) {
    const seller = await this.resolveManagedSeller(userId, role);
    const sellerId = seller.id;
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      select: { id: true, sellerId: true },
    });
    if (!product || product.sellerId !== sellerId) {
      throw new NotFoundException('Product not found');
    }

    const lots = await this.prisma.inventoryLot.findMany({
      where: { productId, sellerId },
      orderBy: [{ createdAt: 'desc' }],
      select: {
        id: true,
        productId: true,
        sellerId: true,
        lotCode: true,
        harvestedAt: true,
        packedAt: true,
        expiresAt: true,
        recommendedConsumeBefore: true,
        storageCondition: true,
        quantityAvailable: true,
        status: true,
        createdAt: true,
      },
    });

    return {
      productId,
      total: lots.length,
      items: lots.map((lot) => this.toManagedLot(lot)),
    };
  }

  async createManagedLot(
    userId: string,
    role: string | undefined,
    productId: string,
    dto: {
      lotCode?: string;
      harvestedAt?: string;
      packedAt?: string;
      expiresAt?: string;
      recommendedConsumeBefore?: string;
      storageCondition?: string;
      quantityAvailable: number;
      status?: string;
    },
  ) {
    const seller = await this.resolveManagedSeller(userId, role);
    const sellerId = seller.id;
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      select: { id: true, sellerId: true, name: true },
    });
    if (!product || product.sellerId !== sellerId) {
      throw new NotFoundException('Product not found');
    }

    if (!Number.isFinite(dto.quantityAvailable) || dto.quantityAvailable <= 0) {
      throw new BadRequestException('Quantity must be greater than 0');
    }

    const nowStamp = Date.now().toString(36);
    const lotCode =
      dto.lotCode?.trim() ||
      `${this.slugify(product.name || 'lot').replace(/-/g, '').slice(0, 8).toUpperCase()}-${nowStamp.toUpperCase()}`;

    const parseDate = (v?: string) => (v && v.trim() ? new Date(v) : null);
    const harvestedAt = parseDate(dto.harvestedAt);
    const packedAt = parseDate(dto.packedAt);
    const expiresAt = parseDate(dto.expiresAt);
    const recommendedConsumeBefore = parseDate(dto.recommendedConsumeBefore);

    const dates = [harvestedAt, packedAt, expiresAt, recommendedConsumeBefore];
    if (dates.some((d) => d !== null && Number.isNaN(d.getTime()))) {
      throw new BadRequestException('Invalid date format');
    }
    const normalizedStatus = dto.status?.trim().toUpperCase() || 'ACTIVE';
    if (!this.isAllowedLotStatus(normalizedStatus)) {
      throw new BadRequestException(
        `Invalid status. Allowed: ${this.allowedLotStatuses.join(', ')}`,
      );
    }

    try {
      const created = await this.prisma.inventoryLot.create({
        data: {
          productId,
          sellerId,
          lotCode,
          harvestedAt,
          packedAt,
          expiresAt,
          recommendedConsumeBefore,
          storageCondition: dto.storageCondition?.trim() || null,
          quantityAvailable: new Prisma.Decimal(dto.quantityAvailable),
          status: normalizedStatus,
        },
        select: {
          id: true,
          productId: true,
          sellerId: true,
          lotCode: true,
          harvestedAt: true,
          packedAt: true,
          expiresAt: true,
          recommendedConsumeBefore: true,
          storageCondition: true,
          quantityAvailable: true,
          status: true,
          createdAt: true,
        },
      });
      return this.toManagedLot(created);
    } catch (e: any) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new ConflictException('Lot code already exists');
      }
      throw e;
    }
  }

  async updateManagedLot(
    userId: string,
    role: string | undefined,
    lotId: string,
    dto: Partial<{
      lotCode?: string;
      harvestedAt?: string | null;
      packedAt?: string | null;
      expiresAt?: string | null;
      recommendedConsumeBefore?: string | null;
      storageCondition?: string | null;
      quantityAvailable?: number;
      status?: string;
    }>,
  ) {
    const seller = await this.resolveManagedSeller(userId, role);
    const sellerId = seller.id;
    const existing = await this.prisma.inventoryLot.findUnique({
      where: { id: lotId },
      select: { id: true, sellerId: true },
    });
    if (!existing || existing.sellerId !== sellerId) {
      throw new NotFoundException('Lot not found');
    }

    if (
      dto.quantityAvailable !== undefined &&
      (!Number.isFinite(dto.quantityAvailable) || dto.quantityAvailable < 0)
    ) {
      throw new BadRequestException('Quantity must be 0 or greater');
    }

    const parseDate = (v?: string | null) => {
      if (v === undefined) return undefined;
      if (v === null || v.trim() === '') return null;
      const d = new Date(v);
      if (Number.isNaN(d.getTime())) throw new BadRequestException('Invalid date format');
      return d;
    };

    const normalizedStatus =
      dto.status === undefined ? undefined : dto.status.trim().toUpperCase();
    if (
      normalizedStatus !== undefined &&
      !this.isAllowedLotStatus(normalizedStatus)
    ) {
      throw new BadRequestException(
        `Invalid status. Allowed: ${this.allowedLotStatuses.join(', ')}`,
      );
    }

    try {
      const updated = await this.prisma.inventoryLot.update({
        where: { id: lotId },
        data: {
          lotCode: dto.lotCode === undefined ? undefined : dto.lotCode.trim(),
          harvestedAt: parseDate(dto.harvestedAt),
          packedAt: parseDate(dto.packedAt),
          expiresAt: parseDate(dto.expiresAt),
          recommendedConsumeBefore: parseDate(dto.recommendedConsumeBefore),
          storageCondition:
            dto.storageCondition === undefined
              ? undefined
              : dto.storageCondition?.trim() || null,
          quantityAvailable:
            dto.quantityAvailable === undefined
              ? undefined
              : new Prisma.Decimal(dto.quantityAvailable),
          status: normalizedStatus,
        },
        select: {
          id: true,
          productId: true,
          sellerId: true,
          lotCode: true,
          harvestedAt: true,
          packedAt: true,
          expiresAt: true,
          recommendedConsumeBefore: true,
          storageCondition: true,
          quantityAvailable: true,
          status: true,
          createdAt: true,
        },
      });
      return this.toManagedLot(updated);
    } catch (e: any) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new ConflictException('Lot code already exists');
      }
      throw e;
    }
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
