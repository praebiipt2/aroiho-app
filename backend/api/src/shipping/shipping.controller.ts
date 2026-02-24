import { Body, Controller, Param, Post, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ShippingService } from './shipping.service';
import { TransitionShipmentLegDto } from './dto/transition-leg.dto';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';

@UseGuards(AuthGuard('jwt'), RolesGuard)
@Controller('v1/orders')
export class ShippingController {
  constructor(private readonly shippingService: ShippingService) {}

  //เฉพาะ ADMIN/RIDER ปรับสถานะขนส่งได้
  @Roles('ADMIN', 'RIDER')
  @Post(':orderId/shipment/legs/:legId/transition')
  transitionLeg(
    @Req() req: any,
    @Param('orderId') orderId: string,
    @Param('legId') legId: string,
    @Body() dto: TransitionShipmentLegDto,
  ) {
    return this.shippingService.transitionLeg(orderId, legId, dto, req.user);
  }
}
