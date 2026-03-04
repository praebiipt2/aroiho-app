import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { TrackingEventType } from '@prisma/client';

@Injectable()
export class TrackingService {
  constructor(private readonly prisma: PrismaService) {}

  private mapOrderStatusToTracking(orderStatus: string): TrackingEventType | null {
    switch (orderStatus) {
      case 'PREPARING':
        return TrackingEventType.PREPARING;
      case 'SHIPPED':
        return TrackingEventType.IN_TRANSIT;
      case 'DELIVERED':
        return TrackingEventType.DELIVERED;
      case 'CANCELLED':
        return TrackingEventType.CANCELLED;
      default:
        return null;
    }
  }

  private async ensureBaselineEvents(order: {
    id: string;
    paymentStatus: string;
    orderStatus: string;
    createdAt: Date;
    trackingEvents: Array<{ id: string }>;
  }) {
    if (order.trackingEvents.length > 0) return;

    await this.prisma.$transaction(async (tx) => {
      await tx.trackingEvent.create({
        data: {
          orderId: order.id,
          type: TrackingEventType.ORDER_CREATED,
          message: 'สร้างคำสั่งซื้อแล้ว',
          createdAt: order.createdAt,
        },
      });

      if (order.paymentStatus === 'PAID') {
        await tx.trackingEvent.create({
          data: {
            orderId: order.id,
            type: TrackingEventType.PAYMENT_CONFIRMED,
            message: 'ชำระเงินสำเร็จ',
          },
        });
      } else {
        await tx.trackingEvent.create({
          data: {
            orderId: order.id,
            type: TrackingEventType.PAYMENT_PENDING,
            message: 'รอการชำระเงิน',
          },
        });
      }

      const mapped = this.mapOrderStatusToTracking(order.orderStatus);
      if (mapped) {
        await tx.trackingEvent.create({
          data: {
            orderId: order.id,
            type: mapped,
            message: `สถานะคำสั่งซื้อ: ${order.orderStatus}`,
          },
        });
      }
    });
  }

  async getMyOrderTracking(userId: string, orderId: string) {
    let order = await this.prisma.order.findFirst({
      where: { id: orderId, userId },
      select: {
        id: true,
        orderNo: true,
        paymentStatus: true,
        orderStatus: true,
        createdAt: true,
        trackingEvents: {
          orderBy: { createdAt: 'asc' },
          select: { id: true, type: true, message: true, meta: true, createdAt: true },
        },
      },
    });

    if (!order) throw new NotFoundException('Order not found');
    await this.ensureBaselineEvents(order);

    // reload after backfill to return latest event list
    order = await this.prisma.order.findFirst({
      where: { id: orderId, userId },
      select: {
        id: true,
        orderNo: true,
        paymentStatus: true,
        orderStatus: true,
        createdAt: true,
        trackingEvents: {
          orderBy: { createdAt: 'asc' },
          select: { id: true, type: true, message: true, meta: true, createdAt: true },
        },
      },
    });
    if (!order) throw new NotFoundException('Order not found');

    return {
      orderId: order.id,
      orderNo: order.orderNo,
      paymentStatus: order.paymentStatus,
      orderStatus: order.orderStatus,
      createdAt: order.createdAt,
      events: order.trackingEvents,
    };
  }

  async createEvent(params: { orderId: string; type: TrackingEventType; message?: string; meta?: any }) {
    return this.prisma.trackingEvent.create({
      data: {
        orderId: params.orderId,
        type: params.type,
        message: params.message,
        meta: params.meta,
      },
    });
  }

  async addEventForMyOrder(
    userId: string,
    orderId: string,
    dto: { type: TrackingEventType; message?: string; meta?: any },
  ) {
    const order = await this.prisma.order.findFirst({
      where: { id: orderId, userId },
      select: { id: true },
    });
    if (!order) throw new NotFoundException('Order not found');

    return this.createEvent({ orderId, type: dto.type, message: dto.message, meta: dto.meta });
  }
}
