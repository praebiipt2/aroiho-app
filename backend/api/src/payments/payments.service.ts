import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class PaymentsService {
  constructor(private readonly prisma: PrismaService) {}

  async createIntent(userId: string, orderId: string, provider: string) {
    const order = await this.prisma.order.findFirst({
      where: { id: orderId, userId },
    });

    if (!order) throw new NotFoundException('Order not found');
    if (order.paymentStatus !== 'PENDING') {
      throw new BadRequestException('Order already paid or invalid');
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
    };
  }

  async webhook(paymentId: string, event: string) {
    const payment = await this.prisma.payment.findUnique({
      where: { id: paymentId },
      include: { order: true },
    });

    if (!payment) throw new NotFoundException('Payment not found');

    if (event === 'PAYMENT_SUCCESS') {
      await this.prisma.$transaction(async (tx) => {
        await tx.payment.update({
          where: { id: paymentId },
          data: { status: 'PAID', paidAt: new Date() },
        });

        await tx.order.update({
          where: { id: payment.orderId },
          data: { paymentStatus: 'PAID', orderStatus: 'PREPARING' },
        });
      });

      return { success: true };
    }

    if (event === 'PAYMENT_FAILED') {
      await this.prisma.payment.update({
        where: { id: paymentId },
        data: { status: 'FAILED' },
      });
      return { success: true };
    }

    throw new BadRequestException('Unknown event');
  }
}