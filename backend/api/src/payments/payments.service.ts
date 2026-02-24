import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { TrackingEventType } from '@prisma/client';

@Injectable()
export class PaymentsService {
  constructor(private readonly prisma: PrismaService) {}

  async createIntent(userId: string, orderId: string, provider: string) {
    const order = await this.prisma.order.findFirst({
      where: { id: orderId, userId },
      include: { payments: true },
    });

    if (!order) throw new NotFoundException('Order not found');

    // กัน order ที่จบแล้ว
    if (order.orderStatus === 'CANCELLED') {
      throw new BadRequestException('Order is cancelled');
    }
    if (order.paymentStatus !== 'PENDING') {
      throw new BadRequestException('Order already paid or invalid');
    }

    // กันสร้าง payment pending ซ้ำ: ถ้ามี pending อยู่แล้ว reuse
    const existingPending = order.payments.find((p) => p.status === 'PENDING');
    if (existingPending) {
      return {
        paymentId: existingPending.id,
        status: existingPending.status,
        amount: existingPending.amount,
        mockQrText: `PROMPTPAY|ORDER:${order.orderNo}|AMOUNT:${order.total}`,
        reused: true,
      };
    }

    const payment = await this.prisma.payment.create({
      data: {
        orderId,
        provider,
        amount: order.total,
        status: 'PENDING',
      },
    });

    return {
      paymentId: payment.id,
      status: payment.status,
      amount: payment.amount,
      mockQrText: `PROMPTPAY|ORDER:${order.orderNo}|AMOUNT:${order.total}`,
      reused: false,
    };
  }

  async webhook(paymentId: string, event: string) {
    const payment = await this.prisma.payment.findUnique({
      where: { id: paymentId },
      include: { order: true },
    });

    if (!payment) throw new NotFoundException('Payment not found');

    // idempotent: ถ้าจ่ายแล้ว ยิงซ้ำให้ผ่าน
    if (event === 'PAYMENT_SUCCESS') {
      if (payment.status === 'PAID') return { success: true, idempotent: true };

      await this.prisma.$transaction(async (tx) => {
        // 1) update payment
        await tx.payment.update({
          where: { id: paymentId },
          data: { status: 'PAID', paidAt: new Date() },
        });

        // 2) update order
        const orderBefore = payment.order.orderStatus;

        await tx.order.update({
          where: { id: payment.orderId },
          data: { paymentStatus: 'PAID', orderStatus: 'PREPARING' },
        });

        // 3) history
        await tx.orderStatusHistory.create({
          data: {
            orderId: payment.orderId,
            fromStatus: orderBefore,
            toStatus: 'PREPARING',
            changedByUserId: null,
            note: `Payment success (${payment.provider})`,
          },
        });

        // 4) tracking events (ต้องอยู่ใน transaction)
        await tx.trackingEvent.create({
          data: {
            orderId: payment.orderId,
            type: TrackingEventType.PAYMENT_CONFIRMED,
            message: `ชำระเงินสำเร็จ (${payment.provider})`,
            meta: { provider: payment.provider, paymentId },
          },
        });

        await tx.trackingEvent.create({
          data: {
            orderId: payment.orderId,
            type: TrackingEventType.PREPARING,
            message: 'เริ่มเตรียมสินค้า',
          },
        });
      });

      return { success: true };
    }

    if (event === 'PAYMENT_FAILED') {
      if (payment.status === 'FAILED') return { success: true, idempotent: true };

      await this.prisma.payment.update({
        where: { id: paymentId },
        data: { status: 'FAILED' },
      });

      return { success: true };
    }

    throw new BadRequestException('Unknown event');
  }
}