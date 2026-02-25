import { Module } from '@nestjs/common';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';
import { PrismaService } from '../prisma/prisma.service';
import { TrackingModule } from '../tracking/tracking.module';
import { OrdersPurgeRunner } from './orders-purge.runner';

@Module({
  imports: [TrackingModule],
  controllers: [OrdersController],
  providers: [OrdersService, PrismaService, OrdersPurgeRunner],
})
export class OrdersModule {}
