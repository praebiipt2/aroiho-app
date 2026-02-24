import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { CatalogModule } from './catalog/catalog.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { CartModule } from './cart/cart.module';
import { OrdersModule } from './orders/orders.module';
import { AddressesModule } from './addresses/addresses.module';
import { PaymentsModule } from './payments/payments.module';
import { TrackingModule } from './tracking/tracking.module';
import { ShippingModule } from './shipping/shipping.module';


@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),
    PrismaModule,
    CatalogModule,
    AuthModule,
    UsersModule,
    CartModule,
    OrdersModule,
    AddressesModule,
    PaymentsModule,
    TrackingModule,
    ShippingModule,
  ],
})
export class AppModule {}
