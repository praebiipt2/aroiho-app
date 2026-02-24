import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AddCartItemDto } from './dto/add-cart-item.dto';
import { UpdateCartItemDto } from './dto/update-cart-item.dto';

@Injectable()
export class CartService {
  constructor(private prisma: PrismaService) {}

  private async getOrCreateActiveCart(userId: string) {
    const existing = await this.prisma.cart.findFirst({
      where: { userId, status: 'ACTIVE' },
    });
    if (existing) return existing;

    return this.prisma.cart.create({
      data: { userId, status: 'ACTIVE' },
    });
  }

  async getMyCart(userId: string) {
    const cart = await this.prisma.cart.findFirst({
      where: { userId, status: 'ACTIVE' },
      include: {
        items: {
          include: {
            product: true,
            inventoryLot: true,
          },
        },
      },
    });

    // ถ้าไม่มี cart ให้คืน empty cart แบบสวย ๆ
    if (!cart) {
      return { id: null, status: 'EMPTY', items: [] };
    }
    return cart;
  }

  async addItem(userId: string, dto: AddCartItemDto) {
    const cart = await this.getOrCreateActiveCart(userId);

    // 1) validate lot
    const lot = await this.prisma.inventoryLot.findUnique({
      where: { id: dto.inventoryLotId },
      include: { product: true },
    });
    if (!lot || lot.status !== 'ACTIVE') {
      throw new NotFoundException('Inventory lot not found or not active');
    }
    if (lot.productId !== dto.productId) {
      throw new BadRequestException('productId does not match inventoryLotId');
    }
    if (Number(lot.quantityAvailable) < dto.quantity) {
      throw new BadRequestException('Not enough stock');
    }

    // 2) snapshot price (MVP ใช้ basePrice)
    const unitPrice = lot.product.basePrice;

    // 3) upsert item ด้วย unique(cartId, inventoryLotId)
    const item = await this.prisma.cartItem.upsert({
      where: {
        cartId_inventoryLotId: { cartId: cart.id, inventoryLotId: dto.inventoryLotId },
      },
      create: {
        cartId: cart.id,
        productId: dto.productId,
        inventoryLotId: dto.inventoryLotId,
        quantity: dto.quantity,
        unitPrice,
      },
      update: {
        quantity: { increment: dto.quantity },
      },
    });

    return item;
  }

  async updateItem(userId: string, cartItemId: string, dto: UpdateCartItemDto) {
    // หา item และเช็คว่าเป็นของ user (ผ่าน cart.userId)
    const item = await this.prisma.cartItem.findUnique({
      where: { id: cartItemId },
      include: { cart: true, inventoryLot: true },
    });
    if (!item || item.cart.userId !== userId) throw new NotFoundException('Cart item not found');

    // quantity=0 -> ลบ
    if (dto.quantity === 0) {
      await this.prisma.cartItem.delete({ where: { id: cartItemId } });
      return { deleted: true };
    }

    // เช็ค stock
    if (Number(item.inventoryLot.quantityAvailable) < dto.quantity) {
      throw new BadRequestException('Not enough stock');
    }

    return this.prisma.cartItem.update({
      where: { id: cartItemId },
      data: { quantity: dto.quantity },
    });
  }

  async removeItem(userId: string, cartItemId: string) {
    const item = await this.prisma.cartItem.findUnique({
      where: { id: cartItemId },
      include: { cart: true },
    });
    if (!item || item.cart.userId !== userId) throw new NotFoundException('Cart item not found');

    await this.prisma.cartItem.delete({ where: { id: cartItemId } });
    return { deleted: true };
  }
}