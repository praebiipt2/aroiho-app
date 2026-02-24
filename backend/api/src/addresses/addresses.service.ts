import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateAddressDto } from './dto/create-address.dto';
import { UpdateAddressDto } from './dto/update-address.dto';

@Injectable()
export class AddressesService {
  constructor(private readonly prisma: PrismaService) {}

  async listMine(userId: string) {
    return this.prisma.address.findMany({
      where: { userId },
      orderBy: [{ isDefault: 'desc' }, { createdAt: 'desc' }],
    });
  }

  async createMine(userId: string, dto: CreateAddressDto) {
    const wantDefault = dto.isDefault === true;

    return this.prisma.$transaction(async (tx) => {
      if (wantDefault) {
        await tx.address.updateMany({
          where: { userId, isDefault: true },
          data: { isDefault: false },
        });
      }

      return tx.address.create({
        data: {
          userId,
          label: dto.label,
          receiverName: dto.receiverName,
          phone: dto.phone,
          addressLine1: dto.addressLine1,
          addressLine2: dto.addressLine2,
          province: dto.province,
          district: dto.district,
          subdistrict: dto.subdistrict,
          postcode: dto.postcode,
          lat: dto.lat,
          lng: dto.lng,
          isDefault: wantDefault,
        },
      });
    });
  }

  async updateMine(userId: string, addressId: string, dto: UpdateAddressDto) {
    const found = await this.prisma.address.findUnique({ where: { id: addressId } });
    if (!found || found.userId !== userId) throw new NotFoundException('Address not found');

    const wantDefault = dto.isDefault === true;

    return this.prisma.$transaction(async (tx) => {
      if (wantDefault) {
        await tx.address.updateMany({
          where: { userId, isDefault: true },
          data: { isDefault: false },
        });
      }

      return tx.address.update({
        where: { id: addressId },
        data: {
          ...dto,
          isDefault: dto.isDefault ?? undefined,
        },
      });
    });
  }

  async deleteMine(userId: string, addressId: string) {
    const found = await this.prisma.address.findUnique({ where: { id: addressId } });
    if (!found || found.userId !== userId) throw new NotFoundException('Address not found');

    await this.prisma.address.delete({ where: { id: addressId } });
    return { deleted: true };
  }

  async setDefault(userId: string, addressId: string) {
    const found = await this.prisma.address.findUnique({ where: { id: addressId } });
    if (!found || found.userId !== userId) throw new NotFoundException('Address not found');

    return this.prisma.$transaction(async (tx) => {
      await tx.address.updateMany({
        where: { userId, isDefault: true },
        data: { isDefault: false },
      });
      return tx.address.update({
        where: { id: addressId },
        data: { isDefault: true },
      });
    });
  }
}