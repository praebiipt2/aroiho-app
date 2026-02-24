import { Controller, Get, Param, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ShippingService } from './shipping.service';

@UseGuards(AuthGuard('jwt'))
@Controller('v1/orders')
export class ShippingQueryController {
  constructor(private readonly shippingService: ShippingService) {}

  @Get(':orderId/shipment')
  getMyShipment(@Req() req: any, @Param('orderId') orderId: string) {
    const userId = req.user.id ?? req.user.sub;
    return this.shippingService.getMyShipment(userId, orderId);
  }
}