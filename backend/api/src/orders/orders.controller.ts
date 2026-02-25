import { Body, Controller, Get, Param, Post, Query, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { OrdersService } from './orders.service';
import { TransitionOrderDto } from './dto/transition-order.dto';
import { CheckoutDto } from './dto/checkout.dto';
import { ShippingMethod } from '@prisma/client';

@UseGuards(AuthGuard('jwt'))
@Controller('v1/orders')
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) {}

  @Post('checkout')
  checkout(@Req() req: any, @Body() dto: CheckoutDto) {
    const userId = req.user.id ?? req.user.sub;

    return this.ordersService.checkout(
      userId,
      dto.addressId,
      dto.shippingMethod ?? ShippingMethod.AUTO,
      dto.shippingSurcharge ?? 0,
    );
  }

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

  @Post(':orderId/transition')
  transition(@Param('orderId') orderId: string, @Req() req: any, @Body() dto: TransitionOrderDto) {
    const userId = req.user.id ?? req.user.sub;
    return this.ordersService.transition(orderId, userId, dto);
  }

  // specific route ต้องอยู่ก่อน :orderId
  @Get(':orderId/history')
  getHistory(@Req() req: any, @Param('orderId') orderId: string) {
    const userId = req.user.id ?? req.user.sub;
    return this.ordersService.getHistory(userId, orderId);
  }

  @Get(':orderId')
  getOrder(@Req() req: any, @Param('orderId') orderId: string) {
    const userId = req.user.id ?? req.user.sub;
    return this.ordersService.getOrder(userId, orderId);
  }

  @Get()
  listMyOrders(
    @Req() req: any,
    @Query('includeHidden') includeHidden?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const userId = req.user.id ?? req.user.sub;
    const pageNum = Number.parseInt(page ?? '1', 10);
    const limitNum = Number.parseInt(limit ?? '10', 10);
    return this.ordersService.listMyOrders(userId, {
      includeHidden: includeHidden === 'true',
      page: Number.isFinite(pageNum) ? pageNum : 1,
      limit: Number.isFinite(limitNum) ? limitNum : 10,
    });
  }

  @Post(':orderId/hide')
  hide(@Req() req: any, @Param('orderId') orderId: string) {
    const userId = req.user.id ?? req.user.sub;
    return this.ordersService.hideOrder(userId, orderId);
  }

  @Post(':orderId/unhide')
  unhide(@Req() req: any, @Param('orderId') orderId: string) {
    const userId = req.user.id ?? req.user.sub;
    return this.ordersService.unhideOrder(userId, orderId);
  }

  @Post(':orderId/delete')
  softDelete(@Req() req: any, @Param('orderId') orderId: string) {
    const userId = req.user.id ?? req.user.sub;
    return this.ordersService.softDeleteOrder(userId, orderId);
  }

  @Post(':orderId/restore')
  restoreDeleted(@Req() req: any, @Param('orderId') orderId: string) {
    const userId = req.user.id ?? req.user.sub;
    return this.ordersService.restoreDeletedOrder(userId, orderId);
  }

  @Get(':orderId/shipment')
  getShipment(@Req() req: any, @Param('orderId') orderId: string) {
    const userId = req.user.id ?? req.user.sub;
    return this.ordersService.getMyShipment(userId, orderId);
  }
}
