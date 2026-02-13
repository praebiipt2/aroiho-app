import { Body, Controller, Delete, Get, Param, Post, Put, Req, UseGuards } from '@nestjs/common';
import { CartService } from './cart.service';
import { AddCartItemDto } from './dto/add-cart-item.dto';
import { UpdateCartItemDto } from './dto/update-cart-item.dto';
import { AuthGuard } from '@nestjs/passport';

@UseGuards(AuthGuard('jwt'))
@Controller('v1/cart')
export class CartController {
  constructor(private readonly cartService: CartService) {}

  @Get()
  getCart(@Req() req: any) {
    return this.cartService.getMyCart(req.user.id);
  }

  @Post('items')
  addItem(@Req() req: any, @Body() dto: AddCartItemDto) {
    const userId = req.user.id ?? req.user.sub;
    return this.cartService.addItem(userId, dto);
  }

  @Put('items/:cartItemId')
  updateItem(@Req() req: any, @Param('cartItemId') cartItemId: string, @Body() dto: UpdateCartItemDto) {
    const userId = req.user.id ?? req.user.sub;
    return this.cartService.updateItem(userId, cartItemId, dto);
  }

  @Delete('items/:cartItemId')
  removeItem(@Req() req: any, @Param('cartItemId') cartItemId: string) {
    const userId = req.user.id ?? req.user.sub;
    return this.cartService.removeItem(userId, cartItemId);
  }
}