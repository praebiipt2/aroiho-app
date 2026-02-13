import { Body, Controller, Delete, Get, Param, Patch, Post, Put, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { AddressesService } from './addresses.service';
import { CreateAddressDto } from './dto/create-address.dto';
import { UpdateAddressDto } from './dto/update-address.dto';

@UseGuards(AuthGuard('jwt'))
@Controller('v1/addresses')
export class AddressesController {
  constructor(private readonly service: AddressesService) {}

  @Get()
  listMine(@Req() req: any) {
    const userId = req.user.id ?? req.user.sub;
    return this.service.listMine(userId);
  }

  @Post()
  createMine(@Req() req: any, @Body() dto: CreateAddressDto) {
    const userId = req.user.id ?? req.user.sub;
    return this.service.createMine(userId, dto);
  }

  @Put(':addressId')
  updateMine(@Req() req: any, @Param('addressId') addressId: string, @Body() dto: UpdateAddressDto) {
    const userId = req.user.id ?? req.user.sub;
    return this.service.updateMine(userId, addressId, dto);
  }

  @Delete(':addressId')
  deleteMine(@Req() req: any, @Param('addressId') addressId: string) {
    const userId = req.user.id ?? req.user.sub;
    return this.service.deleteMine(userId, addressId);
  }

  @Patch(':addressId/default')
  setDefault(@Req() req: any, @Param('addressId') addressId: string) {
    const userId = req.user.id ?? req.user.sub;
    return this.service.setDefault(userId, addressId);
  }
}