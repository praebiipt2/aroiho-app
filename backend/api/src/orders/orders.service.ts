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

  // สร้างเลขออเดอร์แบบง่าย ๆ (ปรับ format ได้ทีหลัง)
  private genOrderNo() {
    const now = new Date();
    const y = now.getFullYear().toString().slice(2);
    const m = String(now.getMonth() + 1).padStart(2, '0');
    const d = String(now.getDate()).padStart(2, '0');
    const rand = Math.random().toString(16).slice(2, 8).toUpperCase();
    return `OR${y}${m}${d}-${rand}`;
  }

  /**
   * Checkout:
   * - ใช้ cart ACTIVE ของ user
   * - ต้องมี address ที่จะส่ง (addressId)
   * - สร้าง order + orderItems
   * - (เวอร์ชันนี้ยังไม่ตัด stock / ยังไม่สร้าง payment record แบบเต็ม)
   */
  async checkout(userId: string, addressId: string) {
    // 1) เช็ค address เป็นของ user จริงไหม
    const address = await this.prisma.address.findFirst({
      where: { id: addressId, userId },
      select: { id: true },
    });
    if (!address) throw new NotFoundException('Address not found');

    // 2) ดึง cart + items + inventoryLot (สำคัญมากเพื่อเอา sellerId)
    const cart = await this.prisma.cart.findFirst({
      where: { userId, status: 'ACTIVE' },
      include: {
        items: {
          include: {
            inventoryLot: true, // ✅ ต้องมี
          },
        },
      },
    });

    if (!cart) throw new NotFoundException('Cart not found');
    if (!cart.items || cart.items.length === 0) {
      throw new BadRequestException('Cart is empty');
    }

    // 3) คำนวณยอด
    const subtotal = cart.items.reduce((acc, item) => {
      const qty = new Prisma.Decimal(item.quantity);
      const price = new Prisma.Decimal(item.unitPrice);
      return acc.add(price.mul(qty));
    }, new Prisma.Decimal(0));

    const deliveryFee = new Prisma.Decimal(0);
    const discount = new Prisma.Decimal(0);
    const total = subtotal.add(deliveryFee).sub(discount);

    // 4) สร้าง order + items
    const order = await this.prisma.order.create({
      data: {
        orderNo: this.genOrderNo(),
        userId,
        addressId,

        // ❌ ห้ามใช้ status (ไม่มีใน schema)
        paymentStatus: 'PENDING',
        // orderStatus ปล่อย default CONFIRMED ก็ได้ แต่ใส่ไว้ชัด ๆ ก็ได้
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
              sellerId: item.inventoryLot.sellerId, // ✅ มาจาก include inventoryLot
              quantity: qty,
              unitPrice: price,
              lineTotal: price.mul(qty),
            };
          }),
        },
      },
      include: { items: true },
    });

    // 5) เคลียร์ cart items (หรือจะเปลี่ยนสถานะ cart เป็น CHECKED_OUT ก็ได้)
    await this.prisma.cartItem.deleteMany({ where: { cartId: cart.id } });

    return order;
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