import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { CatalogService } from './catalog.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

type SellerProductDto = {
  categoryId: string;
  name: string;
  unit: string;
  basePrice: number;
  description?: string;
  thumbnailUrl?: string;
  isActive?: boolean;
};

type SellerApplyDto = {
  name: string;
  phone?: string;
  addressText?: string;
  type?: string;
  taxId?: string;
  coverImageUrl?: string;
  aboutText?: string;
  lat?: number | null;
  lng?: number | null;
};

type SellerUpdateDto = {
  name?: string;
  phone?: string;
  addressText?: string;
  type?: string;
  taxId?: string;
  coverImageUrl?: string;
  aboutText?: string;
  lat?: number | null;
  lng?: number | null;
};

type SellerLotCreateDto = {
  lotCode?: string;
  harvestedAt?: string;
  packedAt?: string;
  expiresAt?: string;
  recommendedConsumeBefore?: string;
  storageCondition?: string;
  quantityAvailable: number;
  status?: string;
};

type SellerLotUpdateDto = {
  lotCode?: string;
  harvestedAt?: string | null;
  packedAt?: string | null;
  expiresAt?: string | null;
  recommendedConsumeBefore?: string | null;
  storageCondition?: string | null;
  quantityAvailable?: number;
  status?: string;
};

type StartPromotionDto = {
  productId: string;
  planCode: string;
  days: number;
  note?: string;
};

@Controller()
export class CatalogController {
  constructor(private readonly catalogService: CatalogService) {}

  @Get('categories')
  listCategories() {
    return this.catalogService.listCategories();
  }

  @Get('products')
  listProducts(
    @Query('categoryId') categoryId?: string,
    @Query('q') q?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.catalogService.listProducts({
      categoryId,
      q,
      page: page ? Number(page) : 1,
      limit: limit ? Number(limit) : 20,
    });
  }

  @Get('products/:id')
  getProductDetail(@Param('id') id: string) {
    return this.catalogService.getProductDetail(id);
  }

  @Get('sellers/:id')
  getSellerInfo(@Param('id') id: string) {
    return this.catalogService.getSellerInfo(id);
  }

  @Get('sellers/:id/products')
  listSellerProducts(
    @Param('id') id: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.catalogService.listProductsBySeller(id, {
      page: page ? Number(page) : 1,
      limit: limit ? Number(limit) : 20,
    });
  }

  @UseGuards(JwtAuthGuard)
  @Get('v1/seller/me')
  getMySeller(@Req() req: any) {
    return this.catalogService.getMySeller(req.user.sub);
  }

  @UseGuards(JwtAuthGuard)
  @Post('v1/seller/apply')
  applySeller(@Req() req: any, @Body() dto: SellerApplyDto) {
    return this.catalogService.applySeller(req.user.sub, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('v1/seller/me')
  updateMySeller(@Req() req: any, @Body() dto: SellerUpdateDto) {
    return this.catalogService.updateMySeller(req.user.sub, req.user.role, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get('v1/seller/products')
  listMySellerProducts(
    @Req() req: any,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.catalogService.listManagedProducts(
      req.user.sub,
      req.user.role,
      page ? Number(page) : 1,
      limit ? Number(limit) : 30,
    );
  }

  @UseGuards(JwtAuthGuard)
  @Get('v1/seller/dashboard')
  getSellerDashboard(@Req() req: any, @Query('days') days?: string) {
    return this.catalogService.getSellerDashboard(
      req.user.sub,
      req.user.role,
      days ? Number(days) : 7,
    );
  }

  @UseGuards(JwtAuthGuard)
  @Get('v1/seller/promotions')
  listMyPromotions(@Req() req: any, @Query('status') status?: string) {
    return this.catalogService.listMyPromotionCampaigns(
      req.user.sub,
      req.user.role,
      status,
    );
  }

  @UseGuards(JwtAuthGuard)
  @Post('v1/seller/promotions/start')
  startMyPromotion(@Req() req: any, @Body() dto: StartPromotionDto) {
    return this.catalogService.startPromotionCampaign(
      req.user.sub,
      req.user.role,
      dto,
    );
  }

  @UseGuards(JwtAuthGuard)
  @Post('v1/seller/products')
  createMySellerProduct(@Req() req: any, @Body() dto: SellerProductDto) {
    return this.catalogService.createManagedProduct(req.user.sub, req.user.role, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('v1/seller/products/:id')
  updateMySellerProduct(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: Partial<SellerProductDto>,
  ) {
    return this.catalogService.updateManagedProduct(req.user.sub, req.user.role, id, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('v1/seller/products/:id/toggle-active')
  toggleMySellerProduct(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { isActive: boolean },
  ) {
    return this.catalogService.toggleManagedProduct(
      req.user.sub,
      req.user.role,
      id,
      !!body.isActive,
    );
  }

  @UseGuards(JwtAuthGuard)
  @Post('v1/seller/products/:id/claim')
  claimMySellerProduct(@Req() req: any, @Param('id') id: string) {
    return this.catalogService.claimManagedProduct(req.user.sub, req.user.role, id);
  }

  @UseGuards(JwtAuthGuard)
  @Get('v1/seller/products/:productId/lots')
  listMyProductLots(
    @Req() req: any,
    @Param('productId') productId: string,
  ) {
    return this.catalogService.listManagedLots(req.user.sub, req.user.role, productId);
  }

  @UseGuards(JwtAuthGuard)
  @Post('v1/seller/products/:productId/lots')
  createMyProductLot(
    @Req() req: any,
    @Param('productId') productId: string,
    @Body() dto: SellerLotCreateDto,
  ) {
    return this.catalogService.createManagedLot(
      req.user.sub,
      req.user.role,
      productId,
      dto,
    );
  }

  @UseGuards(JwtAuthGuard)
  @Patch('v1/seller/lots/:lotId')
  updateMyLot(
    @Req() req: any,
    @Param('lotId') lotId: string,
    @Body() dto: SellerLotUpdateDto,
  ) {
    return this.catalogService.updateManagedLot(req.user.sub, req.user.role, lotId, dto);
  }
}
