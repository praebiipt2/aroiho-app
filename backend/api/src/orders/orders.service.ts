import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class OrdersService {
  constructor(private readonly prisma: PrismaService) {}

  private genOrderNo() {
    const now = new Date();
    const y = now.getFullYear().toString().slice(2);
    const m = String(now.getMonth() + 1).padStart(2, '0');
    const d = String(now.getDate()).padStart(2, '0');
    const rand = Math.random().toString(16).slice(2, 8).toUpperCase();
    return `OR${y}${m}${d}-${rand}`;
  }

  async checkout(userId: string, addressId: string) {
    return this.prisma.$transaction(async (tx) => {
      const address = await tx.address.findFirst({
        where: { id: addressId, userId },
        select: { id: true },
      });
      if (!address) throw new NotFoundException('Address not found');

      const cart = await tx.cart.findFirst({
        where: { userId, status: 'ACTIVE' },
        include: {
          items: {
            include: { inventoryLot: true },
          },
        },
      });

      if (!cart) throw new NotFoundException('Cart not found');
      if (!cart.items || cart.items.length === 0) {
        throw new BadRequestException('Cart is empty');
      }

      // ตัดสต็อกกัน oversell
      for (const item of cart.items) {
        const qty = new Prisma.Decimal(item.quantity);
        if (qty.lte(0)) throw new BadRequestException('Invalid quantity');

        const updated = await tx.inventoryLot.updateMany({
          where: {
            id: item.inventoryLotId,
            status: 'ACTIVE',
            quantityAvailable: { gte: qty },
          },
          data: {
            quantityAvailable: { decrement: qty },
          },
        });

        if (updated.count === 0) {
          const lotCode = item.inventoryLot?.lotCode ?? item.inventoryLotId;
          throw new BadRequestException(`Out of stock: ${lotCode}`);
        }
      }

      // คำนวณยอด
      const subtotal = cart.items.reduce((acc, item) => {
        const qty = new Prisma.Decimal(item.quantity);
        const price = new Prisma.Decimal(item.unitPrice);
        return acc.add(price.mul(qty));
      }, new Prisma.Decimal(0));

      const deliveryFee = new Prisma.Decimal(0);
      const discount = new Prisma.Decimal(0);
      const total = subtotal.add(deliveryFee).sub(discount);

      const order = await tx.order.create({
        data: {
          orderNo: this.genOrderNo(),
          userId,
          addressId,
          paymentStatus: 'PENDING',
          orderStatus: 'CONFIRMED',
          subtotal,
          deliveryFee,
          discount,
          total,
          items: {
            create: cart.items.map((item) => {
              const qty = new Prisma.Decimal(item.quantity);
              const price = new Prisma.Decimal(item.unitPrice);
              return {
                productId: item.productId,
                inventoryLotId: item.inventoryLotId,
                sellerId: item.inventoryLot.sellerId,
                quantity: qty,
                unitPrice: price,
                lineTotal: price.mul(qty),
              };
            }),
          },
        },
        include: { items: true },
      });

      await tx.cartItem.deleteMany({ where: { cartId: cart.id } });
      return order;
    });
  }

  async cancel(userId: string, orderId: string) {
    return this.prisma.$transaction(async (tx) => {
      const order = await tx.order.findFirst({
        where: { id: orderId, userId },
        include: { items: true },
      });
      if (!order) throw new NotFoundException('Order not found');

      if (order.paymentStatus !== 'PENDING') {
        throw new BadRequestException('Only PENDING orders can be cancelled');
      }
      if (order.orderStatus === 'SHIPPED' || order.orderStatus === 'DELIVERED') {
        throw new BadRequestException('Order cannot be cancelled after shipping');
      }

      // idempotent
      if (order.orderStatus === 'CANCELLED') {
        return tx.order.findUnique({
          where: { id: order.id },
          include: { items: true, payments: true, address: true },
        });
      }

      // คืน stock
      for (const item of order.items) {
        const qty = new Prisma.Decimal(item.quantity);
        await tx.inventoryLot.update({
          where: { id: item.inventoryLotId },
          data: { quantityAvailable: { increment: qty } },
        });
      }

      return tx.order.update({
        where: { id: order.id },
        data: { orderStatus: 'CANCELLED' },
        include: { items: true, payments: true, address: true },
      });
    });
  }

  async refund(userId: string, orderId: string) {
    return this.prisma.$transaction(async (tx) => {
      const order = await tx.order.findFirst({
        where: { id: orderId, userId },
        include: { items: true, payments: true },
      });
      if (!order) throw new NotFoundException('Order not found');

      // ✅ idempotent ต้องเช็คก่อน: ยิงซ้ำแล้วคืน order เดิม ไม่ error ไม่คืน stock ซ้ำ
      const alreadyRefunded =
        order.paymentStatus === 'REFUNDED' ||
        order.orderStatus === 'CANCELLED' ||
        order.payments.some((p) => p.status === 'REFUNDED');

      if (alreadyRefunded) {
        return tx.order.findUnique({
          where: { id: order.id },
          include: { items: true, payments: true, address: true },
        });
      }

      // ✅ เงื่อนไข refund
      if (order.paymentStatus !== 'PAID') {
        throw new BadRequestException('Only PAID orders can be refunded');
      }
      if (order.orderStatus === 'DELIVERED') {
        throw new BadRequestException('Refund not allowed after delivery');
      }

      // ✅ คืน stock
      for (const item of order.items) {
        const qty = new Prisma.Decimal(item.quantity);
        await tx.inventoryLot.update({
          where: { id: item.inventoryLotId },
          data: { quantityAvailable: { increment: qty } },
        });
      }

      // ✅ audit trail: เพิ่ม payment record REFUNDED
      const lastPaid =
        [...order.payments].reverse().find((p) => p.status === 'PAID') ?? null;

      await tx.payment.create({
        data: {
          orderId: order.id,
          provider: lastPaid?.provider ?? 'UNKNOWN',
          providerRef: lastPaid?.providerRef ?? null,
          amount: order.total,
          status: 'REFUNDED',
          paidAt: new Date(),
        },
      });

      // ✅ อัปเดต order
      return tx.order.update({
        where: { id: order.id },
        data: { paymentStatus: 'REFUNDED', orderStatus: 'CANCELLED' },
        include: { items: true, payments: true, address: true },
      });
    });
  }

  async getOrder(userId: string, orderId: string) {
    const order = await this.prisma.order.findFirst({
      where: { id: orderId, userId },
      include: { items: true, address: true, payments: true },
    });
    if (!order) throw new NotFoundException('Order not found');
    return order;
  }

  async listMyOrders(userId: string) {
    return this.prisma.order.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      include: { items: true },
    });
  }
}