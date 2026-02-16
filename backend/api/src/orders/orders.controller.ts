import { Body, Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { OrdersService } from './orders.service';

@UseGuards(AuthGuard('jwt'))
@Controller('v1/orders')
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) {}

  @Post('checkout')
  checkout(@Req() req: any, @Body() body: { addressId: string }) {
    const userId = req.user.id ?? req.user.sub;
    return this.ordersService.checkout(userId, body.addressId);
  }

  // ✅ Cancel (เฉพาะยังไม่จ่าย) + คืน stock
    @Post(':orderId/cancel')
    cancel(@Req() req: any, @Param('orderId') orderId: string) {
      const userId = req.user.id ?? req.user.sub;
      return this.ordersService.cancel(userId, orderId);
  }

  @Post(':orderId/refund')
  refund(@Req() req: any, @Param('orderId') orderId: string) {
    const userId = req.user.id ?? req.user.sub;
    return this.ordersService.refund(userId, orderId);
}

  @Get(':orderId')
  getOrder(@Req() req: any, @Param('orderId') orderId: string) {
    const userId = req.user.id ?? req.user.sub;
    return this.ordersService.getOrder(userId, orderId);
  }

  @Get()
  listMyOrders(@Req() req: any) {
    const userId = req.user.id ?? req.user.sub;
    return this.ordersService.listMyOrders(userId);
  }
}