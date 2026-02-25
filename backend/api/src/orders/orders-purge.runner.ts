import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { OrdersService } from './orders.service';

@Injectable()
export class OrdersPurgeRunner implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(OrdersPurgeRunner.name);
  private timer?: NodeJS.Timeout;

  constructor(private readonly ordersService: OrdersService) {}

  onModuleInit() {
    this.timer = setInterval(() => {
      this.ordersService
        .purgeExpiredDeletedOrders()
        .catch((e) => this.logger.error(`Purge failed: ${String(e)}`));
    }, 60 * 60 * 1000);
    this.logger.log('Order purge runner started (every 1 hour)');
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
    this.timer = undefined;
  }
}
