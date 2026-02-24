import { Module } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ShippingController } from './shipping.controller';
import { ShippingQueryController } from './shipping.query.controller';
import { ShippingService } from './shipping.service';
import { RolesGuard } from '../auth/roles.guard';

@Module({
  controllers: [ShippingController, ShippingQueryController],
  providers: [ShippingService, PrismaService, RolesGuard],
  exports: [ShippingService],
})
export class ShippingModule {}