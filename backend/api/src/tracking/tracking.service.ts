import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { TrackingEventType } from '@prisma/client';

@Injectable()
export class TrackingService {
  constructor(private readonly prisma: PrismaService) {}

  async getMyOrderTracking(userId: string, orderId: string) {
    const order = await this.prisma.order.findFirst({
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