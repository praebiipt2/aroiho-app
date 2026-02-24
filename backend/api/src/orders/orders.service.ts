import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import {
  Prisma,
  TrackingEventType,
  ShippingMethod,
  ShipmentStatus,
  TransportMode,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { ALLOWED_TRANSITIONS } from './order-transition.rules';
import { TransitionOrderDto } from './dto/transition-order.dto';

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

  // เพิ่ม shippingMethod (default = AUTO)
  async checkout(
    userId: string,
    addressId: string,
    shippingMethod: ShippingMethod = ShippingMethod.AUTO,
    shippingSurcharge = 0,
  ) {
    return this.prisma.$transaction(async (tx) => {
      const address = await tx.address.findFirst({
        where: { id: addressId, userId },
        select: { id: true },
      });
      if (!address) throw new NotFoundException('Address not found');

      const cart = await tx.cart.findFirst({
        where: { userId, status: 'ACTIVE' },
        include: { items: { include: { inventoryLot: true } } },
      });

      if (!cart) throw new NotFoundException('Cart not found');
      if (!cart.items?.length) throw new BadRequestException('Cart is empty');

      // กัน qty และตัดสต็อก
      for (const item of cart.items) {
        const qty = new Prisma.Decimal(item.quantity);
        if (qty.lte(0)) throw new BadRequestException('Invalid quantity');

        const updated = await tx.inventoryLot.updateMany({
          where: {
            id: item.inventoryLotId,
            status: 'ACTIVE',
            quantityAvailable: { gte: qty },
          },
          data: { quantityAvailable: { decrement: qty } },
        });

        if (updated.count === 0) {
          const lotCode = item.inventoryLot?.lotCode ?? item.inventoryLotId;
          throw new BadRequestException(`Out of stock: ${lotCode}`);
        }
      }

      const subtotal = cart.items.reduce((acc, item) => {
        const qty = new Prisma.Decimal(item.quantity);
        const price = new Prisma.Decimal(item.unitPrice);
        return acc.add(price.mul(qty));
      }, new Prisma.Decimal(0));

      const method = shippingMethod ?? ShippingMethod.AUTO;
      const effectiveMethod = method === ShippingMethod.AUTO ? ShippingMethod.GROUND : method;
      const baseDeliveryFee = effectiveMethod === ShippingMethod.AIR ? 240 : 40;
      const surcharge = Math.max(0, shippingSurcharge || 0);
      const deliveryFee = new Prisma.Decimal(baseDeliveryFee + surcharge);
      const discount = new Prisma.Decimal(0);
      const total = subtotal.add(deliveryFee).sub(discount);

      //  สร้าง order + ใส่ shippingMethod
      const order = await tx.order.create({
        data: {
          orderNo: this.genOrderNo(),
          userId,
          addressId,
          shippingMethod, // ✅ NEW
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

      await tx.orderStatusHistory.create({
        data: {
          orderId: order.id,
          fromStatus: 'CONFIRMED',
          toStatus: 'CONFIRMED',
          changedByUserId: userId,
          note: 'Order created',
        },
      });

      // สร้าง shipment + legs ตามวิธีจัดส่ง
      // AUTO ให้ทำเหมือน GROUND ไปก่อน (ภายหลังค่อยใส่ rule เลือก AIR)
      await tx.shipment.create({
        data: {
          orderId: order.id,
          status: ShipmentStatus.PLANNED,
          legs: {
            create:
              effectiveMethod === ShippingMethod.AIR
                ? [
                    {
                      seq: 1,
                      mode: TransportMode.TRUCK,
                      status: ShipmentStatus.PLANNED,
                      fromName: 'Seller',
                      toName: 'Origin Hub',
                    },
                    {
                      seq: 2,
                      mode: TransportMode.FLIGHT,
                      status: ShipmentStatus.PLANNED,
                      fromName: 'Origin Airport',
                      toName: 'Destination Airport',
                      flightNo: 'TBD',
                      meta: { note: 'flight info will be assigned later' },
                    },
                    {
                      seq: 3,
                      mode: TransportMode.TRUCK,
                      status: ShipmentStatus.PLANNED,
                      fromName: 'Destination Hub',
                      toName: 'Customer',
                    },
                  ]
                : [
                    {
                      seq: 1,
                      mode: TransportMode.TRUCK,
                      status: ShipmentStatus.PLANNED,
                      fromName: 'Seller',
                      toName: 'Customer',
                    },
                  ],
          },
        },
      });

      //  tracking auto
      await tx.trackingEvent.create({
        data: { orderId: order.id, type: TrackingEventType.ORDER_CREATED, message: 'สร้างคำสั่งซื้อแล้ว' },
      });
      await tx.trackingEvent.create({
        data: { orderId: order.id, type: TrackingEventType.PAYMENT_PENDING, message: 'รอการชำระเงิน' },
      });

      // tracking note: ลูกค้าเลือกวิธีจัดส่ง
      await tx.trackingEvent.create({
        data: {
          orderId: order.id,
          type: TrackingEventType.NOTE,
          message: `เลือกวิธีจัดส่ง: ${effectiveMethod} (ค่าจัดส่ง ${baseDeliveryFee + surcharge} บาท)`,
          meta: {
            shippingMethod: effectiveMethod,
            shippingBaseFee: baseDeliveryFee,
            shippingSurcharge: surcharge,
          },
        },
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

      if (order.orderStatus === 'CANCELLED') {
        return tx.order.findUnique({
          where: { id: order.id },
          include: { items: true, payments: true, address: true },
        });
      }

      for (const item of order.items) {
        const qty = new Prisma.Decimal(item.quantity);
        await tx.inventoryLot.update({
          where: { id: item.inventoryLotId },
          data: { quantityAvailable: { increment: qty } },
        });
      }

      const updated = await tx.order.update({
        where: { id: order.id },
        data: { orderStatus: 'CANCELLED' },
        include: { items: true, payments: true, address: true },
      });

      await tx.orderStatusHistory.create({
        data: {
          orderId: order.id,
          fromStatus: order.orderStatus,
          toStatus: 'CANCELLED',
          changedByUserId: userId,
          note: 'Cancelled by customer',
        },
      });

      // tracking auto
      await tx.trackingEvent.create({
        data: { orderId: order.id, type: TrackingEventType.CANCELLED, message: 'ยกเลิกคำสั่งซื้อ', meta: { by: 'customer' } },
      });

      return updated;
    });
  }

  async refund(userId: string, orderId: string) {
    return this.prisma.$transaction(async (tx) => {
      const order = await tx.order.findFirst({
        where: { id: orderId, userId },
        include: { items: true, payments: true },
      });
      if (!order) throw new NotFoundException('Order not found');

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

      if (order.paymentStatus !== 'PAID') {
        throw new BadRequestException('Only PAID orders can be refunded');
      }
      if (order.orderStatus === 'DELIVERED') {
        throw new BadRequestException('Refund not allowed after delivery');
      }

      for (const item of order.items) {
        const qty = new Prisma.Decimal(item.quantity);
        await tx.inventoryLot.update({
          where: { id: item.inventoryLotId },
          data: { quantityAvailable: { increment: qty } },
        });
      }

      const lastPaid = [...order.payments].reverse().find((p) => p.status === 'PAID') ?? null;

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

      const updated = await tx.order.update({
        where: { id: order.id },
        data: { paymentStatus: 'REFUNDED', orderStatus: 'CANCELLED' },
        include: { items: true, payments: true, address: true },
      });

      await tx.orderStatusHistory.create({
        data: {
          orderId: order.id,
          fromStatus: order.orderStatus,
          toStatus: 'CANCELLED',
          changedByUserId: userId,
          note: 'Refunded and cancelled',
        },
      });

      //tracking auto
      await tx.trackingEvent.create({
        data: { orderId: order.id, type: TrackingEventType.REFUND_REQUESTED, message: 'เริ่มดำเนินการคืนเงิน', meta: { by: 'customer' } },
      });
      await tx.trackingEvent.create({
        data: { orderId: order.id, type: TrackingEventType.REFUNDED, message: 'คืนเงินสำเร็จ', meta: { by: 'system' } },
      });
      await tx.trackingEvent.create({
        data: { orderId: order.id, type: TrackingEventType.CANCELLED, message: 'ปิดคำสั่งซื้อ (ยกเลิก)' },
      });

      return updated;
    });
  }

  async transition(orderId: string, actorUserId: string, dto: TransitionOrderDto) {
    return this.prisma.$transaction(async (tx) => {
      const order = await tx.order.findUnique({ where: { id: orderId } });
      if (!order) throw new NotFoundException('Order not found');

      const from = order.orderStatus;
      const to = dto.to;

      const allowed = ALLOWED_TRANSITIONS[from as keyof typeof ALLOWED_TRANSITIONS] ?? [];
      if (!allowed.includes(to)) {
        throw new BadRequestException(`Invalid transition: ${from} -> ${to}`);
      }

      const updated = await tx.order.update({
        where: { id: orderId },
        data: { orderStatus: to },
      });

      await tx.orderStatusHistory.create({
        data: {
          orderId,
          fromStatus: from,
          toStatus: to,
          changedByUserId: actorUserId,
          note: dto.note ?? null,
        },
      });

      // tracking auto: map สถานะเป็น event
      const map: Record<string, TrackingEventType | undefined> = {
        PREPARING: TrackingEventType.PREPARING,
        SHIPPED: TrackingEventType.IN_TRANSIT,
        DELIVERED: TrackingEventType.DELIVERED,
        CANCELLED: TrackingEventType.CANCELLED,
      };

      const ev = map[to];
      if (ev) {
        await tx.trackingEvent.create({
          data: {
            orderId,
            type: ev,
            message: dto.note ?? undefined,
            meta: { from, to },
          },
        });
      }

      return updated;
    });
  }

  async getHistory(userId: string, orderId: string) {
    const order = await this.prisma.order.findFirst({
      where: { id: orderId, userId },
      select: { id: true },
    });
    if (!order) throw new NotFoundException('Order not found');

    return this.prisma.orderStatusHistory.findMany({
      where: { orderId },
      orderBy: { createdAt: 'asc' },
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
  async getMyShipment(userId: string, orderId: string) {
  const order = await this.prisma.order.findFirst({
    where: { id: orderId, userId },
    select: { id: true },
  });
  if (!order) throw new NotFoundException('Order not found');

  return this.prisma.shipment.findUnique({
    where: { orderId },
    include: { legs: { orderBy: { seq: 'asc' } } },
  });
}
}
